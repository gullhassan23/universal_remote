import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import 'tv_service_interface.dart';

class SamsungTvService implements ITvService {
  static const _restPort = 8001;
  static const _wsPort = 8002;
  static const _prefsLastDeviceKey = 'last_samsung_tv';

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();

  WebSocket? _socket;
  TvConnectionState _state = TvConnectionState.disconnected;
  TvDevice? currentDevice;

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  SamsungTvService();

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    final info = NetworkInfo();
    final wifiIp = await info.getWifiIP();

    if (wifiIp == null) {
      print('SamsungTvService: No WiFi IP found, cannot scan for TVs.');
      return [];
    }

    final subnet = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    print('SamsungTvService: Scanning subnet $subnet.x for Samsung TVs...');
    final List<TvDevice> devices = [];

    final futures = <Future<void>>[];

    for (var i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      futures.add(_probeIp(ip).then((device) {
        if (device != null) {
          print(
              'SamsungTvService: Found Samsung TV "${device.name}" at ${device.ip}');
          devices.add(device);
        }
      }));
    }

    await Future.wait(futures);
    return devices;
  }

  Future<TvDevice?> _probeIp(String ip) async {
    final uri = Uri.parse('http://$ip:$_restPort/api/v2/');
    try {
      final response =
          await http.get(uri).timeout(const Duration(milliseconds: 800));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final deviceName =
            data['device']['name'] as String? ?? 'Samsung TV ($ip)';
        final id = data['device']['id'] as String? ?? ip;

        return TvDevice(
          id: id,
          name: deviceName,
          ip: ip,
          port: _wsPort,
          brand: TvBrand.samsung,
        );
      }
    } catch (_) {
      // ignore individual IP errors
    }
    return null;
  }

  @override
  Future<bool> connect(TvDevice device) async {
    await disconnect();

    _updateState(TvConnectionState.connecting);
    currentDevice = device;

    try {
      final appName = Uri.encodeComponent('Flutter Remote');
      final host = device.ip;

      final url =
          'wss://$host:$_wsPort/api/v2/channels/samsung.remote.control?name=$appName';

      final socket = await WebSocket.connect(
        url,
        compression: CompressionOptions.compressionOff,
        // badCertificateCallback: (cert, host, port) => true,
      );

      _socket = socket;
      _listenToSocket(socket);

      await _storeLastDevice(device);

      _updateState(TvConnectionState.connected);
      return true;
    } catch (_) {
      _updateState(TvConnectionState.error);
      return false;
    }
  }

  void _listenToSocket(WebSocket socket) {
    socket.listen(
      (data) {
        // Pairing and token messages can be handled here if needed.
      },
      onDone: () {
        _updateState(TvConnectionState.disconnected);
      },
      onError: (_) {
        _updateState(TvConnectionState.error);
      },
    );
  }

  @override
  Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    _updateState(TvConnectionState.disconnected);
  }

  @override
  Future<bool> sendKey(String key) async {
    if (_socket == null || _state != TvConnectionState.connected) {
      return false;
    }

    final payload = jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': key,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });

    try {
      _socket!.add(payload);
      return true;
    } catch (_) {
      _updateState(TvConnectionState.error);
      return false;
    }
  }

  Future<void> _storeLastDevice(TvDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastDeviceKey, jsonEncode(device.toJson()));
  }

  Future<TvDevice?> getLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsLastDeviceKey);
    if (jsonString == null) return null;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return TvDevice.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  void _updateState(TvConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }
}
