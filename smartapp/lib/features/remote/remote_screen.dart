import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/android_tv/android_tv_keycodes.dart';
import '../../utils/constant.dart';

import '../../controllers/remote_controller.dart';
import '../cast/cast_session_banner.dart';

class RemoteScreen extends GetView<RemoteController> {
  const RemoteScreen({super.key});

  VoidCallback _loggedTap(
    String buttonKey,
    VoidCallback onTap, {
    String action = 'tap',
  }) {
    return () {
      unawaited(
        controller.handleButtonTap(
          buttonKey: buttonKey,
          onTap: onTap,
          action: action,
        ),
      );
    };
  }

  VoidCallback _sendKeyTap(String keyCode) {
    return _loggedTap(
      keyCode,
      () => controller.send(keyCode),
      action: 'send_key',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00B0B6),
              Color(0xFF005AFF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  ImageRes.kGetStartedBackgroundAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Obx(() {
                      final isConnected =
                          controller.connectionController.currentDevice.value !=
                              null;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Connect a device',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isConnected)
                            TextButton.icon(
                              onPressed: _loggedTap(
                                'DISCONNECT_TV',
                                () {
                                  unawaited(
                                    controller.connectionController.disconnect(),
                                  );
                                },
                                action: 'disconnect_tv',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.red.withOpacity(0.28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.link_off, size: 16),
                              label: const Text('Disconnect'),
                            ),
                        ],
                      );
                    }),
                    Obx(() {
                      final label = controller
                          .connectionController.castConnectionLabel.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: CastSessionBanner(label: label),
                      );
                    }),
                    const SizedBox(height: 26),
                    _buildMainButtons(context),
                    const SizedBox(height: 20),
                    _buildModeToggle(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: controller.selectedTab.value == 0
                              ? _buildDpad()
                              : _buildNumberTab(),
                        ),
                      ),
                    ),
                    _buildBottomButtons(context),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundedActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double width = 89,
    double height = 50,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color.fromARGB(33, 11, 27, 37),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
        ),
        child: Icon(icon, color: iconColor, size: 30),
      ),
    );
  }

  Widget _buildMainButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 66,
            height: 194,
            decoration: BoxDecoration(
              color: const Color.fromARGB(33, 11, 27, 37),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 40),
                  onPressed: _sendKeyTap('KEY_VOLUP'),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_off,
                      color: Colors.white, size: 30),
                  onPressed: _sendKeyTap('KEY_MUTE'),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white, size: 40),
                  onPressed: _sendKeyTap('KEY_VOLDOWN'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 194,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _roundedActionButton(
                  icon: Icons.search,
                  onTap: _sendKeyTap('KEY_SEARCH'),
                  width: 88,
                  height: 50,
                ),
                const SizedBox(height: 16),
                // Obx(() {
                //   final castStatus = controller.mediaCastController.status.value;
                //   final isBusy = castStatus == MediaCastStatus.picking ||
                //       castStatus == MediaCastStatus.casting;
                //   final progress =
                //       controller.mediaCastController.progressMessage.value;
                //   return Column(
                //     children: [
                //       _roundedActionButton(
                //         icon: isBusy ? Icons.hourglass_top : Icons.cast,
                //         onTap: _loggedTap(
                //           'MEDIA_CAST',
                //           () => controller.startMediaCasting(),
                //           action: 'start_media_cast',
                //         ),
                //         width: 88,
                //         height: 50,
                //       ),
                //       if (progress.isNotEmpty) ...[
                //         const SizedBox(height: 6),
                //         SizedBox(
                //           width: 120,
                //           child: Text(
                //             progress,
                //             maxLines: 2,
                //             overflow: TextOverflow.ellipsis,
                //             textAlign: TextAlign.center,
                //             style: const TextStyle(
                //               color: Colors.white70,
                //               fontSize: 11,
                //             ),
                //           ),
                //         ),
                //       ],
                //     ],
                //   );
                // }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 194,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _roundedActionButton(
                  icon: Icons.power_settings_new,
                  iconColor: const Color(0xFFFF3D3D),
                  onTap: _sendKeyTap('KEY_POWER'),
                ),
                _roundedActionButton(
                  icon: Icons.keyboard,
                  onTap: () {
                    unawaited(
                      controller.handleButtonTap(
                        buttonKey: 'KEY_KEYBOARD',
                        onTap: () async {
                          if (!context.mounted) return;
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: const Color(0xFF2A2A2A),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (ctx) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                              ),
                              child: _TvKeyboardSheet(
                                controller: controller,
                              ),
                            ),
                          );
                        },
                        action: 'open_keyboard',
                      ),
                    );
                  },
                ),
                _roundedActionButton(
                  icon: Icons.exit_to_app,
                  onTap: _sendKeyTap('KEY_RETURN'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x224A9AD1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
      ),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _buildModeSegment(
                isActive: controller.selectedTab.value == 0,
                icon: Icons.gamepad,
                onTap: () => controller.selectedTab.value = 0,
              ),
            ),
            Expanded(
              child: _buildModeSegment(
                isActive: controller.selectedTab.value == 1,
                text: '123',
                onTap: () => controller.selectedTab.value = 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSegment({
    required bool isActive,
    IconData? icon,
    String text = '',
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(4),
        height: 54,
        decoration: BoxDecoration(
          color: isActive ? const Color(0x4FFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 30)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNumberTab() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['GUIDE', '0', 'TOOLS'],
    ];

    return SingleChildScrollView(
      key: const ValueKey('number_pad'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _numberPadButton(label),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _numberPadButton(String label) {
    late final String keyCode;
    final bool isUtilityButton = label == 'GUIDE' || label == 'TOOLS';

    if (label == 'GUIDE') {
      keyCode = 'KEY_GUIDE';
    } else if (label == 'TOOLS') {
      keyCode = 'KEY_TOOLS';
    } else {
      keyCode = 'KEY_$label';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _sendKeyTap(keyCode),
      child: Container(
        width: isUtilityButton ? 96 : 78,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x2A5AA9D9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isUtilityButton ? 11 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDpad() {
    return SizedBox(
      key: const ValueKey('dpad'),
      width: 228,
      height: 228,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 228,
            height: 228,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF59B6FA), Color(0xFF2A90E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 226,
            height: 226,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
            ),
          ),
          Positioned(
            top: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_UP'),
            ),
          ),
          Positioned(
            bottom: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_DOWN'),
            ),
          ),
          Positioned(
            left: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_LEFT'),
            ),
          ),
          Positioned(
            right: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_RIGHT'),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3777B7),
              border: Border.all(color: const Color(0x8A1A2E4A), width: 1.4),
            ),
            child: TextButton(
              onPressed: _sendKeyTap('KEY_ENTER'),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _roundedActionButton(
            icon: Icons.arrow_back,
            onTap: _sendKeyTap('KEY_RETURN'),
            width: 84,
            height: 50,
          ),
          _roundedActionButton(
            icon: Icons.home,
            onTap: _sendKeyTap('KEY_HOME'),
            width: 84,
            height: 50,
          ),
          _roundedActionButton(
            icon: Icons.menu,
            onTap: _sendKeyTap('KEY_MENU'),
            width: 84,
            height: 50,
          ),
        ],
      ),
    );
  }
}

/// Phone soft keyboard: each character is sent to the TV as Android key events.
class _TvKeyboardSheet extends StatefulWidget {
  const _TvKeyboardSheet({required this.controller});

  final RemoteController controller;

  @override
  State<_TvKeyboardSheet> createState() => _TvKeyboardSheetState();
}

class _TvKeyboardSheetState extends State<_TvKeyboardSheet> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _prev = '';
  Future<void> _sendQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onTextChanged() {
    final v = _text.text;
    if (v.length > _prev.length) {
      final added = v.substring(_prev.length);
      for (final r in added.runes) {
        final ch = String.fromCharCode(r);
        if (mapCharToAndroidKeyCode(ch) == null) continue;
        _enqueueTypedKey(ch);
      }
    } else if (v.length < _prev.length) {
      final deletes = _prev.length - v.length;
      for (var i = 0; i < deletes; i++) {
        _enqueueTypedKey('KEY_BACKSPACE');
      }
    }
    _prev = v;
  }

  void _enqueueTypedKey(String key) {
    _sendQueue = _sendQueue.then((_) => _sendTypedKey(key));
  }

  Future<void> _sendTypedKey(String key) async {
    // Do not trigger reconnect bottom sheet while typing; just send directly.
    var ok = await widget.controller.connectionController.sendKey(key);
    if (ok) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    ok = await widget.controller.connectionController.sendKey(key);
    if (!ok) {
      widget.controller.logButtonEvent(
        buttonKey: key,
        event: 'typing_send_failed',
        action: 'keyboard_input',
      );
    }
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Type on TV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Focus a search box on your TV, then type here',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF3A3A3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
