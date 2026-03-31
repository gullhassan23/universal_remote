import 'package:flutter/material.dart';
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
    TvBrand.samsung,
    TvBrand.lg,
    TvBrand.sony,
    TvBrand.androidTv
  ].obs;

  void onBrandSelected(TvBrand brand) {
    switch (brand) {
      case TvBrand.samsung:
      case TvBrand.sony:
      case TvBrand.androidTv:
        // Remember the user's chosen brand so discovery can filter devices.
        _discoveryController.setPreferredBrand(brand);
        Get.to(() => const RemoteScreen());
        break;
      case TvBrand.lg:
        Get.snackbar(
            colorText: Colors.white,
            'Coming soon',
            'Support for LG is coming soon.');
        break;
    }
  }
}
