import 'package:flutter/material.dart';

class PremiumViersionScreen extends StatelessWidget {
  const PremiumViersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: const [
                      _PremiumHeaderCard(),
                      SizedBox(height: 16),
                      _PremiumFeatureTile(
                        icon: Icons.wifi_tethering_rounded,
                        title: 'Unlimited Wi-Fi Transfer',
                        subtitle: 'Send any number of files without limits.',
                      ),
                      SizedBox(height: 12),
                      _PremiumFeatureTile(
                        icon: Icons.speed_rounded,
                        title: 'Faster Sharing',
                        subtitle: 'Quick pairing and smooth transfer speed.',
                      ),
                      SizedBox(height: 12),
                      _PremiumFeatureTile(
                        icon: Icons.block_rounded,
                        title: 'No Ads Experience',
                        subtitle: 'Enjoy a clean interface without interruptions.',
                      ),
                      SizedBox(height: 12),
                      _PremiumFeatureTile(
                        icon: Icons.verified_rounded,
                        title: 'Secure Direct Connection',
                        subtitle: 'Your data moves directly between devices.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF4E5DF7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Transferring',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
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
              color: Color(0xFF2A2C35),
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All Pro features are unlocked on your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A7F8B),
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFeatureTile extends StatelessWidget {
  const _PremiumFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: const Color(0xFF52C0E9), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2A2C35),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF767B89),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
