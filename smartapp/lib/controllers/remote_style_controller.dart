import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartapp/utils/constant.dart';

class RemoteStyleController extends GetxController {
  static const String _prefsWallpaperKey = 'remote_wallpaper_v1';

  final List<String> wallpapers = <String>[
    RemoteWallpaperAssets.wallpaper1,
    RemoteWallpaperAssets.wallpaper2,
    RemoteWallpaperAssets.wallpaper3,
    RemoteWallpaperAssets.wallpaper4,
    RemoteWallpaperAssets.wallpaper5,
    RemoteWallpaperAssets.wallpaper6
  ];

  final RxString appliedWallpaper = ImageRes.kGetStartedBackgroundAsset2.obs;
  final RxString selectedWallpaper = ''.obs;

  @override
  void onInit() {
    super.onInit();
    selectedWallpaper.value = appliedWallpaper.value;
    loadSavedWallpaper();
  }

  Future<void> loadSavedWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsWallpaperKey);
    if (saved != null && wallpapers.contains(saved)) {
      appliedWallpaper.value = saved;
      selectedWallpaper.value = saved;
    }
  }

  void prepareSelection() {
    selectedWallpaper.value = appliedWallpaper.value;
  }

  void selectWallpaper(String wallpaperPath) {
    selectedWallpaper.value = wallpaperPath;
  }

  Future<void> applySelection() async {
    final nextWallpaper = selectedWallpaper.value;
    if (nextWallpaper.isEmpty || !wallpapers.contains(nextWallpaper)) {
      return;
    }
    appliedWallpaper.value = nextWallpaper;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWallpaperKey, nextWallpaper);
  }
}
