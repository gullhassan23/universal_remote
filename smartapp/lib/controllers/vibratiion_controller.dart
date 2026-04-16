import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class VibrationController extends GetxController {
  final RxBool isHapticEnabled = true.obs;
  bool _supportsVibration = false;

  @override
  void onInit() {
    super.onInit();
    _loadVibrationSupport();
  }

  Future<void> _loadVibrationSupport() async {
    _supportsVibration = await Vibration.hasVibrator() ?? false;
  }

  void toggleHaptic(bool value) {
    isHapticEnabled.value = value;
  }

  Future<void> vibrate() async {
    if (!isHapticEnabled.value) return;

    if (_supportsVibration) {
      await Vibration.vibrate(duration: 30, amplitude: 64);
      return;
    }

    await HapticFeedback.mediumImpact();
  }
}
