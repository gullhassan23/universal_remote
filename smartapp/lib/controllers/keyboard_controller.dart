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

/// Streams typed text to a connected Android TV via the existing
/// `RemoteImeBatchEdit` (commitText-equivalent) pipeline.
///
/// On each keystroke the entire cumulative [buffer] is pushed: the TV's IME
/// service replaces the focused field's text with the new value. Resending the
/// full buffer is intentional — a single dropped packet self-heals on the next
/// keystroke instead of corrupting the displayed text.
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

  /// Total stats — maintained even when [debugLog] is capped.
  final RxInt sentCount = 0.obs;
  final RxInt receivedCount = 0.obs;
  final RxInt failedCount = 0.obs;

  bool get isConnected =>
      _connectionController.connectionState.value ==
      TvConnectionState.connected;

  Future<bool> appendChar(String char) async {
    if (char.isEmpty) return false;
    final next = buffer.value + char;
    return _applyBufferAndPush(next, label: char);
  }

  Future<bool> backspace() async {
    if (buffer.value.isEmpty) {
      // Nothing buffered locally; ask the TV's IME to delete one character.
      final stopwatch = Stopwatch()..start();
      final counters = await _readImeCounters();
      final sent = await _connectionController.sendKey('KEY_BACKSPACE');
      stopwatch.stop();
      final after = await _readImeCounters();
      _appendLog(
        label: _backspaceLabel,
        bufferAfter: '',
        sent: sent,
        latencyMs: stopwatch.elapsedMilliseconds,
        before: counters,
        after: after,
      );
      return sent;
    }
    final next = buffer.value.substring(0, buffer.value.length - 1);
    return _applyBufferAndPush(next, label: _backspaceLabel);
  }

  Future<bool> space() {
    return appendChar(' ').then((sent) {
      // Re-tag the most recent log entry so the user sees <SPACE> in the log.
      _retagLastLog(' ', _spaceLabel);
      return sent;
    });
  }

  Future<bool> enter() async {
    final stopwatch = Stopwatch()..start();
    final before = await _readImeCounters();
    final sent = await _connectionController.sendKey('KEY_ENTER');
    stopwatch.stop();
    final after = await _readImeCounters();
    _appendLog(
      label: _enterLabel,
      bufferAfter: buffer.value,
      sent: sent,
      latencyMs: stopwatch.elapsedMilliseconds,
      before: before,
      after: after,
    );
    return sent;
  }

  Future<bool> clear() async {
    if (buffer.value.isEmpty) return true;
    final stopwatch = Stopwatch()..start();
    final before = await _readImeCounters();
    buffer.value = '';
    final pushed = await _pushBuffer();
    stopwatch.stop();
    final after = await _readImeCounters();
    _appendLog(
      label: _clearLabel,
      bufferAfter: '',
      sent: pushed,
      latencyMs: stopwatch.elapsedMilliseconds,
      before: before,
      after: after,
    );
    return pushed;
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

  Future<bool> _applyBufferAndPush(String nextBuffer, {required String label}) async {
    final stopwatch = Stopwatch()..start();
    final before = await _readImeCounters();
    buffer.value = nextBuffer;
    debugPrint('[UI] Typed: $nextBuffer');
    bool sent = false;
    String? error;
    try {
      sent = await _pushBuffer();
    } catch (e) {
      error = '$e';
      debugPrint('[Error] Message failed');
    }
    stopwatch.stop();
    final after = await _readImeCounters();
    if (sent && _hasImeDelta(before, after)) {
      debugPrint('[TV] Received: $nextBuffer');
    } else if (!sent) {
      debugPrint('[Error] Message failed');
    }
    _appendLog(
      label: label,
      bufferAfter: nextBuffer,
      sent: sent,
      latencyMs: stopwatch.elapsedMilliseconds,
      before: before,
      after: after,
      error: error,
    );
    return sent;
  }

  Future<bool> _pushBuffer() {
    final payload = buffer.value;
    debugPrint('[Protocol] Sending: $payload');
    return _connectionController.sendTextPrepared(
      payload,
      autoPrepareInputContext: false,
      forcePrepareInputContext: false,
      liveTyping: true,
      openPickerOnFailure: true,
    );
  }

  Future<Map<String, int>?> _readImeCounters() async {
    if (!isConnected) return null;
    try {
      final counters =
          await AndroidTvRemotePlatform.instance.getImeCounters();
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

  bool _hasImeDelta(Map<String, int>? before, Map<String, int>? after) {
    final beforeIme = before?['ime'];
    final afterIme = after?['ime'];
    if (beforeIme == null || afterIme == null) return false;
    return afterIme > beforeIme;
  }
}
