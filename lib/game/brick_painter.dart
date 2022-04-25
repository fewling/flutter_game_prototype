// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

import 'brick.dart';

class BrickPainter extends CustomPainter {
  final List<Brick> _bricks;

  BrickPainter(this._bricks);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = Colors.red;
    paint.strokeWidth = 10;

    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), paint);

    for (var brick in _bricks) {
      brick.fallTo(size.height);

      double x = 0;
      switch (brick.content) {
        case 'A':
          x = 0;
          break;
        case 'S':
          x = size.width / 6 * 2;
          break;
        case 'D':
          x = size.width / 6 * 3;
          break;
        case 'J':
          x = size.width / 6 * 4;
          break;
        case 'K':
          x = size.width / 6 * 5;
          break;
        case 'L':
          x = size.width / 6 * 6;
          break;
      }

      final rect = Rect.fromLTWH(x, brick.y, size.width / 6, brick.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(BrickPainter oldDelegate) => true;
}
