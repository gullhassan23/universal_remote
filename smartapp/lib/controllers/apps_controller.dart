import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'tv_connection_controller.dart';
import '../models/streaming_app_item.dart';

class AppsController extends GetxController {
  AppsController({TvConnectionController? connectionController})
    : _connectionController =
          connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;
  final RxString launchingAppId = ''.obs;

  static const apps = <StreamingAppItem>[
    StreamingAppItem(
      id: 'netflix',
      name: 'Netflix',
      packageName: 'com.netflix.ninja',
      icon: Icons.movie_filter_rounded,
      accentColor: Color(0xFFE50914),
    ),
  ];

  Future<bool> launchStreamingApp(StreamingAppItem app) async {
    launchingAppId.value = app.id;
    try {
      return await _connectionController.launchApp(app.packageName);
    } finally {
      launchingAppId.value = '';
    }
  }
}
