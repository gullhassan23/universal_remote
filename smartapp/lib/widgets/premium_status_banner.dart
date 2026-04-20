import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';

class PremiumStatusBanner extends StatelessWidget {
  const PremiumStatusBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final premiumController = Get.find<PremiumController>();
    return Padding(
      padding: padding,
      child: Obx(() {
        final isPremium = premiumController.isPremium.value;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isPremium
                    ? const Color(0xFFFFD27A)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium ? Icons.workspace_premium : Icons.lock_open_rounded,
                  size: 16,
                  color: isPremium
                      ? const Color(0xFFFFD27A)
                      : Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  isPremium ? 'Premium' : 'Free Mode',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
