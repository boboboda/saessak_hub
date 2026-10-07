import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 도트 스프라이트 모음. 로딩에 실패하면 null → 화면은 기존 도형으로 그려짐.
class Sprites {
  static ui.Image? staffWalk;
  static ui.Image? box;
  static ui.Image? floor;

  /// 시트: 가로 7프레임, 세로 4방향 (0 남, 1 서, 2 동, 3 북). 프레임 56x56.
  static const int frames = 7;
  static const double cell = 56;

  static Future<void> load() async {
    staffWalk = await _img('assets/sprites/staff/staff_walk.png');
    box = await _img('assets/sprites/props/box.png');
    floor = await _img('assets/sprites/tiles/floor.png');
  }

  static Future<ui.Image?> _img(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// 직원 한 명을 그린다. (x,y)는 발 위치. dir 0남 1서 2동 3북, moving이면 걷기 모션.
  static void drawStaff(ui.Canvas c, double x, double y, int dir, bool moving,
      double clock,
      {double size = 50, double alpha = 1}) {
    final img = staffWalk;
    if (img == null) return;
    final f = moving ? 1 + (clock * 9).floor() % (frames - 1) : 0;
    final src = ui.Rect.fromLTWH(f * cell, dir * cell, cell, cell);
    final dst = ui.Rect.fromLTWH(x - size / 2, y - size * 0.86, size, size);
    final p = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..color = ui.Color.fromARGB((alpha * 255).round(), 255, 255, 255);
    c.drawImageRect(img, src, dst, p);
  }

  /// 택배 상자. 칸 안에 맞춰 그리고 구역 색 스티커를 붙인다. 이미지가 없으면 false.
  static bool drawBox(ui.Canvas c, ui.Rect r, int stickerColor) {
    final img = box;
    if (img == null) return false;
    c.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        r,
        ui.Paint()..filterQuality = ui.FilterQuality.none);
    final s = r.width * 0.3;
    c.drawRect(ui.Rect.fromLTWH(r.center.dx - s / 2, r.center.dy - s * 0.1, s, s * 0.8),
        ui.Paint()..color = ui.Color(stickerColor));
    return true;
  }

  /// 창고 바닥 한 칸.
  static bool drawFloor(ui.Canvas c, double x, double y, double t) {
    final img = floor;
    if (img == null) return false;
    c.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH(x, y, t, t),
        ui.Paint()..filterQuality = ui.FilterQuality.none);
    return true;
  }
}
