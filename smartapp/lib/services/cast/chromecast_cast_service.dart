import 'dart:async';
import 'dart:io';

import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';

class ChromecastCastService {
  bool _isContextInitialized = false;
  bool _isDiscovering = false;

  GoogleCastConnectState get connectionState =>
      GoogleCastSessionManager.instance.connectionState;

  bool get isConnected => connectionState == GoogleCastConnectState.connected;

  Future<void> ensureContextInitialized() async {
    if (_isContextInitialized) return;
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    if (Platform.isIOS) {
      final options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      );
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    } else if (Platform.isAndroid) {
      final options = GoogleCastOptionsAndroid(appId: appId);
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    }
    _isContextInitialized = true;
  }

  void startDiscovery() {
    if (_isDiscovering) return;
    GoogleCastDiscoveryManager.instance.startDiscovery();
    _isDiscovering = true;
  }

  void stopDiscovery() {
    if (!_isDiscovering) return;
    GoogleCastDiscoveryManager.instance.stopDiscovery();
    _isDiscovering = false;
  }

  Future<List<GoogleCastDevice>> discoverDevices({
    required Duration timeout,
  }) async {
    final completer = Completer<List<GoogleCastDevice>>();
    List<GoogleCastDevice> latest = <GoogleCastDevice>[];
    StreamSubscription<List<GoogleCastDevice>>? sub;

    sub = GoogleCastDiscoveryManager.instance.devicesStream.listen(
      (devices) {
        if (devices.isNotEmpty) {
          latest = List<GoogleCastDevice>.from(devices);
        }
      },
      onError: (_) {},
    );

    await Future<void>.delayed(timeout);
    await sub.cancel();
    if (!completer.isCompleted) {
      completer.complete(latest);
    }
    return completer.future;
  }

  Future<void> startSessionWithDevice(GoogleCastDevice device) {
    return GoogleCastSessionManager.instance.startSessionWithDevice(device);
  }

  Future<void> endSessionAndStopCasting() {
    return GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  Future<GoogleCastConnectState> waitForConnectedSession({
    Duration timeout = const Duration(seconds: 20),
    Duration pollEvery = const Duration(milliseconds: 200),
  }) async {
    final endAt = DateTime.now().add(timeout);
    var state = connectionState;
    while (DateTime.now().isBefore(endAt) &&
        state != GoogleCastConnectState.connected) {
      await Future<void>.delayed(pollEvery);
      state = connectionState;
    }
    return state;
  }

  Future<void> loadMedia({
    required Uri mediaUri,
    required String mimeType,
    required String title,
  }) {
    return GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformationIOS(
        contentId: mediaUri.toString(),
        streamType: CastMediaStreamType.buffered,
        contentUrl: mediaUri,
        contentType: mimeType,
        metadata: GoogleCastMovieMediaMetadata(title: title),
      ),
      autoPlay: true,
      playPosition: Duration.zero,
      playbackRate: 1.0,
    );
  }
}
