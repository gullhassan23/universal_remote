import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/subscription_iap_service.dart';

import '../../models/tv_brand.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final premiumController = Get.find<PremiumController>();
    final iapService = Get.find<SubscriptionIAPService>();

    return Scaffold(
      backgroundColor: const Color(0xFF444643),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Universal TV Remote',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
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
              ),
              label: Text(
                isPremium ? 'Premium' : 'Go Premium',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      // body: Obx(
      //   () => GridView.builder(
      //     padding: const EdgeInsets.all(16),
      //     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      //       crossAxisCount: 2,
      //       crossAxisSpacing: 16,
      //       mainAxisSpacing: 16,
      //       childAspectRatio: 1.1,
      //     ),
      //     itemCount: controller.brands.length,
      //     itemBuilder: (context, index) {
      //       final brand = controller.brands[index];
      //       final activeBrands = [
      //         TvBrand.samsung,
      //         TvBrand.sony,
      //         TvBrand.androidTv
      //       ];
      //       final isActive = activeBrands.contains(brand);

      //       return GestureDetector(
      //         onTap: () => controller.onBrandSelected(brand),
      //         child: AnimatedOpacity(
      //           duration: const Duration(milliseconds: 200),
      //           opacity: isActive ? 1.0 : 0.4,
      //           child: Card(
      //             shape: RoundedRectangleBorder(
      //               borderRadius: BorderRadius.circular(16),
      //             ),
      //             elevation: 4,
      //             child: Column(
      //               mainAxisAlignment: MainAxisAlignment.center,
      //               children: [
      //                 Icon(
      //                   Icons.tv,
      //                   size: 48,
      //                   color: isActive ? Colors.blueGrey : Colors.grey,
      //                 ),
      //                 const SizedBox(height: 12),
      //                 Text(
      //                   brand.name.toUpperCase(),
      //                   style: Theme.of(context).textTheme.titleMedium,
      //                 ),
      //                 if (!isActive)
      //                   const Padding(
      //                     padding: EdgeInsets.only(top: 4.0),
      //                     child: Text(
      //                       'Coming soon',
      //                       style: TextStyle(fontSize: 12, color: Colors.grey),
      //                     ),
      //                   ),
      //               ],
      //             ),
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: controller.brands.map((brand) {
          final activeBrands = [
            TvBrand.samsung,
            TvBrand.sony,
            TvBrand.androidTv
          ];
          final isActive = activeBrands.contains(brand);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Stack(
              children: [
                // Main Button
                ElevatedButton(
                  onPressed:
                      isActive ? () => controller.onBrandSelected(brand) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    disabledBackgroundColor: Colors.blueGrey.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.tv,
                          size: 48,
                          // color: isActive ? Colors.blueGrey : Colors.grey,
                        ),
                        Text(
                          brand.name.toUpperCase(),
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🔴 Coming Soon Banner
                if (!isActive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
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
