// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:smartapp/utils/constant.dart';

class bg_container extends StatelessWidget {
  final Widget child;
  const bg_container({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          ImageRes.kGetStartedBackgroundAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: Color(0xFF0B56D0));
          },
        ),
        child,
      ],
    );
  }
}
