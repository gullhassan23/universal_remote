import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUserIdKey = 'device_user_id';

final _secureStorage = FlutterSecureStorage();
final RegExp _deviceUserIdPattern = RegExp(r'^device_[0-9]+_[0-9]+$');

String _generateUserId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final rand = Random.secure().nextInt(1 << 32);
  return 'device_${timestamp}_$rand';
}

bool _isValidDeviceUserId(String? value) {
  if (value == null || value.isEmpty) return false;
  return _deviceUserIdPattern.hasMatch(value);
}

/// Returns a stable, device-based user id stored in SharedPreferences.
/// Used as Firestore doc id and sent to backend for subscription verification.
Future<String> getOrCreateUserId() async {
  // 1) Prefer secure storage (survives reinstall on iOS in most cases).
  try {
    final secureId = await _secureStorage.read(key: _kUserIdKey);
    if (_isValidDeviceUserId(secureId)) {
      // Keep SharedPreferences in sync (some code paths may read prefs only).
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kUserIdKey) != secureId) {
        await prefs.setString(_kUserIdKey, secureId!);
      }
      return secureId!;
    }
  } catch (_) {
    // Ignore secure storage failures; fall back to prefs.
  }

  // 2) Fall back to SharedPreferences (existing installs).
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kUserIdKey);
  if (_isValidDeviceUserId(id)) {
    // Backfill into secure storage so future reinstalls keep the same id.
    try {
      await _secureStorage.write(key: _kUserIdKey, value: id);
    } catch (_) {}
    return id!;
  }

  // 3) Legacy/invalid IDs are regenerated to satisfy Firestore rules.
  id = _generateUserId();
  await prefs.setString(_kUserIdKey, id);
  try {
    await _secureStorage.write(key: _kUserIdKey, value: id);
  } catch (_) {}
  return id;
}
