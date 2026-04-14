import 'package:flutter/material.dart';

class StreamingAppItem {
  const StreamingAppItem({
    required this.id,
    required this.name,
    required this.packageName,
    required this.icon,
    this.accentColor = const Color(0xFFE50914),
  });

  final String id;
  final String name;
  final String packageName;
  final IconData icon;
  final Color accentColor;
}
