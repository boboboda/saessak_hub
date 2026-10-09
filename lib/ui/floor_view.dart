import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'draw_utils.dart';

/// 창고 바닥: 구역마다 재질이 다름 (① 접수 밝은 타일, ② 포장 콘크리트 + 노란 안전선, ③ 보관 공장 바닥),
/// 유저가 깐 통로(초록 보행로 + 노란 테두리), 바닥에 칠한 구역 글씨.
extension FloorView on HubGame {
  /// 칸 (x, y)의 구역: 0 접수, 1 포장, 2 보관·출고
  int zoneOfX(int x) => x < Cfg.zoneX1 ? 0 : (x < Cfg.zoneX2 ? 1 : 2);

  // 칸마다 고정된 작은 난수 (얼룩·반점 위치)
  int _h(int x, int y) => ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff;

  void drawFloor(Canvas c, int x0, int y0, int x1, int y1) {
    const t = Cfg.tile;
    final a = area;
    final ax0 = max(a.left.toInt(), x0), ax1 = min(a.right.toInt(), x1);
    final ay0 = max(a.top.toInt(), y0), ay1 = min(a.bottom.toInt(), y1);

    // 1) 구역별 바닥 재질
    for (var j = ay0; j < ay1; j++) {
      for (var i = ax0; i < ax1; i++) {
        final x = i * t, y = j * t, h = _h(i, j);
        switch (zoneOfX(i)) {
          case 0: // 밝은 타일 (반 칸 격자, 줄눈)
            box(c, x, y, t, t, 0xFFF3EBDA);
            box(c, x, y, t / 2, t / 2, 0xFFEDE2CB);
            box(c, x + t / 2, y + t / 2, t / 2, t / 2, 0xFFEDE2CB);
            box(c, x, y, t, 1, 0xFFD9C9A8);
            box(c, x, y, 1, t, 0xFFD9C9A8);
            box(c, x, y + t / 2, t, 1, 0x66D9C9A8);
            box(c, x + t / 2, y, 1, t, 0x66D9C9A8);
            break;
          case 1: // 콘크리트 (반점 + 두 칸마다 줄눈)
            box(c, x, y, t, t, 0xFFC4C3BC);
            for (var k = 0; k < 4; k++) {
              final px = (h >> (k * 5)) % 30, py = (h >> (k * 5 + 3)) % 30;
              box(c, x + px, y + py, 2, 2, k.isEven ? 0xFFB2B1AA : 0xFFD3D2CB);
            }
            if (i % 2 == 0) box(c, x, y, 1, t, 0xFFA9A8A1);
            if (j % 2 == 0) box(c, x, y, t, 1, 0xFFA9A8A1);
            break;
          default: // 공장 바닥 (에폭시: 회녹색 + 세 칸 판넬 줄눈 + 얼룩)
            box(c, x, y, t, t, 0xFF97A396);
            if (h % 5 == 0) {
              c.drawOval(
                Rect.fromLTWH(x + h % 14, y + (h >> 4) % 16, 14, 8),
                Paint()..color = const Color(0x22303A30),
              );
            }
            if (i % 3 == 0) box(c, x, y, 2, t, 0xFF7F8B7E);
            if (j % 3 == 0) box(c, x, y, t, 2, 0xFF7F8B7E);
            box(c, x + 2, y + 2, t - 4, 1, 0x22FFFFFF);
        }
      }
    }

    // 2) 포장 구역 양쪽 경계의 노란 안전선
    final safe = Paint()..color = const Color(0xFFF2C230);
    for (final zx in [Cfg.zoneX1, Cfg.zoneX2]) {
      c.drawRect(
        Rect.fromLTRB(zx * t - 3, a.top * t, zx * t + 3, a.bottom * t),
        safe,
      );
    }

    // 3) 바닥에 칠한 구역 글씨 (건물 밑에 깔림)
    const names = ['① 접수', '② 분류·포장', '③ 보관·출고'];
    const ink = [0x55A0783C, 0x55505050, 0x55304030];
    final zx = [a.left, Cfg.zoneX1, Cfg.zoneX2, a.right];
    for (var z = 0; z < 3; z++) {
      final r = Rect.fromLTRB(zx[z] * t, (a.bottom - 1.2) * t, zx[z + 1] * t, (a.bottom - 0.2) * t);
      if (r.width < t) continue;
      labelIn(c, names[z], r, size: 15, color: Color(ink[z]));
    }

    // 4) 유저가 깐 통로: 초록 보행로, 통로가 끝나는 쪽에 노란 테두리
    bool on(int x, int y) => a.contains(Offset(x + 0.5, y + 0.5)) && isAisle(x, y);
    for (var j = ay0; j < ay1; j++) {
      for (var i = ax0; i < ax1; i++) {
        if (!on(i, j)) continue;
        final x = i * t, y = j * t;
        box(c, x, y, t, t, 0xFF5E9E6E);
        box(c, x + 4, y + 4, t - 8, t - 8, 0xFF67A877);
        if (!on(i - 1, j)) box(c, x, y, 3, t, 0xFFF2C230);
        if (!on(i + 1, j)) box(c, x + t - 3, y, 3, t, 0xFFF2C230);
        if (!on(i, j - 1)) box(c, x, y, t, 3, 0xFFF2C230);
        if (!on(i, j + 1)) box(c, x, y + t - 3, t, 3, 0xFFF2C230);
      }
    }
  }
}
