import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';

class SleepTimerController extends GetxController {
  SleepTimerController({TvConnectionController? connectionController})
    : _connectionController =
          connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;

  final RxBool isRunning = false.obs;
  final RxnBool lastCompletionSucceeded = RxnBool();
  final Rx<Duration> remaining = Duration.zero.obs;
  final Rxn<Duration> selectedDuration = Rxn<Duration>();
  final Rxn<DateTime> targetEndTime = Rxn<DateTime>();

  Timer? _ticker;

  String get remainingLabel {
    final current = remaining.value;
    if (current <= Duration.zero) return '00:00';
    final hours = current.inHours;
    final minutes = current.inMinutes.remainder(60);
    final seconds = current.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get endTimeLabel {
    final end = targetEndTime.value;
    if (end == null) return '--:--';
    final hour = end.hour.toString().padLeft(2, '0');
    final minute = end.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void start(Duration duration) {
    if (duration <= Duration.zero) return;
    _cancelTicker();
    lastCompletionSucceeded.value = null;
    selectedDuration.value = duration;
    targetEndTime.value = DateTime.now().add(duration);
    isRunning.value = true;
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void cancel() {
    _cancelTicker();
    _resetState();
  }

  void reset(Duration? nextDuration) {
    cancel();
    if (nextDuration != null) {
      start(nextDuration);
    }
  }

  void _tick() {
    final end = targetEndTime.value;
    if (end == null) {
      cancel();
      return;
    }

    final left = end.difference(DateTime.now());
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      _cancelTicker();
      _completeTimer();
      return;
    }
    remaining.value = left;
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _completeTimer() async {
    final sent = await _sendPowerReliablyForSleepTimer();
    lastCompletionSucceeded.value = sent;
    if (kDebugMode) {
      // ignore: avoid_print
      print('SleepTimerController: completeTimer powerSent=$sent');
    }
    _resetState();
  }

  Future<bool> _sendPowerReliablyForSleepTimer() async {
    Future<bool> sendPowerKeys() async {
      final sentTvPower = await _connectionController.sendKey('KEY_POWER');
      await Future<void>.delayed(const Duration(milliseconds: 90));
      final sentAndroidPower =
          await _connectionController.sendKey('KEY_ANDROID_POWER');
      return sentTvPower || sentAndroidPower;
    }

    if (await sendPowerKeys()) return true;

    // Long-running timers can keep stale "connected" state while the transport
    // is already dead. Force reconnect to current device before restore.
    final currentDevice = _connectionController.currentDevice.value;
    if (currentDevice != null) {
      final reconnected = await _connectionController.connectTo(currentDevice);
      if (reconnected && await sendPowerKeys()) return true;
    }

    final restored =
        await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
    if (!restored) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SleepTimerController: restore failed after power send failure');
      }
      return false;
    }

    return sendPowerKeys();
  }

  void _resetState() {
    isRunning.value = false;
    remaining.value = Duration.zero;
    selectedDuration.value = null;
    targetEndTime.value = null;
  }

  @override
  void onClose() {
    _cancelTicker();
    super.onClose();
  }
}
