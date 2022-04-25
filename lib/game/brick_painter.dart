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

    double lineY = size.height * 0.9;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);

    for (var brick in _bricks) {
      brick.fallTo(lineY);
      final rect = Rect.fromLTWH(brick.x, brick.y, brick.width, brick.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(BrickPainter oldDelegate) => true;
}
