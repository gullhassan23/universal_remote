import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../services/android_tv/android_tv_remote_platform.dart';
import '../services/tv_service_interface.dart';
import 'tv_connection_controller.dart';

/// Records a single keystroke for the Android TV keyboard debug surface.
///
/// `received` is inferred from the TV's IME counter advancing after the send;
/// the protocol does not echo characters back, so a counter delta of zero with
/// [sent] true is the canonical "TV did not acknowledge this keystroke" signal.
class KeyboardLogEntry {
  KeyboardLogEntry({
    required this.timestamp,
    required this.label,
    required this.bufferAfter,
    required this.sent,
    required this.latencyMs,
    this.imeCounterBefore,
    this.imeCounterAfter,
    this.fieldCounterBefore,
    this.fieldCounterAfter,
    this.error,
  });

  final DateTime timestamp;
  final String label;
  final String bufferAfter;
  final bool sent;
  final int latencyMs;
  final int? imeCounterBefore;
  final int? imeCounterAfter;
  final int? fieldCounterBefore;
  final int? fieldCounterAfter;
  final String? error;

  bool get hasCounterDelta =>
      imeCounterBefore != null &&
      imeCounterAfter != null &&
      imeCounterAfter! > imeCounterBefore!;

  bool get receivedByTv => sent && hasCounterDelta;

  String get statusLabel {
    if (!sent) return 'failed';
    if (hasCounterDelta) return 'received';
    return 'unconfirmed';
  }
}

/// Stores typed text locally and submits the full buffer only on ENTER.
class KeyboardController extends GetxController {
  KeyboardController({TvConnectionController? connectionController})
      : _connectionController =
            connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;

  static const int _debugLogCapacity = 200;
  static const String _backspaceLabel = '<BKSP>';
  static const String _enterLabel = '<ENTER>';
  static const String _spaceLabel = '<SPACE>';
  static const String _clearLabel = '<CLEAR>';

  final RxString buffer = ''.obs;
  final RxBool isShiftActive = false.obs;
  final RxBool isCapsLock = false.obs;
  final RxBool isSymbols = false.obs;
  final RxList<KeyboardLogEntry> debugLog = <KeyboardLogEntry>[].obs;

  final Queue<KeyboardLogEntry> _logRing = Queue<KeyboardLogEntry>();
  Future<void> _typingQueue = Future<void>.value();

  /// Total stats — maintained even when [debugLog] is capped.
  final RxInt sentCount = 0.obs;
  final RxInt receivedCount = 0.obs;
  final RxInt failedCount = 0.obs;

  bool get isConnected =>
      _connectionController.connectionState.value ==
      TvConnectionState.connected;

  Future<bool> appendChar(String char) async {
    return _enqueueTyping<bool>(() async {
      if (char.isEmpty) return false;

      buffer.value = buffer.value + char; // ✅ only local state
      return true;
    });
  }

  Future<bool> backspace() async {
    return _enqueueTyping<bool>(() async {
      if (buffer.value.isEmpty) {
        _appendLog(
          label: _backspaceLabel,
          bufferAfter: '',
          sent: true,
          latencyMs: 0,
        );
        return true;
      }
      final next = buffer.value.substring(0, buffer.value.length - 1);
      buffer.value = next;
      _appendLog(
        label: _backspaceLabel,
        bufferAfter: next,
        sent: true,
        latencyMs: 0,
      );
      return true;
    });
  }

  Future<bool> space() {
    return _enqueueTyping<bool>(() async {
      final next = buffer.value + ' ';
      buffer.value = next;
      final sent = true;
      _appendLog(
        label: ' ',
        bufferAfter: next,
        sent: true,
        latencyMs: 0,
      );
      // Re-tag the most recent log entry so the user sees <SPACE> in the log.
      _retagLastLog(' ', _spaceLabel);
      return sent;
    });
  }

  Future<bool> enter() async {
    return _enqueueTyping<bool>(() async {
      final payload = buffer.value;
      if (payload.isEmpty) {
        _appendLog(
          label: _enterLabel,
          bufferAfter: buffer.value,
          sent: true,
          latencyMs: 0,
        );
        return true;
      }

      final stopwatch = Stopwatch()..start();
      final before = await _readImeCounters();
      final sent = await _connectionController.sendTextPrepared(
        payload,
        autoPrepareInputContext: true,
        forcePrepareInputContext: true,
        liveTyping: false,
        openPickerOnFailure: true,
      );
      stopwatch.stop();
      final after = await _readImeCounters();
      if (sent) {
        buffer.value = '';
      }
      _appendLog(
        label: _enterLabel,
        bufferAfter: sent ? '' : buffer.value,
        sent: sent,
        latencyMs: stopwatch.elapsedMilliseconds,
        before: before,
        after: after,
      );
      return sent;
    });
  }

  Future<bool> clear() async {
    return _enqueueTyping<bool>(() async {
      if (buffer.value.isEmpty) return true;
      buffer.value = '';
      _appendLog(
        label: _clearLabel,
        bufferAfter: '',
        sent: true,
        latencyMs: 0,
      );
      return true;
    });
  }

  void clearLocalBufferOnly() {
    buffer.value = '';
  }

  void clearDebugLog() {
    _logRing.clear();
    debugLog.clear();
    sentCount.value = 0;
    receivedCount.value = 0;
    failedCount.value = 0;
  }

  void toggleShift() {
    if (isCapsLock.value) {
      isCapsLock.value = false;
      isShiftActive.value = false;
      return;
    }
    isShiftActive.value = !isShiftActive.value;
  }

  void enableCapsLock() {
    isCapsLock.value = true;
    isShiftActive.value = true;
  }

  void toggleSymbols() {
    isSymbols.value = !isSymbols.value;
  }

  void consumeShiftAfterPress() {
    if (isCapsLock.value) return;
    if (!isShiftActive.value) return;
    isShiftActive.value = false;
  }

  Future<T> _enqueueTyping<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _typingQueue = _typingQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, int>?> _readImeCounters() async {
    if (!isConnected) return null;
    try {
      final counters = await AndroidTvRemotePlatform.instance.getImeCounters();
      return counters;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('KeyboardController._readImeCounters: $e');
      }
      return null;
    }
  }

  void _appendLog({
    required String label,
    required String bufferAfter,
    required bool sent,
    required int latencyMs,
    Map<String, int>? before,
    Map<String, int>? after,
    String? error,
  }) {
    if (sent) {
      sentCount.value += 1;
    } else {
      failedCount.value += 1;
    }
    final entry = KeyboardLogEntry(
      timestamp: DateTime.now(),
      label: label,
      bufferAfter: bufferAfter,
      sent: sent,
      latencyMs: latencyMs,
      imeCounterBefore: before?['ime'],
      imeCounterAfter: after?['ime'],
      fieldCounterBefore: before?['field'],
      fieldCounterAfter: after?['field'],
      error: error,
    );
    if (entry.receivedByTv) {
      receivedCount.value += 1;
    }
    if (!kDebugMode) {
      // Keep aggregate counters in release builds; don't retain individual
      // entries so we never accumulate memory in production.
      return;
    }
    _logRing.addLast(entry);
    while (_logRing.length > _debugLogCapacity) {
      _logRing.removeFirst();
    }
    debugLog.assignAll(_logRing.toList(growable: false).reversed);
  }

  void _retagLastLog(String fromLabel, String toLabel) {
    if (!kDebugMode) return;
    if (_logRing.isEmpty) return;
    final last = _logRing.last;
    if (last.label != fromLabel) return;
    final replacement = KeyboardLogEntry(
      timestamp: last.timestamp,
      label: toLabel,
      bufferAfter: last.bufferAfter,
      sent: last.sent,
      latencyMs: last.latencyMs,
      imeCounterBefore: last.imeCounterBefore,
      imeCounterAfter: last.imeCounterAfter,
      fieldCounterBefore: last.fieldCounterBefore,
      fieldCounterAfter: last.fieldCounterAfter,
      error: last.error,
    );
    _logRing.removeLast();
    _logRing.addLast(replacement);
    debugLog.assignAll(_logRing.toList(growable: false).reversed);
  }

}
