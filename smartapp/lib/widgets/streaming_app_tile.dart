import 'package:flutter/material.dart';
import 'package:smartapp/utils/haptic_action.dart';

import '../models/streaming_app_item.dart';

class StreamingAppTile extends StatelessWidget {
  const StreamingAppTile({
    super.key,
    required this.app,
    required this.onTap,
    this.isBusy = false,
  });

  final StreamingAppItem app;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isBusy ? null : HapticAction.wrap(onTap),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(app.icon, width: 24, height: 24),
            ),
            const SizedBox(width: 72),
            Expanded(
              child: Text(
                app.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isBusy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
