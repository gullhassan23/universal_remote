import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';
import 'media_cast_controller.dart';
import 'keyboard_controller.dart';
import 'vibratiion_controller.dart';
import '../models/tv_device.dart';
import '../services/companion/companion_tv_service.dart';
import '../services/analytics_service.dart';
import '../services/tv_service_interface.dart';
import '../features/device_discovery/device_discovery_controller.dart';
import '../widgets/remote_device_picker_sheet.dart';
import '../widgets/remote_keyboard_sheet.dart';

enum _RemoteSheetType { picker, keyboard }

class _PendingPreparedText {
  const _PendingPreparedText({
    required this.text,
    required this.autoPrepareInputContext,
    required this.forcePrepareInputContext,
  });

  final String text;
  final bool autoPrepareInputContext;
  final bool forcePrepareInputContext;
}

class RemoteController extends GetxController {
  RemoteController({
    TvConnectionController? connectionController,
    DeviceDiscoveryController? discoveryController,
    MediaCastController? mediaCastController,
    CompanionTvService? companionTvService,
  })  : _connectionController =
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
  _PendingPreparedText? _pendingPreparedText;
  bool _pendingOpenKeyboardAfterConnect = false;
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
    String? screenName,
  }) async {
    unawaited(
      _analyticsService.trackClick(
        buttonKey,
        screenName: screenName ?? 'Remote_Screen',
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
    _connectionController.registerKeyboardConnectionRequiredCallback(_openPickerIfNeeded);
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
          if (_pendingOpenKeyboardAfterConnect) {
            _pendingOpenKeyboardAfterConnect = false;
            _dismissPickerSheetIfVisible();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showKeyboardSheet();
            });
            return;
          }
          _dismissActiveSheetIfVisible();
        } else if (state == TvConnectionState.disconnected ||
            state == TvConnectionState.error) {
          // Connection dropped: close the keyboard sheet if it was open and
          // clear any pending open-after-connect intent.
          _dismissKeyboardSheetIfVisible();
        }
      },
    );
  }

  @override
  void onClose() {
    _connectionController.unregisterKeyboardConnectionRequiredCallback();
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
    return sendPreparedTextReliably(
      text,
      openPickerOnFailure: openPickerOnFailure,
      autoPrepareInputContext: true,
      source: 'mobile_voice',
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
    debugPrint(
      '[remote_controller] send_prepared_text_start '
      'source=$source length=${normalized.length} '
      'autoPrepareInputContext=$autoPrepareInputContext '
      'preview="${_previewPayload(normalized)}"',
    );
    if (source != 'mobile_keyboard' && _companionTvService.isFeatureEnabled) {
      final reachable = await _companionTvService.isReachable();
      debugPrint(
        '[remote_controller] companion_route_check '
        'source=$source reachable=$reachable',
      );
      if (reachable) {
        final sentViaCompanion = await _companionTvService.sendVoiceText(
          text: normalized,
          source: source,
        );
        debugPrint(
          '[remote_controller] companion_route_result '
          'source=$source sent=$sentViaCompanion',
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
      _pendingPreparedText = _PendingPreparedText(
        text: normalized,
        autoPrepareInputContext: autoPrepareInputContext,
        forcePrepareInputContext: source == 'mobile_keyboard',
      );
      _openPickerIfNeeded();
      return false;
    }

    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      var ok = await _connectionController.sendTextPrepared(
        normalized,
        autoPrepareInputContext: autoPrepareInputContext,
        forcePrepareInputContext: source == 'mobile_keyboard',
      );
      debugPrint(
        '[remote_controller] prepared_text_attempt_1 '
        'source=$source sent=$ok',
      );
      if (!ok) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        ok = await _connectionController.sendTextPrepared(
          normalized,
          autoPrepareInputContext: autoPrepareInputContext,
          forcePrepareInputContext: source == 'mobile_keyboard',
        );
        debugPrint(
          '[remote_controller] prepared_text_attempt_2 '
          'source=$source sent=$ok',
        );
      }
      if (ok) return true;

      final device = _connectionController.currentDevice.value;
      if (device != null) {
        final reconnected = await _connectionController.connectTo(device);
        debugPrint(
          '[remote_controller] prepared_text_reconnect_for_resend '
          'source=$source reconnected=$reconnected',
        );
        if (reconnected) {
          final resent = await _connectionController.sendTextPrepared(
            normalized,
            autoPrepareInputContext: autoPrepareInputContext,
            forcePrepareInputContext: source == 'mobile_keyboard',
          );
          debugPrint(
            '[remote_controller] prepared_text_resend_after_reconnect '
            'source=$source sent=$resent',
          );
          if (resent) return true;
        }
      }
    }

    final restored =
        await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
    debugPrint(
      '[remote_controller] prepared_text_restore_last_device '
      'source=$source restored=$restored',
    );
    if (restored) {
      final resentAfterRestore = await _connectionController.sendTextPrepared(
        normalized,
        autoPrepareInputContext: autoPrepareInputContext,
        forcePrepareInputContext: source == 'mobile_keyboard',
      );
      debugPrint(
        '[remote_controller] prepared_text_resend_after_restore '
        'source=$source sent=$resentAfterRestore',
      );
      if (resentAfterRestore) return true;
    }

    if (openPickerOnFailure) {
      _showReconnectNoticeIfAny();
      _pendingPreparedText = _PendingPreparedText(
        text: normalized,
        autoPrepareInputContext: autoPrepareInputContext,
        forcePrepareInputContext: source == 'mobile_keyboard',
      );
      _openPickerIfNeeded();
    }
    debugPrint(
      '[remote_controller] send_prepared_text_failed '
      'source=$source preview="${_previewPayload(normalized)}"',
    );
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
      debugPrint(
          '[remote_controller] resend_after_restore ok=$resentAfterRestore');
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
      final pendingPreparedText = _pendingPreparedText;
      _pendingPreparedText = null;
      if (pendingPreparedText != null) {
        await _connectionController.sendTextPrepared(
          pendingPreparedText.text,
          autoPrepareInputContext: pendingPreparedText.autoPrepareInputContext,
          forcePrepareInputContext: pendingPreparedText.forcePrepareInputContext,
        );
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
    _pendingPreparedText = null;
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
      // If the picker is dismissed without connecting, abandon any pending
      // intent to open the keyboard so a later reconnect doesn't surprise
      // the user with an out-of-context sheet.
      _pendingOpenKeyboardAfterConnect = false;
    });
  }

  /// Public entry point: ensures the TV is connected, then opens the keyboard
  /// sheet. If not connected, opens the device picker first; the keyboard
  /// sheet auto-launches after a successful connection.
  Future<void> openKeyboard() async {
    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      _pendingOpenKeyboardAfterConnect = false;
      _showKeyboardSheet();
      return;
    }
    _pendingOpenKeyboardAfterConnect = true;
    _showReconnectNoticeIfAny();
    _openPickerIfNeeded();
  }

  void _showKeyboardSheet() {
    if (_activeSheetType == _RemoteSheetType.keyboard) return;
    _dismissPickerSheetIfVisible();
    KeyboardController kbController;
    try {
      kbController = Get.find<KeyboardController>();
    } catch (_) {
      Get.lazyPut<KeyboardController>(
        () => KeyboardController(connectionController: _connectionController),
        fenix: true,
      );
      kbController = Get.find<KeyboardController>();
    }
    _activeSheetType = _RemoteSheetType.keyboard;
    Get.bottomSheet(
      RemoteKeyboardSheet(
        keyboardController: kbController,
        connectionController: _connectionController,
        onHandleTap: handleButtonTap,
        registerCloser: registerKeyboardSheetCloser,
        unregisterCloser: unregisterKeyboardSheetCloser,
      ),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ).whenComplete(() {
      if (_activeSheetType == _RemoteSheetType.keyboard) {
        _activeSheetType = null;
      }
      _keyboardSheetCloser = null;
    });
  }
}
