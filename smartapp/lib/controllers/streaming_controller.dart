import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';

import 'tv_connection_controller.dart';
import '../models/streaming_app_item.dart';

class StreamingController extends GetxController {
  StreamingController({TvConnectionController? connectionController})
      : _connectionController =
            connectionController ?? Get.find<TvConnectionController>();

  final TvConnectionController _connectionController;
  final RxString launchingAppId = ''.obs;

  static const apps = <StreamingAppItem>[
    StreamingAppItem(
      id: 'netflix',
      name: 'Netflix',
      packageName: 'com.netflix.ninja',
      icon: StreamingAppIcon.netflix,
      accentColor: Color(0xFFE50914),
    ),
    StreamingAppItem(
      id: 'youtube',
      name: 'YouTube',
      packageName: 'com.google.android.youtube.tv',
      icon: StreamingAppIcon.youtube,
      accentColor: Color(0xFFFF0000),
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
