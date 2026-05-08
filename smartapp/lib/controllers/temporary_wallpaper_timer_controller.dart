import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';

class TemporaryWallpaperTimerController extends GetxController {
  TemporaryWallpaperTimerController({RemoteStyleController? styleController})
      : _styleController = styleController ?? Get.find<RemoteStyleController>();

  static const String _logTag = '[TEMP_WALLPAPER]';

  final RemoteStyleController _styleController;

  final RxBool isActive = false.obs;
  final RxnString activeWallpaperPath = RxnString();
  final Rxn<DateTime> targetEndTime = Rxn<DateTime>();
  final Rx<Duration> remaining = Duration.zero.obs;

  Timer? _ticker;
  Worker? _wallpaperWorker;

  @override
  void onInit() {
    super.onInit();
    _wallpaperWorker = ever<String>(_styleController.appliedWallpaper, (next) {
      final currentTemp = activeWallpaperPath.value;
      if (currentTemp == null || currentTemp.isEmpty) return;
      if (!isActive.value) return;
      if (next != currentTemp) {
        cancelTemporaryWallpaper(reason: 'manual_change');
      }
    });
  }

  Future<void> startTemporaryWallpaper({
    required String wallpaperPath,
    Duration duration = const Duration(seconds: 50),
  }) async {
    if (wallpaperPath.isEmpty || duration <= Duration.zero) return;

    // Replace any prior temporary wallpaper session.
    _cancelTicker();
    isActive.value = true;
    activeWallpaperPath.value = wallpaperPath;
    targetEndTime.value = DateTime.now().add(duration);

    await _styleController.applyWallpaper(wallpaperPath);

    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _log('Started temporary wallpaper for ${duration.inSeconds}s.');
  }

  void cancelTemporaryWallpaper({required String reason}) {
    if (_ticker?.isActive ?? false) {
      _log('Cancel requested (reason: $reason).');
    }
    _cancelTicker();
    _reset();
  }

  void _tick() {
    final end = targetEndTime.value;
    if (end == null) {
      cancelTemporaryWallpaper(reason: 'missing_end_time');
      return;
    }

    final left = end.difference(DateTime.now());
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      _cancelTicker();
      unawaited(_expire());
      return;
    }
    remaining.value = left;
  }

  Future<void> _expire() async {
    final tempPath = activeWallpaperPath.value;
    if (tempPath == null || tempPath.isEmpty) {
      _reset();
      return;
    }

    // Only revert if the temporary wallpaper is still the active wallpaper.
    if (_styleController.appliedWallpaper.value == tempPath) {
      final fallback = _styleController.wallpapers.first;
      _log('Expired; reverting to basic wallpaper.');
      await _styleController.applyWallpaper(fallback);
    } else {
      _log('Expired; wallpaper already changed, skipping revert.');
    }

    _reset();
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _reset() {
    isActive.value = false;
    activeWallpaperPath.value = null;
    targetEndTime.value = null;
    remaining.value = Duration.zero;
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }

  @override
  void onClose() {
    _wallpaperWorker?.dispose();
    _wallpaperWorker = null;
    _cancelTicker();
    super.onClose();
  }
}
