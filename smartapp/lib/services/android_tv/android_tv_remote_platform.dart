import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../features/device_discovery/android_tv_pairing_dialog.dart';

/// Android-only native bridge: TLS pairing (port 6467) + remote (6466).
class AndroidTvRemotePlatform {
  AndroidTvRemotePlatform._();

  static final AndroidTvRemotePlatform instance = AndroidTvRemotePlatform._();

  static const MethodChannel _channel =
      MethodChannel('com.example.smartapp/android_tv_remote');

  bool _initialized = false;

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestPin') {
        final ctx = Get.context ?? Get.overlayContext;
        if (ctx == null) return null;
        return showAndroidTvPairingDialog(ctx);
      }
      return null;
    });
  }

  Future<Map<String, dynamic>> generateCertificates() async {
    ensureInitialized();
    final raw = await _channel.invokeMethod<dynamic>('generateCertificates');
    if (raw is! Map) {
      throw PlatformException(
        code: 'CERT',
        message: 'Invalid generateCertificates response',
      );
    }
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Future<bool> connectAndPair({
    required String host,
    required String pkcs12Path,
    int? pairingPort,
    int? remotePort,
  }) async {
    ensureInitialized();
    final ok = await _channel.invokeMethod<bool>(
      'connectAndPair',
      <String, dynamic>{
        'host': host,
        'pkcs12Path': pkcs12Path,
        if (pairingPort != null) 'pairingPort': pairingPort,
        if (remotePort != null) 'remotePort': remotePort,
      },
    );
    return ok == true;
  }

  Future<bool> sendKeyCode(int keyCode) async {
    ensureInitialized();
    final ok = await _channel.invokeMethod<bool>(
      'sendKeyCode',
      <String, dynamic>{'keyCode': keyCode},
    );
    return ok == true;
  }

  Future<bool> acquireMulticastLock() async {
    ensureInitialized();
    try {
      final ok = await _channel.invokeMethod<bool>('acquireMulticastLock');
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.acquireMulticastLock: $e $st');
      }
      return false;
    }
  }

  Future<void> releaseMulticastLock() async {
    try {
      await _channel.invokeMethod<bool>('releaseMulticastLock');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.releaseMulticastLock: $e $st');
      }
    }
  }

  Future<void> disconnectNative() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.disconnectNative: $e $st');
      }
    }
  }
}
