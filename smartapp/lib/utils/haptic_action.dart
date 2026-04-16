import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';

class HapticAction {
  const HapticAction._();

  static void vibrate() {
    if (!Get.isRegistered<VibrationController>()) return;
    Get.find<VibrationController>().vibrate();
  }

  static VoidCallback wrap(VoidCallback callback) {
    return () {
      vibrate();
      callback();
    };
  }
}
