import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import '../remote/remote_screen.dart';

class HomeController extends GetxController {
  final RxList<TvBrand> brands =
      <TvBrand>[TvBrand.samsung, TvBrand.lg, TvBrand.sony].obs;

  void onBrandSelected(TvBrand brand) {
    switch (brand) {
      case TvBrand.samsung:
      case TvBrand.sony:
        Get.to(() => const RemoteScreen());
        break;
      case TvBrand.lg:
        Get.snackbar('Coming soon', 'Support for LG is coming soon.');
        break;
    }
  }
}

