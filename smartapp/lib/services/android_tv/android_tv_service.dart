import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tv_brand.dart';
import '../../models/tv_device.dart';
import '../media/local_media_server.dart';
import 'android_tv_keycodes.dart';
import 'android_tv_remote_platform.dart';
import '../tv_service_interface.dart';

/// Android TV Remote v2: mDNS discovery, TLS pairing on 6467, keys on 6466 (Android native).
class AndroidTvService implements ITvService {
  static const _batchTextPrefix = '__TEXT__:';
  static const _prefsPkcs12 = 'android_tv_pkcs12_path';
  static const _ptrScanWindow = Duration(seconds: 6);
  static const _lookupTimeout = Duration(seconds: 2);
  static const _serviceTypes = <String>[
    '_androidtvremote._tcp.local',
    '_androidtvremote2._tcp.local',
  ];
  static const _browserPackages = <String>[
    'com.android.chrome',
    'com.android.browser',
    'com.google.android.apps.tv.browser',
  ];

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();
  final _castSessionController = StreamController<CastSessionUpdate>.broadcast();
  final LocalMediaServer _mediaServer = LocalMediaServer();

  TvConnectionState _state = TvConnectionState.disconnected;
  TvDevice? _currentDevice;
  String? _lastError;
  String? _lastCertificateError;

  String? get lastError => _lastError;

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('AndroidTvService: $message');
    }
  }

  String _previewTextForLog(String text) {
    final escaped = text
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    if (escaped.length <= 48) {
      return escaped;
    }
    return '${escaped.substring(0, 48)}...';
  }

  AndroidTvService() {
    if (!kIsWeb && Platform.isAndroid) {
      AndroidTvRemotePlatform.instance.ensureInitialized();
      AndroidTvRemotePlatform.instance.onRemoteSessionEnded =
          _onNativeRemoteSessionEnded;
    }
  }

  void _onNativeRemoteSessionEnded(String reason) {
    if (_state == TvConnectionState.disconnected) return;
    _log('native session ended reason=$reason');
    _syncState(TvConnectionState.disconnected);
  }

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  @override
  Stream<CastSessionUpdate> get castSessionStream => _castSessionController.stream;

  @override
  Future<bool> verifyConnectedSessionAlive() async {
    if (_state != TvConnectionState.connected) {
      return false;
    }
    if (!Platform.isAndroid) {
      return true;
    }
    final alive = await AndroidTvRemotePlatform.instance.isRemoteSessionAlive();
    if (!alive) {
      _syncState(TvConnectionState.disconnected);
    }
    return alive;
  }

  @override
  Future<bool> startTerminationKeepAlive({
    Duration duration = const Duration(minutes: 20),
  }) async {
    if (!Platform.isAndroid) return false;
    if (_state != TvConnectionState.connected) return false;
    return AndroidTvRemotePlatform.instance.startTerminationKeepAlive(
      durationMs: duration.inMilliseconds,
    );
  }

  @override
  Future<bool> startBackgroundKeepAlive({Duration? duration}) async {
    if (!Platform.isAndroid) return false;
    if (_state != TvConnectionState.connected) return false;
    return AndroidTvRemotePlatform.instance.startBackgroundKeepAlive(
      durationMs: duration?.inMilliseconds,
    );
  }

  @override
  Future<bool> stopBackgroundKeepAlive() async {
    if (!Platform.isAndroid) return false;
    return AndroidTvRemotePlatform.instance.stopBackgroundKeepAlive();
  }

  @override
  Future<bool> adoptKeepAliveSessionIfAvailable() async {
    if (!Platform.isAndroid) return false;
    final adopted =
        await AndroidTvRemotePlatform.instance.adoptKeepAliveSessionIfAvailable();
    if (!adopted) {
      return false;
    }
    _syncState(TvConnectionState.connected);
    return true;
  }

  void _syncState(TvConnectionState s) {
    _state = s;
    _connectionStateController.add(s);
  }

  void _emitCastUpdate(CastSessionState state, {String? message}) {
    if (_castSessionController.isClosed) return;
    _castSessionController.add(CastSessionUpdate(state: state, message: message));
  }

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    if (filterBrand != null && filterBrand != TvBrand.androidTv) {
      _lastError = 'Brand ${filterBrand.name} is not supported yet.';
      _log('discoverDevices skipped: ${_lastError!}');
      return [];
    }
    _log('discoverDevices start filter=${filterBrand?.name ?? 'all'}');
    return _discoverMdns();
  }

  Future<List<TvDevice>> _discoverMdns() async {
    final devices = <TvDevice>[];
    final seen = <String>{};
    MDnsClient? mdns;
    var hasMulticastLock = false;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        hasMulticastLock =
            await AndroidTvRemotePlatform.instance.acquireMulticastLock();
        if (!hasMulticastLock && kDebugMode) {
          // ignore: avoid_print
          print(
              'AndroidTvService._discoverMdns: failed to acquire multicast lock');
        }
      }
      mdns = MDnsClient();
      await mdns.start();

      final ptrDomains = <String>{};
      StreamSubscription<PtrResourceRecord>? ptrSub;
      ptrSub = mdns
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceTypes.first),
          )
          .listen((ptr) => ptrDomains.add(ptr.domainName));
      final extraPtrSubs = <StreamSubscription<PtrResourceRecord>>[];
      for (final serviceType in _serviceTypes.skip(1)) {
        extraPtrSubs.add(
          mdns
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              )
              .listen((ptr) => ptrDomains.add(ptr.domainName)),
        );
      }

      await Future<void>.delayed(_ptrScanWindow);
      await ptrSub.cancel();
      for (final sub in extraPtrSubs) {
        await sub.cancel();
      }

      for (final domain in ptrDomains) {
        await for (final srv in mdns
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(domain),
            )
            .timeout(_lookupTimeout)) {
          try {
            final addresses = await _lookupServiceAddresses(mdns, srv.target);
            if (addresses.isEmpty) continue;
            final ip = addresses.first.address;
            final key = '$ip:${srv.port}';
            if (!seen.add(key)) continue;

            final name = _extractServiceName(domain);
            devices.add(
              TvDevice(
                id: key,
                name: name.isEmpty ? 'Android TV ($ip)' : name,
                ip: ip,
                port: srv.port,
                brand: TvBrand.androidTv,
              ),
            );
            _log('discovered name=${devices.last.name} ip=$ip port=${srv.port}');
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService._discoverMdns: $e');
      }
    } finally {
      mdns?.stop();
      if (!kIsWeb && Platform.isAndroid && hasMulticastLock) {
        await AndroidTvRemotePlatform.instance.releaseMulticastLock();
      }
    }

    _log('discoverDevices done count=${devices.length}');
    return devices;
  }

  String _extractServiceName(String domainName) {
    final idx = domainName.indexOf('._');
    if (idx > 0) {
      return domainName.substring(0, idx);
    }
    final parts = domainName.split('.');
    return parts.isNotEmpty ? parts.first : domainName;
  }

  Future<List<InternetAddress>> _lookupServiceAddresses(
    MDnsClient mdns,
    String host,
  ) async {
    final results = <InternetAddress>[];

    try {
      await for (final record in mdns
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(host),
          )
          .timeout(_lookupTimeout)) {
        results.add(record.address);
      }
    } on TimeoutException {
      // No mDNS A records arrived in the current scan window.
    } catch (_) {
      // Fall back to system lookup below.
    }

    if (results.isNotEmpty) {
      return results;
    }

    try {
      return await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      ).timeout(_lookupTimeout);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _ensurePkcs12Path() async {
    _lastCertificateError = null;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsPkcs12);
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    if (cached != null && cached.isNotEmpty) {
      await prefs.remove(_prefsPkcs12);
    }
    if (!Platform.isAndroid) return null;

    try {
      final map = await AndroidTvRemotePlatform.instance.generateCertificates();
      final success = map['success'] == true;
      if (!success) {
        _lastCertificateError =
            'Native certificate generation returned success=false: $map';
        return null;
      }
      final path = map['pkcs12Path'];
      if (path is! String || path.isEmpty) {
        _lastCertificateError =
            'Native certificate generation did not return pkcs12Path: $map';
        return null;
      }
      final pkcs12File = File(path);
      if (!pkcs12File.existsSync()) {
        _lastCertificateError =
            'Generated PKCS12 file does not exist at path: $path';
        return null;
      }
      await prefs.setString(_prefsPkcs12, path);
      return path;
    } catch (e) {
      _lastCertificateError = 'Native certificate generation threw: $e';
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          'AndroidTvService._ensurePkcs12Path: '
          '${_lastCertificateError ?? e}',
        );
      }
      return null;
    }
  }

  @override
  Future<bool> connect(TvDevice device) async {
    if (device.brand != TvBrand.androidTv) {
      _lastError =
          'TV brand ${device.brand.name} is not supported for app launch yet.';
      _log('connect rejected: ${_lastError!}');
      _syncState(TvConnectionState.error);
      return false;
    }
    _lastError = null;

    if (!Platform.isAndroid) {
      await disconnect();
      _syncState(TvConnectionState.error);
      return false;
    }

    await disconnect();
    _syncState(TvConnectionState.connecting);
    _currentDevice = device;
    _log('connect start name=${device.name} ip=${device.ip} discoveredPort=${device.port}');

    try {
      final pkcs12 = await _ensurePkcs12Path();
      if (pkcs12 == null) {
        _lastError = _lastCertificateError != null
            ? 'Certificate setup failed. ${_lastCertificateError!}'
            : 'Certificate setup failed (PKCS12 path missing).';
        if (kDebugMode) {
          // ignore: avoid_print
          print('AndroidTvService.connect: ${_lastError ?? 'unknown error'}');
        }
        _syncState(TvConnectionState.error);
        return false;
      }

      final attempts = <(int pairingPort, int remotePort)>[
        (6467, 6466),
      ].toSet().toList();

      for (final attempt in attempts) {
        _log(
          'connect attempt ip=${device.ip} pairingPort=${attempt.$1} remotePort=${attempt.$2}',
        );
        final ok = await AndroidTvRemotePlatform.instance.connectAndPair(
          host: device.ip,
          pkcs12Path: pkcs12,
          pairingPort: attempt.$1,
          remotePort: attempt.$2,
        );
        if (ok) {
          _lastError = null;
          _syncState(TvConnectionState.connected);
          _log('connect success ip=${device.ip}');
          return true;
        }
        _lastError =
            'Pair/connect failed at ${device.ip} (pairing:${attempt.$1}, remote:${attempt.$2}). '
            'Pairing code may be incorrect or expired.';
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'AndroidTvService.connect: attempt failed for ${device.ip} pairingPort=${attempt.$1} remotePort=${attempt.$2}',
          );
        }
      }

      _currentDevice = null;
      _syncState(TvConnectionState.error);
      _log('connect failed ip=${device.ip} reason=${_lastError ?? 'unknown'}');
      return false;
    } catch (e) {
      _lastError = 'Connection exception: $e';
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.connect: $e');
      }
      _currentDevice = null;
      _syncState(TvConnectionState.error);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await stopCasting();
    if (Platform.isAndroid) {
      await AndroidTvRemotePlatform.instance.disconnectNative();
    }
    _currentDevice = null;
    _syncState(TvConnectionState.disconnected);
  }

  @override
  Future<bool> sendKey(String key) async {
    if (_currentDevice == null || _state != TvConnectionState.connected) {
      return false;
    }
    if (!Platform.isAndroid) return false;

    if (key.startsWith(_batchTextPrefix)) {
      final text = key.substring(_batchTextPrefix.length);
      return sendTextPrepared(text, autoPrepareInputContext: false);
    }

    final code = mapRemoteKeyToAndroidKeyCode(key);
    if (code == null) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.sendKey: unmapped key "$key"');
      }
      return false;
    }
    _log(
      'sendKey route=keycode payload="$key" mappedCode=$code '
      'payloadFormat="{method:sendKeyCode,args:{keyCode:int}}"',
    );
    try {
      final sent = await AndroidTvRemotePlatform.instance.sendKeyCode(code);
      _log('sendKey key event result=$sent key="$key" code=$code');
      if (!sent &&
          !await AndroidTvRemotePlatform.instance.isRemoteSessionAlive()) {
        _syncState(TvConnectionState.disconnected);
      }
      return sent;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.sendKey: $e');
      }
      _syncState(TvConnectionState.error);
      return false;
    }
  }

  @override
  Future<bool> sendTextPrepared(
    String text, {
    bool autoPrepareInputContext = true,
  }) async {
    if (_currentDevice == null || _state != TvConnectionState.connected) {
      return false;
    }
    if (!Platform.isAndroid) return false;
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return false;

    _log(
      'sendTextPrepared textLength=${normalizedText.length} '
      'autoPrepareInputContext=$autoPrepareInputContext '
      'preview="${_previewTextForLog(normalizedText)}"',
    );
    try {
      var sent = await AndroidTvRemotePlatform.instance.sendTextPrepared(
        normalizedText,
        autoPrepareInputContext: autoPrepareInputContext,
      );
      if (sent) {
        _log('sendTextPrepared accepted on first attempt');
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 45));
      sent = await AndroidTvRemotePlatform.instance.sendTextPrepared(
        normalizedText,
        autoPrepareInputContext: autoPrepareInputContext,
      );
      _log('sendTextPrepared retry result=$sent');
      return sent;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.sendTextPrepared failed: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> launchApp(String packageName) async {
    if (_currentDevice == null || _state != TvConnectionState.connected) {
      return false;
    }
    if (!Platform.isAndroid) return false;
    final normalizedPackageName = packageName.trim();
    if (normalizedPackageName.isEmpty) return false;

    try {
      final appLink = 'market://launch?id=$normalizedPackageName';
      _log(
        'launchApp send packageName=$normalizedPackageName appLink=$appLink device=${_currentDevice?.ip}',
      );
      final launched = await AndroidTvRemotePlatform.instance.launchApp(
        normalizedPackageName,
      );
      if (!launched) {
        _lastError =
            'Launch command failed for package $normalizedPackageName. Ensure TV is on home screen and app is installed.';
        _log('launchApp failure packageName=$normalizedPackageName');
      } else {
        _lastError = null;
      }
      return launched;
    } catch (e) {
      _lastError = 'Launch exception for package $normalizedPackageName: $e';
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.launchApp: $e');
      }
      _syncState(TvConnectionState.error);
      return false;
    }
  }

  @override
  Future<bool> castMedia(CastMediaItem item) async {
    if (_currentDevice == null || _state != TvConnectionState.connected) {
      _emitCastUpdate(
        CastSessionState.failed,
        message: 'Connect to a TV before casting.',
      );
      return false;
    }
    if (!Platform.isAndroid) return false;
    if (item.type != CastMediaType.image) {
      _lastError =
          'Only image casting is enabled right now. Video casting schema is prepared for a follow-up release.';
      _emitCastUpdate(CastSessionState.failed, message: _lastError);
      return false;
    }

    try {
      _emitCastUpdate(
        CastSessionState.preparing,
        message: 'Preparing image stream for TV...',
      );
      final isReady = await _ensureConnectionReadyForCast();
      if (!isReady) {
        _lastError = 'Connection to TV was lost. Reconnect and try again.';
        _emitCastUpdate(CastSessionState.failed, message: _lastError);
        return false;
      }

      final servedSession = await _mediaServer.serveFile(
        filePath: item.filePath,
        mimeType: item.mimeType,
        sessionId:
            item.sessionId ?? 'cast-${DateTime.now().millisecondsSinceEpoch}',
        preferredRemoteIp: _currentDevice?.ip,
      );
      if (servedSession == null) {
        _lastError = 'Unable to start local media server.';
        _emitCastUpdate(CastSessionState.failed, message: _lastError);
        return false;
      }

      final deviceIp = _currentDevice?.ip;
      if (deviceIp != null &&
          !_isLikelySameSubnet(hostA: servedSession.viewerUri.host, hostB: deviceIp)) {
        _lastError =
            'Phone and TV appear to be on different networks. Connect both to the same Wi-Fi.';
        _emitCastUpdate(CastSessionState.failed, message: _lastError);
        return false;
      }

      _emitCastUpdate(
        CastSessionState.launching,
        message: 'Launching media viewer on TV...',
      );
      final opened = await _openMediaUrlOnTv(servedSession.viewerUri.toString());
      if (!opened) {
        _lastError = 'Unable to open browser on TV for media casting.';
        _emitCastUpdate(CastSessionState.failed, message: _lastError);
        return false;
      }
      _emitCastUpdate(
        CastSessionState.displaying,
        message: 'Image displayed on TV.',
      );
      return true;
    } catch (e) {
      _lastError = 'Cast media failed: $e';
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.castMedia: $e');
      }
      _emitCastUpdate(CastSessionState.failed, message: _lastError);
      return false;
    }
  }

  Future<bool> _openMediaUrlOnTv(String mediaUrl) async {
    final openedNatively =
        await AndroidTvRemotePlatform.instance.openUrlOnTv(mediaUrl);
    if (openedNatively) {
      return true;
    }

    return _openMediaUrlLegacy(mediaUrl);
  }

  Future<bool> _openMediaUrlLegacy(String mediaUrl) async {
    var browserLaunched = false;
    for (final package in _browserPackages) {
      browserLaunched = await launchApp(package);
      if (browserLaunched) {
        break;
      }
    }
    if (!browserLaunched) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 850));
    await sendKey('KEY_SEARCH');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final textSent = await AndroidTvRemotePlatform.instance.sendText(mediaUrl);
    if (!textSent) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    return sendKey('KEY_ENTER');
  }

  @override
  Future<void> stopCasting() async {
    await _mediaServer.stop();
    _emitCastUpdate(
      CastSessionState.stopped,
      message: 'Casting stopped.',
    );
  }

  Future<bool> _ensureConnectionReadyForCast() async {
    if (_currentDevice == null) return false;
    if (_state == TvConnectionState.connected) {
      final probe = await sendKey('KEY_HOME');
      if (probe) {
        return true;
      }
    }
    final target = _currentDevice;
    if (target == null) return false;
    return connect(target);
  }

  bool _isLikelySameSubnet({required String hostA, required String hostB}) {
    final a = hostA.split('.');
    final b = hostB.split('.');
    if (a.length != 4 || b.length != 4) return true;
    return a[0] == b[0] && a[1] == b[1] && a[2] == b[2];
  }
}
