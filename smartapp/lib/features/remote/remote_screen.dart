import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../controllers/tv_connection_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final connectionController = Get.find<TvConnectionController>();
    final PageController pageController = PageController();
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
                      child: buildMainButtons(),
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
  Widget buildMainButtons() {
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
                      onTap: _loggedTap(
                        'KEY_VOLUP',
                        () => controller.send('KEY_VOLUP'),
                        action: 'send_key',
                      ),
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
                      onTap: _loggedTap(
                        'KEY_MUTE',
                        () => controller.send('KEY_MUTE'),
                        action: 'send_key',
                      ),
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
                      onTap: _loggedTap(
                        'KEY_VOLDOWN',
                        () => controller.send('KEY_VOLDOWN'),
                        action: 'send_key',
                      ),
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
              onTap: _loggedTap(
                'KEY_SEARCH',
                () => controller.send('KEY_SEARCH'),
                action: 'send_key',
              ),
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
                    onTap: _loggedTap(
                      'KEY_POWER',
                      () => controller.send('KEY_POWER'),
                      action: 'send_key',
                    ),
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
                    onTap: _loggedTap(
                      'KEY_KEYBOARD',
                      () => controller.send('KEY_KEYBOARD'),
                      action: 'send_key',
                    ),
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
                    onTap: _loggedTap(
                      'KEY_RETURN',
                      () => controller.send('KEY_RETURN'),
                      action: 'send_key',
                    ),
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
                  onTap: _loggedTap(
                    'KEY_RED',
                    () => controller.send('KEY_RED'),
                    action: 'send_key',
                  ),
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
                    onTap: _loggedTap(
                      'KEY_GREEN',
                      () => controller.send('KEY_GREEN'),
                      action: 'send_key',
                    ),
                    border: true,
                    color: Colors.white),
                SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_rewind_sharp,
                    onTap: _loggedTap(
                      'KEY_REWIND',
                      () => controller.send('KEY_REWIND'),
                      action: 'send_key',
                    ),
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
                    onTap: _loggedTap(
                      'KEY_SEARCH',
                      () => controller.send('KEY_SEARCH'),
                      action: 'send_key',
                    ),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.pause,
                    onTap: _loggedTap(
                      'KEY_PAUSE',
                      () => controller.send('KEY_PAUSE'),
                      action: 'send_key',
                    ),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.play_arrow,
                    onTap: _loggedTap(
                      'KEY_PLAY',
                      () => controller.send('KEY_PLAY'),
                      action: 'send_key',
                    ),
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
                    onTap: _loggedTap(
                      'KEY_YELLOW',
                      () => controller.send('KEY_YELLOW'),
                      action: 'send_key',
                    ),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    isActive: true,
                    containercolor: Color(0xffA1CAFE),
                    label: 'D',
                    text: true,
                    icon: Icons.volume_off,
                    onTap: _loggedTap(
                      'KEY_BLUE',
                      () => controller.send('KEY_BLUE'),
                      action: 'send_key',
                    ),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_forward,
                    onTap: _loggedTap(
                      'KEY_FF',
                      () => controller.send('KEY_FF'),
                      action: 'send_key',
                    ),
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
      onTap: _loggedTap(
        keyCode,
        () => controller.send(keyCode),
        action: 'send_key',
      ),
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
              onPressed: _loggedTap(
                'KEY_UP',
                () => controller.send('KEY_UP'),
                action: 'send_key',
              ),
            ),
          ),

          /// DOWN
          Positioned(
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 32),
              onPressed: _loggedTap(
                'KEY_DOWN',
                () => controller.send('KEY_DOWN'),
                action: 'send_key',
              ),
            ),
          ),

          /// LEFT
          Positioned(
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 32),
              onPressed: _loggedTap(
                'KEY_LEFT',
                () => controller.send('KEY_LEFT'),
                action: 'send_key',
              ),
            ),
          ),

          /// RIGHT
          Positioned(
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 32),
              onPressed: _loggedTap(
                'KEY_RIGHT',
                () => controller.send('KEY_RIGHT'),
                action: 'send_key',
              ),
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
              onPressed: _loggedTap(
                'KEY_ENTER',
                () => controller.send('KEY_ENTER'),
                action: 'send_key',
              ),
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
              onTap: _loggedTap(
                'KEY_RETURN',
                () => controller.send('KEY_RETURN'),
                action: 'send_key',
              ),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.home,
              onTap: _loggedTap(
                'KEY_HOME',
                () => controller.send('KEY_HOME'),
                action: 'send_key',
              ),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.menu,
              onTap: _loggedTap(
                'KEY_MENU',
                () => controller.send('KEY_MENU'),
                action: 'send_key',
              ),
              border: true,
              color: Colors.white),
        ],
      ),
    );
  }
}
