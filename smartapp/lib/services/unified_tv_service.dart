import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import 'tv_service_interface.dart';
import 'android_tv/android_tv_service.dart';

const _prefsLastDeviceKey = 'last_tv';

/// Android-TV-only implementation kept for API compatibility with the rest of the app.
class UnifiedTvService implements ITvService {
  final AndroidTvService _androidTv = AndroidTvService();

  final _connectionStateController =
      StreamController<TvConnectionState>.broadcast();

  ITvService? _activeService;
  StreamSubscription<TvConnectionState>? _stateSubscription;

  UnifiedTvService() {
    _connectionStateController.add(TvConnectionState.disconnected);
  }

  ITvService _serviceFor(TvBrand brand) {
    switch (brand) {
      case TvBrand.androidTv:
        return _androidTv;
    }
  }

  void _forwardConnectionState(TvConnectionState state) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  @override
  Stream<TvConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    return _androidTv.discoverDevices(filterBrand: filterBrand);
  }

  @override
  Future<bool> connect(TvDevice device) async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    _activeService = _serviceFor(device.brand);

    _stateSubscription = _activeService!.connectionStateStream.listen(
      _forwardConnectionState,
    );

    final success = await _activeService!.connect(device);
    if (success) {
      await _storeLastDevice(device);
    }
    return success;
  }

  @override
  Future<void> disconnect() async {
    await _activeService?.disconnect();
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    _activeService = null;
  }

  @override
  Future<bool> sendKey(String key) async {
    final service = _activeService;
    if (service == null) return false;
    return service.sendKey(key);
  }

  Future<void> _storeLastDevice(TvDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastDeviceKey, jsonEncode(device.toJson()));
  }

  Future<TvDevice?> getLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_prefsLastDeviceKey);
    if (jsonString == null) return null;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return TvDevice.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  String? getLastErrorMessage() {
    final service = _activeService;
    if (service is AndroidTvService) {
      return service.lastError;
    }
    return null;
  }
}
