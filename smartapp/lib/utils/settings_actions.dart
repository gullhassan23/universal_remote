import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/subscription_iap_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsActions {
  static const String defaultTermsConditionsUrl =
      'https://docs.google.com/document/d/12WTnUBG0hlYkg5fRPIwxP4VnNkUhv_gnC19ulCfgHic/edit?tab=t.0';
  static const String _iosTermsConditionsUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const String _iosPrivacyPolicyUrl =
      'https://maxgamesproduction.blogspot.com/2023/01/privacy-policy.html';

  static AnalyticsService? _analyticsOrNull() {
    if (Get.isRegistered<AnalyticsService>()) {
      return Get.find<AnalyticsService>();
    }
    return null;
  }

  static Future<void> openPrivacyPolicy({
    String screenName = 'Unknown',
  }) async {
    unawaited(
      _analyticsOrNull()?.trackClick(
            'PrivacyPolicy',
            screenName: screenName,
          ) ??
          Future.value(),
    );

    final bool isIos = !kIsWeb && Platform.isIOS;
    final String? privacyUrl = isIos
        ? _iosPrivacyPolicyUrl
        : dotenv.env['PRIVACY_POLICY_URL']?.trim();
    if (privacyUrl == null || privacyUrl.isEmpty) {
      Get.snackbar('Error', 'Privacy policy URL is missing.');
      return;
    }

    final uri = Uri.tryParse(privacyUrl);
    if (uri == null) {
      Get.snackbar('Error', 'Privacy policy URL is invalid.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Get.snackbar('Error', 'Unable to open privacy policy.');
    }
  }

  static Future<void> openTermsAndConditions({
    String screenName = 'Unknown',
  }) async {
    unawaited(
      _analyticsOrNull()?.trackClick(
            'TermsAndConditions',
            screenName: screenName,
          ) ??
          Future.value(),
    );

    final bool isIos = !kIsWeb && Platform.isIOS;
    final String termsUrl = isIos
        ? _iosTermsConditionsUrl
        : (dotenv.env['TERMS_CONDITIONS_URL'] ??
                dotenv.env['TERMS_AND_CONDITIONS_URL'] ??
                defaultTermsConditionsUrl)
            .trim();

    final uri = Uri.tryParse(termsUrl);
    if (uri == null) {
      Get.snackbar('Error', 'Terms & Conditions URL is invalid.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Get.snackbar('Error', 'Unable to open Terms & Conditions.');
    }
  }

  static Future<void> restorePurchases({
    SubscriptionIAPService? iapService,
    String screenName = 'Unknown',
  }) async {
    unawaited(
      _analyticsOrNull()?.trackClick(
            'RestorePurchases',
            screenName: screenName,
          ) ??
          Future.value(),
    );

    final service = iapService ??
        (Get.isRegistered<SubscriptionIAPService>()
            ? Get.find<SubscriptionIAPService>()
            : null);

    if (service == null) {
      Get.snackbar('Restore purchases', 'Purchase service not available.');
      return;
    }

    await service.restorePurchases();
    if (service.lastError.value != null) {
      Get.snackbar('Restore purchases', service.lastError.value!);
      return;
    }
    Get.snackbar(
      'Restore purchases',
      'Restore started. We will unlock premium after verification.',
    );
  }
}

