import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartapp/utils/constant.dart';

class RemoteStyleController extends GetxController {
  static const String _prefsWallpaperKey = 'remote_wallpaper_v1';
  static const String _prefsPendingWallpaperKey = 'remote_wallpaper_pending_v1';

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
  final RxnString pendingPremiumWallpaper = RxnString();

  RemoteWallpaperButtonAssets? get activeButtonAssets {
    switch (appliedWallpaper.value) {
      case RemoteWallpaperAssets.wallpaper1:
        return RemoteWallpaper1ButtonAssets.set;
      case RemoteWallpaperAssets.wallpaper2:
        return RemoteWallpaper2ButtonAssets.set;
      case RemoteWallpaperAssets.wallpaper3:
        return RemoteWallpaper3ButtonAssets.set;
      default:
        return null;
    }
  }

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
    pendingPremiumWallpaper.value = prefs.getString(_prefsPendingWallpaperKey);
  }

  void prepareSelection() {
    selectedWallpaper.value = appliedWallpaper.value;
  }

  void selectWallpaper(String wallpaperPath) {
    selectedWallpaper.value = wallpaperPath;
  }

  Future<void> applySelection() async {
    final nextWallpaper = selectedWallpaper.value;
    await applyWallpaper(nextWallpaper);
  }

  Future<void> applyWallpaper(String wallpaperPath) async {
    if (wallpaperPath.isEmpty || !wallpapers.contains(wallpaperPath)) {
      return;
    }
    appliedWallpaper.value = wallpaperPath;
    selectedWallpaper.value = wallpaperPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWallpaperKey, wallpaperPath);
  }

  Future<void> setPendingPremiumWallpaper(String wallpaperPath) async {
    if (wallpaperPath.isEmpty || !wallpapers.contains(wallpaperPath)) return;
    pendingPremiumWallpaper.value = wallpaperPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPendingWallpaperKey, wallpaperPath);
  }

  Future<void> clearPendingPremiumWallpaper() async {
    pendingPremiumWallpaper.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPendingWallpaperKey);
  }

  /// Call after premium becomes active to auto-apply a wallpaper user picked while locked.
  Future<void> applyPendingPremiumWallpaperIfAny() async {
    final pending = pendingPremiumWallpaper.value;
    if (pending == null || pending.isEmpty) return;
    if (!wallpapers.contains(pending)) {
      await clearPendingPremiumWallpaper();
      return;
    }
    await applyWallpaper(pending);
    await clearPendingPremiumWallpaper();
  }
}
