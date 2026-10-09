import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/scenery.dart';
import '../game/sprites.dart';
import '../models/building.dart';
import '../models/customer.dart';
import '../models/staff.dart';
import 'draw_utils.dart';

/// 게임 맵(캔버스). 메뉴·패널은 위젯이 따로 그림.
extension WorldView on HubGame {
  Rect _px(Rect r) => Rect.fromLTWH(
    r.left * Cfg.tile,
    r.top * Cfg.tile,
    r.width * Cfg.tile,
    r.height * Cfg.tile,
  );

  int x0Of(HubGame g) => max(0, (g.cam.dx / Cfg.tile).floor());
  int x1Of(HubGame g) =>
      min(Cfg.cols, ((g.cam.dx + g.size.x) / Cfg.tile).ceil());
  int y0Of(HubGame g) => max(0, (g.cam.dy / Cfg.tile).floor());
  int y1Of(HubGame g) =>
      min(Cfg.rows, ((g.cam.dy + g.size.y) / Cfg.tile).ceil());

  // ---------------- 인도(길) ----------------
  /// 창고 입구(왼쪽 벽 가운데)에서 왼쪽 세로길까지 이어지는 길. 창고가 커지면 같이 이동.
  Rect get entrancePath {
    final a = area;
    final cy = (a.center.dy - 1).floorToDouble();
    return Rect.fromLTRB(1, cy, a.left + 0.15, cy + 2);
  }

  void _drawPaths(Canvas c) {
    const t = Cfg.tile;
    for (final r in [...Scenery.paths, entrancePath]) {
      for (
        var y = max(r.top.toInt(), y0Of(this));
        y < min(r.bottom.toInt(), y1Of(this));
        y++
      ) {
        for (
          var x = max(r.left.toInt(), x0Of(this));
          x < min(r.right.ceil(), x1Of(this));
          x++
        ) {
          if (!Sprites.drawTile(c, Sprites.sidewalk, x * t, y * t, t)) {
            box(c, x * t, y * t, t, t, 0xFFB9B5A8);
          }
        }
      }
    }
  }

  // ---------------- 배경 장식 ----------------
  void _drawDecor(Canvas c) {
    const t = Cfg.tile;
    final a = _px(area.inflate(0.6)); // 지금 창고(+여백)와 겹치는 장식은 숨김
    final view = Rect.fromLTWH(
      cam.dx - 160,
      cam.dy - 160,
      size.x + 320,
      size.y + 320,
    );
    for (final d in Scenery.items) {
      final img = Sprites.decor[d.key];
      if (img == null) continue;
      final w = img.width.toDouble(), h = img.height.toDouble(); // 도트 원본 크기 그대로
      final r = Rect.fromLTWH(d.x * t - w / 2, d.y * t - h, w, h);
      if (!r.overlaps(view) || r.overlaps(a)) continue;
      if (!Scenery.onPath.contains(d.key) &&
          entrancePath.contains(Offset(d.x, d.y - 0.3))) {
        continue; // 입구 길 위의 나무 등은 숨김
      }
      Sprites.drawContain(c, img, r);
    }
  }

  void renderWorld(Canvas c) {
    const t = Cfg.tile;
    box(c, 0, 0, size.x, size.y, 0xFF2A2438);

    c.save();
    c.translate(-cam.dx, -cam.dy);

    // 잔디
    for (var y = y0Of(this); y < y1Of(this); y++) {
      for (var x = x0Of(this); x < x1Of(this); x++) {
        final v = (x * 7 + y * 13) % 4;
        if (!Sprites.drawTile(c, Sprites.grass, x * t, y * t, t, 4, v)) {
          box(
            c,
            x * t,
            y * t,
            t,
            t,
            (x + y) % 2 == 0 ? 0xFF69A857 : 0xFF6FAE5B,
          );
        }
      }
    }

    _drawPaths(c);
    _drawDecor(c);
    _drawRoadAndYard(c);
    _drawWarehouse(c);
    _drawBuildings(c);
    _drawPeople(c);

    // 배치 목업
    if (mode == 2 && placing != null) {
      final ok = this.ghostProblem == null;
      final r = _px(this.ghostRect);
      box(c, r.left, r.top, r.width, r.height, ok ? 0x9936C46A : 0x99E5484D);
      strokeBox(c, r, ok ? 0xFF2E9E57 : 0xFFE5484D, 3);
      labelIn(c, placing!.name, r, size: 12);
    }

    c.restore();
    _stackClock = clock;
    // 오래된 표정 기록 정리 (사라진 손님·직원)
    if (_faces.length > 64) {
      _faces.removeWhere(
        (k, _) =>
            (k is Customer && !customers.contains(k)) ||
            (k is Staff && !staff.contains(k)),
      );
    }
  }

  // ---------------- 도로 + 도크 마당 (창고 오른쪽 벽 바깥) ----------------
  void _drawRoadAndYard(Canvas c) {
    const t = Cfg.tile;

    // 도로 (아스팔트 + 중앙 점선) + 오른쪽 인도
    final rd = _px(Cfg.road);
    for (var ty = y0Of(this); ty < y1Of(this); ty++) {
      for (var tx = Cfg.road.left.toInt(); tx < Cfg.road.right.toInt(); tx++) {
        if (!Sprites.drawTile(c, Sprites.asphalt, tx * t, ty * t, t)) {
          box(c, tx * t, ty * t, t, t, 0xFF3A3A48);
        }
      }
      for (var tx = Cfg.road.right.toInt(); tx < x1Of(this); tx++) {
        if (!Sprites.drawTile(c, Sprites.sidewalk, tx * t, ty * t, t)) {
          box(c, tx * t, ty * t, t, t, 0xFFB9B5A8);
        }
      }
      box(c, rd.center.dx - 1.5, ty * t + 6, 3, t - 12, 0xFFFFD166);
    }
    // 횡단보도 (위·아래)
    for (final cy in [Cfg.yard.top - 1, Cfg.yard.bottom]) {
      for (var i = 0; i < 6; i++) {
        box(
          c,
          rd.left + 3 + i * (rd.width - 6) / 6,
          cy * t + 4,
          (rd.width - 6) / 6 - 3,
          t - 8,
          0xDDFFFFFF,
        );
      }
    }
    label(c, '→ 운송', rd.left + 4, area.top * t, size: 11);
    _drawTraffic(c);

    // 도크 마당 바닥
    final y = Cfg.yard;
    for (var ty = y.top.toInt(); ty < y.bottom.toInt(); ty++) {
      for (var tx = y.left.toInt(); tx < y.right.toInt(); tx++) {
        if (!Sprites.drawTile(c, Sprites.yard, tx * t, ty * t, t)) {
          box(
            c,
            tx * t,
            ty * t,
            t,
            t,
            (tx + ty) % 2 == 0 ? 0xFF55556A : 0xFF4D4D62,
          );
        }
      }
    }
    // 하역장 표시: 도크 앞 주차칸(흰 선)
    for (final d in ofType('dock')) {
      final r = _px(d.rect);
      final lp = Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = 2;
      c.drawLine(
        Offset(r.right, r.top + 2),
        Offset(_px(y).right - 2, r.top + 2),
        lp,
      );
      c.drawLine(
        Offset(r.right, r.bottom - 2),
        Offset(_px(y).right - 2, r.bottom - 2),
        lp,
      );
    }
    // 도크를 고르면 마당이 강조됨
    if (mode == 2 && placing != null && placing!.zone == 3) {
      final r = _px(y);
      box(c, r.left, r.top, r.width, r.height, Cfg.zoneHot[3]);
    }
    strokeBox(c, _px(y), 0xFF2A2438, 3);
    final dt = Rect.fromLTWH(y.left * t + 6, y.top * t + 6, 74, 18);
    c.drawRRect(
      RRect.fromRectAndRadius(dt, const Radius.circular(4)),
      Paint()..color = const Color(0xF2FFD166),
    );
    labelIn(c, '④ 출고 도크', dt, size: 11, color: const Color(0xFF2A2438));
  }

  /// 도로를 오가는 차량 (배경 연출). 왼쪽 차선은 아래로, 오른쪽 차선은 위로. 화면 밖은 건너뜀
  void _drawTraffic(Canvas c) {
    const t = Cfg.tile;
    final cars = Sprites.roadCars;
    if (cars.isEmpty) return;
    final rd = Cfg.road;
    final view = Rect.fromLTWH(cam.dx, cam.dy, size.x, size.y).inflate(t * 2);
    final p = Paint()..filterQuality = FilterQuality.none;
    for (var lane = 0; lane < 2; lane++) {
      final lx = lane == 0
          ? rd.left + rd.width * 0.27
          : rd.right - rd.width * 0.27;
      for (var i = 0; i < Cfg.trafficPerLane; i++) {
        final img = cars[(lane * 2 + i * 3) % cars.length];
        // 차선 안에서 같은 속도·같은 간격이라 서로 겹치지 않는다
        final u =
            (clock * Cfg.trafficSpeed[lane] +
                i * Cfg.trafficLoop / Cfg.trafficPerLane +
                lane * 13) %
            Cfg.trafficLoop;
        final ty = lane == 0 ? u - 4 : Cfg.rows + 4 - u; // 월드 위·아래 밖에서 나타나고 사라짐
        final w = img.width.toDouble(), h = img.height.toDouble();
        final dst = Rect.fromLTWH(lx * t - w / 2, ty * t - h / 2, w, h);
        if (!dst.overlaps(view)) continue;
        final src = Rect.fromLTWH(0, 0, w, h);
        if (lane == 0) {
          c.drawImageRect(img, src, dst, p);
        } else {
          c.save();
          c.translate(0, dst.center.dy * 2);
          c.scale(1, -1); // 위로 달리는 차는 상하 반전 (위에서 본 그림이라 그대로 맞음)
          c.drawImageRect(img, src, dst, p);
          c.restore();
        }
      }
    }
  }

  // ---------------- 창고 건물 ----------------
  // 동선: 입구(왼쪽 벽) → ① 접수 → ② 분류·포장 → ③ 보관 → ④ 출고 도크(오른쪽 벽 밖).
  // 가운데 노란 통로가 그 길이고, 화살표가 진행 방향이다.
  void _drawWarehouse(Canvas c) {
    const t = Cfg.tile;

    // 확장 미리보기 (현재 창고 아래에 깔림)
    if (mode == 3 && canExpand) {
      final n = Cfg.areas[areaLevel + 1];
      final r = _px(n);
      box(c, r.left, r.top, r.width, r.height, 0x663B82D6);
      strokeBox(c, r, 0xFF3B82D6, 3);
      label(
        c,
        '확장 후 ${n.width.toInt()}×${n.height.toInt()}칸',
        r.left + 6,
        r.top + 6,
        size: 12,
      );
    }

    final a = area;
    final ai = aisle;
    final ar = _px(a);
    // 바닥: 콘크리트 + 노란 통로 (이중 격자 Wang 타일, 창고 안만)
    c.save();
    c.clipRect(ar);
    final fl = Sprites.wangFloor;
    bool aisleAt(int x, int y) =>
        x >= a.left && x < a.right && ai.contains(Offset(x + 0.5, y + 0.5));
    final p = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (
      var j = max(a.top.toInt(), y0Of(this));
      j <= min(a.bottom.toInt(), y1Of(this));
      j++
    ) {
      for (
        var i = max(a.left.toInt(), x0Of(this));
        i <= min(a.right.toInt(), x1Of(this));
        i++
      ) {
        final dst = Rect.fromLTWH((i - 0.5) * t, (j - 0.5) * t, t, t);
        if (fl == null) {
          box(
            c,
            dst.left,
            dst.top,
            t,
            t,
            aisleAt(i, j) ? 0xFFE8C94A : 0xFFDCCDAE,
          );
          continue;
        }
        final m =
            (aisleAt(i - 1, j - 1) ? 8 : 0) |
            (aisleAt(i, j - 1) ? 4 : 0) |
            (aisleAt(i - 1, j) ? 2 : 0) |
            (aisleAt(i, j) ? 1 : 0);
        final w = fl.width / 16;
        c.drawImageRect(
          fl,
          Rect.fromLTWH(w * m, 0, w, fl.height.toDouble()),
          dst,
          p,
        );
      }
    }
    c.restore();

    // 배치 중이면 들어갈 구역만 진하게
    for (var z = 0; z < 3; z++) {
      if (mode == 2 && placing != null && placing!.zone == z) {
        final r = _px(this.zoneRect(z));
        box(c, r.left, r.top, r.width, r.height, Cfg.zoneHot[z]);
      }
    }
    // 통로 화살표 (진행 방향 →)
    final arrow = Paint()..color = const Color(0x553A2E10);
    for (var x = a.left + 1.5; x < a.right - 0.5; x += 2) {
      final cx = x * t, cy = ai.center.dy * t;
      c.drawPath(
        Path()
          ..moveTo(cx - 6, cy - 9)
          ..lineTo(cx + 6, cy)
          ..lineTo(cx - 6, cy + 9)
          ..lineTo(cx - 6, cy + 4)
          ..lineTo(cx, cy)
          ..lineTo(cx - 6, cy - 4)
          ..close(),
        arrow,
      );
    }
    // 구역 경계: 바닥에 칠한 흰 점선 (통로는 끊김)
    final line = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 2;
    for (final zx in [Cfg.zoneX1, Cfg.zoneX2]) {
      for (var y = a.top + 0.2; y < a.bottom; y += 0.6) {
        if (y + 0.3 > ai.top && y < ai.bottom) continue;
        c.drawLine(Offset(zx * t, y * t), Offset(zx * t, (y + 0.3) * t), line);
      }
    }
    // 구역 간판 (번호 = 진행 순서)
    const names = ['① 접수', '② 분류·포장', '③ 보관'];
    for (var z = 0; z < 3; z++) {
      final r = _px(this.zoneRect(z));
      // 창고 윗벽 바깥에 걸린 간판 (안쪽 건물·수량표와 겹치지 않게)
      final tag = Rect.fromLTWH(
        r.left + 4,
        r.top - 26,
        names[z].length * 11.0 + 10,
        18,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(tag, const Radius.circular(4)),
        Paint()..color = Color(Cfg.zoneHot[z]).withValues(alpha: 0.95),
      );
      labelIn(c, names[z], tag, size: 11, color: const Color(0xFF2A2438));
    }

    // 벽: 두께 8px, 입구(왼쪽 벽의 통로 자리)와 도크 문(오른쪽 벽)은 뚫림
    const wall = 0xFF7A5C3A, cap = 0xFF9C7A52;
    box(c, ar.left - 4, ar.top - 4, ar.width + 8, 8, wall); // 위
    box(c, ar.left - 4, ar.top - 4, ar.width + 8, 3, cap);
    box(c, ar.left - 4, ar.bottom - 4, ar.width + 8, 8, wall); // 아래
    final door = _px(ai);
    box(c, ar.left - 4, ar.top, 8, door.top - ar.top, wall); // 왼쪽 (입구 위·아래)
    box(c, ar.left - 4, door.bottom, 8, ar.bottom - door.bottom, wall);
    final openings = <Rect>[
      door, // 통로 끝 (도크로 나가는 길)
      for (final d in ofType('dock')) _px(d.rect),
    ];
    var y = ar.top;
    final ys = <(double, double)>[];
    for (final o in openings..sort((p, q) => p.top.compareTo(q.top))) {
      ys.add((y, o.top));
      y = max(y, o.bottom);
    }
    ys.add((y, ar.bottom));
    for (final (y0, y1) in ys) {
      if (y1 > y0) box(c, ar.right - 4, y0, 8, y1 - y0, wall);
    }
    label(c, '입구', ar.left - 40, door.center.dy - 7, size: 12);
  }

  // ---------------- 건물 ----------------
  void _drawBuildings(Canvas c) {
    for (final b in buildings) {
      final r = _px(b.rect).deflate(1);
      final sp = Sprites.forBuilding(b.type.id);
      if (sp != null) {
        Sprites.drawFitBottom(
          c,
          sp,
          _px(_deskRect(b)).deflate(1),
          left: b.type.id == 'dock',
        );
      } else {
        box(c, r.left, r.top, r.width, r.height, b.type.color);
        strokeBox(c, r, 0xFF2A2438, 2);
        if (b.type.id != 'lounge') labelIn(c, b.type.name, r, size: 12);
      }

      if (b.level > 1) {
        box(c, r.left + 2, r.top + 2, 28, 13, 0xFFFFD166);
        labelIn(
          c,
          'Lv${b.level}',
          Rect.fromLTWH(r.left + 2, r.top + 2, 28, 13),
          size: 10,
          color: const Color(0xFF2A2438),
        );
      }

      // 직원이 필요한 건물: 배치가 없으면 빨강, 전원 휴식 중이면 주황
      if (b.mine) {
        box(c, r.left + 2, r.bottom - 16, 40, 14, 0xFF3FB27F);
        labelIn(
          c,
          '내 자리',
          Rect.fromLTWH(r.left + 2, r.bottom - 16, 40, 14),
          size: 10,
        );
      }
      // 배치된 직원이 없으면 건물 위쪽 바깥에 표시. (자리 비움은 직원 머리 위에 표시)
      if (b.type.slots > 0 && b.crew.isEmpty && !b.mine) {
        box(c, r.center.dx - 22, r.top - 17, 44, 15, 0xFFE5484D);
        labelIn(
          c,
          '직원 필요',
          Rect.fromLTWH(r.center.dx - 22, r.top - 17, 44, 15),
          size: 10,
        );
      }

      // 포장 실수 표시
      if (b.flash > 0) {
        box(c, r.left, r.top, r.width, r.height, 0x66E5484D);
        labelIn(c, '실수!', r, size: 13);
      }

      switch (b.type.id) {
        case 'counter':
          _drawStack(c, b);
          break;
        case 'pack':
          break; // 상자·진행 막대는 직원 뒤에 다시 그림 (_drawPackContent)
        case 'shelf':
          // 들어온 택배 수만큼 선반 칸에 상자가 쌓임 (아래 칸부터)
          // 들어온 택배 수만큼 선반 판 위에 상자가 쌓임 (아래 판부터). 수량 표시는 선반 위 빈칸에
          final sh = Sprites.forBuilding('shelf');
          if (sh != null && Sprites.boxS != null) {
            final d = Sprites.fitBottom(sh, r);
            final k = d.width / sh.width;
            const tierBase = [
              48.0,
              31.0,
              14.0,
            ]; // 각 판 위 상자 바닥 (그림 기준 픽셀, hub_shelf)
            const perTier = 4;
            final slots = (b.stored / b.cap * perTier * 3).ceil().clamp(
              0,
              perTier * 3,
            );
            for (var i = 0; i < slots; i++) {
              final tier = i ~/ perTier, col = i % perTier;
              Sprites.drawSmallBox(
                c,
                d.left + (7 + col * 12) * k,
                d.top + tierBase[tier] * k - 12,
              );
            }
          }
          final full = b.stored >= b.cap;
          final tag = Rect.fromLTWH(r.left + 6, r.top + 2, r.width - 12, 14);
          c.drawRRect(
            RRect.fromRectAndRadius(tag, const Radius.circular(4)),
            Paint()..color = const Color(0xCC2A2438),
          );
          box(
            c,
            tag.left + 2,
            tag.bottom - 4,
            (tag.width - 4) * (b.stored / b.cap).clamp(0.0, 1.0),
            2,
            full ? 0xFFE5484D : 0xFF7BD389,
          );
          labelIn(c, '${b.stored}/${b.cap}', tag.translate(0, -1), size: 10);
          break;
        case 'lounge':
          // 그림이 없을 때만 벤치를 그림 (그림에는 소파가 있음)
          if (sp == null) {
            for (final o in Cfg.loungeSeats) {
              _bench(
                c,
                Offset((b.tx + o.dx) * Cfg.tile, (b.ty + o.dy) * Cfg.tile),
              );
            }
            label(c, '휴게실', r.center.dx - 18, r.bottom - 15, size: 11);
          }
          break;
        case 'dock':
          // 그림이 없을 때만 셔터·주차선을 그림
          if (sp == null) {
            box(c, r.left, r.top + 8, 8, r.height - 16, 0xFFB0B0C0);
            for (var i = 1; i < 3; i++) {
              box(
                c,
                r.left + 14,
                r.top + i * r.height / 3 - 1,
                r.width - 22,
                2,
                0x55FFFFFF,
              );
            }
          }
          final v = b.vehicle;
          if (v != null) {
            final span = r.width - 22;
            final vw = span * v.type.len;
            final vh = (r.height - 6) * v.type.wid;
            final mv = (v.t / Cfg.vehicleMove).clamp(0.0, 1.0);
            final off = v.state == 0 ? 1 - mv : (v.state == 2 ? mv : 0.0);
            final vx = r.left + 14 + off * (Cfg.road.left - b.tx) * Cfg.tile;
            final vy = r.center.dy - vh / 2;
            final vimg = Sprites.vehicleImg(v.type.name);
            final ti = Sprites.dockTruck;
            if (ti != null) {
              // 새 도크 트럭: 1:1 크기, 짐칸 뒤(왼쪽)가 도크 문에 붙게
              final w = ti.width.toDouble(), h = ti.height.toDouble();
              final dst = Rect.fromLTWH(
                (r.left + 8 + off * (Cfg.road.left - b.tx) * Cfg.tile)
                    .roundToDouble(),
                (r.center.dy - h / 2).roundToDouble(),
                w,
                h,
              );
              final np = Paint()..filterQuality = FilterQuality.none;
              final src = Rect.fromLTWH(0, 0, w, h);
              c.drawImageRect(ti, src, dst, np);
              final full = Sprites.dockTruckFull;
              if (full != null && v.loaded > 0) {
                // 실은 만큼 짐칸을 운전석 쪽부터 상자로 채움
                const bed = Sprites.dockTruckBed;
                final frac = (v.loaded / v.cap).clamp(0.0, 1.0);
                c.save();
                c.clipRect(
                  Rect.fromLTRB(
                    dst.left + bed.right - bed.width * frac,
                    dst.top,
                    dst.left + bed.right,
                    dst.bottom,
                  ),
                );
                c.drawImageRect(full, src, dst, np);
                c.restore();
              }
              box(
                c,
                dst.left + 2,
                dst.top - 7,
                22,
                4,
                Cfg.regionColor[v.region],
              );
              labelIn(
                c,
                '${v.loaded}/${v.cap}',
                Rect.fromLTWH(dst.left + 26, dst.top - 13, 44, 14),
                size: 11,
                color: const Color(0xFFFFFFFF),
              );
            } else if (vimg != null) {
              final vr = Rect.fromLTWH(vx, vy, vw, vh);
              final drawn = Sprites.containRect(vimg, vr);
              final fimg = Sprites.vehicleFullImg(v.type.name);
              if (fimg != null && v.loaded >= v.cap * 0.6) {
                // 거의 찼으면 상자 가득 실린 그림 (빈 그림과 같은 배율, 바닥·오른쪽 맞춤)
                final k = drawn.width / vimg.width;
                final fw = fimg.width * k, fh = fimg.height * k;
                final dst = Rect.fromLTWH(
                  drawn.right - fw,
                  drawn.bottom - fh,
                  fw,
                  fh,
                );
                c.drawImageRect(
                  fimg,
                  Rect.fromLTWH(
                    0,
                    0,
                    fimg.width.toDouble(),
                    fimg.height.toDouble(),
                  ),
                  dst,
                  Paint()..filterQuality = FilterQuality.none,
                );
              } else {
                Sprites.drawContain(c, vimg, vr);
                // 싣은 만큼 짐칸에 상자가 쌓임
                Sprites.drawCargo(c, v.type.name, vimg, drawn, v.loaded, v.cap);
              }
              // 구역 색 띠 + 적재 현황 (차량 위쪽)
              box(
                c,
                drawn.left + 2,
                drawn.top - 7,
                22,
                4,
                Cfg.regionColor[v.region],
              );
              labelIn(
                c,
                '${v.loaded}/${v.cap}',
                Rect.fromLTWH(drawn.left + 26, drawn.top - 13, 44, 14),
                size: 11,
                color: const Color(0xFFFFFFFF),
              );
            } else {
              box(c, vx, vy, vw, vh, Cfg.regionColor[v.region]);
              box(c, vx + vw - vw * 0.25, vy, vw * 0.25, vh, 0xFF3D4466); // 운전석
              strokeBox(c, Rect.fromLTWH(vx, vy, vw, vh), 0xFF2A2438, 2);
              labelIn(
                c,
                '${v.loaded}/${v.cap}',
                Rect.fromLTWH(vx, vy, vw * 0.75, vh),
                size: 11,
                color: const Color(0xFF2A2438),
              );
            }
          }
          break;
      }
      if (b == selected) strokeBox(c, r.inflate(2), 0xFFFFD166, 3);
    }
  }

  void _person(
    Canvas c,
    Offset p,
    String initial,
    int fill,
    int stroke, {
    bool tired = false,
    double energy = 1.0,
    Object? key,
    bool work = false,
    double workHz = 7,
  }) {
    const t = Cfg.tile;
    if (Sprites.staffWalk != null) {
      final f = _faces.putIfAbsent(key ?? initial, () => _Face(p));
      final dx = p.dx - f.last.dx, dy = p.dy - f.last.dy;
      final moved = dx * dx + dy * dy > 0.9;
      if (moved) {
        f.dir = dx.abs() > dy.abs() ? (dx < 0 ? 1 : 2) : (dy < 0 ? 3 : 0);
        f.until = clock + 0.15;
      }
      if (!moved && clock > f.until + 0.3) f.dir = 0; // 멈춰 있으면 정면(남쪽)을 봄
      f.last = p;
      Sprites.drawStaff(
        c,
        p.dx,
        p.dy + t * 0.35,
        f.dir,
        clock < f.until,
        clock,
        look: key is Staff ? key.id : 0,
        work: work,
        workHz: workHz,
      );
      if (tired) {
        label(
          c,
          'Zz',
          p.dx + t * 0.18,
          p.dy - t * 0.7,
          size: 11,
          color: const Color(0xFF8EC5FF),
        );
      }
      if (energy < 0.98) {
        box(c, p.dx - 12, p.dy + t * 0.42, 24, 3, 0xFF2A2438);
        box(
          c,
          p.dx - 12,
          p.dy + t * 0.42,
          24 * energy.clamp(0.0, 1.0),
          3,
          energy >= 0.6
              ? 0xFF7BD389
              : (energy >= 0.3 ? 0xFFF0963A : 0xFFE5484D),
        );
      }
      return;
    }
    c.drawCircle(p, t * 0.3, Paint()..color = Color(fill));
    c.drawCircle(
      p,
      t * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color(stroke),
    );
    labelIn(
      c,
      initial,
      Rect.fromCircle(center: p, radius: t * 0.3),
      size: 12,
      color: const Color(0xFF2A2438),
    );
    if (tired) {
      label(
        c,
        'Zz',
        p.dx + t * 0.18,
        p.dy - t * 0.62,
        size: 11,
        color: const Color(0xFF8EC5FF),
      );
    }
    // 컨디션 막대 (가득 차 있을 땐 숨김)
    if (energy < 0.98) {
      box(c, p.dx - 12, p.dy + t * 0.34, 24, 3, 0xFF2A2438);
      box(
        c,
        p.dx - 12,
        p.dy + t * 0.34,
        24 * energy.clamp(0.0, 1.0),
        3,
        energy >= 0.6 ? 0xFF7BD389 : (energy >= 0.3 ? 0xFFF0963A : 0xFFE5484D),
      );
    }
  }

  /// 길을 오가는 행인 (보기용). 시간만으로 위치가 정해지는 왕복 경로.
  static final List<List<Offset>> _walkRoutes = [
    // 윗길(가로) → 왼쪽 길(세로) → 아랫길(가로)
    [
      Offset(Cfg.road.left - 1, 6.6),
      Offset(1, 6.6),
      Offset(1, 29.4),
      Offset(Cfg.road.left - 1, 29.4),
    ],
    // 오른쪽 인도(세로)
    [Offset(Cfg.road.right + 0.5, 1.5), Offset(Cfg.road.right + 0.5, 34.5)],
  ];
  static const List<List<double>> _walkers = [
    // [경로, 위상(칸), 속도(칸/초), 방향(+1/-1), 외형]
    [0, 0, 1.1, 1, 0],
    [0, 17, 0.9, -1, 1],
    [0, 33, 1.3, 1, 2],
    [0, 50, 1.0, -1, 3],
    [0, 66, 1.2, 1, 4],
    [1, 0, 1.0, 1, 5],
    [1, 20, 1.2, -1, 2],
    [1, 40, 0.9, 1, 0],
  ];

  void _drawPedestrians(Canvas c) {
    const t = Cfg.tile;
    if (Sprites.staffWalk == null) return;
    final list = <(double, Offset, int, bool, int)>[];
    for (final w in _walkers) {
      final route = _walkRoutes[w[0].toInt()];
      final seg = <double>[];
      var total = 0.0;
      for (var i = 0; i + 1 < route.length; i++) {
        final d = (route[i + 1] - route[i]).distance;
        seg.add(d);
        total += d;
      }
      // 왕복: 0..2*total 를 오가며 위치를 구함
      var u = (w[1] + w[2] * clock * w[3]) % (2 * total);
      if (u < 0) u += 2 * total;
      final back = u > total;
      final d = back ? 2 * total - u : u;
      var acc = 0.0;
      var pos = route.last;
      var dir = 0;
      for (var i = 0; i < seg.length; i++) {
        if (d <= acc + seg[i] || i == seg.length - 1) {
          final a = route[i], b = route[i + 1];
          final k = ((d - acc) / seg[i]).clamp(0.0, 1.0);
          pos = Offset(a.dx + (b.dx - a.dx) * k, a.dy + (b.dy - a.dy) * k);
          var v = b - a;
          if (back) v = -v;
          if (w[3] < 0) v = -v;
          dir = v.dx.abs() > v.dy.abs()
              ? (v.dx < 0 ? 1 : 2)
              : (v.dy < 0 ? 3 : 0);
          break;
        }
        acc += seg[i];
      }
      list.add((pos.dy, pos, dir, true, w[4].toInt()));
    }
    list.sort((a, b) => a.$1.compareTo(b.$1));
    for (final e in list) {
      Sprites.drawPerson(c, e.$2.dx * t, e.$2.dy * t, e.$3, true, clock, e.$5);
    }
  }

  /// 벤치. 발 위치(p) 기준 가운데. front=true면 아래쪽 절반만 다시 그림(앉은 모습).
  void _bench(Canvas c, Offset p, {bool front = false}) {
    final img = Sprites.decor['bench'];
    if (img == null) {
      if (!front) box(c, p.dx - 18, p.dy - 4, 36, 10, 0xFF8B5E3C);
      return;
    }
    const k = 1.5;
    final w = img.width * k, h = img.height * k;
    final dst = Rect.fromLTWH(p.dx - w / 2, p.dy + 9 - h, w, h);
    if (front) {
      c.save();
      c.clipRect(
        Rect.fromLTRB(dst.left, dst.top + h * 9 / 21, dst.right, dst.bottom),
      ); // 좌판·다리만 사람 앞에
    }
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
    if (front) c.restore();
  }

  /// 건물 그림이 들어가는 칸. 접수 창구는 왼쪽 2칸이 책상, 오른쪽 1칸은 적재대
  Rect _deskRect(Building b) => b.type.id == 'counter'
      ? Rect.fromLTWH(b.tx.toDouble(), b.ty.toDouble(), 2, b.type.h.toDouble())
      : b.rect;

  /// 접수 창구 오른쪽 칸: 팔레트 위에 상자를 격자로 쌓는다 (아래 층 왼쪽부터, 집어 가면 맨 위부터 줄어듦)
  void _drawStack(Canvas c, Building b) {
    const t = Cfg.tile;
    final cell = Rect.fromLTWH(
      (b.tx + b.type.w - 1) * t,
      b.ty * t,
      t,
      b.type.h * t,
    );
    // 보이는 상자 수가 실제 수를 부드럽게 따라감
    final n = b.outbox.length;
    final dt = (clock - _stackClock).clamp(0.0, 0.1);
    if (b.stackVis < n) {
      b.stackVis = min(n.toDouble(), b.stackVis + dt * Cfg.stackAnim);
    } else if (b.stackVis > n) {
      b.stackVis = max(n.toDouble(), b.stackVis - dt * Cfg.stackAnim);
    }
    // 나무 팔레트 (바닥에 붙음): 윗판 + 앞면 받침 3개
    final px0 = cell.left + 2, pw = t - 4, pBot = cell.bottom - 4;
    box(c, px0, pBot - 11, pw, 7, 0xFFC8955E); // 윗판
    for (var k = 1; k < 4; k++) {
      box(c, px0, pBot - 11 + k * 2 - 1, pw, 1, 0xFF9A6A3C); // 판 사이 틈
    }
    box(c, px0, pBot - 4, pw, 4, 0xFF7A5230); // 앞면
    for (final bxx in [px0, px0 + pw / 2 - 2, px0 + pw - 4]) {
      box(c, bxx, pBot - 4, 4, 4, 0xFFB07B47); // 받침 기둥
    }
    strokeBox(c, Rect.fromLTWH(px0, pBot - 11, pw, 11), 0xFF4A3020, 1);
    final bx = Sprites.boxS;
    const side = 12.0;
    final baseY = pBot - 5; // 1층 상자 바닥 (윗판 앞쪽)
    final full = b.stackVis.floor();
    final frac = b.stackVis - full;
    final shown = frac > 0.01 ? full + 1 : full;
    for (var i = 0; i < shown && i < Cfg.stackCols * Cfg.stackLayers; i++) {
      final layer = i ~/ Cfg.stackCols, col = i % Cfg.stackCols;
      final top = i == full; // 올라오는 중이거나 사라지는 중인 맨 위 상자
      final lift = top ? (1 - frac) * 8 : 0.0;
      final x = cell.left + 4 + col * side;
      final y = baseY - side - layer * Cfg.stackStep - lift;
      final region = i < n ? b.outbox[i].region : b.stackGhost;
      final alpha = top ? frac : 1.0;
      if (bx != null) {
        c.drawImageRect(
          bx,
          Rect.fromLTWH(0, 0, bx.width.toDouble(), bx.height.toDouble()),
          Rect.fromLTWH(x, y, side, side),
          Paint()
            ..filterQuality = FilterQuality.none
            ..color = Color.fromRGBO(255, 255, 255, alpha),
        );
      } else {
        box(c, x, y, side - 1, side - 1, 0xFFB8865A);
      }
      // 지역 색 스티커 (앞면 가운데)
      c.drawRect(
        Rect.fromLTWH(x + 4, y + 6, 4, 3),
        Paint()
          ..color = Color(Cfg.regionColor[region]).withValues(alpha: alpha),
      );
      if (i < n && b.outbox[i].kind > 0) {
        c.drawRect(
          Rect.fromLTWH(x + 9, y + 3, 2, 2),
          Paint()..color = const Color(0xFFFF3B30),
        );
      }
    }
    // 가득 차면 적재대 위에 표시
    if (n >= b.outCap) {
      final layers = (n + Cfg.stackCols - 1) ~/ Cfg.stackCols;
      final tag = Rect.fromLTWH(
        cell.left + 2,
        baseY - side - (layers - 1) * Cfg.stackStep - 14,
        t - 4,
        12,
      );
      box(c, tag.left, tag.top, tag.width, tag.height, 0xEEE5484D);
      labelIn(c, '가득', tag, size: 9);
    }
  }

  /// 손님 사연 말풍선: 머리 오른쪽 옆 (줄 선 손님끼리 위아래로 겹치지 않게). 탭하면 미리 처리.
  void _storyBubble(Canvas c, Customer cu, Offset p) {
    const t = Cfg.tile;
    final s = Cfg.stories[cu.story];
    final text = cu.pre ? '고마워요!' : s.$1;
    final w = textWidth(text, 10) + 10;
    final r = Rect.fromLTWH(p.dx + 9, p.dy - t * 0.95, w, 15);
    final col = Color(cu.pre ? 0xFFE6F4EA : Cfg.storyColor[s.$2]);
    // 꼬리 (머리 쪽)
    c.drawPath(
      Path()
        ..moveTo(r.left + 2, r.bottom - 5)
        ..lineTo(r.left - 4, r.bottom + 2)
        ..lineTo(r.left + 7, r.bottom - 1)
        ..close(),
      Paint()..color = col,
    );
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    c.drawRRect(rr, Paint()..color = col);
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF2A2438),
    );
    labelIn(c, text, r, size: 10, color: const Color(0xFF2A2438));
    if (!cu.pre) cu.bubble = r;
  }

  /// 창구·포장대에서 직원이 서는 자리 (건물 왼쪽 위 기준, 칸). 책상 그림 뒤쪽, 칸 안.
  List<Offset> _spots(Building b) {
    final w = _deskRect(b).width, h = b.type.h.toDouble();
    final sp = Sprites.forBuilding(b.type.id);
    // 책상 윗면 뒤쪽 = 그림 위 끝에서 조금 아래
    final topY = sp == null ? 0.1 : h - sp.height / Cfg.tile + 0.25;
    return [Offset(w - 0.5, topY), Offset(0.5, topY)];
  }

  /// 포장대 위 상자(가운데)와 진행 막대. 직원·책상 앞면 위에 그린다.
  void _drawPackContent(Canvas c, Building b) {
    final p = b.slot;
    if (p == null) return;
    final r0 = _px(b.rect).deflate(1);
    final sp = Sprites.forBuilding('pack');
    // 상자는 책상 윗면 가운데에 놓이도록 (그림이 있으면 그림 위 끝 기준)
    final r = sp == null
        ? r0
        : Rect.fromLTRB(
            r0.left,
            Sprites.fitBottom(sp, r0).top - 6,
            r0.right,
            r0.bottom,
          );
    final dyn = Sprites.packEmpty != null || Sprites.boxOpen != null;
    final prog = (b.progress / Cfg.packTime).clamp(0.0, 1.0);
    if (p.stage == 3) {
      final rr = Rect.fromLTWH(r.center.dx - 10, r.top + 1, 20, 20);
      if (!Sprites.drawBox(c, rr, Cfg.regionColor[p.region])) {
        box(
          c,
          r.center.dx - 7,
          r.bottom - 20,
          14,
          14,
          Cfg.regionColor[p.region],
        );
      }
    } else {
      if (dyn && p.stage == 2 && Sprites.boxOpen != null) {
        final k = (0.45 + prog * 6).clamp(0.45, 1.0);
        final w = 20 * k, h = 20 * k;
        // 포장 중엔 상자가 살짝 들썩임
        final live = b.active.isNotEmpty; // 직원이 자리에 없으면 작업이 멈춘 상태
        final jx = live ? sin(clock * 22) * 0.8 * k : 0.0;
        final jy = live ? (sin(clock * 14) * 0.5 + 0.5) * -1.2 : 0.0;
        final br = Rect.fromLTWH(
          r.center.dx - w / 2 + jx,
          r.top + 21 - h + jy,
          w,
          h,
        );
        Sprites.drawContain(c, Sprites.boxOpen!, br);
        // 테이프가 위로 붙어 나가는 선 (진행도만큼)
        if (prog > 0.35) {
          final tp = ((prog - 0.35) / 0.65).clamp(0.0, 1.0);
          box(c, br.left + 2, br.top + h * 0.28, (w - 4) * tp, 2.5, 0xFFE8C98A);
        }
        // 작업 먼지/반짝임
        for (var i = 0; i < (live ? 3 : 0); i++) {
          final ph = (clock * 3 + i * 0.37) % 1.0;
          final sx = br.center.dx + (i - 1) * 9 + sin(i * 5 + clock * 4) * 3;
          box(
            c,
            sx,
            br.top + 4 - ph * 9,
            2,
            2,
            ph < 0.8 ? 0xFFFFF3C4 : 0x00FFFFFF,
          );
        }
      }
      box(c, r.left + 4, r.bottom - 10, r.width - 8, 6, 0xFF2A2438);
      box(c, r.left + 4, r.bottom - 10, (r.width - 8) * prog, 6, 0xFFFFD166);
    }
  }

  // ---------------- 사람 (직원·손님) ----------------
  void _drawPeople(Canvas c) {
    const t = Cfg.tile;

    _drawPedestrians(c);

    // 창고 밖 휴식 자리 (벤치)
    final bs = breakSpot;
    final bsPos = Offset(bs.dx * t, bs.dy * t);
    _bench(c, bsPos);
    label(c, '휴식', bs.dx * t - 12, bs.dy * t + 14, size: 11);

    // 자리를 비운 직원 (쉬러 가는 중·쉬는 중·돌아오는 중)
    for (final s in staff) {
      if (!s.away) continue;
      var p = Offset(s.pos.dx * t, s.pos.dy * t);
      if (s.carrier) {
        _person(
          c,
          p,
          s.initial,
          0xFF8EC5FF,
          0xFFFFFFFF,
          tired: true,
          energy: s.energyPct,
          key: s,
        );
      } else if (s.post?.type.id == 'counter') {
        _person(
          c,
          p,
          s.initial,
          0xFFFFE0B2,
          0xFF8B4A00,
          tired: true,
          energy: s.energyPct,
          key: s,
        );
      } else {
        _person(
          c,
          p,
          s.initial,
          0xFFB9F6CA,
          0xFF1B5E20,
          tired: true,
          energy: s.energyPct,
          key: s,
        );
      }
    }

    // 접수 직원: 창구 뒤(위)에 서 있음. 자리에 있는 직원만 표시.
    for (final b in ofType('counter')) {
      final working = customers.any(
        (cu) => cu.counter == b && cu.state != 2 && cu.serveT > 0,
      );
      final spots = _spots(b);
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        const bob = 0.0;
        final p = Offset(
          (b.tx + spots[i].dx) * t,
          (b.ty + spots[i].dy) * t + bob,
        );
        _person(
          c,
          p,
          act[i].initial,
          0xFFFFE0B2,
          0xFF8B4A00,
          tired: act[i].tired,
          energy: act[i].energyPct,
          key: act[i],
          work: working,
          workHz: 9,
        ); // 접수: 타이핑처럼 빠르고 작게
      }
    }

    // 포장 직원: 포장대 안쪽. 자리에 있는 직원만 표시.
    for (final b in ofType('pack')) {
      final working = b.slot != null && b.slot!.stage == 2;
      final spots = _spots(b);
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        const bob = 0.0;
        final p = Offset(
          (b.tx + spots[i].dx) * t,
          (b.ty + spots[i].dy) * t + bob,
        );
        _person(
          c,
          p,
          act[i].initial,
          0xFFB9F6CA,
          0xFF1B5E20,
          tired: act[i].tired,
          energy: act[i].energyPct,
          key: act[i],
          work: working,
          workHz: 7,
        );
      }
    }

    // 책상 앞면을 직원 위에 다시 그려서 '책상 뒤에 서 있는' 모습으로
    for (final id in const ['counter', 'pack']) {
      for (final b in ofType(id)) {
        if (b.active.isEmpty) continue;
        final sp = Sprites.forBuilding(id);
        if (sp == null) continue;
        final r = _px(_deskRect(b)).deflate(1);
        final d = Sprites.fitBottom(sp, r);
        // 책상(윗면 뒤 끝 아래부터)을 다시 그려 직원 다리를 가림
        c.save();
        c.clipRect(
          Rect.fromLTRB(d.left, d.top + d.height * 0.22, d.right, d.bottom),
        );
        Sprites.drawFitBottom(c, sp, r);
        c.restore();
      }
    }
    for (final b in ofType('pack')) {
      _drawPackContent(c, b);
    }

    // 자리 비움 표시: 쉬러 간 직원을 따라가지 않고, 그 직원이 서 있던 자리(머리 위)에 표시
    for (final b in [...ofType('counter'), ...ofType('pack')]) {
      final spots = _spots(b);
      // 자리에 있는 직원이 앞 칸을 쓰므로, 빈자리는 그 다음 칸부터
      final here = b.active.length;
      final awayN = b.crew.where((s) => s.away).length;
      for (var k = 0; k < awayN; k++) {
        final i = here + k;
        if (i >= spots.length) break;
        final sx = (b.tx + spots[i].dx) * t, sy = (b.ty + spots[i].dy) * t;
        final bub = Rect.fromLTWH(sx - 24, sy - 50, 48, 14);
        box(c, bub.left, bub.top, bub.width, bub.height, 0xFFD98B2B);
        labelIn(c, '자리 비움', bub, size: 10);
      }
    }

    // 앉아서 쉬는 직원: 벤치 앞쪽을 다시 그려 '앉은' 느낌
    var sitAtBreak = false;
    for (final s in staff) {
      if (!s.away || s.rest != 2) continue;
      final l = s.lounge;
      if (l == null) {
        sitAtBreak = true;
      } else {
        final o = Cfg.loungeSeats[s.seat];
        _bench(c, Offset((l.tx + o.dx) * t, (l.ty + o.dy) * t), front: true);
      }
    }
    if (sitAtBreak) {
      _bench(c, Offset(breakSpot.dx * t, breakSpot.dy * t), front: true);
    }

    // 손님
    for (final cu in customers) {
      final p = Offset(cu.pos.dx * t, cu.pos.dy * t);
      if (Sprites.staffWalk != null) {
        final f = _faces.putIfAbsent(cu, () => _Face(p));
        final dx = p.dx - f.last.dx, dy = p.dy - f.last.dy;
        final moved = dx * dx + dy * dy > 0.9;
        if (moved) {
          f.dir = dx.abs() > dy.abs() ? (dx < 0 ? 1 : 2) : (dy < 0 ? 3 : 0);
          f.until = clock + 0.15;
        }
        if (!moved && clock > f.until + 0.3) f.dir = 3; // 서서 기다릴 땐 창구(위)를 봄
        f.last = p;
        Sprites.drawPerson(
          c,
          p.dx,
          p.dy + t * 0.35,
          f.dir,
          clock < f.until,
          clock,
          cu.look,
        );
      } else {
        c.drawCircle(p, t * 0.28, Paint()..color = const Color(0xFFE8B07A));
        c.drawCircle(
          p,
          t * 0.28,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF2A2438),
        );
        box(c, p.dx - 4, p.dy - t * 0.5, 8, 8, Cfg.regionColor[cu.region]);
      }
      if (cu.vip) {
        c.drawCircle(
          p,
          t * 0.34,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFFFD166),
        );
      }
      if (cu.kind > 0 && cu.state != 2) {
        label(
          c,
          Cfg.kindName[cu.kind],
          p.dx -
              9 -
              textWidth(Cfg.kindName[cu.kind], 10), // 머리 왼쪽 (오른쪽은 사연 말풍선)
          p.dy - t * 0.62,
          size: 10,
          color: const Color(0xFFFF8A80),
        );
      }
      if (cu.state != 2 && cu.ready) {
        // 내 자리 맨 앞 손님: 눌러 달라는 말풍선 (살짝 깜빡임)
        final pulse = 0.5 + 0.5 * sin(clock * 8);
        // 머리 왼쪽 (오른쪽은 사연 말풍선)
        final bubble = Rect.fromLTWH(p.dx - 44, p.dy - t * 0.95, 34, 15);
        box(
          c,
          bubble.left,
          bubble.top,
          bubble.width,
          bubble.height,
          pulse > 0.5 ? 0xFFFFD166 : 0xFFF0963A,
        );
        labelIn(c, '탭!', bubble, size: 11, color: const Color(0xFF2A2438));
      } else if (cu.state != 2 && cu.patience / Cfg.patience < Cfg.alertAngry) {
        label(
          c,
          '!',
          p.dx - 3,
          p.dy - t * 0.98,
          size: 14,
          color: const Color(0xFFE5484D),
        );
      }
      cu.bubble = null;
      if (cu.state != 2 && cu.story >= 0) _storyBubble(c, cu, p);
      if (cu.state != 2) {
        final ratio = (cu.patience / Cfg.patience).clamp(0.0, 1.0);
        box(c, p.dx - 12, p.dy + t * 0.34, 24, 3, 0xFF2A2438);
        box(
          c,
          p.dx - 12,
          p.dy + t * 0.34,
          24 * ratio,
          3,
          ratio > 0.4 ? 0xFF7BD389 : 0xFFE5484D,
        );
      }
    }

    // 떠오르는 글 (사연 보너스)
    hubFx.removeWhere((f) => clock - f.$4 > 1.4);
    for (final f in hubFx) {
      final k = (clock - f.$4) / 1.4;
      final r = Rect.fromCenter(
        center: f.$1.translate(0, -8 - k * 22),
        width: 70,
        height: 16,
      );
      labelIn(
        c,
        f.$2,
        r.translate(1, 1),
        size: 11,
        color: Color.fromRGBO(0, 0, 0, 1 - k),
      );
      labelIn(
        c,
        f.$2,
        r,
        size: 11,
        color: Color(f.$3).withValues(alpha: 1 - k),
      );
    }

    // 운반 직원 (쉬러 간 직원은 위에서 따로 그림)
    for (final w in carriers) {
      if (w.staff.away) continue;
      final p = Offset(w.pos.dx * t, w.pos.dy * t);
      final carrying = w.carrying && w.job != null;
      final dir = _faces[w.staff]?.dir ?? 0; // 0 남, 1 서, 2 동, 3 북
      void carried() {
        // 상자를 가슴 앞에 안고 있는 모습 (머리 위가 아님)
        final cx = p.dx + (dir == 1 ? -9 : (dir == 2 ? 9 : 0));
        final cy = p.dy + (dir == 0 ? 3 : 0);
        final r = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 17,
          height: 17,
        );
        if (!Sprites.drawBox(c, r, Cfg.regionColor[w.job!.region])) {
          box(
            c,
            r.left,
            r.top,
            r.width,
            r.height,
            Cfg.regionColor[w.job!.region],
          );
          strokeBox(c, r, 0xFF2A2438, 1.5);
        }
      }

      if (carrying && dir == 3) carried(); // 뒤돌아 걸을 땐 몸에 가려지게 먼저
      _person(
        c,
        p,
        w.staff.initial,
        0xFF8EC5FF,
        0xFFFFFFFF,
        tired: w.staff.tired,
        energy: w.staff.energyPct,
        key: w.staff,
      );
      if (carrying && dir != 3) carried();
    }
  }
}

class _Face {
  Offset last;
  int dir = 0;
  double until = 0;
  _Face(this.last);
}

final Map<Object, _Face> _faces = {};
double _stackClock = 0; // 지난 프레임 시각 (적재대 연출용)
