import 'package:flutter/material.dart';
import 'package:get/get.dart';


class Pro_Screen extends StatelessWidget {
  const Pro_Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF006B7D),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 10),
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
            const SizedBox(height: 8),
            const _PremiumHeaderCard(),
            const SizedBox(height: 24),
            const Profeature(
              title: 'Control Any TV Instantly',
              icon: Icons.control_camera,
            ),
            const SizedBox(height: 16),
            const Profeature(
              icon: Icons.gamepad_outlined,
              title: '1-Tap Channel & Volume',
            ),
            const SizedBox(height: 16),
            const Profeature(
              icon: Icons.block,
              title: 'No Ads. No Interruptions',
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumHeaderCard extends StatelessWidget {
  const _PremiumHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
      decoration: BoxDecoration(
        color: Color(0xFF3A3F4A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 34,
              color: Color(0xFF58BEE9),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'You are Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text("All Pro features are unlocked on your account",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class Profeature extends StatelessWidget {
  final String title;

  final IconData icon;

  const Profeature({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF2E323C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 28,
            color: Color(0xFF58BEE9),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
