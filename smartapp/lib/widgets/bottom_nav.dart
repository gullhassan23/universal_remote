import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/Streamings/streaming_apps_screen.dart';
import 'package:smartapp/features/Settings/settings_screen.dart';
import 'package:smartapp/features/cast/cast_screen.dart';
import 'package:smartapp/features/remote/remote_screen.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/utils/constant.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;
  late final AnalyticsService _analyticsService;
  static const List<String> _tabScreenKeys = <String>[
    'Remote_View',
    'Streaming_App_Screen',
    'CastScreen',
    'SettingsScreen',
  ];
  static const List<String> _tabNavNames = <String>[
    'Remote',
    'Streaming',
    'Cast',
    'Settings',
  ];

  static  List<Widget> _tabs = <Widget>[
    RemoteScreen(),
    StreamingAppsScreen(),
    CastScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _analyticsService = Get.find<AnalyticsService>();
    _trackTab(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF242b34),
        indicatorColor: const Color.fromARGB(33, 11, 27, 37),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
          ),
        ),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          final previousIndex = _selectedIndex;
          setState(() {
            _selectedIndex = index;
          });
          if (previousIndex != index) {
            _analyticsService.trackBottomNav(
              _tabNavNames[index],
              from: _tabNavNames[previousIndex],
            );
          }
          _trackTab(index);
        },
        destinations: [
          NavigationDestination(
            icon: _navIcon(NavIcon.remoteIcon),
            selectedIcon: _navIcon(NavIcon.remoteIcon, isSelected: true),
            label: 'Remote',
          ),
          NavigationDestination(
            icon: _navIcon(NavIcon.appsIcon),
            selectedIcon: _navIcon(NavIcon.appsIcon, isSelected: true),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: _navIcon(NavIcon.castIcon),
            selectedIcon: _navIcon(NavIcon.castIcon, isSelected: true),
            label: 'Cast',
          ),
          NavigationDestination(
            icon: _navIcon(NavIcon.settingsIcon),
            selectedIcon: _navIcon(NavIcon.settingsIcon, isSelected: true),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _navIcon(String assetPath, {bool isSelected = false}) {
    return Opacity(
      opacity: isSelected ? 1 : 0.7,
      child: Image.asset(
        assetPath,
        width: isSelected ? 30 : 25,
        height: isSelected ? 30 : 25,
      ),
    );
  }

  void _trackTab(int index) {
    _analyticsService.trackScreenByKey(_tabScreenKeys[index]);
  }
}
