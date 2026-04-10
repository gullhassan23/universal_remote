import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/subscription_iap_service.dart';

import 'package:smartapp/utils/constant.dart';

import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premiumController = Get.find<PremiumController>();
    final iapService = Get.find<SubscriptionIAPService>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topContentPadding =
        MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: kGradientBottom,
      appBar: AppBar(
        leading:
            Icon(Icons.settings, color: Colors.white.withValues(alpha: 0.85)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Universal TV Remote',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          Obx(() {
            final isPremium = premiumController.isPremium.value;
            final isLoading = iapService.isLoading.value;
            return TextButton.icon(
              onPressed:
                  isLoading ? null : () => _showSubscriptionSheet(context),
              icon: Icon(
                isPremium ? Icons.workspace_premium : Icons.lock_open,
                color: Colors.amber.shade200,
                size: 20,
              ),
              label: Text(
                isPremium ? 'Premium' : 'Go Premium',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            kGetStartedBackgroundAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGradientTop.withValues(alpha: 0.58),
                  kGradientBottom.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                topContentPadding + 8,
                24,
                16 + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'R',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      height: 0.95,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -2,
                      fontFamily: 'serif',
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Universal Remote',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Control your Android TV on the same Wi‑Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 40),
                  Image.asset(
                    "assets/images/welcome.png",
                    height: 280,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const Spacer(),
                  // ...controller.brands.map(
                  //   (brand) => Padding(
                  //     padding: const EdgeInsets.only(top: 12),
                  //     child: FilledButton(
                  //       style: FilledButton.styleFrom(
                  //         backgroundColor: Colors.white,
                  //         foregroundColor: buttonText,
                  //         elevation: 0,
                  //         padding: const EdgeInsets.symmetric(vertical: 18),
                  //         shape: const StadiumBorder(),
                  //       ),
                  //       onPressed: () => controller.onBrandSelected(brand),
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.center,
                  //         children: [
                  //           Icon(
                  //             Icons.tv,
                  //             color: buttonText.withValues(alpha: 0.85),
                  //             size: 26,
                  //           ),
                  //           const SizedBox(width: 12),
                  //           Text(
                  //             brand == TvBrand.androidTv
                  //                 ? 'ANDROID TV'
                  //                 : brand.name.toUpperCase(),
                  //             style: const TextStyle(
                  //               fontSize: 15,
                  //               fontWeight: FontWeight.w800,
                  //               letterSpacing: 1.0,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  ...controller.brands.map(
                    (brand) => ElevatedButton.icon(
                        icon: Icon(Icons.tv, size: 30),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: buttonText,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 25, horizontal: 25),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => controller.onBrandSelected(brand),
                        label: Text(
                          "Remote Controlling",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubscriptionSheet(BuildContext context) async {
    final iapService = Get.find<SubscriptionIAPService>();
    final premiumController = Get.find<PremiumController>();

    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final products = iapService.products;
            final error = iapService.lastError.value;
            final isLoading = iapService.isLoading.value;
            final isPurchasing = iapService.isPurchasing.value;
            final isPremium = premiumController.isPremium.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPremium
                      ? 'Your premium is active.'
                      : 'Unlock all premium remote features.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (products.isEmpty)
                  const Text(
                    'No subscription plans found. Please try again later.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  ...products.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: const Color(0xFF3B3B3B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          product.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          product.description,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          product.priceLabel,
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: isPurchasing
                            ? null
                            : () async {
                                await iapService.buy(product.productDetails);
                              },
                      ),
                    ),
                  ),
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            isPurchasing ? null : iapService.restorePurchases,
                        child: const Text('Restore purchases'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Get.back<void>(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
