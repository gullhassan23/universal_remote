import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/keyboard_controller.dart';
import '../controllers/tv_connection_controller.dart';
import '../features/remote/keyboard_debug_log_screen.dart';
import '../services/tv_service_interface.dart';

/// Production-grade Android TV keyboard bottom sheet.
///
/// Renders a custom QWERTY/symbols pad whose every keystroke streams the
/// cumulative buffer to the TV via [KeyboardController.appendChar] (which uses
/// the live-typing fast-path through [TvConnectionController.sendTextPrepared]
/// with `liveTyping: true`).
class RemoteKeyboardSheet extends StatefulWidget {
  const RemoteKeyboardSheet({
    super.key,
    required this.keyboardController,
    required this.connectionController,
    required this.onHandleTap,
    required this.registerCloser,
    required this.unregisterCloser,
  });

  final KeyboardController keyboardController;
  final TvConnectionController connectionController;
  final Future<void> Function({
    required String buttonKey,
    required FutureOr<void> Function() onTap,
    String action,
  }) onHandleTap;
  final void Function(VoidCallback closeSheet) registerCloser;
  final VoidCallback unregisterCloser;

  @override
  State<RemoteKeyboardSheet> createState() => _RemoteKeyboardSheetState();
}

class _RemoteKeyboardSheetState extends State<RemoteKeyboardSheet> {
  static const List<List<String>> _qwertyRows = <List<String>>[
    <String>['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    <String>['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    <String>['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const List<List<String>> _symbolRows = <List<String>>[
    <String>['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    <String>['-', '/', ':', ';', '(', ')', r'$', '&', '@', '"'],
    <String>['.', ',', '?', '!', "'", '*', '#', '+', '='],
  ];

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.registerCloser(_closeFromController);
  }

  @override
  void dispose() {
    widget.unregisterCloser();
    super.dispose();
  }

  void _closeFromController() {
    if (_closing) return;
    _closing = true;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  KeyboardController get _kb => widget.keyboardController;
  TvConnectionController get _conn => widget.connectionController;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.78,
          ),
          child: Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildPreview(),
                const SizedBox(height: 12),
                Obx(() => _buildKeysGrid(_kb.isSymbols.value)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const SizedBox(width: 4),
        const Icon(Icons.keyboard_alt, color: Colors.white70, size: 22),
        const SizedBox(width: 10),
        const Text(
          'Type on TV',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Obx(() {
          final state = _conn.connectionState.value;
          final isConnected = state == TvConnectionState.connected;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0x3329C25C)
                  : const Color(0x33FF6B6B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isConnected ? 'CONNECTED' : 'DISCONNECTED',
              style: TextStyle(
                color: isConnected
                    ? const Color(0xFF7CDFA0)
                    : const Color(0xFFFFB3B3),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          );
        }),
        const Spacer(),
        if (kDebugMode)
          IconButton(
            tooltip: 'Open keyboard debug log',
            icon: const Icon(
              Icons.bug_report_outlined,
              color: Colors.white54,
              size: 22,
            ),
            onPressed: () {
              Get.to(
                () => KeyboardDebugLogScreen(
                  keyboardController: _kb,
                ),
              );
            },
          ),
        IconButton(
          tooltip: 'Close keyboard',
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () {
            unawaited(
              widget.onHandleTap(
                buttonKey: 'KEYBOARD_CLOSE',
                action: 'dismiss_keyboard',
                onTap: () {
                  if (Navigator.of(context, rootNavigator: true).canPop()) {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final value = _kb.buffer.value;
              return Text(
                value.isEmpty ? 'Start typing — letters appear on TV' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? Colors.white38 : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          Obx(() {
            final canClear = _kb.buffer.value.isNotEmpty;
            return IconButton(
              tooltip: 'Clear text',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 20,
                color: canClear ? Colors.white70 : Colors.white24,
              ),
              onPressed: canClear
                  ? () {
                      unawaited(
                        widget.onHandleTap(
                          buttonKey: 'KB_CLEAR',
                          action: 'clear_buffer',
                          onTap: () => _kb.clear(),
                        ),
                      );
                    }
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKeysGrid(bool symbolsMode) {
    final letterRows = symbolsMode ? _symbolRows : _qwertyRows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letterRows.length; i++) ...[
          _buildLetterRow(letterRows[i],
              isLastLetterRow: i == letterRows.length - 1),
          const SizedBox(height: 6),
        ],
        _buildBottomActionRow(),
      ],
    );
  }

  Widget _buildLetterRow(List<String> chars, {required bool isLastLetterRow}) {
    final children = <Widget>[];
    if (isLastLetterRow) {
      children.add(_modifierKey(
        label: null,
        icon: Obx(() => Icon(
              _kb.isCapsLock.value
                  ? Icons.keyboard_capslock
                  : (_kb.isShiftActive.value
                      ? Icons.arrow_upward
                      : Icons.arrow_upward_outlined),
              size: 20,
              color: _kb.isShiftActive.value || _kb.isCapsLock.value
                  ? const Color(0xFF59B6FA)
                  : Colors.white,
            )),
        widthFactor: 1.45,
        onTap: () => _kb.toggleShift(),
        onLongPress: () => _kb.enableCapsLock(),
        buttonKey: 'KB_SHIFT',
        action: 'toggle_shift',
      ));
    }
    for (final ch in chars) {
      children.add(_letterKey(ch));
    }
    if (isLastLetterRow) {
      children.add(_modifierKey(
        label: null,
        icon: const Icon(
          Icons.backspace_outlined,
          size: 18,
          color: Colors.white,
        ),
        widthFactor: 1.45,
        onTap: () => _kb.backspace(),
        onLongPress: () => _kb.clear(),
        buttonKey: 'KB_BACKSPACE',
        action: 'send_backspace',
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildBottomActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modifierKey(
          label: Obx(() => Text(
                _kb.isSymbols.value ? 'ABC' : '?123',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )),
          widthFactor: 1.5,
          onTap: () => _kb.toggleSymbols(),
          buttonKey: 'KB_SYMBOLS',
          action: 'toggle_symbols',
        ),
        _letterKey(','),
        _modifierKey(
          label: const Text(
            'space',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          widthFactor: 4.6,
          onTap: () => _kb.space(),
          buttonKey: 'KB_SPACE',
          action: 'send_space',
        ),
        _letterKey('.'),
        _modifierKey(
          label: null,
          icon: const Icon(
            Icons.keyboard_return,
            size: 18,
            color: Colors.white,
          ),
          widthFactor: 1.5,
          onTap: () => _kb.enter(),
          buttonKey: 'KB_ENTER',
          action: 'send_enter',
        ),
      ],
    );
  }

  Widget _letterKey(String char) {
    return Obx(() {
      final shifted = _kb.isShiftActive.value || _kb.isCapsLock.value;
      final visible = (!_kb.isSymbols.value && shifted) ? char.toUpperCase() : char;
      return _KeyButton(
        widthFactor: 1.0,
        child: Text(
          visible,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          unawaited(
            widget.onHandleTap(
              buttonKey: 'KB_${visible.toUpperCase()}',
              action: 'send_char',
              onTap: () async {
                await _kb.appendChar(visible);
                _kb.consumeShiftAfterPress();
              },
            ),
          );
        },
      );
    });
  }

  Widget _modifierKey({
    Widget? label,
    Widget? icon,
    required double widthFactor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required String buttonKey,
    required String action,
  }) {
    return _KeyButton(
      widthFactor: widthFactor,
      onTap: () {
        unawaited(
          widget.onHandleTap(
            buttonKey: buttonKey,
            action: action,
            onTap: () async {
              onTap();
            },
          ),
        );
      },
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress();
            },
      child: icon ?? label ?? const SizedBox.shrink(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.child,
    required this.onTap,
    required this.widthFactor,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (widthFactor * 100).round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: const Color(0xFF2D3640),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              alignment: Alignment.center,
              height: 44,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
