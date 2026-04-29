import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/keyboard_controller.dart';

/// Debug-only viewer for [KeyboardController.debugLog].
///
/// Shows a per-keystroke timeline (newest first) including:
/// - timestamp
/// - char label (e.g. `A`, `<BKSP>`, `<ENTER>`)
/// - resulting buffer
/// - sent/failed/unconfirmed status
/// - IME counter delta (`5 -> 6` means the TV acknowledged this keystroke;
///   `5 -> 5` while `sent=true` means the TV did not advance counters — the
///   exact "missing character" signal you're looking for)
/// - latency in ms
/// - error (if any)
class KeyboardDebugLogScreen extends StatelessWidget {
  const KeyboardDebugLogScreen({super.key, required this.keyboardController});

  final KeyboardController keyboardController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181F26),
        title: const Text('Keyboard debug log'),
        actions: [
          IconButton(
            tooltip: 'Copy log to clipboard',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final text = _serializeLog(keyboardController);
              Clipboard.setData(ClipboardData(text: text));
              Get.snackbar(
                'Copied',
                'Keyboard log copied to clipboard.',
                colorText: Colors.white,
              );
            },
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => keyboardController.clearDebugLog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CountersStrip(keyboardController: keyboardController),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: Obx(() {
                if (!kDebugMode) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Keyboard debug log is only available in debug builds.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final log = keyboardController.debugLog;
                if (log.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No keystrokes logged yet. Open the keyboard and start typing.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: log.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (context, index) =>
                      _LogRow(entry: log[index]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  static String _serializeLog(KeyboardController kb) {
    final buf = StringBuffer();
    buf.writeln(
      'Keyboard debug log @ ${DateTime.now().toIso8601String()}',
    );
    buf.writeln(
      'sent=${kb.sentCount.value} received=${kb.receivedCount.value} '
      'failed=${kb.failedCount.value}',
    );
    buf.writeln('---');
    for (final e in kb.debugLog) {
      buf.writeln(
        '${e.timestamp.toIso8601String()} '
        'label=${e.label} '
        'buffer="${e.bufferAfter}" '
        'status=${e.statusLabel} '
        'sent=${e.sent} '
        'imeBefore=${e.imeCounterBefore ?? '-'} '
        'imeAfter=${e.imeCounterAfter ?? '-'} '
        'fieldBefore=${e.fieldCounterBefore ?? '-'} '
        'fieldAfter=${e.fieldCounterAfter ?? '-'} '
        'latencyMs=${e.latencyMs} '
        'error=${e.error ?? '-'}',
      );
    }
    return buf.toString();
  }
}

class _CountersStrip extends StatelessWidget {
  const _CountersStrip({required this.keyboardController});

  final KeyboardController keyboardController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Obx(() {
        final sent = keyboardController.sentCount.value;
        final received = keyboardController.receivedCount.value;
        final failed = keyboardController.failedCount.value;
        return Row(
          children: [
            _Counter(label: 'Sent', value: sent, color: const Color(0xFF59B6FA)),
            const SizedBox(width: 12),
            _Counter(
              label: 'Received',
              value: received,
              color: const Color(0xFF7CDFA0),
            ),
            const SizedBox(width: 12),
            _Counter(
              label: 'Failed',
              value: failed,
              color: const Color(0xFFFFB3B3),
            ),
            const Spacer(),
            Obx(() {
              final buffer = keyboardController.buffer.value;
              return Text(
                'buffer="${buffer.length > 32 ? '${buffer.substring(0, 32)}…' : buffer}"',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: color, fontSize: 12),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final KeyboardLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ts = entry.timestamp;
    final timeStr = '${_two(ts.hour)}:${_two(ts.minute)}:${_two(ts.second)}.'
        '${ts.millisecond.toString().padLeft(3, '0')}';
    final delta = (entry.imeCounterBefore == null ||
            entry.imeCounterAfter == null)
        ? '?'
        : '${entry.imeCounterBefore} -> ${entry.imeCounterAfter}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'buffer="${entry.bufferAfter}"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _StatusChip(entry: entry),
                    Text(
                      'ime $delta',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '${entry.latencyMs}ms',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (entry.error != null)
                      Text(
                        'err=${entry.error}',
                        style: const TextStyle(
                          color: Color(0xFFFFB3B3),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});

  final KeyboardLogEntry entry;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (!entry.sent) {
      color = const Color(0xFFFFB3B3);
      label = 'failed';
    } else if (entry.hasCounterDelta) {
      color = const Color(0xFF7CDFA0);
      label = 'received';
    } else {
      color = const Color(0xFFFFD27A);
      label = 'unconfirmed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
