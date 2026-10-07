import 'package:flutter/material.dart';

/// from에서 to를 향해 speed*dt만큼 이동한 위치
Offset stepToward(Offset from, Offset to, double speed, double dt) {
  final d = to - from;
  final dist = d.distance;
  final step = speed * dt;
  if (dist <= step) return to;
  return from + d / dist * step;
}