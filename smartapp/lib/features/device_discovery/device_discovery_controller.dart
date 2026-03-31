import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import '../../models/tv_device.dart';
import '../../services/tv_service_interface.dart';
import '../../services/unified_tv_service.dart';
import '../../controllers/tv_connection_controller.dart';
import '../remote/remote_screen.dart';
import 'sony_pairing_dialog.dart';

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

  void setPreferredBrand(TvBrand brand) {
    _preferredBrand = brand;
  }

  Future<void> discoverDevices() async {
    isLoading.value = true;
    errorMessage.value = '';
    devices.clear();

    try {
      final results =
          await _tvService.discoverDevices(filterBrand: _preferredBrand);
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
    TvDevice deviceToUse = device;
    if (device.brand == TvBrand.sony &&
        (device.token == null || device.token!.isEmpty)) {
      final context = Get.context;
      if (context == null) return false;
      final psk = await showSonyPairingDialog(context);
      if (psk == null || psk.isEmpty) return false;
      deviceToUse = device.copyWith(token: psk);
    }

    final success = await _connectionController.connectTo(deviceToUse);
    if (success) {
      Get.snackbar(
        colorText: Colors.white,
        'Connected',
        'Connected to ${deviceToUse.name}.',
      );
      if (navigateToRemote) {
        Get.to(() => const RemoteScreen());
      }
      return true;
    } else {
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
      final hint = device.brand == TvBrand.sony
          ? 'Ensure the TV is on and the Pre-Shared Key is set in TV Settings > Network > IP Control.'
          : device.brand == TvBrand.androidTv
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
}
