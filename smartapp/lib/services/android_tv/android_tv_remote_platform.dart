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
  VoidCallback? _onPairingPromptRequested;

  /// Called from Android when the remote TLS reader stops or the socket is lost.
  void Function(String reason)? onRemoteSessionEnded;

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('AndroidTvRemotePlatform: $message');
    }
  }

  String _previewText(String value) {
    final escaped = value
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    if (escaped.length <= 64) return escaped;
    return '${escaped.substring(0, 64)}...';
  }

  void setOnPairingPromptRequested(VoidCallback? callback) {
    _onPairingPromptRequested = callback;
  }

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestPin') {
        _onPairingPromptRequested?.call();
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
    _log('sendKeyCode call args={keyCode:$keyCode}');
    final ok = await _channel.invokeMethod<bool>(
      'sendKeyCode',
      <String, dynamic>{'keyCode': keyCode},
    );
    _log('sendKeyCode result=${ok == true} rawResult=$ok');
    return ok == true;
  }

  Future<bool> sendText(String text) async {
    ensureInitialized();
    _log(
      'sendText call args={textLength:${text.length},textPreview:"${_previewText(text)}"}',
    );
    final ok = await _channel.invokeMethod<bool>(
      'sendText',
      <String, dynamic>{'text': text},
    );
    _log('sendText result=${ok == true} rawResult=$ok');
    return ok == true;
  }

  Future<bool> sendTextPrepared(
    String text, {
    bool autoPrepareInputContext = true,
    bool forcePrepareInputContext = false,
  }) async {
    ensureInitialized();
    _log(
      'sendTextPrepared call args={textLength:${text.length},'
      'textPreview:"${_previewText(text)}",autoPrepareInputContext:$autoPrepareInputContext,'
      'forcePrepareInputContext:$forcePrepareInputContext}',
    );
    final ok = await _channel.invokeMethod<bool>(
      'sendTextPrepared',
      <String, dynamic>{
        'text': text,
        'autoPrepareInputContext': autoPrepareInputContext,
        'forcePrepareInputContext': forcePrepareInputContext,
      },
    );
    _log('sendTextPrepared result=${ok == true} rawResult=$ok');
    return ok == true;
  }

  Future<bool> launchApp(String packageName) async {
    ensureInitialized();
    final ok = await _channel.invokeMethod<bool>(
      'launchApp',
      <String, dynamic>{'packageName': packageName},
    );
    return ok == true;
  }

  Future<bool> openUrlOnTv(String url) async {
    ensureInitialized();
    final ok = await _channel.invokeMethod<bool>(
      'openUrlOnTv',
      <String, dynamic>{'url': url},
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

  /// Reflects native remote TLS, reader job, and ready flag (Android only).
  Future<bool> isRemoteSessionAlive() async {
    ensureInitialized();
    try {
      final ok = await _channel.invokeMethod<bool>('isRemoteSessionAlive');
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.isRemoteSessionAlive: $e $st');
      }
      return false;
    }
  }

  Future<bool> startTerminationKeepAlive({int durationMs = 20 * 60 * 1000}) async {
    ensureInitialized();
    try {
      final ok = await _channel.invokeMethod<bool>(
        'startTerminationKeepAlive',
        <String, dynamic>{'durationMs': durationMs},
      );
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.startTerminationKeepAlive: $e $st');
      }
      return false;
    }
  }

  Future<bool> startBackgroundKeepAlive({int? durationMs}) async {
    ensureInitialized();
    try {
      final ok = await _channel.invokeMethod<bool>(
        'startBackgroundKeepAlive',
        <String, dynamic>{if (durationMs != null) 'durationMs': durationMs},
      );
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.startBackgroundKeepAlive: $e $st');
      }
      return false;
    }
  }

  Future<bool> stopBackgroundKeepAlive() async {
    ensureInitialized();
    try {
      final ok = await _channel.invokeMethod<bool>('stopBackgroundKeepAlive');
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.stopBackgroundKeepAlive: $e $st');
      }
      return false;
    }
  }

  Future<bool> adoptKeepAliveSessionIfAvailable() async {
    ensureInitialized();
    try {
      final ok =
          await _channel.invokeMethod<bool>('adoptKeepAliveSessionIfAvailable');
      return ok == true;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.adoptKeepAliveSessionIfAvailable: $e $st');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> getKeepAliveStatus() async {
    ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<dynamic>('getKeepAliveStatus');
      if (raw is! Map) {
        return const <String, dynamic>{'active': false, 'remainingMs': 0};
      }
      return raw.map((key, value) => MapEntry(key.toString(), value));
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvRemotePlatform.getKeepAliveStatus: $e $st');
      }
      return const <String, dynamic>{'active': false, 'remainingMs': 0};
    }
  }
}
