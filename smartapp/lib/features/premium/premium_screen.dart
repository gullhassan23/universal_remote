import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/models/subscription_product.dart';
import 'package:smartapp/services/subscription_iap_service.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/settings_actions.dart';

enum _PremiumPlanType { monthly, weekly, yearly }

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final Rx<_PremiumPlanType> _selectedPlan = _PremiumPlanType.weekly.obs;

  String? _envProductIdForPlan(_PremiumPlanType plan) {
    final bool isIos = !kIsWeb && Platform.isIOS;
    return switch (plan) {
      _PremiumPlanType.weekly => (dotenv
          .env[isIos ? 'IAP_PRODUCT_IOS_WEEKLY' : 'IAP_PRODUCT_WEEKLY']
          ?.trim()),
      _PremiumPlanType.monthly => (dotenv
          .env[isIos ? 'IAP_PRODUCT_IOS_MONTHLY' : 'IAP_PRODUCT_MONTHLY']
          ?.trim()),
      _PremiumPlanType.yearly => (dotenv
          .env[isIos ? 'IAP_PRODUCT_IOS_YEARLY' : 'IAP_PRODUCT_YEARLY']
          ?.trim()),
    };
  }

  SubscriptionProduct? _matchByPlan(
    List<SubscriptionProduct> products,
    _PremiumPlanType plan,
  ) {
    final String? expectedId = _envProductIdForPlan(plan);
    if (expectedId != null && expectedId.isNotEmpty) {
      final SubscriptionProduct? byId = products.firstWhereOrNull(
        (p) => p.id == expectedId,
      );
      if (byId != null) return byId;
    }

    return products.firstWhereOrNull(
      (p) => switch (plan) {
        _PremiumPlanType.weekly => p.title.toLowerCase().contains('week') ||
            p.id.toLowerCase().contains('week'),
        _PremiumPlanType.monthly => p.title.toLowerCase().contains('month') ||
            p.id.toLowerCase().contains('month'),
        _PremiumPlanType.yearly => p.title.toLowerCase().contains('year') ||
            p.id.toLowerCase().contains('year'),
      },
    );
  }

  SubscriptionProduct _resolveSelectedProduct(
    List<SubscriptionProduct> products,
  ) {
    return _matchByPlan(products, _selectedPlan.value) ??
        _matchByPlan(products, _PremiumPlanType.weekly) ??
        _matchByPlan(products, _PremiumPlanType.monthly) ??
        _matchByPlan(products, _PremiumPlanType.yearly) ??
        products.first;
  }

// 🔥 ADD THESE HELPERS ON TOP

  @override
  Widget build(BuildContext context) {

    final iapService = Get.find<SubscriptionIAPService>();
    final premiumController = Get.find<PremiumController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF006B7D), Color(0xFF003C90)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  ImageRes.kGetStartedBackgroundAsset2,
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(0.28),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3, right: 10),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        splashRadius: 18,
                        iconSize: 18,
                        onPressed: () => Get.back<void>(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 190,
                            alignment: Alignment.topCenter,
                            child: Image.asset(
                              Premium.premium,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Unlock Premium TV Control',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 30,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Faster connection, smoother controls, and an ad-free remote experience',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _FeatureItem(
                            icon: Icons.control_camera,
                            text: 'Instant Smart TV Pairing',
                          ),
                          const SizedBox(height: 14),
                          const _FeatureItem(
                            icon: Icons.gamepad_outlined,
                            text: 'One-Tap Channel & Volume',
                          ),
                          const SizedBox(height: 14),
                          const _FeatureItem(
                            icon: Icons.block,
                            text: 'No Ads, No Interruptions',
                          ),
                          const SizedBox(height: 20),
                          Obx(
                            () {
                              final allProducts = iapService.products;
                              final monthlyProduct = _matchByPlan(
                                allProducts,
                                _PremiumPlanType.monthly,
                              );
                              final weeklyProduct = _matchByPlan(
                                allProducts,
                                _PremiumPlanType.weekly,
                              );
                              final yearlyProduct = _matchByPlan(
                                allProducts,
                                _PremiumPlanType.yearly,
                              );

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _PlanCard(
                                          badge: 'POPULAR',
                                          title: 'Monthly',
                                          subtitle:
                                              monthlyProduct?.description ??
                                                  'Billed every month',
                                          priceLine:
                                              monthlyProduct?.priceLabel ??
                                                  '--',
                                          durationLine: 'per month',
                                          highlighted: _selectedPlan.value ==
                                              _PremiumPlanType.monthly,
                                          onTap: () => _selectedPlan.value =
                                              _PremiumPlanType.monthly,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _PlanCard(
                                          badge: 'BEST START',
                                          title: 'Weekly',
                                          subtitle:
                                              weeklyProduct?.description ??
                                                  'Billed every week',
                                          priceLine:
                                              weeklyProduct?.priceLabel ?? '--',
                                          durationLine: 'per week',
                                          highlighted: _selectedPlan.value ==
                                              _PremiumPlanType.weekly,
                                          onTap: () => _selectedPlan.value =
                                              _PremiumPlanType.weekly,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _PlanCard(
                                          badge: 'BEST DEAL',
                                          title: 'Yearly',
                                          subtitle:
                                              yearlyProduct?.description ??
                                                  'Billed every year',
                                          priceLine:
                                              yearlyProduct?.priceLabel ?? '--',
                                          durationLine: 'per year',
                                          highlighted: _selectedPlan.value ==
                                              _PremiumPlanType.yearly,
                                          onTap: () => _selectedPlan.value =
                                              _PremiumPlanType.yearly,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 16),
                    child: Obx(
                      () {
                        final bool isBusy = iapService.isPurchasing.value ||
                            iapService.isRestoring.value;
                        return SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF4CB4FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final products = iapService.products;
                                    if (products.isEmpty) {
                                      Get.snackbar(
                                        'Premium',
                                        'No plans available right now.',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                      return;
                                    }
                                    final product =
                                        _resolveSelectedProduct(products);
                                    final bool launched = await iapService.buy(
                                      product.productDetails,
                                    );
                                    final String? error =
                                        iapService.lastError.value;
                                    final String? message =
                                        iapService.lastMessage.value;
                                    if (error != null && error.isNotEmpty) {
                                      Get.snackbar('Purchase failed', error);
                                    } else if (message != null &&
                                        message.isNotEmpty) {
                                      Get.snackbar('Premium', message);
                                    } else if (!launched) {
                                      Get.snackbar(
                                        'Premium',
                                        'Could not start purchase flow.',
                                      );
                                    }
                                    if (premiumController.isPremium.value) {
                                      Get.back<void>();
                                    }
                                  },
                            child: isBusy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 22, // FIXED
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    // child: Text(
                    //   'Limited Time Offer -- Cancel Anytime',
                    //   textAlign: TextAlign.center,
                    //   style: TextStyle(
                    //     color: Colors.white70,
                    //     fontSize: 13,
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () => SettingsActions.openTermsAndConditions(
                            screenName: 'PremiumScreen',
                          ),
                          child: Text(
                            "Term",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => SettingsActions.restorePurchases(
                            iapService: iapService,
                            screenName: 'PremiumScreen',
                          ),
                          child: Text(
                            "Restore",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => SettingsActions.openPrivacyPolicy(
                            screenName: 'PremiumScreen',
                          ),
                          child: Text(
                            "Privacy",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), // center alignment
      child: Row(
        children: [
          Icon(icon,
              color: Colors.white.withValues(alpha: 0.9), size: 22), // smaller
          const SizedBox(width: 14),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w500,
              fontSize: 15, // FIXED
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.priceLine,
    required this.durationLine,
    required this.highlighted,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String priceLine;
  final String durationLine;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(top: highlighted ? 0 : 10),
          child: Ink(
            height: highlighted ? 183 : 172,
            decoration: BoxDecoration(
              color: highlighted
                  ? const Color(0xFF57BFFF)
                  : const Color(0xFF3A3F4A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? Colors.white : Colors.white24,
                width: highlighted ? 2 : 1,
              ),
              boxShadow: highlighted
                  ? const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: highlighted ? const Color(0xFFD6F1FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: highlighted
                          ? const Color(0xFF1E88E5)
                          : Colors.grey[700],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20, // FIXED
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  priceLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(color: Colors.white24, height: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        priceLine,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        durationLine,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
