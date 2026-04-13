// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

class bg_container extends StatelessWidget {
  final Widget child;
  const bg_container({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/icons/bg.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
