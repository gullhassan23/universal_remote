import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF444643),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Universal TV Remote',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
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
                  onPressed: isActive ? () => controller.onBrandSelected(brand) : null,
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
                          ).textTheme.titleMedium?.copyWith(color: Colors.white),
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
}
