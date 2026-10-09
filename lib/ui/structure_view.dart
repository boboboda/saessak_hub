import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'draw_utils.dart';

/// 코드로 그리는 건물 구조·소품·그림자. 외곽선은 모두 [ink] 1px, 색은 [Pal]에서 고름 (에셋 톤에 맞춤).
const int ink = 0xFF2A2438;

/// 허브 공통 팔레트 (도트 에셋들의 톤에서 뽑음)
class Pal {
  static const wallFace = 0xFFCBB898; // 외벽 판넬
  static const wallLine = 0xFFB4A07E;
  static const wallDark = 0xFF8C7556; // 기둥·그늘
  static const wallCap = 0xFF7A5C3A; // 벽 윗면
  static const wallCapHi = 0xFF9C7A52;
  static const glass = 0xFF7FB6D9;
  static const glassHi = 0xFFCDE8F7;
  static const frame = 0xFF4E4A5C;
  static const green = 0xFF3FA34D; // 새싹 초록 (간판)
  static const greenDark = 0xFF2B7A37;
  static const yellow = 0xFFF2C230; // 안전선·경고
  static const cardboard = 0xFFC8955E;
  static const cardboardDark = 0xFF9A6A3C;
  static const metal = 0xFF9AA3AE;
  static const red = 0xFFD9483B;
}

void _rectInk(Canvas c, Rect r, int fill) {
  box(c, r.left, r.top, r.width, r.height, fill);
  strokeBox(c, r.deflate(0.5), ink, 1);
}

extension StructureView on HubGame {
  /// 바닥 그림자: 발끝(바닥 접점) 아래 납작한 타원
  void shadowAt(
    Canvas c,
    Offset foot,
    double w, {
    double h = 0,
    int alpha = 0x40,
  }) {
    final hh = h > 0 ? h : max(4.0, w * 0.28);
    c.drawOval(
      Rect.fromCenter(center: foot.translate(0, -1), width: w, height: hh),
      Paint()..color = Color(alpha << 24),
    );
  }

  /// 시설 그림자: 그림 아래쪽에 깔리는 둥근 띠 (오른쪽 아래로 살짝 밀림)
  void shadowUnder(Canvas c, Rect sprite) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          sprite.left + 1,
          sprite.bottom - 7,
          sprite.right + 3,
          sprite.bottom + 3,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x38000000),
    );
  }

  /// 창고 북쪽 외벽(안쪽 면): 판넬·기둥·창문 + 가운데 간판. 발끝 = 창고 위 끝
  void drawFacade(Canvas c, Rect ar) {
    const fh = 30.0; // 벽 높이(px)
    final f = Rect.fromLTRB(ar.left - 6, ar.top - fh, ar.right + 6, ar.top + 2);
    box(c, f.left, f.top, f.width, f.height, Pal.wallFace);
    for (var y = f.top + 9; y < f.bottom - 2; y += 9) {
      box(c, f.left, y, f.width, 1, Pal.wallLine); // 판넬 줄
    }
    const t = Cfg.tile;
    // 기둥(4칸마다) 사이에 창문(2칸마다)
    for (var x = ar.left; x <= ar.right + 0.5; x += t * 4) {
      _rectInk(c, Rect.fromLTWH(x - 5, f.top, 10, f.height), Pal.wallDark);
      box(c, x - 4, f.top + 1, 2, f.height - 2, 0x33FFFFFF);
    }
    for (var x = ar.left + t; x < ar.right - t * 0.5; x += t * 2) {
      if (((x - ar.left) / (t * 4)).round() * t * 4 == x - ar.left)
        continue; // 기둥 자리
      final w = Rect.fromLTWH(x - 11, f.top + 7, 22, 13);
      _rectInk(c, w, Pal.frame);
      box(c, w.left + 2, w.top + 2, w.width - 4, w.height - 4, Pal.glass);
      // 유리 반사
      c.drawLine(
        Offset(w.left + 4, w.bottom - 3),
        Offset(w.left + 9, w.top + 3),
        Paint()
          ..color = const Color(Pal.glassHi)
          ..strokeWidth = 2,
      );
      box(c, w.left + 2, w.center.dy, w.width - 4, 1, Pal.frame); // 창살
    }
    // 벽 윗면(캡)
    _rectInk(
      c,
      Rect.fromLTRB(f.left - 2, f.top - 6, f.right + 2, f.top + 1),
      Pal.wallCap,
    );
    box(c, f.left - 1, f.top - 5, f.width + 2, 2, Pal.wallCapHi);
    box(c, f.left, f.bottom - 1, f.width, 1, ink);
    // 간판: 새싹 택배 허브 (외벽 가운데)
    final sw = min(150.0, ar.width - 40);
    final s = Rect.fromCenter(
      center: Offset(ar.center.dx, f.top + 13),
      width: sw,
      height: 18,
    );
    _rectInk(c, s, Pal.green);
    box(c, s.left + 1, s.top + 1, s.width - 2, 2, 0x55FFFFFF);
    _leaf(c, Offset(s.left + 10, s.center.dy));
    labelIn(c, '새싹 택배 허브', s.translate(6, 0), size: 11);
    // 벽 아래 바닥 그늘 (창고 안쪽)
    c.drawRect(
      Rect.fromLTWH(ar.left, ar.top + 2, ar.width, 8),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x40000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(ar.left, ar.top + 2, ar.width, 8)),
    );
  }

  /// 새싹 잎 아이콘
  void _leaf(Canvas c, Offset p) {
    final g = Paint()..color = const Color(0xFFB8F28A);
    c.drawOval(
      Rect.fromCenter(center: p.translate(-3, -1), width: 7, height: 5),
      g,
    );
    c.drawOval(
      Rect.fromCenter(center: p.translate(3, -2), width: 7, height: 5),
      g,
    );
    box(c, p.dx - 0.5, p.dy - 1, 1.5, 5, 0xFFB8F28A);
  }

  /// 옆벽·남쪽 벽(윗면 + 바깥 앞면), 모서리 기둥, 입구 문틀·발판. openingsR = 오른쪽 벽의 뚫린 곳(px)
  void drawSideWalls(Canvas c, Rect ar, Rect door, List<Rect> openingsR) {
    // 왼쪽 벽 (입구 위·아래)
    _wallV(c, ar.left, ar.top, door.top);
    _wallV(c, ar.left, door.bottom, ar.bottom);
    // 오른쪽 벽 (문·도크 자리는 뚫림)
    var y = ar.top;
    for (final o in openingsR..sort((p, q) => p.top.compareTo(q.top))) {
      if (o.top > y) _wallV(c, ar.right, y, o.top);
      y = max(y, o.bottom);
    }
    if (ar.bottom > y) _wallV(c, ar.right, y, ar.bottom);
    // 남쪽 벽: 윗면 + 바깥으로 보이는 앞면
    _rectInk(
      c,
      Rect.fromLTRB(ar.left - 5, ar.bottom - 4, ar.right + 5, ar.bottom + 4),
      Pal.wallCap,
    );
    box(c, ar.left - 4, ar.bottom - 3, ar.width + 8, 2, Pal.wallCapHi);
    _rectInk(
      c,
      Rect.fromLTRB(ar.left - 5, ar.bottom + 3, ar.right + 5, ar.bottom + 13),
      Pal.wallDark,
    );
    for (var x = ar.left + 16; x < ar.right; x += 32) {
      box(c, x, ar.bottom + 5, 1, 7, 0x33000000);
    }
    // 모서리 기둥
    for (final p in [ar.topLeft, ar.topRight, ar.bottomLeft, ar.bottomRight]) {
      _rectInk(
        c,
        Rect.fromCenter(center: p, width: 12, height: 12),
        Pal.wallDark,
      );
      box(c, p.dx - 5, p.dy - 5, 10, 3, Pal.wallCapHi);
    }
    // 입구: 문틀 기둥 + 유리문 레일 + 안쪽 발판
    for (final py in [door.top, door.bottom]) {
      _rectInk(
        c,
        Rect.fromCenter(center: Offset(ar.left, py), width: 10, height: 10),
        Pal.frame,
      );
    }
    box(c, ar.left - 1, door.top + 5, 2, door.height - 10, 0x997FB6D9);
    _rectInk(
      c,
      Rect.fromLTWH(ar.left + 3, door.top + 6, 18, door.height - 12),
      0xFF4A4F5C,
    );
    for (var yy = door.top + 9; yy < door.bottom - 8; yy += 4) {
      box(c, ar.left + 5, yy, 14, 1, 0xFF5D6372);
    }
  }

  void _wallV(Canvas c, double x, double y0, double y1) {
    if (y1 - y0 < 1) return;
    _rectInk(c, Rect.fromLTRB(x - 4, y0, x + 4, y1), Pal.wallCap);
    box(c, x - 3, y0, 2, y1 - y0, Pal.wallCapHi);
  }

  /// 입구 간판 (기둥 둘에 걸린 판). foot = 기둥 아래 가운데
  void drawEntranceSign(Canvas c, Offset foot) {
    shadowAt(c, foot, 44, h: 6);
    for (final dx in [-17.0, 17.0]) {
      _rectInk(
        c,
        Rect.fromLTWH(foot.dx + dx - 2, foot.dy - 30, 4, 30),
        Pal.frame,
      );
    }
    final b = Rect.fromCenter(
      center: Offset(foot.dx, foot.dy - 30),
      width: 58,
      height: 20,
    );
    _rectInk(c, b, Pal.green);
    box(c, b.left + 1, b.top + 1, b.width - 2, 2, 0x55FFFFFF);
    _leaf(c, Offset(b.left + 8, b.center.dy));
    labelIn(c, '새싹 택배', b.translate(5, 0), size: 10);
  }

  // ---------------- 시설 소품 (그림 위에 덧그림) ----------------

  /// 접수대: 스탬프·벨 (컴퓨터·저울은 그림에 있음). d = 책상 그림 영역
  void drawCounterProps(Canvas c, Rect d) {
    // 스탬프 (빨간 손잡이 + 인주판)
    final sx = d.left + d.width * 0.47, sy = d.top + 22;
    _rectInk(c, Rect.fromLTWH(sx - 5, sy, 10, 4), 0xFF3A3346);
    _rectInk(c, Rect.fromLTWH(sx - 2, sy - 5, 4, 6), Pal.red);
    // 벨 (금색 반구 + 받침)
    final bx = d.left + d.width * 0.62, by = d.top + 25;
    c.drawArc(
      Rect.fromCenter(center: Offset(bx, by), width: 9, height: 9),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFFF2C230),
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(bx, by), width: 9, height: 9),
      pi,
      pi,
      true,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(ink),
    );
    box(c, bx - 5, by, 10, 2, 0xFF6B5A3A);
    box(c, bx - 1, by - 6, 2, 2, 0xFFFFE9A0);
  }

  /// 포장대: 테이프 디스펜서·뽁뽁이 롤(책상 위), 옆에 접은 상자 더미. d = 책상 그림, r = 건물 칸
  void drawPackProps(Canvas c, Rect d, Rect r) {
    // 테이프 디스펜서
    final tx = d.left + d.width * 0.62, ty = d.top + 9;
    _rectInk(c, Rect.fromLTWH(tx - 6, ty, 12, 5), 0xFF3A3346);
    c.drawCircle(
      Offset(tx - 1, ty - 1),
      4,
      Paint()..color = const Color(0xFFE8C98A),
    );
    c.drawCircle(
      Offset(tx - 1, ty - 1),
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(ink),
    );
    c.drawCircle(
      Offset(tx - 1, ty - 1),
      1.5,
      Paint()..color = const Color(0xFF8A6A3C),
    );
    // 뽁뽁이 롤 (책상 왼쪽 뒤)
    final wx = d.left + d.width * 0.3, wy = d.top + 4;
    _rectInk(c, Rect.fromLTWH(wx, wy, 14, 7), 0xFFDDEEF5);
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        Offset(wx + 3 + i * 4, wy + 3.5),
        1,
        Paint()..color = const Color(0xFFA8C8D8),
      );
    }
    // 오른쪽 아래: 접어 둔 상자 더미 (높이 다르게)
    final px = r.right - 9, py = r.bottom - 2;
    for (var i = 0; i < 3; i++) {
      final rr = Rect.fromLTWH(
        px - 6 + (i.isOdd ? 1 : 0),
        py - 4 - i * 3,
        13,
        3,
      );
      _rectInk(c, rr, i.isEven ? Pal.cardboard : Pal.cardboardDark);
    }
  }

  /// 도크 문 앞(창고 안) 바닥 경고 줄무늬. r = 도크 칸(px), 창고 오른쪽 벽 안쪽에 붙음
  void drawDockStripes(Canvas c, Rect r, double wallX) {
    final z = Rect.fromLTWH(wallX - 12, r.top + 3, 10, r.height - 6);
    c.save();
    c.clipRect(z);
    box(c, z.left, z.top, z.width, z.height, Pal.yellow);
    final p = Paint()
      ..color = const Color(0xFF2A2438)
      ..strokeWidth = 4;
    for (var y = z.top - 12; y < z.bottom + 12; y += 10) {
      c.drawLine(Offset(z.left, y), Offset(z.right, y + 10), p);
    }
    c.restore();
    strokeBox(c, z, ink, 1);
  }

  // ---------------- 작업 손동작 ----------------
  static const int skin = 0xFFF2C29B;

  void _hand(Canvas c, double x, double y) {
    box(c, x - 2, y - 1.5, 4, 3, skin);
    strokeBox(c, Rect.fromLTWH(x - 2.5, y - 2, 5, 4), ink, 1);
  }

  /// 접수: 책상 위 키보드 + 번갈아 두드리는 두 손. at = 키보드 가운데
  void typingHands(Canvas c, Offset at, bool busy, double phase) {
    final k = Rect.fromCenter(center: at, width: 16, height: 5);
    _rectInk(c, k, 0xFF3A3346);
    for (var i = 0; i < 4; i++) {
      box(c, k.left + 2 + i * 3.2, k.top + 1.5, 2, 2, 0xFF8A8FA0);
    }
    final ph = (clock * 9 + phase * 10);
    final l = busy ? (sin(ph) > 0 ? -2.0 : 0.0) : 0.0;
    final r = busy ? (sin(ph) > 0 ? 0.0 : -2.0) : 0.0;
    _hand(c, k.left + 4, k.top + l);
    _hand(c, k.right - 4, k.top + r);
  }

  /// 포장: 테이프 건(손잡이 + 롤)이 상자 윗면을 좌우로 지나감. br = 상자 그림 영역
  void tapeGun(Canvas c, Rect br, double clock) {
    final u = (sin(clock * 3) * 0.5 + 0.5);
    final x = br.left + 2 + (br.width - 4) * u, y = br.top + br.height * 0.28;
    c.drawCircle(Offset(x, y - 3), 3, Paint()..color = const Color(0xFFE8C98A));
    c.drawCircle(
      Offset(x, y - 3),
      3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(ink),
    );
    _rectInk(c, Rect.fromLTWH(x + 1, y - 7, 6, 3), Pal.red);
    _hand(c, x + 6, y - 5);
  }

  /// 운반: 상자 양옆을 받친 두 손
  void liftHands(Canvas c, Rect box) {
    _hand(c, box.left + 1, box.center.dy + 2);
    _hand(c, box.right - 1, box.center.dy + 2);
  }
}
