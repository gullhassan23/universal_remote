import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum RewardedMediaCastSheetAction { watchAd, goPremium, cancel }

class RewardedMediaCastSheet extends StatelessWidget {
  const RewardedMediaCastSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Unlock 1 free media cast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Watch a short ad to cast media one time, or upgrade to Premium for unlimited access.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_fill, color: Colors.white),
            title: const Text(
              'Watch Ad',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Unlock 1 free cast',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            onTap: () => Get.back(result: RewardedMediaCastSheetAction.watchAd),
          ),
          ListTile(
            leading: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFD27A),
            ),
            title: const Text(
              'Go Premium',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Unlimited media casting',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            onTap: () =>
                Get.back(result: RewardedMediaCastSheetAction.goPremium),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Get.back(result: RewardedMediaCastSheetAction.cancel),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Not now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

