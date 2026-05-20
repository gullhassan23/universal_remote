import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/tv_service_interface.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/premium_navigation.dart';

import '../../controllers/tv_connection_controller.dart';
import '../../features/device_discovery/device_discovery_controller.dart';
import '../../controllers/streaming_controller.dart';
import '../../models/tv_device.dart';
import '../../models/streaming_app_item.dart';
import '../../widgets/premium_status_banner.dart';
import '../../widgets/remote_device_picker_sheet.dart';
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
  late final AnalyticsService _analyticsService;
  bool _requestedDiscovery = false;
  final List<Worker> _discoveryWorkers = <Worker>[];

  @override
  void initState() {
    super.initState();
    _streamingController = Get.find<StreamingController>();
    _connectionController = Get.find<TvConnectionController>();
    _discoveryController = Get.find<DeviceDiscoveryController>();
    _analyticsService = Get.find<AnalyticsService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestDiscoveryIfNeeded();
      }
    });
    _discoveryWorkers.addAll(<Worker>[
      ever(_discoveryController.isLoading, (_) => _scheduleDiscoveryCheck()),
      ever(_discoveryController.devices, (_) => _scheduleDiscoveryCheck()),
    ]);
  }

  @override
  void dispose() {
    for (final w in _discoveryWorkers) {
      w.dispose();
    }
    super.dispose();
  }

  void _scheduleDiscoveryCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestDiscoveryIfNeeded();
      }
    });
  }

  Future<void> _onAppTap(BuildContext context, StreamingAppItem app) async {
    final alreadyConnected =
        _connectionController.connectionState.value == TvConnectionState.connected;
    if (!alreadyConnected) {
      final connected = await _openDeviceDiscoverySheet();
      if (!context.mounted) return;
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to your TV first to launch apps.'),
          ),
        );
        return;
      }
    }

    unawaited(
      _analyticsService.trackClick(
        app.name,
        screenName: 'StreamingAppsScreen',
      ),
    );
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

  // Future<void> _connectToDevice(BuildContext context, TvDevice device) async {
  //   unawaited(
  //     _analyticsService.trackClick(
  //       'SelectDevice_${device.name}',
  //       screenName: 'StreamingAppsScreen',
  //     ),
  //   );
  //   final messenger = ScaffoldMessenger.of(context);
  //   final success = await _discoveryController.connectTo(
  //     device,
  //     navigateToRemote: false,
  //   );
  //   if (!mounted || success) return;
  //   messenger.showSnackBar(
  //     const SnackBar(
  //       content: Text('Unable to connect. Please try another device.'),
  //     ),
  //   );
  // }

  Future<bool> _openDeviceDiscoverySheet() async {
    final result = Completer<bool>();
    await Get.bottomSheet<void>(
      RemoteDevicePickerSheet(
        discoveryController: _discoveryController,
        onDeviceSelected: (TvDevice device) async {
          final connected = await _discoveryController.connectTo(
            device,
            navigateToRemote: false,
          );
          if (!result.isCompleted) {
            result.complete(connected);
          }
          if (connected && (Get.isBottomSheetOpen ?? false)) {
            Get.back<void>();
          }
          return connected;
        },
        onDismiss: () {
          if (!result.isCompleted) {
            result.complete(false);
          }
        },
        onHandleTap: ({
          required String buttonKey,
          required FutureOr<void> Function() onTap,
          String action = 'tap',
        }) async {
          await onTap();
        },
      ),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );

    if (!result.isCompleted) {
      result.complete(false);
    }
    return result.future;
  }

  void _requestDiscoveryIfNeeded() {
    if (!_requestedDiscovery &&
        !_discoveryController.isLoading.value &&
        _discoveryController.devices.isEmpty) {
      _requestedDiscovery = true;
      Future<void>.microtask(
        _discoveryController.discoverDevices,
      );
    }
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
                const SizedBox(height: 6),
                Obx(() {
                  final bool isPremium =
                      Get.find<PremiumController>().isPremium.value;
                  if (isPremium) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        unawaited(
                          _analyticsService.trackClick(
                            'PremiumBanner',
                            screenName: 'StreamingAppsScreen',
                          ),
                        );
                        openPremiumStatusScreen();
                      },
                      child: Image.asset(
                        Premium.premium,
                        width: double.infinity,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
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
                      onTap: () {
                        unawaited(
                          _analyticsService.trackClick(
                            'PremiumStatusBanner',
                            screenName: 'StreamingAppsScreen',
                          ),
                        );
                        openPremiumStatusScreen();
                      },
                      child: const PremiumStatusBanner(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Obx(
                    () {
                      final launchingAppId =
                          _streamingController.launchingAppId.value;
                      final isConnected = _connectionController
                              .connectionState.value ==
                          TvConnectionState.connected;
                      final selectedDeviceName =
                          _connectionController.currentDevice.value?.name;
                      final hasMrecSlot = StreamingController.apps.length >= 2;
                      final totalItemCount =
                          StreamingController.apps.length + (hasMrecSlot ? 1 : 0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ConnectionStatusCard(
                            isConnected: isConnected,
                            selectedDeviceName: selectedDeviceName,
                            onConnectPressed: _openDeviceDiscoverySheet,
                            onReconnectPressed: () async {
                              _requestedDiscovery = false;
                              _discoveryController.devices.clear();
                              await _openDeviceDiscoverySheet();
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
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
                            ),
                          ),
                        ],
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

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.isConnected,
    required this.selectedDeviceName,
    required this.onConnectPressed,
    required this.onReconnectPressed,
  });

  final bool isConnected;
  final String? selectedDeviceName;
  final Future<bool> Function() onConnectPressed;
  final Future<void> Function() onReconnectPressed;

  @override
  Widget build(BuildContext context) {
    final title = isConnected
        ? 'Connected to ${selectedDeviceName ?? 'TV'}'
        : 'Connect your TV to launch apps';
    final subtitle = isConnected
        ? 'You can now launch apps directly on your TV.'
        : 'Apps are visible now. Connection is needed only when launching.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.tv_rounded : Icons.cast_connected,
            color: Colors.white70,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (isConnected) {
                await onReconnectPressed();
              } else {
                await onConnectPressed();
              }
            },
            child: Text(
              isConnected ? 'Change' : 'Connect',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
