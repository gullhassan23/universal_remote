import 'package:flutter/material.dart';
import 'package:smartapp/features/Streamings/streaming_apps_screen.dart';
import 'package:smartapp/features/Settings/settings_screen.dart';
import 'package:smartapp/features/cast/cast_screen.dart';
import 'package:smartapp/features/remote/remote_screen.dart';
import 'package:smartapp/utils/constant.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = <Widget>[
    RemoteScreen(),
    StreamingAppsScreen(),
    CastScreen(),
    SettingsScreen(),
  ];

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
          setState(() {
            _selectedIndex = index;
          });
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
}
