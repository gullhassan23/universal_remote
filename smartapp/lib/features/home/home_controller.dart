import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import '../device_discovery/device_discovery_controller.dart';
import '../remote/remote_screen.dart';

class HomeController extends GetxController {
  HomeController({DeviceDiscoveryController? discoveryController})
      : _discoveryController =
            discoveryController ?? Get.find<DeviceDiscoveryController>();

  final DeviceDiscoveryController _discoveryController;

  final RxList<TvBrand> brands = <TvBrand>[
    TvBrand.androidTv,
  ].obs;

  void onBrandSelected(TvBrand brand) {
    // Android TV only.
    _discoveryController.setPreferredBrand(TvBrand.androidTv);
    Get.to(() => const RemoteScreen());
  }
}
