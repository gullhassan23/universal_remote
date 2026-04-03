import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/get_started.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Universal TV Remote',
      debugShowCheckedModeBanner: false,

      home: GetStarted(),
      // home: const RemoteScreen(),
    );
  }
}
