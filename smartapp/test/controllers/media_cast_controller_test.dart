import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/media_cast_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/models/tv_brand.dart';
import 'package:smartapp/models/tv_device.dart';
import 'package:smartapp/services/tv_service_interface.dart';

class _FakeTvService implements ITvService {
  final _stateController = StreamController<TvConnectionState>.broadcast();
  bool castShouldSucceed = true;
  CastMediaItem? lastCastItem;

  @override
  Stream<TvConnectionState> get connectionStateStream => _stateController.stream;

  @override
  Future<bool> castMedia(CastMediaItem item) async {
    lastCastItem = item;
    return castShouldSucceed;
  }

  @override
  Future<bool> connect(TvDevice device) async => true;

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async => [];

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> launchApp(String packageName) async => true;

  @override
  Future<bool> sendKey(String key) async => true;

  @override
  Future<void> stopCasting() async {}
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  test('TvConnectionController castMedia delegates when connected', () async {
    final fakeService = _FakeTvService();
    final controller = TvConnectionController(tvService: fakeService);
    controller.connectionState.value = TvConnectionState.connected;

    final ok = await controller.castMedia(
      CastMediaItem(
        type: CastMediaType.image,
        filePath: '/tmp/demo.png',
        mimeType: 'image/png',
      ),
    );

    expect(ok, isTrue);
    expect(fakeService.lastCastItem?.filePath, '/tmp/demo.png');
  });

  test('MediaCastController errors when no connected device', () async {
    final fakeService = _FakeTvService();
    final connectionController = TvConnectionController(tvService: fakeService);
    final mediaController = MediaCastController(
      connectionController: connectionController,
    );

    await mediaController.pickAndCastImage();

    expect(mediaController.status.value, MediaCastStatus.error);
    expect(mediaController.errorMessage.value, isNotEmpty);
  });
}
