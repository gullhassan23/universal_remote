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
      body: Obx(
        () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: controller.brands.length,
          itemBuilder: (context, index) {
            final brand = controller.brands[index];
            final activeBrands = [TvBrand.samsung, TvBrand.sony];
            final isActive = activeBrands.contains(brand);

            return GestureDetector(
              onTap: () => controller.onBrandSelected(brand),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 1.0 : 0.4,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tv,
                        size: 48,
                        color: isActive ? Colors.blueGrey : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        brand.name.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!isActive)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Coming soon',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
