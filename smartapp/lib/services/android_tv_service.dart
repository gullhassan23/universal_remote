import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import 'android_tv/android_tv_keycodes.dart';
import 'android_tv/android_tv_remote_platform.dart';
import 'tv_service_interface.dart';

/// Android TV Remote v2: mDNS discovery, TLS pairing on 6467, keys on 6466 (Android native).
class AndroidTvService implements ITvService {
  static const _prefsPkcs12 = 'android_tv_pkcs12_path';
  static const _ptrScanWindow = Duration(seconds: 6);
  static const _lookupTimeout = Duration(seconds: 2);
  static const _serviceTypes = <String>[
    '_androidtvremote._tcp.local',
    '_androidtvremote2._tcp.local',
  ];

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();

  TvConnectionState _state = TvConnectionState.disconnected;
  TvDevice? _currentDevice;
  String? _lastError;
  String? _lastCertificateError;

  String? get lastError => _lastError;

  AndroidTvService() {
    if (!kIsWeb && Platform.isAndroid) {
      AndroidTvRemotePlatform.instance.ensureInitialized();
    }
  }

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  void _syncState(TvConnectionState s) {
    _state = s;
    _connectionStateController.add(s);
  }

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    if (filterBrand != null && filterBrand != TvBrand.androidTv) {
      return [];
    }
    return _discoverMdns();
  }

  Future<List<TvDevice>> _discoverMdns() async {
    final devices = <TvDevice>[];
    final seen = <String>{};
    MDnsClient? mdns;
    var hasMulticastLock = false;
    try {
      hasMulticastLock =
          await AndroidTvRemotePlatform.instance.acquireMulticastLock();
      if (!hasMulticastLock && kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService._discoverMdns: failed to acquire multicast lock');
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
      if (hasMulticastLock) {
        await AndroidTvRemotePlatform.instance.releaseMulticastLock();
      }
    }

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
    if (device.brand != TvBrand.androidTv) return false;
    _lastError = null;

    if (!Platform.isAndroid) {
      await disconnect();
      _syncState(TvConnectionState.error);
      return false;
    }

    await disconnect();
    _syncState(TvConnectionState.connecting);
    _currentDevice = device;

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
        final ok = await AndroidTvRemotePlatform.instance.connectAndPair(
          host: device.ip,
          pkcs12Path: pkcs12,
          pairingPort: attempt.$1,
          remotePort: attempt.$2,
        );
        if (ok) {
          _lastError = null;
          _syncState(TvConnectionState.connected);
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

    final code = mapRemoteKeyToAndroidKeyCode(key);
    if (code == null) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.sendKey: unmapped key "$key"');
      }
      return false;
    }
    try {
      return await AndroidTvRemotePlatform.instance.sendKeyCode(code);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AndroidTvService.sendKey: $e');
      }
      _syncState(TvConnectionState.error);
      return false;
    }
  }
}
