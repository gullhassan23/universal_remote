/// Bindings for the `/home` shell ([BottomNav]): remote, cast, streaming, ads, and UX prefs.
///
/// **Core / session** (TV connection, discovery, analytics, IAP) are registered in
/// `_registerCoreDependencies()` in `main.dart` so they persist across onboarding → home and are
/// not disposed with this route.
///
/// **Shell controllers** here use `lazyPut` + `fenix: true` so leaving `/home` can dispose heavy
/// controllers (cast, ads) while allowing recreation when the user returns. Registration order
/// follows constructor dependencies: MediaCast → Remote → Voice (Voice needs Remote).
import 'package:get/get.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/ad_controller.dart';
import 'package:smartapp/controllers/keyboard_controller.dart';
import 'package:smartapp/controllers/media_cast_controller.dart';
import 'package:smartapp/controllers/remote_controller.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/controllers/rewarded_media_cast_controller.dart';
import 'package:smartapp/controllers/sleep_timer_controller.dart';
import 'package:smartapp/controllers/streaming_controller.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';
import 'package:smartapp/controllers/voice_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MediaCastController>()) {
      Get.lazyPut<MediaCastController>(
        () => MediaCastController(
          connectionController: Get.find<TvConnectionController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<RemoteController>()) {
      Get.lazyPut<RemoteController>(
        () => RemoteController(
          connectionController: Get.find<TvConnectionController>(),
          discoveryController: Get.find<DeviceDiscoveryController>(),
          mediaCastController: Get.find<MediaCastController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<KeyboardController>()) {
      Get.lazyPut<KeyboardController>(
        () => KeyboardController(
          connectionController: Get.find<TvConnectionController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VoiceController>()) {
      Get.lazyPut<VoiceController>(
        () => VoiceController(
          connectionController: Get.find<TvConnectionController>(),
          remoteController: Get.find<RemoteController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<StreamingController>()) {
      Get.lazyPut<StreamingController>(
        () => StreamingController(
          connectionController: Get.find<TvConnectionController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<SleepTimerController>()) {
      Get.lazyPut<SleepTimerController>(
        () => SleepTimerController(
          connectionController: Get.find<TvConnectionController>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<AdController>()) {
      Get.lazyPut<AdController>(
        () => AdController(
          adUnitId: AdMobConfig.bannerAdUnitId,
          interstitialAdUnitId: AdMobConfig.interstitialAdUnitId,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VibrationController>()) {
      Get.lazyPut<VibrationController>(
        () => VibrationController(),
        fenix: true,
      );
    }
    if (!Get.isRegistered<RemoteStyleController>()) {
      Get.lazyPut<RemoteStyleController>(
        () => RemoteStyleController(),
        fenix: true,
      );
    }
    if (!Get.isRegistered<RewardedMediaCastController>()) {
      Get.lazyPut<RewardedMediaCastController>(
        () => RewardedMediaCastController(),
        fenix: true,
      );
    }
  }
}
