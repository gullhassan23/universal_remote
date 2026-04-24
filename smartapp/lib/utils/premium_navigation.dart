import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/features/Settings/remote_style.dart';
import 'package:smartapp/features/premium/premium_screen.dart';

void openRemoteStyleOrPaywall() {
  final PremiumController premiumController = Get.find<PremiumController>();
  if (premiumController.isPremium.value) {
    Get.to(() => const RemoteStyleScreen());
    return;
  }
  Get.to(() => const PremiumScreen());
}
