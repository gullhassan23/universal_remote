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
  final Future<bool> Function(TvDevice) onDeviceSelected;
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
  static final RegExp _ipv4Pattern =
      RegExp(r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$');

  @override
  void initState() {
    super.initState();
    // Defer Rx updates until after the bottom sheet finishes its first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.discoveryController.discoverDevices();
    });
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
                          const SizedBox(height: 8),
                          _ManualIpButton(
                            buttonKey: 'MANUAL_IP_CONNECT_EMPTY',
                            onHandleTap: widget.onHandleTap,
                            onTap: _showManualIpDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: devices.length + 1,
                    separatorBuilder: (_, index) {
                      if (index >= devices.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return const Divider(height: 1, color: Colors.white24);
                    },
                    itemBuilder: (context, index) {
                      if (index >= devices.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              _RescanButton(
                                buttonKey: 'DISCOVERY_RESCAN_LIST',
                                onTap: () =>
                                    widget.discoveryController.discoverDevices(),
                                onHandleTap: widget.onHandleTap,
                              ),
                              _ManualIpButton(
                                buttonKey: 'MANUAL_IP_CONNECT_LIST',
                                onHandleTap: widget.onHandleTap,
                                onTap: _showManualIpDialog,
                              ),
                            ],
                          ),
                        );
                      }

                      final device = devices[index];
                      final isConnectingThisDevice =
                          _connectingDeviceId.value == device.id;
                      final brandLabel = device.brand == TvBrand.androidTv
                          ? 'Smart TV'
                          : device.brand.name;
                      return ListTile(
                        leading: const Icon(
                          Icons.tv,
                          color: Colors.white70,
                          size: 28,
                        ),
                        title: Text(
                          device.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          brandLabel,
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
                                  final connected =
                                      await widget.onDeviceSelected(device);
                                  if (connected && mounted) {
                                    Navigator.of(context).maybePop();
                                  }
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
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManualIpDialog() async {
    var ipValue = '';
    String? validationMessage;

    final manualDevice = await showDialog<TvDevice>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1D1F),
              title: const Text(
                'Connect with IP address',
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. 192.168.1.24',
                  hintStyle: const TextStyle(color: Colors.white54),
                  errorText: validationMessage,
                ),
                onChanged: (value) {
                  ipValue = value.trim();
                  if (validationMessage != null) {
                    setState(() => validationMessage = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (ipValue.isEmpty) {
                      setState(() => validationMessage = 'TV IP address required');
                      return;
                    }
                    if (!_ipv4Pattern.hasMatch(ipValue)) {
                      setState(
                        () => validationMessage = 'Enter a valid IPv4 address',
                      );
                      return;
                    }
                    final ip = ipValue;
                    Navigator.of(dialogContext).pop(
                      TvDevice(
                        id: 'manual-$ip:6467',
                        name: 'Smart TV ($ip)',
                        ip: ip,
                        port: 6467,
                        brand: TvBrand.androidTv,
                      ),
                    );
                  },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || manualDevice == null) return;
    if (_connectingDeviceId.value != null) return;
    _connectingDeviceId.value = manualDevice.id;
    try {
      final connected = await widget.onDeviceSelected(manualDevice);
      if (connected && mounted) {
        Navigator.of(context).maybePop();
      }
    } finally {
      if (!mounted) return;
      _connectingDeviceId.value = null;
    }
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

class _ManualIpButton extends StatelessWidget {
  const _ManualIpButton({
    required this.buttonKey,
    required this.onTap,
    required this.onHandleTap,
  });

  final String buttonKey;
  final Future<void> Function() onTap;
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
              action: 'manual_ip_connect',
              onTap: onTap,
            ),
          );
        },
        child: const Text(
          'Connect with IP address',
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
