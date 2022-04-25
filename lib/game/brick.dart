import 'package:flutter/material.dart';

class Brick {
  final String content;
  final int position;
  final double x;
  double y;
  final double width;
  final double height;
  final Color color;

  final double fallTime = 1000;

  Brick(
    this.content,
    this.position,
    this.x,
    this.y,
    this.width,
    this.height,
    this.color,
  );

  void fallTo(double destination) {
    /// AnimationBuilder used above will run 60 fps
    /// Assume top-to-bottom (distance) = 600 units
    /// if falling takes 1000 ms, then every frame falls by 600 / 60 = 10 units units/frame (velocity).
    /// if falling takes 500 ms, then it should double the velocity (600 / 30 = 20 units/frame)/
    /// where 30 = 60fps * (falltime / 1000ms)
    double velocity = destination / (60 * (fallTime / 1000));
    y += velocity;
  }
}
