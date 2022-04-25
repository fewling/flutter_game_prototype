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
    paint.strokeWidth = 3;

    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), paint);

    for (var brick in _bricks) {
      brick.fallTo(size.height);
      final rect = Rect.fromLTWH(brick.x, brick.y, brick.width, brick.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(BrickPainter oldDelegate) => true;
}
