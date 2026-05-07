import 'dart:ui';

const Color kGradientTop = Color(0xFF00B0B6);
const Color kGradientBottom = Color(0xFF005AFF);
const Color buttonText = Color(0xFF333333);

class ImageRes {
  ImageRes._();
  static const String onboardingMobile = 'assets/images/onboarding/Mobile.png';
  static const String onboardingWifi = "assets/images/onboarding/Wifi.png";
  static const String onboardingLCD = "assets/images/onboarding/LCD.png";
  static const String kGetStartedBackgroundAsset =
      'assets/images/waves_design.png';

  static const String kGetStartedBackgroundAsset2 = 'assets/images/BGround.png';
}

class RemoteWallpaperAssets {
  RemoteWallpaperAssets._();

  static const String wallpaper1 =
      'assets/images/remote_wallpapers/wallpaper_1.png';
  static const String wallpaper2 =
      'assets/images/remote_wallpapers/wallpaper_2.png';
  static const String wallpaper3 =
      'assets/images/remote_wallpapers/wallpaper_3.png';
  static const String wallpaper6 =
      'assets/images/remote_wallpapers/wallpaper_6.png';
}

class RemoteWallpaperButtonAssets {
  const RemoteWallpaperButtonAssets._({required String basePath})
      : volUp = '$basePath/10.png',
        mic = '$basePath/18.png',
        mute = '$basePath/11.png',
        plus = '$basePath/plus.png',
        minus = '$basePath/minus.png',
        sound = '$basePath/mute.png',
        volDown = '$basePath/12.png',
        search = '$basePath/2.png',
        power = '$basePath/1.png',
        keyboard = '$basePath/3.png',
        input = '$basePath/7.png',
        gamepad = '$basePath/gamepad.png',
        back = '$basePath/9.png',
        home = '$basePath/8.png',
        modeDpad = '$basePath/6.png',
        modeNumbers = '$basePath/5.png',
        number = "$basePath/number.png",
        dpadOk = '$basePath/13.png',
        togglebar = '$basePath/togglebar.png',
        dpadDown = '$basePath/downarrow.png',
        dpadRight = '$basePath/rightarrow.png',
        volumebar = '$basePath/volumebar.png',
        dpadUp = '$basePath/uparrow.png',
        dpadLeft = '$basePath/leftarrow.png',
        dpadcircle = '$basePath/circle.png';

  final String volUp;
  final String mute;
  final String volDown;
  final String search;
  final String power;
  final String keyboard;
  final String input;
  final String back;
  final String home;
  final String number;
  final String modeDpad;
  final String modeNumbers;
  final String dpadOk;
  final String dpadDown;
  final String dpadcircle;
  final String dpadRight;
  final String dpadUp;
  final String dpadLeft;
  final String mic;
  final String gamepad;
  final String togglebar;
  final String volumebar;
  final String plus;
  final String minus;
  final String sound;
}

/// Button art mapping for [RemoteWallpaperAssets.wallpaper1].
class RemoteWallpaper1ButtonAssets {
  RemoteWallpaper1ButtonAssets._();

  static const RemoteWallpaperButtonAssets set = RemoteWallpaperButtonAssets._(
    basePath: 'assets/images/remote_wallpapers/wallpaper1',
  );
}

/// Button art mapping for [RemoteWallpaperAssets.wallpaper2].
class RemoteWallpaper2ButtonAssets {
  RemoteWallpaper2ButtonAssets._();

  static const RemoteWallpaperButtonAssets set = RemoteWallpaperButtonAssets._(
    basePath: 'assets/images/remote_wallpapers/wallpaper2',
  );
}

/// Button art mapping for [RemoteWallpaperAssets.wallpaper3].
class RemoteWallpaper3ButtonAssets {
  RemoteWallpaper3ButtonAssets._();

  static const RemoteWallpaperButtonAssets set = RemoteWallpaperButtonAssets._(
    basePath: 'assets/images/remote_wallpapers/wallpaper3',
  );
}

/// Button art mapping for [RemoteWallpaperAssets.wallpaper6].
class RemoteWallpaper6ButtonAssets {
  RemoteWallpaper6ButtonAssets._();

  static const RemoteWallpaperButtonAssets set = RemoteWallpaperButtonAssets._(
    basePath: 'assets/images/remote_wallpapers/wallpaper6',
  );
}

class CastTileImage {
  static const browse = 'assets/images/Browser.png';
  static const mirror = 'assets/images/Mirror.png';
  static const media = 'assets/images/Media.png';
  static const youtube = 'assets/images/Youtube.png';
}

class Premium {
  static const String premium = "assets/images/premium/Premium Access.png";
}

class StreamingAppIcon {
  static const String netflix = 'assets/images/netflix-icon.png';
  static const String youtube = 'assets/images/YTLogo.png';
  static const String prime = 'assets/images/prime.png';
}

class SettingsIcon {
  static const String faq = 'assets/images/settings/FAQ.png';
  static const String haptic = 'assets/images/settings/Hapticfeedback.png';
  static const String privacy = 'assets/images/settings/Privacypolicy.png';
  static const String remotestyle = 'assets/images/settings/Remotestyle.png';
  static const String restore = 'assets/images/settings/Restorepurchases.png';
  static const String sleep = 'assets/images/settings/Sleeptimer.png';
  static const String switchdevice = 'assets/images/settings/SwitchDevice.png';
  static const String howtouse = 'assets/images/settings/howtouse.png';
  static const String term = 'assets/images/settings/Terms.png';
  static const String notebook = 'assets/images/settings/NotePad.png';
}

class NavIcon {
  static const String remoteIcon = 'assets/images/bottomnav/Remote.png';
  static const String appsIcon = 'assets/images/bottomnav/Apps.png';
  static const String castIcon = 'assets/images/bottomnav/Cast.png';
  static const String settingsIcon = 'assets/images/bottomnav/Setting.png';
}
