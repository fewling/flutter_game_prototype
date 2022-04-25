// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

class Brick extends StatefulWidget {
  final String content;
  final int position;
  final double x;
  double y;
  final double width;
  final double height;
  final Color color;

  final double fallTime = 1000;

  bool isOutOfScreen = false;
  double totalDist = 0;
  String result = '';

  Brick(this.content, this.position, this.x, this.y, this.width, this.height,
      this.color,
      {Key? key})
      : super(key: key);

  @override
  State<Brick> createState() => _BrickState();

  void fallTo(double destination) {
    totalDist = destination;

    /// AnimationBuilder used in game.dart will run 60 fps
    /// Assume top-to-bottom (distance) = 600 units
    /// if falling takes 1000 ms, then every frame falls by 600 / 60 = 10 pixels/frame (velocity).
    /// if falling takes 500 ms, then it should double the velocity (600 / 30 = 20 units/frame)/
    /// where 30 = 60fps * (falltime / 1000ms)
    /// velocity units: pixels/frame
    double velocity = destination / (60 * (fallTime / 1000));
    y += velocity;

    if (y >= destination) isOutOfScreen = true;
  }

  double remainingDist() => totalDist - y;
}

class _BrickState extends State<Brick> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white,
    );
  }
}
