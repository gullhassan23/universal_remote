import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(ImageRes.kGetStartedBackgroundAsset2),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.adaptive.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: HapticAction.wrap(Get.back),
                    padding: const EdgeInsets.only(left: 12),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Frequently Asked Questions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        'Get quick answers for setup, connection issues, controls, sleep timer, and premium features.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._faqItems.map((item) => _FaqTile(item: item)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          collapsedIconColor: Colors.white70,
          iconColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            item.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

const List<_FaqItem> _faqItems = [
  _FaqItem(
    question: 'How do I connect my TV to the app?',
    answer:
        'Open Settings and tap "Switch device", then select your TV from the list. Make sure your phone and TV are on the same Wi-Fi network. If no device appears, wait a few seconds and scan again.',
  ),
  _FaqItem(
    question: 'Why is my TV not showing in the discovery list?',
    answer:
        'Check that the TV is powered on, connected to the same router, and remote-control permissions are enabled on the TV. Restarting Wi-Fi on your phone and TV often helps if discovery is delayed.',
  ),
  _FaqItem(
    question: 'What should I do if the remote buttons are not responding?',
    answer:
        'First confirm the app is still connected to your TV. If connected but commands do not work, reconnect the device from Settings, then retry. On some TVs, opening the native TV home screen can refresh command handling.',
  ),
  _FaqItem(
    question: 'Can I control volume and channel with this app?',
    answer:
        'Yes, supported TVs allow basic controls such as volume, mute, navigation, and media actions. Available buttons can vary by TV brand and model depending on system permissions and API support.',
  ),
  _FaqItem(
    question: 'How does Sleep Timer work?',
    answer:
        'Sleep Timer sends a power-off command when the countdown ends. Keep the app connected and running in the background for best reliability. If the connection drops before timer completion, the command may not be delivered.',
  ),
  _FaqItem(
    question: 'Why does haptic feedback not work on my phone?',
    answer:
        'Haptic feedback depends on your device hardware and system vibration settings. Ensure vibration is enabled at system level, then turn on "Haptic feedback" in app settings.',
  ),
  _FaqItem(
    question: 'What is included in Premium?',
    answer:
        'Premium removes ads and unlocks the complete uninterrupted experience. Feature availability may expand over time as new premium capabilities are added in updates.',
  ),
  _FaqItem(
    question: 'How do I restore my purchases?',
    answer:
        'Go to Settings and tap "Restore purchases". Sign in with the same app store account used for the original purchase. Restores only work for active purchases linked to that account.',
  ),
  _FaqItem(
    question: 'Does this app work without internet?',
    answer:
        'Your phone and TV must be connected to the same local Wi-Fi network. Internet access is not always required for remote commands, but some TVs and discovery services may still need an online connection.',
  ),
  _FaqItem(
    question: 'How can I get help if the issue continues?',
    answer:
        'Try reconnecting the device, restarting the app, and checking TV permissions first. If the problem persists, use the app support contact or store listing support details and include your TV model for faster troubleshooting.',
  ),
];
