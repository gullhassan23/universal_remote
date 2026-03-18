import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../controllers/tv_connection_controller.dart';
import '../../services/tv_service_interface.dart';
import 'remote_controller.dart';

class RemoteScreen extends GetView<RemoteController> {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionController = Get.find<TvConnectionController>();
    final PageController pageController = PageController();
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
                    // buildSideButtons(),
                    SizedBox(
                      height: 202,
                      child: PageView(
                        controller: pageController,
                        children: [
                          buildMainButtons(),
                          buildSideMainButtons(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SmoothPageIndicator(
                      controller: pageController,
                      count: 2,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: Colors.white,
                        dotColor: Colors.grey,
                      ),
                    ),
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
                      onTap: () => controller.send('KEY_VOLUP'),
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
                      onTap: () => controller.send('KEY_MUTE'),
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
                      onTap: () => controller.send('KEY_VOLDOWN'),
                      border: false,
                      color: Colors.white),
                ],
              ),
            ),
          ),

          /// CENTER BUTTONS
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.power_settings_new,
                    onTap: () => controller.send('KEY_POWER'),
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
                    onTap: () => controller.send('KEY_KEYBOARD'),
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
                    onTap: () => controller.send('KEY_RETURN'),
                    border: true,
                    color: Colors.white),
              ),
            ],
          ),

          /// CHANNEL
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    remoteButton(
                        containercolor: Colors.white,
                        text: false,
                        icon: Icons.keyboard_arrow_up,
                        onTap: () => controller.send('KEY_CHUP'),
                        border: false,
                        color: Colors.white),
                    const SizedBox(height: 9),
                    remoteButton(
                        containercolor: Colors.white,
                        text: false,
                        icon: Icons.menu,
                        onTap: () {},
                        border: false,
                        color: Colors.white),
                    const SizedBox(height: 9),
                    remoteButton(
                        containercolor: Colors.white,
                        text: false,
                        icon: Icons.keyboard_arrow_down,
                        onTap: () => controller.send('KEY_CHDOWN'),
                        border: false,
                        color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
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
                  onTap: () => controller.send('KEY_RED'),
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
                    onTap: () => controller.send('KEY_GREEN'),
                    border: true,
                    color: Colors.white),
                SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_rewind_sharp,
                    onTap: () => controller.send('KEY_REWIND'),
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
                    onTap: () => controller.send('KEY_SEARCH'),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.pause,
                    onTap: () => controller.send('KEY_PAUSE'),
                    border: true,
                    color: Colors.white),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.play_arrow,
                    onTap: () => controller.send('KEY_PLAY'),
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
                    onTap: () => controller.send('KEY_YELLOW'),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    isActive: true,
                    containercolor: Color(0xffA1CAFE),
                    label: 'D',
                    text: true,
                    icon: Icons.volume_off,
                    onTap: () => controller.send('KEY_BLUE'),
                    border: true,
                    color: Colors.white),
                const SizedBox(height: 15),
                remoteButton(
                    containercolor: Colors.white,
                    text: false,
                    icon: Icons.fast_forward,
                    onTap: () => controller.send('KEY_FF'),
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
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.arrow_back,
              onTap: () => controller.send('KEY_RETURN'),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.home,
              onTap: () => controller.send('KEY_HOME'),
              border: true,
              color: Colors.white),
          remoteButton(
              containercolor: Colors.white,
              text: false,
              icon: Icons.menu,
              onTap: () => controller.send('KEY_MENU'),
              border: true,
              color: Colors.white),
        ],
      ),
    );
  }
}
