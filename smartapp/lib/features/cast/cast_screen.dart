// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/media_cast_controller.dart';
import 'package:smartapp/features/cast/cast_session_banner.dart';

class CastScreen extends StatefulWidget {
  const CastScreen({super.key});

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  late final MediaCastController controller;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    controller = Get.find<MediaCastController>();
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cast',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    Obx(() {
                      final isConnected =
                          controller.connectedDeviceName.value.isNotEmpty;
                      return IconButton(
                        onPressed: isConnected ? controller.disconnectSession : null,
                        icon: Icon(
                          Icons.cast_connected,
                          color: isConnected ? Colors.white : Colors.white54,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                Obx(
                  () => CastSessionBanner(
                    label: controller.connectedDeviceName.value.isEmpty
                        ? ''
                        : 'Connected to ${controller.connectedDeviceName.value}',
                  ),
                ),
                const SizedBox(height: 10),
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
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.88,
                        children: [
                          CastTile(
                            ontap: () {},
                            title: 'Browser',
                            subtitle: 'Cast from websites',
                            icon: Icons.web_asset_outlined,
                          ),
                          CastTile(
                            ontap: controller.pickAndCastMedia,
                            title: 'Media',
                            subtitle: 'Cast photos & video',
                            icon: Icons.photo_library_outlined,
                          ),
                          CastTile(
                            ontap: () {},
                            title: 'Mirror',
                            subtitle: 'Mirror your screen',
                            icon: Icons.tv_outlined,
                          ),
                          CastTile(
                            ontap: () {},
                            title: 'YouTube',
                            subtitle: 'Watch YouTube',
                            icon: Icons.play_circle_outline_rounded,
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
                                    ? () => _moveToPage(currentIndex - 1)
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
                                    ? () => _moveToPage(currentIndex + 1)
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
                            onPressed: controller.pickAndCastMedia,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Replace Media'),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveToPage(int index) async {
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
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
    required this.icon,
  }) : super(key: key);
  final VoidCallback ontap;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFDF45D7),
                      Color(0xFFFFA938),
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Icon(
                    icon,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
