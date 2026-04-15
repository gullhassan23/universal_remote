import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isHapticEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PremiumCard(),
                const SizedBox(height: 26),
                const _SectionTitle(title: 'REMOTE'),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.devices_outlined,
                  title: 'Switch device',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.settings_remote_outlined,
                  title: 'Remote style',
                  onTap: () {},
                ),
                _SwitchSettingsTile(
                  icon: Icons.vibration_outlined,
                  title: 'Haptic feedback',
                  subtitle: 'Enables haptics on remote',
                  value: _isHapticEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isHapticEnabled = value;
                    });
                  },
                ),
                _SettingsTile(
                  icon: Icons.timer_outlined,
                  title: 'Sleep timer',
                  subtitle: 'Turns off your TV automatically',
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'GENERAL'),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'FAQ',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.restore_rounded,
                  title: 'Restore purchases',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy policy',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.menu_book_outlined,
                  title: 'How to use app',
                  onTap: () {
                    Get.to(() => const InstructionOnboardingScreen());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBE35FF), Color(0xFF5B1BD1)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNLOCK PREMIUM\nFEATURES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: const Color(0xFFFFCC00),
                  ),
                  child: const Text(
                    'Get Now',
                    style: TextStyle(
                      color: Color(0xFF1B1B1B),
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 118,
            width: 74,
            decoration: BoxDecoration(
              color: const Color(0xAA101433),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.settings_remote_rounded, color: Colors.white70, size: 36),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.64),
        fontSize: 30,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 27),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingsTile extends StatelessWidget {
  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF2FCC6A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
