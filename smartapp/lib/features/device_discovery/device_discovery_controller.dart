import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import '../../models/tv_device.dart';
import '../../services/tv_service_interface.dart';
import '../../services/unified_tv_service.dart';
import '../../services/android_tv/android_tv_remote_platform.dart';
import '../../controllers/tv_connection_controller.dart';
import '../remote/remote_screen_switcher.dart';

class DeviceDiscoveryController extends GetxController {
  DeviceDiscoveryController({
    ITvService? tvService,
    TvConnectionController? connectionController,
  })  : _tvService = tvService ?? Get.find<ITvService>(),
        _connectionController =
            connectionController ?? Get.find<TvConnectionController>();

  final ITvService _tvService;
  final TvConnectionController _connectionController;
  /// The brand the user selected on the home screen, used to filter discovery.
  TvBrand? _preferredBrand;

  final RxList<TvDevice> devices = <TvDevice>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  bool _isConnectingLoaderVisible = false;
  Future<void>? _discoverInFlight;
  static const int _maxDiscoveryAttempts = 3;
  static const Duration _discoveryRetryDelay = Duration(milliseconds: 700);
  static const int _maxConnectAttempts = 2;
  static const Duration _connectRetryDelay = Duration(milliseconds: 500);
  static const String _genericDiscoveryHint =
      'No TVs found.\nMake sure your phone and TV are on the same WiFi network.';

  void _log(String message) {
    // ignore: avoid_print
    print('DeviceDiscoveryController: $message');
  }

  void setPreferredBrand(TvBrand brand) {
    _preferredBrand = brand;
  }

  String? _sanitizeDiscoveryError(String? rawError) {
    if (rawError == null || rawError.trim().isEmpty) return null;
    final normalized = rawError.toLowerCase();
    if (normalized.contains('android tv') ||
        normalized.contains('mdns') ||
        normalized.contains('supported on android only')) {
      return null;
    }
    return rawError;
  }

  Future<void> discoverDevices() async {
    if (_discoverInFlight != null) {
      await _discoverInFlight;
      return;
    }
    _discoverInFlight = _discoverDevicesImpl();
    try {
      await _discoverInFlight;
    } finally {
      _discoverInFlight = null;
    }
  }

  Future<void> _discoverDevicesImpl() async {
    isLoading.value = true;
    errorMessage.value = '';
    devices.clear();

    try {
      var results = <TvDevice>[];
      for (var attempt = 1; attempt <= _maxDiscoveryAttempts; attempt++) {
        _log(
          'discoverDevices attempt=$attempt/$_maxDiscoveryAttempts brand=${_preferredBrand?.name ?? 'all'}',
        );
        results = await _connectionController.discoverCastTargets(
          filterBrand: _preferredBrand,
        );
        _log('discoverDevices attempt=$attempt found=${results.length}');
        if (results.isNotEmpty) {
          break;
        }
        if (attempt < _maxDiscoveryAttempts) {
          await Future<void>.delayed(_discoveryRetryDelay);
        }
      }
      if (results.isEmpty) {
        final detailedErrorRaw = _tvService is UnifiedTvService
            ? (_tvService as UnifiedTvService).getLastErrorMessage()
            : null;
        final detailedError = _sanitizeDiscoveryError(detailedErrorRaw);
        errorMessage.value = (detailedError != null && detailedError.isNotEmpty)
            ? 'No TVs found.\n$detailedError'
            : _genericDiscoveryHint;
      }
      devices.assignAll(results);
    } catch (e) {
      errorMessage.value = 'Failed to discover devices: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> connectTo(TvDevice device,
      {bool navigateToRemote = true}) async {
    _log('connectTo start name=${device.name} ip=${device.ip} brand=${device.brand.name}');
    _showConnectionLoader(device);
    AndroidTvRemotePlatform.instance.setOnPairingPromptRequested(() {
      _log('pairing prompt requested by native layer');
      _hideConnectionLoader();
    });
    var success = false;
    for (var attempt = 1; attempt <= _maxConnectAttempts; attempt++) {
      _log('connectTo attempt=$attempt/$_maxConnectAttempts device=${device.name}');
      success = await _connectionController.connectCastTarget(device);
      _log('connectTo attempt=$attempt success=$success');
      if (success) {
        break;
      }
      final liveError = _tvService is UnifiedTvService
          ? (_tvService as UnifiedTvService).getLastErrorMessage()
          : null;
      final liveErrorNormalized = (liveError ?? '').toLowerCase();
      final isPlatformUnsupported =
          liveErrorNormalized.contains('supported on android only');
      if (isPlatformUnsupported) {
        _log('connectTo stop retrying due to platform restriction');
        break;
      }
      if (attempt < _maxConnectAttempts) {
        await Future<void>.delayed(_connectRetryDelay);
      }
    }
    AndroidTvRemotePlatform.instance.setOnPairingPromptRequested(null);
    _hideConnectionLoader();
    if (success) {
      _log('connectTo success device=${device.name}');
      Get.snackbar(
        colorText: Colors.white,
        'Connected',
        'Connected to ${device.name}.',
      );
      if (navigateToRemote) {
        Get.to(() => const RemoteScreenSwitcher());
      }
      return true;
    } else {
      final reconnectNotice = _connectionController.consumeReconnectNotice();
      if (reconnectNotice != null && reconnectNotice.isNotEmpty) {
        Get.snackbar(
          colorText: Colors.white,
          'Connection update',
          reconnectNotice,
        );
      }
      final detailedError = _tvService is UnifiedTvService
          ? (_tvService as UnifiedTvService).getLastErrorMessage()
          : null;
      final normalizedError = (detailedError ?? '').toLowerCase();
      final isPlatformUnsupportedError =
          normalizedError.contains('supported on android only');
      final isAndroidPairingCodeError = device.brand == TvBrand.androidTv &&
          !isPlatformUnsupportedError &&
          (normalizedError.contains('pair') ||
              normalizedError.contains('password') ||
              normalizedError.contains('pin') ||
              normalizedError.contains('code'));
      final androidPairingHint =
          'Use the same Wi‑Fi as the TV, accept pairing on the TV, and enter the PIN shown on screen. '
          'If pairing fails, your code may be incorrect/expired, so enter the latest 6-character code again.';
      final hint = device.brand == TvBrand.androidTv
          ? '$androidPairingHint This connection method is not available on this device.'
          : 'Please ensure the TV is on and try again.';
      final reason = (detailedError != null && detailedError.isNotEmpty)
          ? '\nReason: $detailedError'
          : '';
      final title = isPlatformUnsupportedError
          ? 'Connection unavailable'
          : (isAndroidPairingCodeError
              ? 'Incorrect password'
              : 'Connection failed');
      final message = isPlatformUnsupportedError
          ? 'This connection method is currently unavailable on this platform.'
          : (isAndroidPairingCodeError
              ? 'Code is not correct or has expired. Please enter the latest code shown on your TV and try again.'
              : 'Unable to connect to ${device.name}. $hint$reason');
      Get.snackbar(
        colorText: Colors.white,

        title,
        message,
      );
      if (detailedError != null && detailedError.isNotEmpty) {
        _log('connectTo detailedError=$detailedError');
      }
      _log('connectTo failed device=${device.name} reason=${detailedError ?? 'unknown'}');
      return false;
    }
  }

  void _showConnectionLoader(TvDevice device) {
    if (_isConnectingLoaderVisible) return;
    _isConnectingLoaderVisible = true;
    Get.dialog<void>(
      PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  device.brand == TvBrand.androidTv
                      ? 'Connecting to ${device.name}...\nWaiting for pairing code on TV.'
                      : 'Connecting to ${device.name}...',
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _hideConnectionLoader() {
    if (!_isConnectingLoaderVisible) return;
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
    _isConnectingLoaderVisible = false;
  }
}
