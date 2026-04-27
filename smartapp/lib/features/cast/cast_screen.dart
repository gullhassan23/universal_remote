// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/media_cast_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';
import 'package:smartapp/features/cast/cast_session_banner.dart';
import 'package:smartapp/models/tv_device.dart';
import 'package:smartapp/services/tv_service_interface.dart' hide CastMediaItem;
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/premium_navigation.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/widgets/remote_device_picker_sheet.dart';
import 'package:smartapp/widgets/streaming_mrec_ad.dart';
import 'package:smartapp/widgets/top_banner_ad.dart';
import 'package:smartapp/widgets/premium_status_banner.dart';
import 'package:url_launcher/url_launcher.dart';

class CastScreen extends StatefulWidget {
  const CastScreen({super.key});

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  static const String _fallbackStreamingAppUrl =
      'https://play.google.com/store/apps/details?id=com.FutureDialLabs.screen.mirroring.tv.casting.wireless.app';
  late final MediaCastController controller;
  late final TvConnectionController _tvConnectionController;
  late final DeviceDiscoveryController _discoveryController;
  late final AnalyticsService _analyticsService;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    controller = Get.find<MediaCastController>();
    _tvConnectionController = Get.find<TvConnectionController>();
    _discoveryController = Get.find<DeviceDiscoveryController>();
    _analyticsService = Get.find<AnalyticsService>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
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
                            screenName: 'CastScreen',
                          ),
                        );
                        openPremiumStatusScreen();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          Premium.premium,
                          width: double.infinity,
                          height: 94,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Obx(
                  () {
                    // final bool isPremium =
                    //     Get.find<PremiumController>().isPremium.value;
                    return Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Cast',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 0.95,
                            ),
                          ),
                        ),
                        // if (!isPremium)
                        //   IconButton(
                        //     onPressed: openRemoteStyleOrPaywall,
                        //     tooltip: 'Premium remote styles',
                        //     icon: const Icon(
                        //       Icons.diamond_outlined,
                        //       color: Color(0xFFFFD27A),
                        //     ),
                        //   ),
                        GestureDetector(
                          onTap: () {
                            unawaited(
                              _analyticsService.trackClick(
                                'PremiumStatusBanner',
                                screenName: 'CastScreen',
                              ),
                            );
                            openPremiumStatusScreen();
                          },
                          child: PremiumStatusBanner(),
                        ),
                        if (controller.isCastingActive)
                          IconButton(
                            onPressed: () {
                              unawaited(
                                _analyticsService.trackClick(
                                  'StopCasting',
                                  screenName: 'CastScreen',
                                ),
                              );
                              controller.stopCastingAndReset();
                            },
                            tooltip: 'Stop casting',
                            icon: const Icon(
                              Icons.cast_connected,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Obx(
                  () => CastSessionBanner(
                    label: controller.connectedDeviceName.value.isEmpty
                        ? ''
                        : 'Connected to ${controller.connectedDeviceName.value}',
                  ),
                ),
                const SizedBox(height: 6),
                Obx(() {
                  final message = controller.progressMessage.value;
                  if (message.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
                Expanded(
                  child: Obx(() {
                    if (!controller.hasMedia) {
                      return GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.84,
                        children: [
                          CastTile(
                            ontap: () => _openStreamingUrl('Browser'),
                            title: 'Browser',
                            subtitle: 'Cast your screen',
                            image: CastTileImage.browse,
                          ),
                          CastTile(
                            ontap: () => _handleMediaCastTap('Media'),
                            title: 'Media',
                            subtitle: 'Cast photos & video',
                            image: CastTileImage.media,
                            isPremiumFeature: true,
                          ),
                          CastTile(
                            ontap: () => _openStreamingUrl('Mirror'),
                            title: 'Mirror',
                            subtitle: 'Mirror your screen',
                            image: CastTileImage.mirror,
                          ),
                          CastTile(
                            ontap: () => _openStreamingUrl('YouTube'),
                            title: 'YouTube',
                            subtitle: 'Watch YouTube',
                            image: CastTileImage.youtube,
                          ),
                        ],
                      );
                    }

                    final queue = controller.mediaQueue;
                    final currentIndex = controller.currentMediaIndex.value;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_pageController.hasClients) return;
                      if (_pageController.page?.round() == currentIndex) return;
                      _pageController.jumpToPage(currentIndex);
                    });

                    return Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.28),
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: queue.length,
                                onPageChanged: (index) {
                                  unawaited(
                                    _analyticsService.trackClick(
                                      'MediaQueueSwipe',
                                      screenName: 'CastScreen',
                                    ),
                                  );
                                  controller.castMediaAt(index);
                                },
                                itemBuilder: (_, index) {
                                  final media = queue[index];
                                  return _MediaPreviewCard(item: media);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${currentIndex + 1} / ${queue.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: currentIndex > 0
                                    ? () => _moveToPage(currentIndex - 1, 'Previous')
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Previous'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: currentIndex < queue.length - 1
                                    ? () => _moveToPage(currentIndex + 1, 'Next')
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Next'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleMediaCastTap('ReplaceMedia'),
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Replace Media'),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                // const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final adWidth = constraints.maxWidth.clamp(0.0, 300.0);
                    final adHeight = adWidth * (140 / 300);

                    return Center(
                      child: SizedBox(
                        width: adWidth,
                        height: adHeight,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: const SizedBox(
                            width: 300,
                            height: 200,
                            child: StreamingMrecAd(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveToPage(int index, String buttonName) async {
    unawaited(
      _analyticsService.trackClick(
        buttonName,
        screenName: 'CastScreen',
      ),
    );
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleMediaCastTap(String source) async {
    unawaited(
      _analyticsService.trackClick(
        source,
        screenName: 'CastScreen',
      ),
    );
    if (!isPremiumUnlocked()) {
      openPremiumPaywall();
      return;
    }
    if (!await _ensureTvConnectedForMediaCast()) return;
    await controller.pickAndCastMedia();
  }

  Future<void> _openStreamingUrl(String source) async {
    unawaited(
      _analyticsService.trackClick(
        source,
        screenName: 'CastScreen',
      ),
    );
    final String streamingUrl =
        (dotenv.env['StreamingAppLink'] ?? _fallbackStreamingAppUrl).trim();

    final uri = Uri.tryParse(streamingUrl);
    if (uri == null) {
      Get.snackbar(
        'Error',
        'Streaming app link is invalid.',
        colorText: Colors.white,
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Get.snackbar(
        'Error',
        'Unable to open streaming app.',
        colorText: Colors.white,
      );
    }
  }

  Future<bool> _ensureTvConnectedForMediaCast() async {
    if (_tvConnectionController.connectionState.value ==
        TvConnectionState.connected) {
      return true;
    }

    final connected = await _openDeviceDiscoverySheet();
    if (!connected) {
      Get.snackbar(
        'Connect device first',
        'Please connect to a TV before casting media.',
        colorText: Colors.white,
      );
    }
    return connected;
  }

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
}

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard({required this.item});

  final CastMediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_rounded,
              size: 68,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Swipe to cast next media',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Image.file(
      File(item.path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          item.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class CastTile extends StatelessWidget {
  CastTile({
    Key? key,
    required this.ontap,
    required this.title,
    required this.subtitle,
    required this.image,
    this.isPremiumFeature = false,
  }) : super(key: key);
  final VoidCallback ontap;
  final String title;
  final String subtitle;
  final String image;
  final bool isPremiumFeature;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPremiumUnlocked = Get.find<PremiumController>().isPremium.value;
      return GestureDetector(
        onTap: ontap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Image.asset(
                      image,
                      width: 85,
                      height: 85,
                    ),
                  ),
                  if (isPremiumFeature && !isPremiumUnlocked)
                    const Positioned(
                      top: -8,
                      right: 10,
                      child: Icon(
                        Icons.diamond_outlined,
                        size: 18,
                        color: Color(0xFFFFD27A),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
