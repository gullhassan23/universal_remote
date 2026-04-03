import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tv_brand.dart';
import 'device_discovery_controller.dart';

class DeviceListScreen extends GetView<DeviceDiscoveryController> {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.discoverDevices(),
          ),
        ],
      ),
      body: Obx(
        () {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.devices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  controller.errorMessage.isNotEmpty
                      ? controller.errorMessage.value
                      : 'No TVs found.\nMake sure your phone and TV are on the same WiFi network.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = controller.devices[index];
              final brandLabel =
                  device.brand == TvBrand.androidTv ? 'Android TV' : device.brand.name;
              return ListTile(
                leading: const Icon(Icons.tv),
                title: Text(device.name),
                subtitle: Text('${device.ip} • $brandLabel'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => controller.connectTo(device),
              );
            },
          );
        },
      ),
    );
  }
}

