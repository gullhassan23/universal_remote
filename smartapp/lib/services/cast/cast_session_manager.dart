import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tv_device.dart';
import 'cast_events.dart';
import '../tv_service_interface.dart';

const _prefsCastSessionKey = 'active_cast_session_v1';

class CastSessionSnapshot {
  const CastSessionSnapshot({
    required this.sessionId,
    required this.device,
    required this.startedAt,
    required this.isActive,
  });

  final String sessionId;
  final TvDevice device;
  final DateTime startedAt;
  final bool isActive;

  CastSessionSnapshot copyWith({
    String? sessionId,
    TvDevice? device,
    DateTime? startedAt,
    bool? isActive,
  }) {
    return CastSessionSnapshot(
      sessionId: sessionId ?? this.sessionId,
      device: device ?? this.device,
      startedAt: startedAt ?? this.startedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'device': device.toJson(),
      'startedAt': startedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory CastSessionSnapshot.fromJson(Map<String, dynamic> json) {
    return CastSessionSnapshot(
      sessionId: json['sessionId'] as String,
      device: TvDevice.fromJson(json['device'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['startedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class CastSessionManager {
  final _eventsController = StreamController<CastEvent<dynamic>>.broadcast();
  CastSessionSnapshot? _activeSession;

  Stream<CastEvent<dynamic>> get events => _eventsController.stream;
  CastSessionSnapshot? get activeSession => _activeSession;

  Future<void> emitDeviceList(List<TvDevice> devices) async {
    _eventsController.add(
      CastEvent<DeviceListEventPayload>(
        type: CastEventType.deviceList,
        payload: DeviceListEventPayload(devices: devices),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> emitConnectDevice(TvDevice device, {required bool success}) async {
    _eventsController.add(
      CastEvent<ConnectDeviceEventPayload>(
        type: CastEventType.connectDevice,
        payload: ConnectDeviceEventPayload(device: device, success: success),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<CastSessionSnapshot> startSession(TvDevice device) async {
    final snapshot = CastSessionSnapshot(
      sessionId: _newSessionId(),
      device: device,
      startedAt: DateTime.now(),
      isActive: true,
    );
    _activeSession = snapshot;
    await _persist(snapshot);
    _eventsController.add(
      CastEvent<StartCastEventPayload>(
        type: CastEventType.startCast,
        payload: StartCastEventPayload(
          sessionId: snapshot.sessionId,
          device: snapshot.device,
        ),
        createdAt: DateTime.now(),
      ),
    );
    return snapshot;
  }

  Future<void> emitSendMedia({
    required String sessionId,
    required CastMediaItem item,
    required bool success,
  }) async {
    _eventsController.add(
      CastEvent<SendMediaEventPayload>(
        type: CastEventType.sendMedia,
        payload: SendMediaEventPayload(
          sessionId: sessionId,
          item: item,
          success: success,
        ),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<CastSessionSnapshot?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsCastSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _activeSession = CastSessionSnapshot.fromJson(decoded);
      return _activeSession;
    } catch (_) {
      await prefs.remove(_prefsCastSessionKey);
      return null;
    }
  }

  Future<void> clearSession() async {
    _activeSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCastSessionKey);
  }

  Future<void> _persist(CastSessionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCastSessionKey, jsonEncode(snapshot.toJson()));
  }

  String _newSessionId() {
    final rand = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'cast-${DateTime.now().millisecondsSinceEpoch}-$rand';
  }
}
