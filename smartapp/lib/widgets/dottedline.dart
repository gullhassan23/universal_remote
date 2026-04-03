import 'dart:math';

import 'package:flutter/material.dart';

class DottedCirclePainter extends CustomPainter {
  final double progress;

  DottedCirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double radius = size.width / 2;
    int dotCount = 40;

    for (int i = 0; i < dotCount; i++) {
      double angle = (2 * pi * i / dotCount) + (progress * 2 * pi);

      double x = radius + radius * cos(angle);
      double y = radius + radius * sin(angle);

      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
