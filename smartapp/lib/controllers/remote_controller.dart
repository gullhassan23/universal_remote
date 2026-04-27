import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';
import 'media_cast_controller.dart';
import 'vibratiion_controller.dart';
import '../models/tv_device.dart';
import '../services/companion/companion_tv_service.dart';
import '../services/analytics_service.dart';
import '../services/tv_service_interface.dart';
import '../features/device_discovery/device_discovery_controller.dart';
import '../widgets/remote_device_picker_sheet.dart';

enum _RemoteSheetType { picker, keyboard }

class RemoteController extends GetxController {
  RemoteController({
    TvConnectionController? connectionController,
    DeviceDiscoveryController? discoveryController,
    MediaCastController? mediaCastController,
    CompanionTvService? companionTvService,
  }) : _connectionController =
           connectionController ?? Get.find<TvConnectionController>(),
       _discoveryController =
           discoveryController ?? Get.find<DeviceDiscoveryController>(),
       _mediaCastController =
           mediaCastController ?? Get.find<MediaCastController>(),
       _companionTvService = companionTvService ?? CompanionTvService();

  final TvConnectionController _connectionController;
  final DeviceDiscoveryController _discoveryController;
  final MediaCastController _mediaCastController;
  final CompanionTvService _companionTvService;
  final AnalyticsService _analyticsService = Get.find<AnalyticsService>();

  var selectedTab = 0.obs;
  final RxBool showDevicePicker = false.obs;
  String? _pendingKey;
  bool _pickerSheetVisible = false;
  _RemoteSheetType? _activeSheetType;
  VoidCallback? _keyboardSheetCloser;
  Worker? _connectionStateWorker;

  TvConnectionController get connectionController => _connectionController;
  MediaCastController get mediaCastController => _mediaCastController;

  void logButtonEvent({
    required String buttonKey,
    required String event,
    String? action,
  }) {
    final actionSegment = action == null ? '' : ' action=$action';
    debugPrint('[button] key=$buttonKey event=$event$actionSegment');
  }

  String _previewPayload(String payload) {
    final escaped = payload
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    if (escaped.length <= 64) return escaped;
    return '${escaped.substring(0, 64)}...';
  }

  Future<void> handleButtonTap({
    required String buttonKey,
    required FutureOr<void> Function() onTap,
    String action = 'tap',
  }) async {
    unawaited(
      _analyticsService.trackClick(
        buttonKey,
        screenName: 'Remote_Screen',
      ),
    );
    if (Get.isRegistered<VibrationController>()) {
      Get.find<VibrationController>().vibrate();
    }
    logButtonEvent(buttonKey: buttonKey, event: 'pressed', action: action);
    try {
      await onTap();
    } catch (error, stackTrace) {
      logButtonEvent(buttonKey: buttonKey, event: 'error', action: action);
      debugPrint(
        '[button] key=$buttonKey action=$action failed: $error\n$stackTrace',
      );
    } finally {
      logButtonEvent(buttonKey: buttonKey, event: 'released', action: action);
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(showDevicePicker, (show) {
      if (show && !_pickerSheetVisible) {
        _pickerSheetVisible = true;
        _showDevicePickerSheet();
      }
    });
    _connectionStateWorker = ever<TvConnectionState>(
      _connectionController.connectionState,
      (state) {
        if (state == TvConnectionState.connected) {
          _dismissActiveSheetIfVisible();
        }
      },
    );
  }

  @override
  void onClose() {
    _connectionStateWorker?.dispose();
    super.onClose();
  }

  Future<void> send(String key) async {
    logButtonEvent(
      buttonKey: key,
      event: 'action_triggered',
      action: 'send_key',
    );

    final sent = await sendKeyReliably(key, openPickerOnFailure: true);
    logButtonEvent(
      buttonKey: key,
      event: 'send_status',
      action: sent ? 'working' : 'not_working',
    );
  }

  Future<bool> sendKeyReliably(
    String key, {
    bool openPickerOnFailure = false,
  }) {
    return _sendReliably(
      payload: key,
      openPickerOnFailure: openPickerOnFailure,
      retryDelay: const Duration(milliseconds: 30),
    );
  }

  Future<bool> sendPowerReliably({
    bool openPickerOnFailure = false,
  }) async {
    final sentTvPower = await sendKeyReliably(
      'KEY_POWER',
      openPickerOnFailure: openPickerOnFailure,
    );
    await Future<void>.delayed(const Duration(milliseconds: 90));
    final sentAndroidPower = await sendKeyReliably(
      'KEY_ANDROID_POWER',
      openPickerOnFailure: openPickerOnFailure,
    );
    return sentTvPower || sentAndroidPower;
  }

  Future<bool> sendTextReliably(
    String text, {
    bool openPickerOnFailure = false,
  }) {
    if (text.isEmpty) return Future<bool>.value(false);
    debugPrint(
      '[remote_controller] send_text_reliably length=${text.length} '
      'openPickerOnFailure=$openPickerOnFailure preview="${_previewPayload(text)}"',
    );
    return _sendReliably(
      payload: '__TEXT__:$text',
      openPickerOnFailure: openPickerOnFailure,
      retryDelay: const Duration(milliseconds: 40),
    );
  }

  Future<bool> sendPreparedTextReliably(
    String text, {
    bool openPickerOnFailure = false,
    bool autoPrepareInputContext = true,
    String source = 'mobile_voice',
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    if (_companionTvService.isFeatureEnabled) {
      final reachable = await _companionTvService.isReachable();
      if (reachable) {
        final sentViaCompanion = await _companionTvService.sendVoiceText(
          text: normalized,
          source: source,
        );
        if (sentViaCompanion) {
          return true;
        }
      }
    }
    _showReconnectNoticeIfAny();
    if (_connectionController.connectionState.value !=
            TvConnectionState.connected &&
        openPickerOnFailure) {
      _pendingKey = '__TEXT__:$normalized';
      _openPickerIfNeeded();
      return false;
    }

    if (_connectionController.connectionState.value == TvConnectionState.connected) {
      var ok = await _connectionController.sendTextPrepared(
        normalized,
        autoPrepareInputContext: autoPrepareInputContext,
      );
      if (!ok) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        ok = await _connectionController.sendTextPrepared(
          normalized,
          autoPrepareInputContext: autoPrepareInputContext,
        );
      }
      if (ok) return true;

      final device = _connectionController.currentDevice.value;
      if (device != null) {
        final reconnected = await _connectionController.connectTo(device);
        if (reconnected) {
          final resent = await _connectionController.sendTextPrepared(
            normalized,
            autoPrepareInputContext: autoPrepareInputContext,
          );
          if (resent) return true;
        }
      }
    }

    final restored =
        await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
    if (restored) {
      final resentAfterRestore = await _connectionController.sendTextPrepared(
        normalized,
        autoPrepareInputContext: autoPrepareInputContext,
      );
      if (resentAfterRestore) return true;
    }

    if (openPickerOnFailure) {
      _showReconnectNoticeIfAny();
      _pendingKey = '__TEXT__:$normalized';
      _openPickerIfNeeded();
    }
    return false;
  }

  Future<bool> _sendReliably({
    required String payload,
    required bool openPickerOnFailure,
    required Duration retryDelay,
  }) async {
    debugPrint(
      '[remote_controller] send_reliably_start '
      'payloadPreview="${_previewPayload(payload)}" '
      'openPickerOnFailure=$openPickerOnFailure '
      'connectionState=${_connectionController.connectionState.value.name}',
    );
    _showReconnectNoticeIfAny();
    if (_connectionController.connectionState.value !=
            TvConnectionState.connected &&
        openPickerOnFailure) {
      _pendingKey = payload;
      _openPickerIfNeeded();
      return false;
    }

    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      var ok = await _connectionController.sendKey(payload);
      debugPrint('[remote_controller] send_attempt_1 ok=$ok');
      if (!ok) {
        await Future<void>.delayed(retryDelay);
        ok = await _connectionController.sendKey(payload);
        debugPrint('[remote_controller] send_attempt_2 ok=$ok');
      }
      if (ok) return true;

      final device = _connectionController.currentDevice.value;
      if (device != null) {
        final reconnected = await _connectionController.connectTo(device);
        debugPrint('[remote_controller] reconnect_for_resend ok=$reconnected');
        if (reconnected) {
          final resent = await _connectionController.sendKey(payload);
          debugPrint('[remote_controller] resend_after_reconnect ok=$resent');
          if (resent) return true;
        }
      }
    }

    final restored =
        await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
    debugPrint('[remote_controller] restore_last_device ok=$restored');
    if (restored) {
      final resentAfterRestore = await _connectionController.sendKey(payload);
      debugPrint('[remote_controller] resend_after_restore ok=$resentAfterRestore');
      if (resentAfterRestore) return true;
    }

    if (openPickerOnFailure) {
      _showReconnectNoticeIfAny();
      _pendingKey = payload;
      _openPickerIfNeeded();
    }
    debugPrint(
      '[remote_controller] send_reliably_failed '
      'payloadPreview="${_previewPayload(payload)}"',
    );
    return false;
  }

  Future<void> startMediaCasting() async {
    logButtonEvent(
      buttonKey: 'MEDIA_CAST',
      event: 'action_triggered',
      action: 'start_media_cast',
    );
    await _mediaCastController.pickAndCastImage();
  }

  Future<bool> onDeviceSelected(TvDevice device) async {
    _pickerSheetVisible = false;
    _activeSheetType = null;
    _setShowDevicePickerSafely(false);
    final success = await _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
    if (success) {
      if (Get.isBottomSheetOpen ?? false) {
        Get.back<void>();
      }
      final pendingKey = _pendingKey;
      _pendingKey = null;
      if (pendingKey != null) {
        await _connectionController.sendKey(pendingKey);
      }
    }
    return success;
  }

  void dismissDevicePicker() {
    _pickerSheetVisible = false;
    if (_activeSheetType == _RemoteSheetType.picker) {
      _activeSheetType = null;
    }
    _setShowDevicePickerSafely(false);
    _pendingKey = null;
  }

  void registerKeyboardSheetCloser(VoidCallback closeSheet) {
    _activeSheetType = _RemoteSheetType.keyboard;
    _keyboardSheetCloser = closeSheet;
  }

  void unregisterKeyboardSheetCloser() {
    _keyboardSheetCloser = null;
    if (_activeSheetType == _RemoteSheetType.keyboard) {
      _activeSheetType = null;
    }
  }

  void _dismissActiveSheetIfVisible() {
    if (_activeSheetType == _RemoteSheetType.keyboard) {
      _dismissKeyboardSheetIfVisible();
      return;
    }
    if (_activeSheetType == _RemoteSheetType.picker || _pickerSheetVisible) {
      _dismissPickerSheetIfVisible();
    }
  }

  void _dismissPickerSheetIfVisible() {
    if (!_pickerSheetVisible) return;
    _pickerSheetVisible = false;
    if (_activeSheetType == _RemoteSheetType.picker) {
      _activeSheetType = null;
    }
    _setShowDevicePickerSafely(false);
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
  }

  void _dismissKeyboardSheetIfVisible() {
    final closer = _keyboardSheetCloser;
    if (closer == null) return;
    _keyboardSheetCloser = null;
    if (_activeSheetType == _RemoteSheetType.keyboard) {
      _activeSheetType = null;
    }
    closer();
  }

  void _openPickerIfNeeded() {
    if (_pickerSheetVisible || showDevicePicker.value) return;
    _setShowDevicePickerSafely(true);
  }

  void _setShowDevicePickerSafely(bool value) {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final isBuildingFrame =
        schedulerPhase == SchedulerPhase.transientCallbacks ||
        schedulerPhase == SchedulerPhase.persistentCallbacks ||
        schedulerPhase == SchedulerPhase.midFrameMicrotasks;
    if (isBuildingFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (showDevicePicker.value != value) {
          showDevicePicker.value = value;
        }
      });
      return;
    }
    if (showDevicePicker.value != value) {
      showDevicePicker.value = value;
    }
  }

  void _showReconnectNoticeIfAny() {
    final notice = _connectionController.consumeReconnectNotice();
    if (notice == null || notice.isEmpty) return;
    Get.snackbar(
      'Connection update',
      notice,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  void _showDevicePickerSheet() {
    _activeSheetType = _RemoteSheetType.picker;
    Get.bottomSheet(
      RemoteDevicePickerSheet(
        discoveryController: _discoveryController,
        onDeviceSelected: onDeviceSelected,
        onDismiss: dismissDevicePicker,
        onHandleTap: handleButtonTap,
      ),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ).whenComplete(() {
      _pickerSheetVisible = false;
      if (_activeSheetType == _RemoteSheetType.picker) {
        _activeSheetType = null;
      }
      if (showDevicePicker.value) {
        _setShowDevicePickerSafely(false);
      }
    });
  }
}
