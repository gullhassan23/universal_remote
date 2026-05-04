import 'dart:async';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/utils/userId.dart';

class AdaptyService extends GetxService {
  static const String _logTag = '[ADAPTY]';
  final Adapty _adapty = Adapty();
  StreamSubscription<AdaptyProfile>? _profileUpdatesSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    final String apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      _log('SDK key missing in .env. Skipping activation.');
      return;
    }

    try {
      final String userId = await getOrCreateUserId();
      final bool alreadyActivated =
          kDebugMode ? await _adapty.isActivated() : false;

      if (alreadyActivated) {
        _adapty.setupAfterHotRestart();
      } else {
        final configuration = AdaptyConfiguration(apiKey: apiKey)
          ..withObserverMode(true)
          ..withLogLevel(
              kDebugMode ? AdaptyLogLevel.verbose : AdaptyLogLevel.info)
          ..withCustomerUserId(userId);
        await _adapty.activate(configuration: configuration);
      }

      await _adapty.identify(userId);
      _profileUpdatesSub ??= _adapty.didUpdateProfileStream.listen(
        (AdaptyProfile profile) =>
            unawaited(_applyProfile(profile, source: 'didUpdateProfile')),
        onError: (Object error, StackTrace stackTrace) {
          _log('Profile stream error: $error');
        },
      );

      final AdaptyProfile profile = await _adapty.getProfile();
      await _applyProfile(profile, source: 'initialize');
      _log('Activated successfully.');
    } catch (error) {
      _log('Initialization failed: $error');
    }
  }

  Future<void> identifyCurrentUser() async {
    if (kIsWeb) return;
    try {
      final String userId = await getOrCreateUserId();
      await _adapty.identify(userId);
    } catch (error) {
      _log('identifyCurrentUser failed: $error');
    }
  }

  Future<void> syncProfileToPremiumState(
      {String source = 'manual_sync'}) async {
    if (kIsWeb) return;
    try {
      final AdaptyProfile profile = await _adapty.getProfile();
      await _applyProfile(profile, source: source);
    } catch (error) {
      _log('syncProfileToPremiumState failed: $error');
    }
  }

  Future<void> reportTransactionIfNeeded({
    required String transactionId,
    String? variationId,
  }) async {
    if (kIsWeb || transactionId.isEmpty) return;
    try {
      await _adapty.reportTransaction(
        transactionId: transactionId,
        variationId: variationId,
      );
    } catch (error) {
      _log('reportTransactionIfNeeded failed: $error');
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    try {
      final AdaptyProfile profile = await _adapty.restorePurchases();
      await _applyProfile(profile, source: 'restorePurchases');
    } catch (error) {
      _log('restorePurchases failed: $error');
    }
  }

  String _resolveApiKey() {
    if (!kIsWeb && Platform.isIOS) {
      final String iosKey = dotenv.env['ADAPTY_SDK_KEY_IOS']?.trim() ?? '';
      if (iosKey.isNotEmpty) return iosKey;
    }
    if (!kIsWeb && Platform.isAndroid) {
      final String androidKey =
          dotenv.env['ADAPTY_SDK_KEY_ANDROID']?.trim() ?? '';
      if (androidKey.isNotEmpty) return androidKey;
    }
    return dotenv.env['ADAPTY_SDK_KEY']?.trim() ?? '';
  }

  Future<void> _applyProfile(AdaptyProfile profile,
      {required String source}) async {
    if (!Get.isRegistered<PremiumController>()) return;
    final PremiumController premiumController = Get.find<PremiumController>();

    final String configuredAccessLevelId =
        dotenv.env['ADAPTY_ACCESS_LEVEL_ID']?.trim() ?? 'premium';
    final AdaptyAccessLevel? accessLevel =
        profile.accessLevels[configuredAccessLevelId] ??
            (profile.accessLevels.isNotEmpty
                ? profile.accessLevels.values.first
                : null);

    final bool isPremium = accessLevel?.isActive == true;
    final bool hasLocalPremium = premiumController.isPremium.value;

    // Adapty profile can transiently report inactive right after purchase/restore
    // before all stores/backends are fully synchronized. Do not overwrite a
    // locally verified premium=true state with this temporary false signal.
    if (!isPremium && hasLocalPremium) {
      _log(
        'Profile sync ($source) reported inactive access level; '
        'keeping existing local premium state to avoid false downgrade.',
      );
      return;
    }

    await premiumController.setPremium(
      enabled: isPremium,
      productId: isPremium ? accessLevel?.vendorProductId : null,
      autoRenew: accessLevel?.willRenew,
      expiryDate: isPremium ? accessLevel?.expiresAt?.toUtc() : null,
      purchaseDate: accessLevel?.activatedAt.toUtc(),
    );
    _log(
      'Profile synced ($source): isPremium=$isPremium accessLevel=${accessLevel?.id}',
    );
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }

  @override
  void onClose() {
    _profileUpdatesSub?.cancel();
    super.onClose();
  }
}
