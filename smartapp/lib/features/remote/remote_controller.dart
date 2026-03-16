import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tv_connection_controller.dart';
import '../../models/tv_brand.dart';
import '../../models/tv_device.dart';
import '../../services/tv_service_interface.dart';
import '../device_discovery/device_discovery_controller.dart';

class RemoteController extends GetxController {
  final TvConnectionController _connectionController =
      Get.find<TvConnectionController>();
  final DeviceDiscoveryController _discoveryController =
      Get.find<DeviceDiscoveryController>();

  var selectedTab = 0.obs;
  final RxBool showDevicePicker = false.obs;
  String? _pendingKey;
  bool _pickerSheetVisible = false;

  @override
  void onInit() {
    super.onInit();
    ever(showDevicePicker, (show) {
      if (show && !_pickerSheetVisible) {
        _pickerSheetVisible = true;
        _showDevicePickerSheet();
      }
    });
  }

  Future<void> send(String key) async {
    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      final ok = await _connectionController.sendKey(key);
      if (!ok) {
        Get.snackbar('Connection issue',
            'Failed to send command. Connection may have been lost.');
      }
      return;
    }

    _pendingKey = key;
    showDevicePicker.value = true;
  }

  Future<void> onDeviceSelected(TvDevice device) async {
    _pickerSheetVisible = false;
    showDevicePicker.value = false;
    final key = _pendingKey;
    _pendingKey = null;
    if (key == null) return;

    final success = await _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
    if (success) {
      await _connectionController.sendKey(key);
    }
  }

  void dismissDevicePicker() {
    _pickerSheetVisible = false;
    showDevicePicker.value = false;
    _pendingKey = null;
  }

  void _showDevicePickerSheet() {
    Get.bottomSheet(
      _DevicePickerSheet(
        discoveryController: _discoveryController,
        onDeviceSelected: onDeviceSelected,
        onDismiss: dismissDevicePicker,
      ),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ).whenComplete(() {
      _pickerSheetVisible = false;
      if (showDevicePicker.value) showDevicePicker.value = false;
      _pendingKey = null;
    });
  }
}

class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet({
    required this.discoveryController,
    required this.onDeviceSelected,
    required this.onDismiss,
  });

  final DeviceDiscoveryController discoveryController;
  final Future<void> Function(TvDevice) onDeviceSelected;
  final VoidCallback onDismiss;

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  @override
  void initState() {
    super.initState();
    widget.discoveryController.discoverDevices();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      Get.back();
                      widget.onDismiss();
                    },
                  ),
                ],
              ),
            ),
            Obx(
              () {
                final isLoading = widget.discoveryController.isLoading.value;
                final devices = widget.discoveryController.devices;
                final errorMessage =
                    widget.discoveryController.errorMessage.value;

                if (isLoading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _AnimatedDotsLoader(),
                        const SizedBox(height: 20),
                        Text(
                          textAlign: TextAlign.center,
                          'Make sure your TV / Streaming player is turned on and connected to the same Wi-Fi network as your iPhone. If your device is not on the list, please power reset it and try again.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 100),
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Color(0xFFA9ACAB),
                              borderRadius: BorderRadius.circular(50)),
                          child: Icon(Icons.search),
                        ),
                      ],
                    ),
                  );
                }

                if (devices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
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
                        const SizedBox(height: 200),
                        _RescanButton(
                          onTap: () =>
                              widget.discoveryController.discoverDevices(),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.95,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white24),
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final brandLabel = device.brand == TvBrand.sony
                              ? 'Sony'
                              : device.brand == TvBrand.samsung
                                  ? 'Samsung'
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
                              '${device.ip} • $brandLabel',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                            onTap: () async {
                              Get.back();
                              await widget.onDeviceSelected(device);
                            },
                          );
                        },
                      ),
                    ),
                    _RescanButton(
                      onTap: () => widget.discoveryController.discoverDevices(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RescanButton extends StatelessWidget {
  const _RescanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
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

/// Three small colored dots with a smooth pulsing animation for the dark-themed loader.
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
    Color(0xFFFF9800), // orange
    Color(0xFFAB47BC), // purple
    Color(0xFF66BB6A), // green
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
              padding: EdgeInsets.symmetric(
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
                        color: _dotColors[index].withOpacity(0.5),
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
