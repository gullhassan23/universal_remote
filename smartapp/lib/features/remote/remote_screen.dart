import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tv_connection_controller.dart';
import '../../services/tv_service_interface.dart';
import 'remote_controller.dart';

class RemoteScreen extends GetView<RemoteController> {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionController = Get.find<TvConnectionController>();

    return Scaffold(
      backgroundColor: const Color(0xFF444643),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Connect a device",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
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
                    buildSideButtons(),
                    const SizedBox(height: 24),
                    _buildTabs(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: _buildTabViews(),
                    ),
                    buildBottomButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      /// Bottom Navigation
      // bottomNavigationBar: Container(
      //   height: 70,
      //   color: const Color(0xFF1A1A1A),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceAround,
      //     children: const [
      //       _NavItem(icon: Icons.settings_remote, label: "Remote"),
      //       _NavItem(icon: Icons.apps, label: "Apps"),
      //       _NavItem(icon: Icons.cast, label: "Cast"),
      //       _NavItem(icon: Icons.settings, label: "Settings"),
      //     ],
      //   ),
      // ),
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
  Widget remoteButton(
      IconData icon, VoidCallback onTap, bool border, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: border ? 80 : 60,
        height: 50,
        decoration: border
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black),
              )
            : null,
        child: Icon(icon, color: color),
      ),
    );
  }

  /// SIDE BUTTONS (Volume / Power / Channel)
  Widget buildSideButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  remoteButton(Icons.add, () => controller.send('KEY_VOLUP'),
                      false, Colors.white),
                  const Divider(
                    color: Colors.black,
                    height: 10,
                    thickness: 5,
                  ),
                  remoteButton(Icons.volume_off,
                      () => controller.send('KEY_MUTE'), false, Colors.white),
                  const Divider(
                    color: Colors.black,
                    height: 12,
                    thickness: 1,
                  ),
                  remoteButton(
                      Icons.remove,
                      () => controller.send('KEY_VOLDOWN'),
                      false,
                      Colors.white),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 40,
          ),

          /// CENTER BUTTONS
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(Icons.power_settings_new,
                    () => controller.send('KEY_POWER'), true, Colors.red),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(Icons.keyboard,
                    () => controller.send('KEY_KEYBOARD'), true, Colors.white),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(Icons.exit_to_app,
                    () => controller.send('KEY_RETURN'), true, Colors.white),
              ),
            ],
          ),
          SizedBox(
            width: 40,
          ),

          /// CHANNEL
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    remoteButton(Icons.keyboard_arrow_up,
                        () => controller.send('KEY_CHUP'), false, Colors.white),
                    const SizedBox(height: 10),
                    remoteButton(Icons.menu, () {}, false, Colors.white),
                    const SizedBox(height: 10),
                    remoteButton(
                        Icons.keyboard_arrow_down,
                        () => controller.send('KEY_CHDOWN'),
                        false,
                        Colors.white),
                  ],
                ),
              ),
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
        _buildNumberTab(),
      ],
    );
  }

  /// Keyboard TAB: simple keyboard prompt
  // Widget _buildKeyboardTab() {
  //   return Center(
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(horizontal: 24),
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //       decoration: BoxDecoration(
  //         color: const Color(0xFF2A2A2A),
  //         borderRadius: BorderRadius.circular(24),
  //       ),
  //       child: Row(
  //         children: [
  //           const Icon(Icons.keyboard, color: Colors.white70),
  //           const SizedBox(width: 8),
  //           const Expanded(
  //             child: Text(
  //               'Use phone keyboard to type on TV',
  //               style: TextStyle(color: Colors.white70, fontSize: 13),
  //             ),
  //           ),
  //           IconButton(
  //             icon: const Icon(Icons.send, color: Colors.white70),
  //             onPressed: () => controller.send('KEY_TTX_SUBFACE'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
    if (label == 'GUIDE') {
      keyCode = 'KEY_GUIDE';
    } else if (label == 'TOOLS') {
      keyCode = 'KEY_TOOLS';
    } else {
      keyCode = 'KEY_$label';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.send(keyCode),
      child: Container(
        width: 100,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFA9ACAB),
            ),
          ),

          /// UP
          Positioned(
            top: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white, size: 32),
              onPressed: () => controller.send('KEY_UP'),
            ),
          ),

          /// DOWN
          Positioned(
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 32),
              onPressed: () => controller.send('KEY_DOWN'),
            ),
          ),

          /// LEFT
          Positioned(
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 32),
              onPressed: () => controller.send('KEY_LEFT'),
            ),
          ),

          /// RIGHT
          Positioned(
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 32),
              onPressed: () => controller.send('KEY_RIGHT'),
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
              onPressed: () => controller.send('KEY_ENTER'),
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
  Widget buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          remoteButton(Icons.arrow_back, () => controller.send('KEY_RETURN'),
              true, Colors.white),
          remoteButton(Icons.home, () => controller.send('KEY_HOME'), true,
              Colors.white),
          remoteButton(Icons.menu, () => controller.send('KEY_MENU'), true,
              Colors.white),
        ],
      ),
    );
  }
}
