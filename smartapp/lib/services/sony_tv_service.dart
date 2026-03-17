import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import 'tv_service_interface.dart';
import 'sony_ircc_codes.dart';

/// Sony Bravia TV service: SSDP discovery, PSK auth, IRCC control.
class SonyTvService implements ITvService {
  static const _ssdpPort = 1900;
  static const _ssdpMulticast = '239.255.255.250';
  static const _sonyServiceType =
      'urn:schemas-sony-com:service:ScalarWebAPI:1';
  static const _defaultApiPort = 80;
  static const _dmrPort = 52323; // Some TVs expose API on 80, SSDP returns 52323
  static const _discoverTimeout = Duration(seconds: 4);

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();

  TvConnectionState _state = TvConnectionState.disconnected;
  TvDevice? _currentDevice;
  /// IRCC codes from this TV (Sony API name -> code). Filled at connect via getRemoteControllerInfo.
  final Map<String, String> _tvIrccCodes = {};

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  SonyTvService();

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    final devices = <TvDevice>[];
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.joinMulticast(InternetAddress(_ssdpMulticast));
      socket.multicastHops = 2;
      socket.broadcastEnabled = true;

      final searchMessage = [
        'M-SEARCH * HTTP/1.1',
        'HOST: $_ssdpMulticast:$_ssdpPort',
        'MAN: "ssdp:discover"',
        'MX: 3',
        'ST: $_sonyServiceType',
        '',
        '',
      ].join('\r\n');

      final data = utf8.encode(searchMessage);
      socket.send(
        data,
        InternetAddress(_ssdpMulticast),
        _ssdpPort,
      );

      final completer = Completer<void>();
      final seenLocations = <String>{};

      void onDatagram(Datagram event) {
        final response = utf8.decode(event.data);
        final location = _parseLocation(response);
        if (location != null && location.isNotEmpty && seenLocations.add(location)) {
          final device = _deviceFromLocation(location);
          if (device != null) {
            devices.add(device);
          }
        }
      }

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            onDatagram(datagram);
          }
        }
      });

      Timer(_discoverTimeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    } catch (e) {
      print('SonyTvService: SSDP discovery error: $e');
    } finally {
      socket?.close();
    }

    return devices;
  }

  String? _parseLocation(String response) {
    final lines = response.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.toUpperCase().startsWith('LOCATION:')) {
        return line.substring(9).trim();
      }
    }
    return null;
  }

  TvDevice? _deviceFromLocation(String locationUrl) {
    try {
      final uri = Uri.parse(locationUrl);
      final host = uri.host;
      if (host.isEmpty) return null;
      final port = uri.hasPort ? uri.port : _defaultApiPort;
      final id = '$host:$port';
      return TvDevice(
        id: id,
        name: 'Sony TV ($host)',
        ip: host,
        port: port,
        brand: TvBrand.sony,
        token: null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> connect(TvDevice device) async {
    if (device.brand != TvBrand.sony) return false;

    await disconnect();
    _updateState(TvConnectionState.connecting);
    _currentDevice = device;

    final psk = device.token;
    if (psk == null || psk.isEmpty) {
      _updateState(TvConnectionState.error);
      return false;
    }

    try {
      var ok = await _verifyConnection(device.ip, device.port, psk);
      if (!ok && device.port == _dmrPort) {
        ok = await _verifyConnection(device.ip, _defaultApiPort, psk);
        if (ok) _currentDevice = device.copyWith(port: _defaultApiPort);
      }
      if (ok) {
        await _fetchTvIrccCodes(_currentDevice!.ip, _currentDevice!.port, _currentDevice!.token!);
        _updateState(TvConnectionState.connected);
        return true;
      }
    } catch (_) {}
    _updateState(TvConnectionState.error);
    return false;
  }

  Future<bool> _verifyConnection(String ip, int port, String psk) async {
    final uri = Uri.parse('http://$ip:$port/sony/system');
    final body = jsonEncode({
      'id': 1,
      'method': 'getRemoteControllerInfo',
      'params': [],
      'version': '1.0',
    });
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Auth-PSK': psk,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  }

  /// Fetches IRCC codes from TV and fills _tvIrccCodes so keys match this model.
  Future<void> _fetchTvIrccCodes(String ip, int port, String psk) async {
    _tvIrccCodes.clear();
    try {
      final uri = Uri.parse('http://$ip:$port/sony/system');
      final body = jsonEncode({
        'id': 1,
        'method': 'getRemoteControllerInfo',
        'params': [],
        'version': '1.0',
      });
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Auth-PSK': psk,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = data['result'] as List<dynamic>?;
      if (result == null || result.length < 2) return;
      final buttons = result[1] as List<dynamic>?;
      if (buttons == null) return;
      for (final b in buttons) {
        final map = b as Map<String, dynamic>?;
        if (map == null) continue;
        final name = map['name'] as String?;
        final value = map['value'] as String?;
        if (name != null && value != null) _tvIrccCodes[name] = value;
      }
    } catch (_) {
      _tvIrccCodes.clear();
    }
  }

  @override
  Future<void> disconnect() async {
    _currentDevice = null;
    _tvIrccCodes.clear();
    _updateState(TvConnectionState.disconnected);
  }

  @override
  Future<bool> sendKey(String key) async {
    final device = _currentDevice;
    if (device == null ||
        _state != TvConnectionState.connected ||
        device.token == null ||
        device.token!.isEmpty) {
      return false;
    }

    final sonyName = sonyKeyToApiName[key];
    String? irccCode;
    if (sonyName != null) {
      irccCode = _tvIrccCodes[sonyName];
      if (irccCode == null && key == 'KEY_POWER') {
        irccCode = _tvIrccCodes['Power'] ?? _tvIrccCodes['PowerOff'];
      }
    }
    irccCode ??= sonyIrccCodes[key];
    if (irccCode == null) return false;

    try {
      var port = device.port;
      var response = await _sendIrcc(device.ip, port, device.token!, irccCode);
      if (response.statusCode != 200 && port == _dmrPort) {
        response = await _sendIrcc(device.ip, _defaultApiPort, device.token!, irccCode);
      }
      return response.statusCode == 200;
    } catch (_) {
      _updateState(TvConnectionState.error);
      return false;
    }
  }

  Future<http.Response> _sendIrcc(String ip, int port, String psk, String irccCode) async {
    final uri = Uri.parse('http://$ip:$port/sony/IRCC');
    final soapBody = '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
      <IRCCCode>$irccCode</IRCCCode>
    </u:X_SendIRCC>
  </s:Body>
</s:Envelope>''';
    return http.post(
      uri,
      headers: {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPACTION': '"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"',
        'X-Auth-PSK': psk,
      },
      body: soapBody,
    ).timeout(const Duration(seconds: 3));
  }

  void _updateState(TvConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }
}
