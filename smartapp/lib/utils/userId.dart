import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUserIdKey = 'device_user_id';

final _secureStorage = FlutterSecureStorage();

String _generateUserId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final rand = Random.secure().nextInt(1 << 32);
  return 'device_${timestamp}_$rand';
}

/// Returns a stable, device-based user id stored in SharedPreferences.
/// Used as Firestore doc id and sent to backend for subscription verification.
Future<String> getOrCreateUserId() async {
  // 1) Prefer secure storage (survives reinstall on iOS in most cases).
  try {
    final secureId = await _secureStorage.read(key: _kUserIdKey);
    if (secureId != null && secureId.isNotEmpty) {
      // Keep SharedPreferences in sync (some code paths may read prefs only).
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kUserIdKey) != secureId) {
        await prefs.setString(_kUserIdKey, secureId);
      }
      return secureId;
    }
  } catch (_) {
    // Ignore secure storage failures; fall back to prefs.
  }

  // 2) Fall back to SharedPreferences (existing installs).
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kUserIdKey);
  if (id != null && id.isNotEmpty) {
    // Backfill into secure storage so future reinstalls keep the same id.
    try {
      await _secureStorage.write(key: _kUserIdKey, value: id);
    } catch (_) {}
    return id;
  }

  // 3) Create a new id once and store in both.
  id = _generateUserId();
  await prefs.setString(_kUserIdKey, id);
  try {
    await _secureStorage.write(key: _kUserIdKey, value: id);
  } catch (_) {}
  return id;
}
