import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 도트 스프라이트 모음. 로딩에 실패하면 null → 화면은 기존 도형으로 그려짐.
class Sprites {
  static ui.Image? staffWalk;
  static ui.Image? box;
  static ui.Image? floor;
  static ui.Image? counter, pack, shelf, van;
  static ui.Image? grass, asphalt, sidewalk, yard;
  static ui.Image? boxS, boxOpen, packEmpty;

  /// 배경 장식 도트 (assets/sprites/decor/<이름>.png). 없는 건 null.
  static final Map<String, ui.Image> decor = {};
  static const List<String> decorNames = [
    'tree', 'tree2', 'bush', 'lamp', 'light', 'bench', 'cone', 'sign',
    'house1', 'house2', 'house3', 'pallet', 'flower',
  ];

  /// 시트: 가로 7프레임, 세로 4방향 (0 남, 1 서, 2 동, 3 북). 프레임 56x56.
  static const int frames = 7;
  static const double cell = 56;

  static Future<void> load() async {
    staffWalk = await _img('assets/sprites/staff/staff_walk.png');
    box = await _img('assets/sprites/props/box.png');
    floor = await _img('assets/sprites/tiles/floor.png');
    counter = await _img('assets/sprites/props/counter.png');
    pack = await _img('assets/sprites/props/pack.png');
    shelf = await _img('assets/sprites/props/shelf.png');
    van = await _img('assets/sprites/props/van.png');
    boxS = await _img('assets/sprites/props/box_s.png');
    boxOpen = await _img('assets/sprites/props/box_open.png');
    packEmpty = await _img('assets/sprites/props/pack_empty.png'); // 있으면 포장 상자가 동적으로 생김
    grass = await _img('assets/sprites/tiles/grass.png');
    asphalt = await _img('assets/sprites/tiles/asphalt.png');
    sidewalk = await _img('assets/sprites/tiles/sidewalk.png');
    yard = await _img('assets/sprites/tiles/yard.png');
    for (final n in decorNames) {
      final im = await _img('assets/sprites/decor/$n.png');
      if (im != null) decor[n] = im;
    }
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
      {double size = 56, double alpha = 1}) {
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

  static ui.Image? forBuilding(String id) {
    switch (id) {
      case 'counter':
        return counter;
      case 'pack':
        return packEmpty ?? pack;
      case 'shelf':
        return shelf;
    }
    return null;
  }

  /// 칸 너비에 맞춰(비율 유지) 아래쪽 기준으로 그린다. 위로 넘쳐도 됨.
  static void drawFitWidth(ui.Canvas c, ui.Image img, ui.Rect r) {
    final h = r.width * img.height / img.width;
    _blit(c, img, ui.Rect.fromLTWH(r.left, r.bottom - h, r.width, h));
  }

  /// 칸 안에 비율을 유지하며 가운데에 맞춘다.
  static void drawContain(ui.Canvas c, ui.Image img, ui.Rect r) {
    final k = (r.width / img.width) < (r.height / img.height)
        ? r.width / img.width
        : r.height / img.height;
    final w = img.width * k, h = img.height * k;
    _blit(c, img,
        ui.Rect.fromLTWH(r.center.dx - w / 2, r.center.dy - h / 2, w, h));
  }

  static void _blit(ui.Canvas c, ui.Image img, ui.Rect dst) {
    c.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        ui.Paint()..filterQuality = ui.FilterQuality.none);
  }

  /// 32x32 바닥 한 칸. variants>1이면 가로로 이어진 시트에서 v번째를 그림.
  static bool drawTile(ui.Canvas c, ui.Image? img, double x, double y,
      double t, [int variants = 1, int v = 0]) {
    if (img == null) return false;
    final w = img.width / variants;
    c.drawImageRect(
        img,
        ui.Rect.fromLTWH(w * v, 0, w, img.height.toDouble()),
        ui.Rect.fromLTWH(x, y, t, t),
        ui.Paint()..filterQuality = ui.FilterQuality.none);
    return true;
  }

  /// 작은 상자(선반 칸용). 이미지 없으면 false.
  static bool drawSmallBox(ui.Canvas c, double x, double y) {
    final img = boxS;
    if (img == null) return false;
    c.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH(x, y, img.width.toDouble(), img.height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.none);
    return true;
  }
}
