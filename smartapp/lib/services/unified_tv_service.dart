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
  final _castSessionController =
      StreamController<CastSessionUpdate>.broadcast();

  ITvService? _activeService;
  StreamSubscription<TvConnectionState>? _stateSubscription;
  StreamSubscription<CastSessionUpdate>? _castSubscription;
  String? _lastError;

  UnifiedTvService() {
    _connectionStateController.add(TvConnectionState.disconnected);
    _castSessionController.add(
      const CastSessionUpdate(state: CastSessionState.idle),
    );
  }

  ITvService _serviceFor(TvBrand brand) {
    switch (brand) {
      case TvBrand.androidTv:
        return _androidTv;
      case TvBrand.samsung:
      case TvBrand.lg:
        throw UnsupportedError('TV brand ${brand.name} is not supported yet.');
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
  Stream<CastSessionUpdate> get castSessionStream => _castSessionController.stream;

  @override
  Future<List<TvDevice>> discoverDevices({TvBrand? filterBrand}) async {
    return _androidTv.discoverDevices(filterBrand: filterBrand);
  }

  @override
  Future<bool> connect(TvDevice device) async {
    await _stateSubscription?.cancel();
    await _castSubscription?.cancel();
    _stateSubscription = null;
    _castSubscription = null;
    try {
      _activeService = _serviceFor(device.brand);
    } on UnsupportedError catch (e) {
      _lastError = e.message;
      _forwardConnectionState(TvConnectionState.error);
      return false;
    }

    _stateSubscription = _activeService!.connectionStateStream.listen(
      _forwardConnectionState,
    );
    _castSubscription = _activeService!.castSessionStream.listen((update) {
      if (!_castSessionController.isClosed) {
        _castSessionController.add(update);
      }
    });

    final success = await _activeService!.connect(device);
    _lastError = success ? null : getLastErrorMessage();
    if (success) {
      await _storeLastDevice(device);
    }
    return success;
  }

  @override
  Future<void> disconnect() async {
    await _activeService?.disconnect();
    await _stateSubscription?.cancel();
    await _castSubscription?.cancel();
    _stateSubscription = null;
    _castSubscription = null;
    _activeService = null;
    if (!_castSessionController.isClosed) {
      _castSessionController.add(
        const CastSessionUpdate(state: CastSessionState.stopped),
      );
    }
  }

  @override
  Future<bool> sendKey(String key) async {
    final service = _activeService;
    if (service == null) return false;
    return service.sendKey(key);
  }

  @override
  Future<bool> sendTextPrepared(
    String text, {
    bool autoPrepareInputContext = true,
  }) async {
    final service = _activeService;
    if (service == null) return false;
    return service.sendTextPrepared(
      text,
      autoPrepareInputContext: autoPrepareInputContext,
    );
  }

  @override
  Future<bool> launchApp(String packageName) async {
    final service = _activeService;
    if (service == null) return false;
    return service.launchApp(packageName);
  }

  @override
  Future<bool> castMedia(CastMediaItem item) async {
    final service = _activeService;
    if (service == null) return false;
    return service.castMedia(item);
  }

  @override
  Future<void> stopCasting() async {
    await _activeService?.stopCasting();
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
    if (_lastError != null && _lastError!.isNotEmpty) {
      return _lastError;
    }
    final service = _activeService;
    if (service is AndroidTvService) {
      return service.lastError;
    }
    return null;
  }
}
