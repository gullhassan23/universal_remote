import 'dart:async';

import 'package:get/get.dart';

import 'tv_connection_controller.dart';

class SleepTimerController extends GetxController {
  SleepTimerController({TvConnectionController? connectionController})
    : _connectionController =
          connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;

  final RxBool isRunning = false.obs;
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
    final sent = await _connectionController.sendKey('KEY_POWER');
    if (!sent) {
      await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
      await _connectionController.sendKey('KEY_POWER');
    }
    _resetState();
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
