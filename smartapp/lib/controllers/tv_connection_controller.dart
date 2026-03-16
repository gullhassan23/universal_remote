import 'package:get/get.dart';

import '../models/tv_device.dart';
import '../services/tv_service_interface.dart';

class TvConnectionController extends GetxController {
  final ITvService _tvService = Get.find<ITvService>();

  final Rx<TvDevice?> currentDevice = Rx<TvDevice?>(null);
  final Rx<TvConnectionState> connectionState =
      TvConnectionState.disconnected.obs;

  @override
  void onInit() {
    super.onInit();
    _tvService.connectionStateStream.listen((state) {
      connectionState.value = state;
    });
  }

  Future<bool> connectTo(TvDevice device) async {
    currentDevice.value = device;
    final success = await _tvService.connect(device);
    if (!success) {
      currentDevice.value = null;
    }
    return success;
  }

  Future<void> disconnect() async {
    await _tvService.disconnect();
    currentDevice.value = null;
  }

  Future<bool> sendKey(String key) {
    return _tvService.sendKey(key);
  }
}

