import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';
import 'media_cast_controller.dart';
import 'vibratiion_controller.dart';
import '../models/tv_device.dart';
import '../services/tv_service_interface.dart';
import '../features/device_discovery/device_discovery_controller.dart';
import '../widgets/remote_device_picker_sheet.dart';

class RemoteController extends GetxController {
  RemoteController({
    TvConnectionController? connectionController,
    DeviceDiscoveryController? discoveryController,
    MediaCastController? mediaCastController,
  }) : _connectionController =
           connectionController ?? Get.find<TvConnectionController>(),
       _discoveryController =
           discoveryController ?? Get.find<DeviceDiscoveryController>(),
       _mediaCastController =
           mediaCastController ?? Get.find<MediaCastController>();

  final TvConnectionController _connectionController;
  final DeviceDiscoveryController _discoveryController;
  final MediaCastController _mediaCastController;

  var selectedTab = 0.obs;
  final RxBool showDevicePicker = false.obs;
  String? _pendingKey;
  bool _pickerSheetVisible = false;

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

  Future<void> handleButtonTap({
    required String buttonKey,
    required FutureOr<void> Function() onTap,
    String action = 'tap',
  }) async {
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
  }

  Future<void> send(String key) async {
    logButtonEvent(
      buttonKey: key,
      event: 'action_triggered',
      action: 'send_key',
    );

    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      var ok = await _connectionController.sendKey(key);
      if (!ok) {
        // Brief retry avoids reopening picker for transient key-send misses.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        ok = await _connectionController.sendKey(key);
      }
      if (ok) {
        logButtonEvent(
          buttonKey: key,
          event: 'send_status',
          action: 'working',
        );
        return;
      }

      final device = _connectionController.currentDevice.value;
      if (device != null) {
        final reconnected = await _connectionController.connectTo(device);
        if (reconnected) {
          final resent = await _connectionController.sendKey(key);
          if (resent) {
            logButtonEvent(
              buttonKey: key,
              event: 'send_status',
              action: 'working_after_reconnect',
            );
            return;
          }
        }
      }
    }

    final restored =
        await _connectionController.tryRestoreLastConnectedDeviceOnDemand();
    if (restored) {
      final resentAfterRestore = await _connectionController.sendKey(key);
      if (resentAfterRestore) {
        logButtonEvent(
          buttonKey: key,
          event: 'send_status',
          action: 'working_after_restore',
        );
        return;
      }
    }

    logButtonEvent(
      buttonKey: key,
      event: 'send_status',
      action: 'not_working',
    );
    _pendingKey = key;
    _openPickerIfNeeded();
  }

  Future<void> startMediaCasting() async {
    logButtonEvent(
      buttonKey: 'MEDIA_CAST',
      event: 'action_triggered',
      action: 'start_media_cast',
    );
    await _mediaCastController.pickAndCastImage();
  }

  Future<void> onDeviceSelected(TvDevice device) async {
    _pickerSheetVisible = false;
    showDevicePicker.value = false;
    final success = await _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
    if (success) {
      final pendingKey = _pendingKey;
      _pendingKey = null;
      if (pendingKey != null) {
        await _connectionController.sendKey(pendingKey);
      }
    }
  }

  void dismissDevicePicker() {
    _pickerSheetVisible = false;
    showDevicePicker.value = false;
    _pendingKey = null;
  }

  void _openPickerIfNeeded() {
    if (_pickerSheetVisible || showDevicePicker.value) return;
    showDevicePicker.value = true;
  }

  void _showDevicePickerSheet() {
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
      if (showDevicePicker.value) showDevicePicker.value = false;
    });
  }
}
