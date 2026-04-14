import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/apps_controller.dart';
import '../../models/streaming_app_item.dart';
import '../../widgets/streaming_app_tile.dart';

class StreamingAppsScreen extends GetView<AppsController> {
  const StreamingAppsScreen({super.key});

  Future<void> _onAppTap(BuildContext context, StreamingAppItem app) async {
    final success = await controller.launchStreamingApp(app);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Launching ${app.name} on TV'
              : 'Unable to launch ${app.name}. Check TV connection.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00B0B6),
              Color(0xFF005AFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Streaming Apps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Launch installed apps directly on your connected Android TV.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Obx(
                    () {
                      final launchingAppId = controller.launchingAppId.value;
                      return ListView.separated(
                        itemCount: AppsController.apps.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final app = AppsController.apps[index];
                          return StreamingAppTile(
                            app: app,
                            isBusy: launchingAppId == app.id,
                            onTap: () => _onAppTap(context, app),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
