import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkContextSnapshot {
  const NetworkContextSnapshot({
    required this.ssid,
    required this.ipv4,
    required this.subnetKey,
  });

  final String? ssid;
  final String? ipv4;
  final String? subnetKey;
}

class NetworkContextService {
  final NetworkInfo _networkInfo = NetworkInfo();
  NetworkContextSnapshot? _lastConnectedSnapshot;

  Future<void> captureOnSuccessfulConnection() async {
    _lastConnectedSnapshot = await _readCurrentSnapshot();
  }

  Future<bool> hasWifiChangedSinceLastConnection() async {
    final baseline = _lastConnectedSnapshot;
    if (baseline == null) return false;

    final current = await _readCurrentSnapshot();
    return _isDifferentNetwork(baseline, current);
  }

  Future<NetworkContextSnapshot> _readCurrentSnapshot() async {
    String? ssid;
    String? ipv4;
    String? subnetKey;

    try {
      ssid = _normalizeSsid(await _networkInfo.getWifiName());
    } catch (error) {
      _log('Failed to read SSID: $error');
    }

    try {
      ipv4 = await _networkInfo.getWifiIP();
    } catch (error) {
      _log('Failed to read Wi-Fi IP: $error');
    }

    subnetKey = _subnetPrefix(ipv4) ?? await _fallbackSubnetFromInterfaces();

    return NetworkContextSnapshot(
      ssid: ssid,
      ipv4: ipv4,
      subnetKey: subnetKey,
    );
  }

  bool _isDifferentNetwork(
    NetworkContextSnapshot baseline,
    NetworkContextSnapshot current,
  ) {
    if (_hasValue(baseline.ssid) && _hasValue(current.ssid)) {
      return baseline.ssid != current.ssid;
    }
    if (_hasValue(baseline.subnetKey) && _hasValue(current.subnetKey)) {
      return baseline.subnetKey != current.subnetKey;
    }
    if (_hasValue(baseline.ipv4) && _hasValue(current.ipv4)) {
      return baseline.ipv4 != current.ipv4;
    }
    return false;
  }

  String? _normalizeSsid(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '<unknown ssid>') return null;
    return trimmed.replaceAll('"', '');
  }

  String? _subnetPrefix(String? ip) {
    if (ip == null || ip.isEmpty) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  Future<String?> _fallbackSubnetFromInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        final interfaceName = interface.name.toLowerCase();
        final looksWifi = interfaceName.contains('wlan') ||
            interfaceName.contains('wifi') ||
            interfaceName.contains('en0');
        if (!looksWifi) continue;

        for (final address in interface.addresses) {
          final subnet = _subnetPrefix(address.address);
          if (subnet != null) return subnet;
        }
      }
    } catch (error) {
      _log('Failed to read network interfaces: $error');
    }
    return null;
  }

  bool _hasValue(String? value) => value != null && value.isNotEmpty;

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('NetworkContextService: $message');
    }
  }
}
