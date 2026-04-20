import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import '../../models/tv_device.dart';
import '../../services/tv_service_interface.dart';
import '../../services/unified_tv_service.dart';
import '../../services/android_tv/android_tv_remote_platform.dart';
import '../../controllers/tv_connection_controller.dart';
import '../remote/remote_screen.dart';

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

  void setPreferredBrand(TvBrand brand) {
    _preferredBrand = brand;
  }

  Future<void> discoverDevices() async {
    isLoading.value = true;
    errorMessage.value = '';
    devices.clear();

    try {
      final results = await _connectionController.discoverCastTargets(
        filterBrand: _preferredBrand,
      );
      if (results.isEmpty) {
        errorMessage.value =
            'No TVs found.\nMake sure your phone and TV are on the same WiFi network.';
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
    _showConnectionLoader(device);
    AndroidTvRemotePlatform.instance.setOnPairingPromptRequested(() {
      _hideConnectionLoader();
    });
    final success = await _connectionController.connectCastTarget(device);
    AndroidTvRemotePlatform.instance.setOnPairingPromptRequested(null);
    _hideConnectionLoader();
    if (success) {
      Get.snackbar(
        colorText: Colors.white,
        'Connected',
        'Connected to ${device.name}.',
      );
      if (navigateToRemote) {
        Get.to(() => const RemoteScreen());
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
      final isAndroidPairingCodeError = device.brand == TvBrand.androidTv &&
          (normalizedError.contains('pair') ||
              normalizedError.contains('password') ||
              normalizedError.contains('pin') ||
              normalizedError.contains('code'));
      final androidPairingHint =
          'On Android, use the same Wi‑Fi as the TV, accept pairing on the TV, and enter the PIN shown on screen. '
          'If pairing fails, your code may be incorrect/expired, so enter the latest 6-character code again.';
      final hint = device.brand == TvBrand.androidTv
          ? '$androidPairingHint iOS is not supported for Android TV control yet.'
          : 'Please ensure the TV is on and try again.';
      final reason = (detailedError != null && detailedError.isNotEmpty)
          ? '\nReason: $detailedError'
          : '';
      final title =
          isAndroidPairingCodeError ? 'Incorrect password' : 'Connection failed';
      final message = isAndroidPairingCodeError
          ? 'Code is not correct or has expired. Please enter the latest code shown on your TV and try again.'
          : 'Unable to connect to ${device.name}. $hint$reason';
      Get.snackbar(
        colorText: Colors.white,

        title,
        message,
      );
      if (detailedError != null && detailedError.isNotEmpty) {
        // ignore: avoid_print
        print('DeviceDiscoveryController.connectTo error: $detailedError');
      }
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
