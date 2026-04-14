import 'package:get/get.dart';

import '../models/tv_device.dart';
import '../services/tv_service_interface.dart';
import '../services/unified_tv_service.dart';

class TvConnectionController extends GetxController {
  TvConnectionController({ITvService? tvService})
    : _tvService = tvService ?? Get.find<ITvService>();

  final ITvService _tvService;
  bool _restoringLastDevice = false;

  final Rx<TvDevice?> currentDevice = Rx<TvDevice?>(null);
  final Rx<TvConnectionState> connectionState =
      TvConnectionState.disconnected.obs;
  final Rx<CastSessionUpdate> castSession =
      const CastSessionUpdate(state: CastSessionState.idle).obs;

  @override
  void onInit() {
    super.onInit();
    _tvService.connectionStateStream.listen((state) {
      connectionState.value = state;
    });
    _tvService.castSessionStream.listen((update) {
      castSession.value = update;
    });
    _tryRestoreLastConnectedDevice();
  }

  Future<void> _tryRestoreLastConnectedDevice() async {
    if (_restoringLastDevice) return;
    _restoringLastDevice = true;
    try {
      if (_tvService is! UnifiedTvService) return;
      final lastDevice = await (_tvService as UnifiedTvService).getLastDevice();
      if (lastDevice == null) return;
      if (connectionState.value == TvConnectionState.connected) return;
      await connectTo(lastDevice);
    } finally {
      _restoringLastDevice = false;
    }
  }

  Future<bool> connectTo(TvDevice device) async {
    currentDevice.value = device;
    final success = await _tvService.connect(device);
    if (!success) {
      currentDevice.value = null;
      connectionState.value = TvConnectionState.disconnected;
    }
    return success;
  }

  Future<void> disconnect() async {
    connectionState.value = TvConnectionState.disconnected;
    await _tvService.disconnect();
    currentDevice.value = null;
  }

  Future<bool> sendKey(String key) {
    return _tvService.sendKey(key);
  }

  Future<bool> launchApp(String packageName) {
    if (connectionState.value != TvConnectionState.connected) {
      return Future<bool>.value(false);
    }
    return _tvService.launchApp(packageName);
  }

  Future<bool> castMedia(CastMediaItem item) {
    if (connectionState.value != TvConnectionState.connected) {
      return Future<bool>.value(false);
    }
    return _tvService.castMedia(item);
  }

  Future<void> stopCasting() {
    return _tvService.stopCasting();
  }

  String? getLastServiceError() {
    final service = _tvService;
    if (service is UnifiedTvService) {
      return service.getLastErrorMessage();
    }
    return null;
  }
}

