import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import 'tv_service_interface.dart';

/// Best-effort Android TV service.
///
/// Discovery strategy:
/// - SSDP search for generic media renderers and Android-like servers.
///
/// Control strategy:
/// - Simple HTTP POST of key commands to a lightweight `/android-remote` endpoint
///   if present. Many OEMs expose vendor-specific endpoints; this implementation
///   is intentionally minimal and may not work on all Android TVs out of the box.
class AndroidTvService implements ITvService {
  static const _ssdpPort = 1900;
  static const _ssdpMulticast = '239.255.255.250';
  static const _discoverTimeout = Duration(seconds: 4);

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();

  TvConnectionState _state = TvConnectionState.disconnected;
  TvDevice? _currentDevice;

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  AndroidTvService();

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    // Temporary: for emulator testing, return a single hard-coded Android TV.
    // When automatic discovery is enabled, replace this with SSDP/mDNS probing.
    return [
      TvDevice(
        id: 'android_emulator_10.0.2.15_6466',
        name: 'Android TV Emulator',
        ip: '10.0.2.15',
        port: 6466,
        brand: TvBrand.androidTv,
      ),
    ];
  }

  String? _parseHeader(String response, String header) {
    final upper = header.toUpperCase();
    final lines = response.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.toUpperCase().startsWith('$upper:')) {
        return line.substring(header.length + 1).trim();
      }
    }
    return null;
  }

  TvDevice? _deviceFromLocation(String locationUrl, {String? server}) {
    try {
      final uri = Uri.parse(locationUrl);
      final host = uri.host;
      if (host.isEmpty) return null;
      final port = uri.hasPort ? uri.port : 80;
      final id = '$host:$port';
      final name = server != null && server.isNotEmpty
          ? 'Android TV ($server)'
          : 'Android TV ($host)';
      return TvDevice(
        id: id,
        name: name,
        ip: host,
        port: port,
        brand: TvBrand.androidTv,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> connect(TvDevice device) async {
    if (device.brand != TvBrand.androidTv) return false;

    print(
        'AndroidTvService.connect: requested for ${device.ip}:${device.port}, id=${device.id}, name=${device.name}');

    await disconnect();
    _updateState(TvConnectionState.connecting);
    _currentDevice = device;

    // For any other port, keep a lightweight reachability probe.
    try {
      final reachable = await _probeReachable(device.ip, device.port);
      print(
          'AndroidTvService.connect: reachability probe to http://${device.ip}:${device.port}/ => $reachable');
      if (!reachable) {
        _updateState(TvConnectionState.error);
        return false;
      }
      _updateState(TvConnectionState.connected);
      return true;
    } catch (e) {
      print('AndroidTvService.connect: exception during probe: $e');
      _updateState(TvConnectionState.error);
      return false;
    }
  }

  Future<bool> _probeReachable(String ip, int port) async {
    final uri = Uri.parse('http://$ip:$port/');
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _currentDevice = null;
    _updateState(TvConnectionState.disconnected);
  }

  @override
  Future<bool> sendKey(String key) async {
    final device = _currentDevice;
    if (device == null || _state != TvConnectionState.connected) {
      print(
          'AndroidTvService.sendKey: cannot send, device=${device?.id}, state=$_state');
      return false;
    }

    // Extremely simple, best-effort key endpoint. This is intentionally generic;
    // specific OEMs may require custom integrations to be truly reliable.
    final uri = Uri.parse('http://${device.ip}:${device.port}/android-remote');
    print(
        'AndroidTvService.sendKey: POST $uri with key="$key", token=${device.token != null ? '***' : 'null'}');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'key': key,
              if (device.token != null && device.token!.isNotEmpty)
                'token': device.token,
            }),
          )
          .timeout(const Duration(seconds: 3));
      print(
          'AndroidTvService.sendKey: response status=${response.statusCode}, body=${response.body}');
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return ok;
    } catch (e) {
      print('AndroidTvService.sendKey: exception while sending key "$key": $e');
      // Do not change connection state here; treat command as best-effort.
      return false;
    }
  }

  void _updateState(TvConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }
}

