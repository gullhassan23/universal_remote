import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import '../services/cast/cast_events.dart';
import '../services/cast/cast_session_manager.dart';
import '../services/network_context_service.dart';
import '../services/tv_service_interface.dart';
import '../services/unified_tv_service.dart';

class TvConnectionController extends GetxController with WidgetsBindingObserver {
  TvConnectionController({
    ITvService? tvService,
    CastSessionManager? castSessionManager,
    NetworkContextService? networkContextService,
  }) : _tvService = tvService ?? Get.find<ITvService>(),
       _castSessionManager = castSessionManager ?? CastSessionManager(),
       _networkContextService =
           networkContextService ?? Get.find<NetworkContextService>();

  final ITvService _tvService;
  final CastSessionManager _castSessionManager;
  final NetworkContextService _networkContextService;
  Future<bool>? _restoreFuture;
  bool _reconnectInProgress = false;
  bool _isInForeground = true;
  String? _pendingReconnectNotice;

  final Rx<TvDevice?> currentDevice = Rx<TvDevice?>(null);
  final Rx<TvConnectionState> connectionState =
      TvConnectionState.disconnected.obs;
  final Rx<CastSessionUpdate> castSession =
      const CastSessionUpdate(state: CastSessionState.idle).obs;
  final Rxn<CastSessionSnapshot> activeCastSession = Rxn<CastSessionSnapshot>();
  final RxString castConnectionLabel = ''.obs;

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('TvConnectionController: $message');
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _tvService.connectionStateStream.listen((state) {
      connectionState.value = state;
      if ((state == TvConnectionState.error ||
              state == TvConnectionState.disconnected) &&
          activeCastSession.value != null &&
          _isInForeground) {
        _attemptCastReconnect();
      }
    });
    _tvService.castSessionStream.listen((update) {
      castSession.value = update;
    });
    _castSessionManager.events.listen(_onCastEvent);
    _tryRestoreCastSession();
    // No cold-start auto-reconnect: avoids Android TV pairing dialog before the
    // user uses the remote. Restore runs from key taps, sleep timer, or resume.
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _attemptReconnectOnResume();
    }
  }

  Future<void> _attemptReconnectOnResume() async {
    if (_reconnectInProgress) return;
    if (connectionState.value == TvConnectionState.connected) return;

    final lastDevice = currentDevice.value ??
        (activeCastSession.value != null ? activeCastSession.value!.device : null);
    if (lastDevice == null) {
      await tryRestoreLastConnectedDeviceOnDemand();
      return;
    }

    await _attemptReconnectToDevice(lastDevice);
  }

  Future<bool> tryRestoreLastConnectedDeviceOnDemand() async {
    if (connectionState.value == TvConnectionState.connected) return true;

    final existingRestore = _restoreFuture;
    if (existingRestore != null) {
      return existingRestore;
    }

    final restoreFuture = _restoreLastConnectedDevice();
    _restoreFuture = restoreFuture;
    final restored = await restoreFuture;
    if (!restored) {
      _restoreFuture = null;
    }
    return restored;
  }

  Future<bool> _restoreLastConnectedDevice() async {
    if (_tvService is! UnifiedTvService) return false;
    final lastDevice = await (_tvService as UnifiedTvService).getLastDevice();
    if (lastDevice == null) return false;
    return connectTo(lastDevice);
  }

  Future<void> _tryRestoreCastSession() async {
    final restored = await _castSessionManager.restoreSession();
    if (restored == null) return;
    activeCastSession.value = restored;
    castConnectionLabel.value = 'Casting to ${restored.device.name}';
  }

  Future<void> _attemptCastReconnect() async {
    if (_reconnectInProgress) return;
    final snapshot = activeCastSession.value;
    if (snapshot == null) return;
    await _attemptReconnectToDevice(
      snapshot.device,
      reconnectingLabel: 'Reconnecting to ${snapshot.device.name}...',
      disconnectedLabel: 'Cast disconnected from ${snapshot.device.name}',
      connectedLabel: 'Casting to ${snapshot.device.name}',
    );
  }

  Future<void> _attemptReconnectToDevice(
    TvDevice device, {
    String? reconnectingLabel,
    String? connectedLabel,
    String? disconnectedLabel,
  }) async {
    if (_reconnectInProgress) return;
    if (await _networkContextService.hasWifiChangedSinceLastConnection()) {
      _pendingReconnectNotice =
          'Your Wi-Fi changed. Connect to the same Wi-Fi as TV and reconnect.';
      connectionState.value = TvConnectionState.disconnected;
      if (disconnectedLabel != null) {
        castConnectionLabel.value = disconnectedLabel;
      }
      return;
    }

    _reconnectInProgress = true;
    if (reconnectingLabel != null) {
      castConnectionLabel.value = reconnectingLabel;
    }
    try {
      for (final wait in const [250, 600, 1200]) {
        await Future<void>.delayed(Duration(milliseconds: wait));
        final connected = await connectTo(device);
        if (connected) {
          if (connectedLabel != null) {
            castConnectionLabel.value = connectedLabel;
          }
          return;
        }
      }
      if (disconnectedLabel != null) {
        castConnectionLabel.value = disconnectedLabel;
      }
    } finally {
      _reconnectInProgress = false;
    }
  }

  Future<bool> connectTo(TvDevice device) async {
    _log('connectTo start device=${device.name} ip=${device.ip}:${device.port}');
    currentDevice.value = device;
    final success = await _tvService.connect(device);
    if (!success) {
      _log('connectTo failed device=${device.name} ip=${device.ip}');
      currentDevice.value = null;
    } else {
      _log('connectTo success device=${device.name} ip=${device.ip}');
      _pendingReconnectNotice = null;
      await _networkContextService.captureOnSuccessfulConnection();
    }
    return success;
  }

  Future<List<TvDevice>> discoverCastTargets({TvBrand? filterBrand}) async {
    final devices = await _tvService.discoverDevices(filterBrand: filterBrand);
    await _castSessionManager.emitDeviceList(devices);
    return devices;
  }

  Future<bool> connectCastTarget(TvDevice device) async {
    final success = await connectTo(device);
    await _castSessionManager.emitConnectDevice(device, success: success);
    return success;
  }

  Future<CastSessionSnapshot?> startCastSession() async {
    final device = currentDevice.value;
    if (device == null || connectionState.value != TvConnectionState.connected) {
      return null;
    }
    final snapshot = await _castSessionManager.startSession(device);
    activeCastSession.value = snapshot;
    castConnectionLabel.value = 'Casting to ${snapshot.device.name}';
    return snapshot;
  }

  Future<void> disconnect() async {
    connectionState.value = TvConnectionState.disconnected;
    await _tvService.disconnect();
    currentDevice.value = null;
    _restoreFuture = null;
    castConnectionLabel.value = '';
    activeCastSession.value = null;
    await _castSessionManager.clearSession();
  }

  Future<bool> sendKey(String key) async {
    final state = connectionState.value;
    final deviceName = currentDevice.value?.name ?? 'unknown-device';
    if (state != TvConnectionState.connected) {
      _log('sendKey failed key=$key reason=not_connected state=$state');
      return false;
    }

    final sent = await _tvService.sendKey(key);
    if (sent) {
      _log('sendKey success key=$key device=$deviceName');
    } else {
      _log('sendKey failed key=$key device=$deviceName reason=service_rejected');
    }
    return sent;
  }

  Future<bool> launchApp(String packageName) {
    if (connectionState.value != TvConnectionState.connected) {
      _log('launchApp blocked: not connected package=$packageName');
      return Future<bool>.value(false);
    }
    _log('launchApp dispatch package=$packageName');
    return _tvService.launchApp(packageName);
  }

  Future<bool> castMedia(CastMediaItem item) {
    if (connectionState.value != TvConnectionState.connected) {
      return Future<bool>.value(false);
    }
    return _castMediaWithSession(item);
  }

  Future<void> stopCasting() async {
    castConnectionLabel.value = '';
    activeCastSession.value = null;
    await _castSessionManager.clearSession();
    return _tvService.stopCasting();
  }

  String? getLastServiceError() {
    final service = _tvService;
    if (service is UnifiedTvService) {
      return service.getLastErrorMessage();
    }
    return null;
  }

  String? consumeReconnectNotice() {
    final notice = _pendingReconnectNotice;
    _pendingReconnectNotice = null;
    return notice;
  }

  Future<bool> _castMediaWithSession(CastMediaItem item) async {
    final session = activeCastSession.value ?? await startCastSession();
    if (session == null) return false;
    final casted = await _tvService.castMedia(
      CastMediaItem(
        type: item.type,
        filePath: item.filePath,
        mimeType: item.mimeType,
        title: item.title,
        sessionId: session.sessionId,
        metadata: item.metadata,
      ),
    );
    await _castSessionManager.emitSendMedia(
      sessionId: session.sessionId,
      item: item,
      success: casted,
    );
    if (!casted) {
      castConnectionLabel.value = 'Cast failed on ${session.device.name}';
    } else {
      castConnectionLabel.value = 'Casting to ${session.device.name}';
    }
    return casted;
  }

  void _onCastEvent(CastEvent<dynamic> event) {
    switch (event.type) {
      case CastEventType.deviceList:
      case CastEventType.connectDevice:
      case CastEventType.startCast:
      case CastEventType.sendMedia:
        break;
    }
  }
}

