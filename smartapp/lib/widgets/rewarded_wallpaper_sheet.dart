import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum RewardedWallpaperSheetAction { watchAd, goPremium, cancel }

class RewardedWallpaperSheet extends StatelessWidget {
  const RewardedWallpaperSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF2A2A2A),
              const Color(0xFF1C1C1C).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD27A).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD27A).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.wallpaper_rounded,
                      color: Color(0xFFFFD27A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Unlock Premium Wallpaper',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Watch a short ad to unlock this wallpaper for 30 seconds, or go Premium for unlimited access to all wallpapers.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => Get.back(
                    result: RewardedWallpaperSheetAction.watchAd,
                  ),
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text(
                    'Watch Ad',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => Get.back(
                    result: RewardedWallpaperSheetAction.goPremium,
                  ),
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD27A),
                  ),
                  label: const Text(
                    'Go Premium',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      Get.back(result: RewardedWallpaperSheetAction.cancel),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.75),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Not now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

