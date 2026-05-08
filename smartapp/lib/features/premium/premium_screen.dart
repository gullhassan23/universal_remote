import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/models/subscription_product.dart';
import 'package:smartapp/services/analytics_service.dart';
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
  Worker? _premiumStateWorker;
  Worker? _messageWorker;
  Worker? _errorWorker;
  String? _lastShownMessage;
  String? _lastShownError;
  late bool _wasPremiumOnOpen;

  @override
  void initState() {
    super.initState();
    final premiumController = Get.find<PremiumController>();
    final iapService = Get.find<SubscriptionIAPService>();
    final analytics = Get.find<AnalyticsService>();
    _wasPremiumOnOpen = premiumController.isPremium.value;

    unawaited(
      analytics.logScreen(
        screenName: 'PremiumScreen',
        screenClass: 'PremiumScreen',
      ),
    );
    unawaited(
      analytics.logEvent(
        'premium_paywall_open',
        params: <String, Object?>{
          'screen_name': 'PremiumScreen',
          'was_premium': _wasPremiumOnOpen,
        },
      ),
    );

    _premiumStateWorker = ever<bool>(premiumController.isPremium, (isPremium) {
      if (!isPremium || _wasPremiumOnOpen) return;
      unawaited(
        analytics.logEvent(
          'premium_activated',
          params: const <String, Object?>{'screen_name': 'PremiumScreen'},
        ),
      );
      _showSnackbar('Premium', 'Subscription activated successfully.');
      _goToRemoteScreen();
    });

    _messageWorker = ever<String?>(iapService.lastMessage, (message) {
      if (message == null || message.isEmpty) return;
      if (message == _lastShownMessage) return;
      _lastShownMessage = message;
      _showSnackbar('Premium', message);
    });

    _errorWorker = ever<String?>(iapService.lastError, (error) {
      if (error == null || error.isEmpty) return;
      if (error == _lastShownError) return;
      _lastShownError = error;
      _showSnackbar('Purchase failed', error);
    });
  }

  void _showSnackbar(String title, String message) {
    if (!mounted) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  // Bypass any onboarding/instructions screens that might be in the stack so the
  // user always lands on the Remote tab inside BottomNav after a successful
  // subscription.
  void _goToRemoteScreen() {
    if (!mounted) return;
    Get.offAllNamed('/home');
  }

  @override
  void dispose() {
    _premiumStateWorker?.dispose();
    _messageWorker?.dispose();
    _errorWorker?.dispose();
    super.dispose();
  }

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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 200,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    Premium.premium,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 10,
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    splashRadius: 18,
                                    iconSize: 22,
                                    onPressed: () {
                                      unawaited(
                                        Get.find<AnalyticsService>().trackClick(
                                          'ClosePaywall',
                                          screenName: 'PremiumScreen',
                                        ),
                                      );
                                      Get.back<void>();
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 24),
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
                          const SizedBox(height: 24),
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
                                          onTap: () {
                                            _selectedPlan.value =
                                                _PremiumPlanType.monthly;
                                            unawaited(
                                              Get.find<AnalyticsService>().logEvent(
                                                'premium_plan_selected',
                                                params: const <String, Object?>{
                                                  'screen_name': 'PremiumScreen',
                                                  'plan': 'monthly',
                                                },
                                              ),
                                            );
                                          },
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
                                          onTap: () {
                                            _selectedPlan.value =
                                                _PremiumPlanType.weekly;
                                            unawaited(
                                              Get.find<AnalyticsService>().logEvent(
                                                'premium_plan_selected',
                                                params: const <String, Object?>{
                                                  'screen_name': 'PremiumScreen',
                                                  'plan': 'weekly',
                                                },
                                              ),
                                            );
                                          },
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
                                          onTap: () {
                                            _selectedPlan.value =
                                                _PremiumPlanType.yearly;
                                            unawaited(
                                              Get.find<AnalyticsService>().logEvent(
                                                'premium_plan_selected',
                                                params: const <String, Object?>{
                                                  'screen_name': 'PremiumScreen',
                                                  'plan': 'yearly',
                                                },
                                              ),
                                            );
                                          },
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Auto-renewable. Cancel anytime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                                    unawaited(
                                      Get.find<AnalyticsService>().logEvent(
                                        'premium_continue_clicked',
                                        params: <String, Object?>{
                                          'screen_name': 'PremiumScreen',
                                          'plan': _selectedPlan.value.name,
                                          'is_premium': premiumController
                                              .isPremium.value,
                                        },
                                      ),
                                    );
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
                                    if (!launched) {
                                      unawaited(
                                        Get.find<AnalyticsService>().logEvent(
                                          'premium_purchase_launch_failed',
                                          params: <String, Object?>{
                                            'screen_name': 'PremiumScreen',
                                            'product_id': product.id,
                                          },
                                        ),
                                      );
                                      Get.snackbar(
                                        'Premium',
                                        'Could not start purchase flow.',
                                      );
                                      return;
                                    }
                                    unawaited(
                                      Get.find<AnalyticsService>().logEvent(
                                        'premium_purchase_flow_started',
                                        params: <String, Object?>{
                                          'screen_name': 'PremiumScreen',
                                          'product_id': product.id,
                                        },
                                      ),
                                    );
                                    // If premium was already active by the time
                                    // buy() returned (rare race), short-circuit
                                    // to the Remote screen instead of relying on
                                    // the reactive worker.
                                    if (premiumController.isPremium.value) {
                                      _goToRemoteScreen();
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () => SettingsActions.openPrivacyPolicy(
                            screenName: 'PremiumScreen',
                          ),
                          child: Text(
                            'Privacy',
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
                          onTap: () => SettingsActions.openTermsAndConditions(
                            screenName: 'PremiumScreen',
                          ),
                          child: Text(
                            'Terms',
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        durationLine,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
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
