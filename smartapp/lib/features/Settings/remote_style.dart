import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';
import 'package:smartapp/utils/premium_navigation.dart';

class RemoteStyleScreen extends StatefulWidget {
  const RemoteStyleScreen({super.key});

  @override
  State<RemoteStyleScreen> createState() => _RemoteStyleScreenState();
}

class _RemoteStyleScreenState extends State<RemoteStyleScreen> {
  final RemoteStyleController _styleController =
      Get.find<RemoteStyleController>();
  final PremiumController _premiumController = Get.find<PremiumController>();

  bool _isFreeWallpaper(String wallpaperPath) {
    return wallpaperPath == _styleController.wallpapers.last;
  }

  @override
  void initState() {
    super.initState();
    _styleController.prepareSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(ImageRes.kGetStartedBackgroundAsset2),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.adaptive.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: HapticAction.wrap(Get.back),
                      padding: const EdgeInsets.only(left: 12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Remote Style',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FlutterCarousel.builder(
                    itemCount: _styleController.wallpapers.length,
                    itemBuilder: (context, index, realIndex) {
                      final wallpaperPath = _styleController.wallpapers[index];
                      return Obx(() {
                        final isPremiumUser = _premiumController.isPremium.value;
                        final isFreeWallpaper = _isFreeWallpaper(wallpaperPath);
                        final isSelected =
                            _styleController.selectedWallpaper.value ==
                                wallpaperPath;

                        return GestureDetector(
                          onTap: () =>
                              _styleController.selectWallpaper(wallpaperPath),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4FC3F7)
                                          : Colors.white24,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    image: DecorationImage(
                                      image: AssetImage(wallpaperPath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? const Color(0xFF4FC3F7)
                                        : Colors.white70,
                                  ),
                                ),
                                if (!isPremiumUser && !isFreeWallpaper)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.diamond_outlined,
                                        size: 16,
                                        color: Color(0xFFFFD27A),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      });
                    },
                    options: FlutterCarouselOptions(
                      height: 500,
                      viewportFraction: 0.72,
                      enlargeCenterPage: true,
                      enableInfiniteScroll: false,
                      showIndicator: true,
                      slideIndicator: CircularSlideIndicator(
                        slideIndicatorOptions: SlideIndicatorOptions(
                          indicatorBackgroundColor: Colors.white24,
                          currentIndicatorColor: const Color(0xFF4FC3F7),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final selectedWallpaper =
                          _styleController.selectedWallpaper.value;
                      final canApplyForFree =
                          _isFreeWallpaper(selectedWallpaper);
                      if (!_premiumController.isPremium.value &&
                          !canApplyForFree) {
                        await _styleController
                            .setPendingPremiumWallpaper(selectedWallpaper);
                        openPremiumPaywall();
                        return;
                      }
                      await _styleController.applySelection();
                      if (!context.mounted) return;
                      Get.back<void>();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
