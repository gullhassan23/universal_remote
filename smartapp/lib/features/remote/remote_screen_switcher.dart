import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/utils/constant.dart';

import 'remote_screen.dart';
import 'remote_screen2.dart';
import 'remote_screen3.dart';
import 'remote_screen6.dart';

/// Reactively renders the remote screen variant that matches the currently
/// applied wallpaper. Each variant has its own hardcoded background and button
/// art, so changing the wallpaper swaps the entire screen tree (instead of
/// updating images in-place on a single shared screen).
class RemoteScreenSwitcher extends StatelessWidget {
  const RemoteScreenSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final styleController = Get.find<RemoteStyleController>();
    return Obx(() {
      switch (styleController.appliedWallpaper.value) {
        case RemoteWallpaperAssets.wallpaper2:
          return RemoteScreen2();
        case RemoteWallpaperAssets.wallpaper3:
          return RemoteScreen3();
        case RemoteWallpaperAssets.wallpaper6:
          return RemoteScreen6();
        case RemoteWallpaperAssets.wallpaper1:
        default:
          return RemoteScreen();
      }
    });
  }
}
