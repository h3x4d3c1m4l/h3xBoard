import 'package:flutter/material.dart';

class Board extends StatelessWidget {
  const Board({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Container(
        width: 1920,
        height: 1080,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black45, width: 1),
        ),
      ),
    );
  }
}
