import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/tv_brand.dart';
import '../models/tv_device.dart';
import '../features/device_discovery/device_discovery_controller.dart';

class RemoteDevicePickerSheet extends StatefulWidget {
  const RemoteDevicePickerSheet({
    super.key,
    required this.discoveryController,
    required this.onDeviceSelected,
    required this.onDismiss,
    required this.onHandleTap,
  });

  final DeviceDiscoveryController discoveryController;
  final Future<void> Function(TvDevice) onDeviceSelected;
  final VoidCallback onDismiss;
  final Future<void> Function({
    required String buttonKey,
    required FutureOr<void> Function() onTap,
    String action,
  }) onHandleTap;

  @override
  State<RemoteDevicePickerSheet> createState() =>
      _RemoteDevicePickerSheetState();
}

class _RemoteDevicePickerSheetState extends State<RemoteDevicePickerSheet> {
  final RxnString _connectingDeviceId = RxnString();

  @override
  void initState() {
    super.initState();
    widget.discoveryController.discoverDevices();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 260,
            maxHeight: screenHeight * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select your device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        unawaited(
                          widget.onHandleTap(
                            buttonKey: 'DEVICE_PICKER_CLOSE',
                            action: 'dismiss_picker',
                            onTap: () {
                              Get.back();
                              widget.onDismiss();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final isLoading = widget.discoveryController.isLoading.value;
                  final devices = widget.discoveryController.devices;
                  final errorMessage =
                      widget.discoveryController.errorMessage.value;

                  if (isLoading) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _AnimatedDotsLoader(),
                          const SizedBox(height: 20),
                          const Text(
                            textAlign: TextAlign.center,
                            'Make sure your TV / Streaming player is turned on and connected to the same Wi-Fi network as your phone. If your device is not on the list, please power reset it and try again.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA9ACAB),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(Icons.search),
                          ),
                        ],
                      ),
                    );
                  }

                  if (devices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 20),
                          _RescanButton(
                            buttonKey: 'DISCOVERY_RESCAN_EMPTY',
                            onTap: () =>
                                widget.discoveryController.discoverDevices(),
                            onHandleTap: widget.onHandleTap,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white24),
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            final isConnectingThisDevice =
                                _connectingDeviceId.value == device.id;
                            final brandLabel = device.brand == TvBrand.androidTv
                                ? 'Android TV'
                                : device.brand.name;
                            return ListTile(
                              leading: const Icon(Icons.tv,
                                  color: Colors.white70, size: 28),
                              title: Text(
                                device.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '$brandLabel',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: isConnectingThisDevice
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                if (_connectingDeviceId.value != null) return;
                                _connectingDeviceId.value = device.id;
                                unawaited(
                                  widget.onHandleTap(
                                    buttonKey: 'DEVICE_${device.name}',
                                    action: 'select_device',
                                    onTap: () async {
                                      try {
                                        await widget.onDeviceSelected(device);
                                      } finally {
                                        if (!mounted) return;
                                        _connectingDeviceId.value = null;
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RescanButton(
                          buttonKey: 'DISCOVERY_RESCAN_LIST',
                          onTap: () =>
                              widget.discoveryController.discoverDevices(),
                          onHandleTap: widget.onHandleTap,
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
    );
  }
}

class _RescanButton extends StatelessWidget {
  const _RescanButton({
    required this.buttonKey,
    required this.onTap,
    required this.onHandleTap,
  });

  final String buttonKey;
  final VoidCallback onTap;
  final Future<void> Function({
    required String buttonKey,
    required FutureOr<void> Function() onTap,
    String action,
  }) onHandleTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          unawaited(
            onHandleTap(
              buttonKey: buttonKey,
              action: 'discover_devices',
              onTap: onTap,
            ),
          );
        },
        child: const Text(
          "Don't see your device?",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _AnimatedDotsLoader extends StatefulWidget {
  const _AnimatedDotsLoader();

  static const double _dotRadius = 5;
  static const double _spacing = 8;

  @override
  State<_AnimatedDotsLoader> createState() => _AnimatedDotsLoaderState();
}

class _AnimatedDotsLoaderState extends State<_AnimatedDotsLoader>
    with SingleTickerProviderStateMixin {
  static const List<Color> _dotColors = [
    Color(0xFFFF9800),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index / 3) % 1.0;
            final scale = 0.7 + 0.5 * math.sin(phase * 2 * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: _AnimatedDotsLoader._spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: _AnimatedDotsLoader._dotRadius * 2,
                  height: _AnimatedDotsLoader._dotRadius * 2,
                  decoration: BoxDecoration(
                    color: _dotColors[index],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _dotColors[index].withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
