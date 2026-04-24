import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/features/Settings/remote_style.dart';
import 'package:smartapp/features/premium/premium_screen.dart';

bool isPremiumUnlocked() {
  final PremiumController premiumController = Get.find<PremiumController>();
  return premiumController.isPremium.value;
}

void openPremiumPaywall() {
  Get.to(() => const PremiumScreen());
}

void openRemoteStyleOrPaywall() {
  if (isPremiumUnlocked()) {
    Get.to(() => const RemoteStyleScreen());
    return;
  }
  openPremiumPaywall();
}

