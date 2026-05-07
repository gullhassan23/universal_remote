import 'package:flutter/material.dart';

class VolumeRailIcon extends StatelessWidget {
  const VolumeRailIcon({
    Key? key,
    required this.asset,
    required this.ontap,
  }) : super(key: key);

  final String asset;
  final VoidCallback ontap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Image.asset(
        asset,
        height: 40,
        width: 25,
        fit: BoxFit.contain,
      ),
    );
  }
}
