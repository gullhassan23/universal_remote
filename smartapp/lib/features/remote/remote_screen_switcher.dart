import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/features/remote/remote_screen2.dart';
import 'package:smartapp/features/remote/remote_screen4.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/utils/constant.dart';

import 'remote_screen3.dart';

import 'remote_screen.dart';

/// Reactively renders the remote screen variant that matches the currently
/// applied wallpaper. Each variant has its own hardcoded background and button
/// art, so changing the wallpaper swaps the entire screen tree (instead of
/// updating images in-place on a single shared screen).
class RemoteScreenSwitcher extends StatefulWidget {
  const RemoteScreenSwitcher({super.key});

  @override
  State<RemoteScreenSwitcher> createState() => _RemoteScreenSwitcherState();
}

class _RemoteScreenSwitcherState extends State<RemoteScreenSwitcher> {
  late final RemoteStyleController _styleController;
  late final AnalyticsService _analyticsService;
  Worker? _wallpaperWorker;
  bool _didPrecacheWallpapers = false;

  @override
  void initState() {
    super.initState();
    _styleController = Get.find<RemoteStyleController>();
    _analyticsService = Get.find<AnalyticsService>();
    _wallpaperWorker = ever<String>(
      _styleController.appliedWallpaper,
      _trackWallpaperScreen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackWallpaperScreen(_styleController.appliedWallpaper.value);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheWallpapers) return;
    _didPrecacheWallpapers = true;
    for (final wallpaper in _wallpapersToPrecache) {
      unawaited(precacheImage(AssetImage(wallpaper), context));
    }
  }

  @override
  void dispose() {
    _wallpaperWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final wallpaper = _styleController.appliedWallpaper.value;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: RepaintBoundary(
          key: ValueKey<String>(wallpaper),
          child: _screenForWallpaper(wallpaper),
        ),
      );
    });
  }

  Widget _screenForWallpaper(String wallpaper) {
    switch (wallpaper) {
      case RemoteWallpaperAssets.wallpaper3:
        return const RemoteScreen3();
      case RemoteWallpaperAssets.wallpaper4:
        return const RemoteScreen4();
      case RemoteWallpaperAssets.wallpaper2:
        return const RemoteScreen2();
      case RemoteWallpaperAssets.wallpaper:
      default:
        return const RemoteScreen();
    }
  }

  void _trackWallpaperScreen(String wallpaper) {
    final meta = _screenMetaForWallpaper(wallpaper);
    unawaited(
      _analyticsService.logScreen(
        screenName: meta.$1,
        screenClass: meta.$2,
      ),
    );
  }

  (String, String) _screenMetaForWallpaper(String wallpaper) {
    switch (wallpaper) {
      case RemoteWallpaperAssets.wallpaper3:
        return ('Remote_Screen_3', 'RemoteScreen3');
      case RemoteWallpaperAssets.wallpaper4:
        return ('Remote_Screen_4', 'RemoteScreen4');
      case RemoteWallpaperAssets.wallpaper2:
        return ('Remote_Screen_2', 'RemoteScreen2');
      case RemoteWallpaperAssets.wallpaper:
      default:
        return ('Remote_Screen', 'RemoteScreen');
    }
  }

  static const List<String> _wallpapersToPrecache = <String>[
    RemoteWallpaperAssets.wallpaper,
    RemoteWallpaperAssets.wallpaper2,
    RemoteWallpaperAssets.wallpaper3,
    RemoteWallpaperAssets.wallpaper4,
  ];
}
