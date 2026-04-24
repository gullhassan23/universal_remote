import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/premium_navigation.dart';

import '../../controllers/tv_connection_controller.dart';
import '../../features/device_discovery/device_discovery_controller.dart';
import '../../controllers/streaming_controller.dart';
import '../../models/tv_device.dart';
import '../../models/streaming_app_item.dart';
import '../../widgets/premium_status_banner.dart';
import '../../widgets/streaming_mrec_ad.dart';
import '../../widgets/top_banner_ad.dart';
import '../../widgets/streaming_app_tile.dart';

class StreamingAppsScreen extends StatefulWidget {
  const StreamingAppsScreen({super.key});

  @override
  State<StreamingAppsScreen> createState() => _StreamingAppsScreenState();
}

class _StreamingAppsScreenState extends State<StreamingAppsScreen> {
  late final StreamingController _streamingController;
  late final TvConnectionController _connectionController;
  late final DeviceDiscoveryController _discoveryController;
  bool _requestedDiscovery = false;

  @override
  void initState() {
    super.initState();
    _streamingController = Get.find<StreamingController>();
    _connectionController = Get.find<TvConnectionController>();
    _discoveryController = Get.find<DeviceDiscoveryController>();
  }

  Future<void> _onAppTap(BuildContext context, StreamingAppItem app) async {
    final success = await _streamingController.launchStreamingApp(app);
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

  Future<void> _connectToDevice(BuildContext context, TvDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
    if (!mounted || success) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to connect. Please try another device.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              ImageRes.kGetStartedBackgroundAsset2,
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: TopBannerAd(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Apps',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                      ),
                    ),
                    GestureDetector(
                      onTap: openPremiumStatusScreen,
                      child: const PremiumStatusBanner(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Obx(
                    () {
                      final isConnected =
                          _connectionController.currentDevice.value != null;
                      if (isConnected) {
                        final launchingAppId =
                            _streamingController.launchingAppId.value;
                        final hasMrecSlot =
                            StreamingController.apps.length >= 2;
                        final totalItemCount = StreamingController.apps.length +
                            (hasMrecSlot ? 1 : 0);
                        return ListView.separated(
                          itemCount: totalItemCount,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (hasMrecSlot &&
                                index == StreamingController.apps.length) {
                              return const Center(
                                child: StreamingMrecAd(),
                              );
                            }
                            final app = StreamingController.apps[index];
                            return StreamingAppTile(
                              app: app,
                              isBusy: launchingAppId == app.id,
                              onTap: () => _onAppTap(context, app),
                            );
                          },
                        );
                      }

                      if (!_requestedDiscovery &&
                          !_discoveryController.isLoading.value &&
                          _discoveryController.devices.isEmpty) {
                        _requestedDiscovery = true;
                        Future<void>.microtask(
                          _discoveryController.discoverDevices,
                        );
                      }

                      return _buildDeviceSelection(context);
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

  Widget _buildDeviceSelection(BuildContext context) {
    return Obx(() {
      final isLoading = _discoveryController.isLoading.value;
      final devices = _discoveryController.devices;
      final errorMessage = _discoveryController.errorMessage.value;

      if (isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      if (devices.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage.isNotEmpty
                    ? errorMessage
                    : 'No devices found.\nMake sure your phone and TV are on the same WiFi network.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _discoveryController.discoverDevices,
                child: const Text(
                  "Don't see your device?",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white24),
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.tv, color: Colors.white70, size: 28),
                  title: Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    device.brand.name,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _connectToDevice(context, device),
                );
              },
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _discoveryController.discoverDevices,
              child: const Text(
                "Don't see your device?",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
