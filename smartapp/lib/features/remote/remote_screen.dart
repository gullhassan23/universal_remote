import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/tv_connection_controller.dart';
import '../../services/android_tv/android_tv_keycodes.dart';
import '../../services/tv_service_interface.dart';
import 'remote_controller.dart';

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
    final connectionController = controller.connectionController;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Connect a device",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            final isConnected = connectionController.connectionState.value ==
                TvConnectionState.connected;
            return TextButton.icon(
              onPressed: isConnected
                  ? () async {
                      await connectionController.disconnect();
                      controller.logButtonEvent(
                        buttonKey: 'DISCONNECT',
                        event: 'action_triggered',
                        action: 'disconnect',
                      );
                    }
                  : null,
              icon: const Icon(Icons.link_off, color: Colors.white70, size: 18),
              label: Text(
                'Disconnect',
                style: TextStyle(
                  color: isConnected ? Colors.white : Colors.white38,
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// Connection Status
              Obx(
                () => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _connectionLabel(connectionController),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // buildSideButtons(),
                    SizedBox(
                      height: 202,
                      child: buildMainButtons(context),
                    ),
                    const SizedBox(height: 12),
                    // SmoothPageIndicator(
                    //   controller: pageController,
                    //   count: 2,
                    //   effect: const ExpandingDotsEffect(
                    //     dotHeight: 8,
                    //     dotWidth: 8,
                    //     activeDotColor: Colors.white,
                    //     dotColor: Colors.grey,
                    //   ),
                    // ),
                    const SizedBox(height: 24),
                    _buildTabs(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: _buildTabViews(),
                    ),
                    buildBottomButtons(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Connection Label
  String _connectionLabel(TvConnectionController c) {
    final device = c.currentDevice.value;
    final state = c.connectionState.value;
    final isConnected = state == TvConnectionState.connected;
    if (device == null || !isConnected) {
      return 'Press any button to find your TV on the same WiFi.';
    }
    return '${device.name} • ${state.name}';
  }

//  decoration: BoxDecoration(
//           color: const Color(0xFF2A2A2A),
//           borderRadius: BorderRadius.circular(12),
//         ),
  /// BUTTON STYLE
  Widget remoteButton({
    required bool text,
    String? label,
    required IconData icon,
    required VoidCallback onTap,
    required bool border,
    required Color color,
    required Color containercolor,
    bool? isActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: border ? 80 : 60,
        height: 50,
        decoration: border
            ? BoxDecoration(
                color: isActive == true ? containercolor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isActive == true ? containercolor : Colors.black),
              )
            : null,
        child: Center(
          child: text
              ? Text(
                  label ?? '',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 22),
                )
              : Icon(icon, color: color),
        ),
      ),
    );
  }

  /// SIDE BUTTONS (Volume / Power / Channel)
  Widget buildMainButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// VOLUME
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  remoteButton(
                      containercolor: Colors.white,
                      text: false,
                      icon: Icons.add,
                      onTap: _sendKeyTap('KEY_VOLUP'),
                      border: false,
                      color: Colors.white),
                  const Divider(
                    color: Colors.black,
                    height: 10,
                    thickness: 5,
                  ),
                  remoteButton(
                      containercolor: Colors.white,
                      text: false,
                      icon: Icons.volume_off,
                      onTap: _sendKeyTap('KEY_MUTE'),
                      border: false,
                      color: Colors.white),
                  const Divider(
                    color: Colors.black,
                    height: 12,
                    thickness: 1,
                  ),
                  remoteButton(
                      containercolor: Colors.white,
                      text: false,
                      icon: Icons.remove,
                      onTap: _sendKeyTap('KEY_VOLDOWN'),
                      border: false,
                      color: Colors.white),
                ],
              ),
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Container(
          //     decoration: BoxDecoration(
          //         borderRadius: BorderRadius.circular(20),
          //         border: Border.all(color: Colors.black)),
          //     child: Padding(
          //       padding: const EdgeInsets.all(8.0),
          //       child: Column(
          //         children: [
          //           // remoteButton(
          //           //     containercolor: Colors.white,
          //           //     text: false,
          //           //     icon: Icons.keyboard_arrow_up,
          //           //     onTap: _loggedTap(
          //           //       'KEY_CHUP',
          //           //       () => controller.send('KEY_CHUP'),
          //           //       action: 'send_key',
          //           //     ),
          //           //     border: false,
          //           //     color: Colors.white),
          //           remoteButton(
          //               containercolor: Colors.white,
          //               text: false,
          //               icon: Icons.search,
          //               onTap: _loggedTap(
          //                 'KEY_SEARCH',
          //                 () => controller.send('KEY_SEARCH'),
          //                 action: 'send_key',
          //               ),
          //               border: true,
          //               color: Colors.white),
          //           const SizedBox(height: 9),
          //           remoteButton(
          //               containercolor: Colors.white,
          //               text: false,
          //               icon: Icons.menu,
          //               onTap: _loggedTap(
          //                 'KEY_MENU',
          //                 () => controller.send('KEY_MENU'),
          //                 action: 'send_key',
          //               ),
          //               border: false,
          //               color: Colors.white),
          //           const SizedBox(height: 9),
          //           remoteButton(
          //               containercolor: Colors.white,
          //               text: false,
          //               icon: Icons.keyboard_arrow_down,
          //               onTap: _loggedTap(
          //                 'KEY_CHDOWN',
          //                 () => controller.send('KEY_CHDOWN'),
          //                 action: 'send_key',
          //               ),
          //               border: false,
          //               color: Colors.white),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.search,
              onTap: _sendKeyTap('KEY_SEARCH'),
              border: true,
              color: Colors.white),

          /// CENTER BUTTONS
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.power_settings_new,
                    onTap: _sendKeyTap('KEY_POWER'),
                    border: true,
                    color: Colors.red),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(
                    containercolor: Colors.white,
                    text: false,
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
                    border: true,
                    color: Colors.white),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.exit_to_app,
                    onTap: _sendKeyTap('KEY_RETURN'),
                    border: true,
                    color: Colors.white),
              ),
            ],
          ),

          /// CHANNEL
        ],
      ),
    );
  }

  Widget buildSideMainButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// VOLUME
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                remoteButton(
                  isActive: true,
                  containercolor: Color(0xffF27E74),
                  label: 'A',
                  text: true,
                  icon: Icons.add,
                  onTap: _sendKeyTap('KEY_RED'),
                  border: true,
                  color: Colors.white,
                ),
                SizedBox(height: 15),
                remoteButton(
                    isActive: true,
                    containercolor: Color(0xff7ED875),
                    label: 'B',
                    text: true,
                    icon: Icons.volume_off,
                    onTap: _sendKeyTap('KEY_GREEN'),
                    border: true,
                    color: Colors.white),
                SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_rewind_sharp,
                    onTap: _sendKeyTap('KEY_REWIND'),
                    border: true,
                    color: Colors.white),
              ],
            ),
          ),

          /// CENTER BUTTONS
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.search,
                    onTap: _sendKeyTap('KEY_SEARCH'),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.pause,
                    onTap: _sendKeyTap('KEY_PAUSE'),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.play_arrow,
                    onTap: _sendKeyTap('KEY_PLAY'),
                    border: true,
                    color: Colors.white),
              ],
            ),
          ),

          /// CHANNEL
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                remoteButton(
                    isActive: true,
                    containercolor: Color(0xffF6CC56),
                    label: 'C',
                    text: true,
                    icon: Icons.volume_off,
                    onTap: _sendKeyTap('KEY_YELLOW'),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    isActive: true,
                    containercolor: Color(0xffA1CAFE),
                    label: 'D',
                    text: true,
                    icon: Icons.volume_off,
                    onTap: _sendKeyTap('KEY_BLUE'),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_forward,
                    onTap: _sendKeyTap('KEY_FF'),
                    border: true,
                    color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// TAB BAR
  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: 60, // increased tab bar heights
        child: TabBar(
          onTap: (index) {
            controller.logButtonEvent(
              buttonKey: 'TAB_$index',
              event: 'action_triggered',
              action: 'tab_selected',
            );
            controller.selectedTab.value = index;
          },
          dividerColor: Colors.transparent, // removes white line
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Color(0xFF3A3A3A),
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.gamepad)),
            Tab(text: '123'),
          ],
        ),
      ),
    );
  }

  /// TAB CONTENTS
  Widget _buildTabViews() {
    return TabBarView(
      children: [
        Center(
          child: buildDpad(),
        ),
        // _buildKeyboardTab(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildNumberTab()),
        ),
      ],
    );
  }

  /// 123 TAB: numeric keypad (1–9, 0, GUIDE, TOOLS)
  Widget _buildNumberTab() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['GUIDE', '0', 'TOOLS'],
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
        width: isUtilityButton ? 84 : 72,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isUtilityButton ? 12 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// DPAD
  Widget buildDpad() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// OUTER CIRCLE
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[600],
            ),
          ),

          /// UP
          Positioned(
            top: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white, size: 32),
              onPressed: _sendKeyTap('KEY_UP'),
            ),
          ),

          /// DOWN
          Positioned(
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 32),
              onPressed: _sendKeyTap('KEY_DOWN'),
            ),
          ),

          /// LEFT
          Positioned(
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 32),
              onPressed: _sendKeyTap('KEY_LEFT'),
            ),
          ),

          /// RIGHT
          Positioned(
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 32),
              onPressed: _sendKeyTap('KEY_RIGHT'),
            ),
          ),

          /// OK BUTTON
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF444444),
            ),
            child: TextButton(
              onPressed: _sendKeyTap('KEY_ENTER'),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// BOTTOM BUTTONS
  Widget buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.arrow_back,
              onTap: _sendKeyTap('KEY_RETURN'),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.home,
              onTap: _sendKeyTap('KEY_HOME'),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.menu,
              onTap: _sendKeyTap('KEY_MENU'),
              border: true,
              color: Colors.white),
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
  int _skipAddedCharsFromHardware = 0;
  int _skipDeletesFromHardware = 0;

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
      final runes = added.runes.toList();
      var skip = _skipAddedCharsFromHardware;
      var startIndex = 0;
      if (skip > 0) {
        if (skip > runes.length) skip = runes.length;
        _skipAddedCharsFromHardware -= skip;
        startIndex = skip;
      }
      for (var i = startIndex; i < runes.length; i++) {
        final r = runes[i];
        final ch = String.fromCharCode(r);
        final key = mapTypedCharToRemoteKey(ch);
        if (key == null) continue;
        _enqueueTypedKey(key);
      }
    } else if (v.length < _prev.length) {
      var deletes = _prev.length - v.length;
      if (_skipDeletesFromHardware > 0) {
        final skipped = _skipDeletesFromHardware > deletes
            ? deletes
            : _skipDeletesFromHardware;
        _skipDeletesFromHardware -= skipped;
        deletes -= skipped;
      }
      for (var i = 0; i < deletes; i++) {
        _enqueueTypedKey('KEY_BACKSPACE');
      }
    }
    _prev = v;
  }

  KeyEventResult _onKeyboardEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_focusNode.hasFocus) {
      return KeyEventResult.ignored;
    }

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.backspace) {
      _skipDeletesFromHardware++;
      _enqueueTypedKey('KEY_BACKSPACE');
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      _skipAddedCharsFromHardware++;
      _enqueueTypedKey('\n');
      return KeyEventResult.handled;
    }

    final label = logical.keyLabel;
    if (label.length != 1) {
      return KeyEventResult.ignored;
    }

    final key = mapTypedCharToRemoteKey(label);
    if (key == null) {
      return KeyEventResult.ignored;
    }

    _skipAddedCharsFromHardware++;
    _enqueueTypedKey(key);
    return KeyEventResult.handled;
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
            Focus(
              onKeyEvent: _onKeyboardEvent,
              child: TextField(
                controller: _text,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'Focus a search box on your TV, then type here',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF3A3A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
