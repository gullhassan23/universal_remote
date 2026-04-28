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

// void openPremiumStatusScreen() {
//   if (isPremiumUnlocked()) {
//     Get.to(() => const Pro_Screen());
//     return;
//   }
//   openPremiumPaywall();
// }
void openPremiumStatusScreen() {
  if (isPremiumUnlocked()) {
    return; // 🚫 Do nothing if already premium
  }

  openPremiumPaywall(); // ✅ Only for non-premium users
}

void openRemoteStyleOrPaywall() {
  Get.to(() => const RemoteStyleScreen());
}
