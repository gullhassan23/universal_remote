import 'package:flutter/material.dart';
import 'package:smartapp/features/Streamings/streaming_apps_screen.dart';
import 'package:smartapp/features/Settings/settings_screen.dart';
import 'package:smartapp/features/remote/remote_screen.dart';

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
        backgroundColor: const Color(0xFF005AFF),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.gamepad, color: Colors.white70),
            selectedIcon: Icon(Icons.gamepad, color: Colors.white),
            label: 'Remote',
          ),
          NavigationDestination(
            icon: Icon(Icons.ondemand_video_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.ondemand_video, color: Colors.white),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.settings, color: Colors.white),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
