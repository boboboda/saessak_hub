import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'draw_utils.dart';

/// 게임 맵(캔버스). 메뉴·패널은 위젯이 따로 그림.
extension WorldView on HubGame {
  Rect _px(Rect r) => Rect.fromLTWH(r.left * Cfg.tile, r.top * Cfg.tile,
      r.width * Cfg.tile, r.height * Cfg.tile);

  void renderWorld(Canvas c) {
    const t = Cfg.tile;
    box(c, 0, 0, size.x, size.y, 0xFF2A2438);

    c.save();
    c.translate(-cam.dx, -cam.dy);

    // 잔디
    box(c, 0, 0, Cfg.cols * t, Cfg.rows * t, 0xFF6FAE5B);
    final x0 = max(0, (cam.dx / t).floor());
    final x1 = min(Cfg.cols, ((cam.dx + size.x) / t).ceil());
    final y0 = max(0, (cam.dy / t).floor());
    final y1 = min(Cfg.rows, ((cam.dy + size.y) / t).ceil());
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if ((x + y) % 2 == 0) box(c, x * t, y * t, t, t, 0xFF69A857);
      }
    }

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
  }

  // ---------------- 도로 + 도크 마당 (창고 오른쪽 벽 바깥) ----------------
  void _drawRoadAndYard(Canvas c) {
    const t = Cfg.tile;

    // 도로
    final rd = _px(Cfg.road);
    box(c, rd.left, rd.top, rd.width, rd.height, 0xFF3A3A48);
    for (var y = 0; y < Cfg.rows; y++) {
      box(c, rd.center.dx - 2, y * t + 8, 4, t - 16, 0xFFFFD166);
    }
    label(c, '도로', rd.left + 8, area.top * t, size: 12);
    label(c, '→ 운송', rd.left + 4, area.top * t + 16, size: 11);

    // 도크 마당 바닥
    final y = Cfg.yard;
    for (var ty = y.top.toInt(); ty < y.bottom.toInt(); ty++) {
      for (var tx = y.left.toInt(); tx < y.right.toInt(); tx++) {
        box(c, tx * t, ty * t, t, t,
            (tx + ty) % 2 == 0 ? 0xFF55556A : 0xFF4D4D62);
      }
    }
    // 도크를 고르면 마당이 강조됨
    if (mode == 2 && placing != null && placing!.zone == 3) {
      final r = _px(y);
      box(c, r.left, r.top, r.width, r.height, Cfg.zoneHot[3]);
    }
    strokeBox(c, _px(y), 0xFF2A2438, 3);
    label(c, Cfg.zoneName[3], y.left * t + 8, y.top * t + 6, size: 12);
  }

  // ---------------- 창고 건물 ----------------
  void _drawWarehouse(Canvas c) {
    const t = Cfg.tile;

    // 확장 미리보기 (현재 창고 아래에 깔림)
    if (mode == 3 && canExpand) {
      final n = Cfg.areas[areaLevel + 1];
      final r = _px(n);
      box(c, r.left, r.top, r.width, r.height, 0x663B82D6);
      strokeBox(c, r, 0xFF3B82D6, 3);
      label(c, '확장 후 ${n.width.toInt()}×${n.height.toInt()}칸', r.left + 6,
          r.top + 6, size: 12);
    }

    // 창고 바닥
    final a = area;
    for (var y = a.top.toInt(); y < a.bottom.toInt(); y++) {
      for (var x = a.left.toInt(); x < a.right.toInt(); x++) {
        box(c, x * t, y * t, t, t,
            (x + y) % 2 == 0 ? 0xFFE3D5B8 : 0xFFDCCDAE);
      }
    }

    // 구역 색 + 이름 (건물을 고르면 들어갈 구역이 진하게)
    for (var z = 0; z < 3; z++) {
      final r = _px(this.zoneRect(z));
      final hot = mode == 2 && placing != null && placing!.zone == z;
      box(c, r.left, r.top, r.width, r.height,
          hot ? Cfg.zoneHot[z] : Cfg.zoneTint[z]);
      label(c, Cfg.zoneName[z], r.left + 6, r.top + 5,
          size: 12, color: const Color(0xFF5A3A28));
    }
    final line = Paint()
      ..color = const Color(0xAA7A5C3A)
      ..strokeWidth = 2;
    c.drawLine(Offset(Cfg.zoneX1 * t, a.top * t),
        Offset(Cfg.zoneX1 * t, a.bottom * t), line);
    c.drawLine(Offset(Cfg.zoneX2 * t, a.top * t),
        Offset(Cfg.zoneX2 * t, a.bottom * t), line);

    // 벽 (오른쪽 벽은 두껍게: 도크가 붙는 벽)
    strokeBox(c, _px(a), 0xFF7A5C3A, 4);
    box(c, Cfg.wallX * t - 4, a.top * t, 8, a.height * t, 0xFF7A5C3A);

    // 입구 (왼쪽 벽 가운데)
    box(c, a.left * t - 4, (a.center.dy - 0.7) * t, 8, 1.4 * t, 0xFF8B5E3C);
    label(c, '입구', a.left * t - 38, a.center.dy * t - 7, size: 12);
  }

  // ---------------- 건물 ----------------
  void _drawBuildings(Canvas c) {
    for (final b in buildings) {
      final r = _px(b.rect).deflate(1);
      box(c, r.left, r.top, r.width, r.height, b.type.color);
      strokeBox(c, r, 0xFF2A2438, 2);
      labelIn(c, b.type.name, r, size: 12);

      // 직원이 필요한 건물: 배치가 없으면 빨강, 전원 휴식 중이면 주황
      if (b.mine) {
        box(c, r.left + 2, r.bottom - 16, 40, 14, 0xFF3FB27F);
        labelIn(c, '내 자리', Rect.fromLTWH(r.left + 2, r.bottom - 16, 40, 14),
            size: 10);
      }
      if (b.type.slots > 0 && b.active.isEmpty && !(b.mine && b.crew.isEmpty)) {
        final none = b.crew.isEmpty;
        box(c, r.right - 46, r.top + 2, 44, 15, none ? 0xFFE5484D : 0xFFD98B2B);
        labelIn(c, none ? '직원 필요' : '자리 비움',
            Rect.fromLTWH(r.right - 46, r.top + 2, 44, 15), size: 10);
      }

      // 포장 실수 표시
      if (b.flash > 0) {
        box(c, r.left, r.top, r.width, r.height, 0x66E5484D);
        labelIn(c, '실수!', r, size: 13);
      }

      switch (b.type.id) {
        case 'counter':
        // 대기 중인 택배는 창구 안쪽 위에 작은 상자로
          for (var i = 0; i < b.outbox.length; i++) {
            box(c, r.left + 4 + i * 11, r.top + 3, 9, 9,
                Cfg.regionColor[b.outbox[i].region]);
          }
          break;
        case 'pack':
          final p = b.slot;
          if (p != null) {
            if (p.stage == 3) {
              box(c, r.center.dx - 7, r.bottom - 20, 14, 14,
                  Cfg.regionColor[p.region]);
            } else {
              box(c, r.left + 4, r.bottom - 10, r.width - 8, 6, 0xFF2A2438);
              box(c, r.left + 4, r.bottom - 10,
                  (r.width - 8) * (b.progress / Cfg.packTime).clamp(0.0, 1.0),
                  6, 0xFFFFD166);
            }
          }
          break;
        case 'shelf':
          box(c, r.left + 4, r.bottom - 10, r.width - 8, 6, 0xFF2A2438);
          box(c, r.left + 4, r.bottom - 10,
              (r.width - 8) * (b.stored / Cfg.shelfCap).clamp(0.0, 1.0), 6,
              b.stored >= Cfg.shelfCap ? 0xFFE5484D : 0xFF7BD389);
          label(c, '${b.stored}/${Cfg.shelfCap}', r.left + 5, r.bottom - 26,
              size: 11);
          break;
        case 'lounge':
          final n = staff.where((s) => s.rest == 2 && s.lounge == b).length;
          label(c, '쉬는 중 $n/${Cfg.loungeSeats.length}', r.left + 5,
              r.bottom - 16,
              size: 10);
          break;
        case 'dock':
        // 벽 쪽에 셔터, 바깥쪽에 주차선
          box(c, r.left, r.top + 8, 8, r.height - 16, 0xFFB0B0C0);
          for (var i = 1; i < 3; i++) {
            box(c, r.left + 14, r.top + i * r.height / 3 - 1, r.width - 22, 2,
                0x55FFFFFF);
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
            box(c, vx, vy, vw, vh, Cfg.regionColor[v.region]);
            box(c, vx + vw - vw * 0.25, vy, vw * 0.25, vh, 0xFF3D4466); // 운전석
            strokeBox(c, Rect.fromLTWH(vx, vy, vw, vh), 0xFF2A2438, 2);
            labelIn(c, '${v.loaded}/${v.type.cap}',
                Rect.fromLTWH(vx, vy, vw * 0.75, vh),
                size: 11, color: const Color(0xFF2A2438));
          }
          break;
      }
      if (b == selected) strokeBox(c, r.inflate(2), 0xFFFFD166, 3);
    }
  }

  void _person(Canvas c, Offset p, String initial, int fill, int stroke,
      {bool tired = false, double energy = 1.0}) {
    const t = Cfg.tile;
    c.drawCircle(p, t * 0.3, Paint()..color = Color(fill));
    c.drawCircle(
        p,
        t * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color(stroke));
    labelIn(c, initial, Rect.fromCircle(center: p, radius: t * 0.3),
        size: 12, color: const Color(0xFF2A2438));
    if (tired) {
      label(c, 'Zz', p.dx + t * 0.18, p.dy - t * 0.62,
          size: 11, color: const Color(0xFF8EC5FF));
    }
    // 컨디션 막대 (가득 차 있을 땐 숨김)
    if (energy < 0.98) {
      box(c, p.dx - 12, p.dy + t * 0.34, 24, 3, 0xFF2A2438);
      box(c, p.dx - 12, p.dy + t * 0.34, 24 * energy.clamp(0.0, 1.0), 3,
          energy >= 0.6
              ? 0xFF7BD389
              : (energy >= 0.3 ? 0xFFF0963A : 0xFFE5484D));
    }
  }

  // ---------------- 사람 (직원·손님) ----------------
  void _drawPeople(Canvas c) {
    const t = Cfg.tile;

    // 창고 밖 휴식 자리 (벤치)
    final bs = breakSpot;
    box(c, bs.dx * t - 22, bs.dy * t + 12, 44, 8, 0xFF8B5E3C);
    label(c, '휴식', bs.dx * t - 12, bs.dy * t + 22, size: 11);

    // 자리를 비운 직원 (쉬러 가는 중·쉬는 중·돌아오는 중)
    for (final s in staff) {
      if (!s.away) continue;
      final p = Offset(s.pos.dx * t, s.pos.dy * t);
      if (s.carrier) {
        _person(c, p, s.initial, 0xFF8EC5FF, 0xFFFFFFFF,
            tired: true, energy: s.energyPct);
      } else if (s.post?.type.id == 'counter') {
        _person(c, p, s.initial, 0xFFFFE0B2, 0xFF8B4A00,
            tired: true, energy: s.energyPct);
      } else {
        _person(c, p, s.initial, 0xFFB9F6CA, 0xFF1B5E20,
            tired: true, energy: s.energyPct);
      }
    }

    // 접수 직원: 창구 뒤(위)에 서 있음. 자리에 있는 직원만 표시.
    for (final b in ofType('counter')) {
      final working = customers
          .any((cu) => cu.counter == b && cu.state != 2 && cu.serveT > 0);
      final w = b.type.w.toDouble();
      final spots = [Offset(w - 0.5, -0.15), Offset(0.5, -0.15)];
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        final bob = working ? sin(clock * 10 + i) * 3 : 0.0;
        final p =
        Offset((b.tx + spots[i].dx) * t, (b.ty + spots[i].dy) * t + bob);
        _person(c, p, act[i].initial, 0xFFFFE0B2, 0xFF8B4A00,
            tired: act[i].tired, energy: act[i].energyPct);
      }
    }

    // 포장 직원: 포장대 안쪽. 자리에 있는 직원만 표시.
    for (final b in ofType('pack')) {
      final working = b.slot != null && b.slot!.stage == 2;
      final w = b.type.w.toDouble();
      final spots = [Offset(w - 0.55, 0.55), Offset(0.55, 0.55)];
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        final bob = working ? sin(clock * 12 + i) * 3 : 0.0;
        final p =
        Offset((b.tx + spots[i].dx) * t, (b.ty + spots[i].dy) * t + bob);
        _person(c, p, act[i].initial, 0xFFB9F6CA, 0xFF1B5E20,
            tired: act[i].tired, energy: act[i].energyPct);
      }
    }

    // 손님
    for (final cu in customers) {
      final p = Offset(cu.pos.dx * t, cu.pos.dy * t);
      c.drawCircle(p, t * 0.28, Paint()..color = const Color(0xFFE8B07A));
      c.drawCircle(
          p,
          t * 0.28,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF2A2438));
      box(c, p.dx - 4, p.dy - t * 0.5, 8, 8, Cfg.regionColor[cu.region]);
      if (cu.state != 2 && cu.ready) {
        // 내 자리 맨 앞 손님: 눌러 달라는 말풍선 (살짝 깜빡임)
        final pulse = 0.5 + 0.5 * sin(clock * 8);
        final bubble = Rect.fromLTWH(p.dx - 17, p.dy - t * 0.98, 34, 15);
        box(c, bubble.left, bubble.top, bubble.width, bubble.height,
            pulse > 0.5 ? 0xFFFFD166 : 0xFFF0963A);
        labelIn(c, '탭!', bubble, size: 11, color: const Color(0xFF2A2438));
      } else if (cu.state != 2 &&
          cu.patience / Cfg.patience < Cfg.alertAngry) {
        label(c, '!', p.dx - 3, p.dy - t * 0.98,
            size: 14, color: const Color(0xFFE5484D));
      }
      if (cu.state != 2) {
        final ratio = (cu.patience / Cfg.patience).clamp(0.0, 1.0);
        box(c, p.dx - 12, p.dy + t * 0.34, 24, 3, 0xFF2A2438);
        box(c, p.dx - 12, p.dy + t * 0.34, 24 * ratio, 3,
            ratio > 0.4 ? 0xFF7BD389 : 0xFFE5484D);
      }
    }

    // 운반 직원 (쉬러 간 직원은 위에서 따로 그림)
    for (final w in carriers) {
      if (w.staff.away) continue;
      final p = Offset(w.pos.dx * t, w.pos.dy * t);
      _person(c, p, w.staff.initial, 0xFF8EC5FF, 0xFFFFFFFF,
          tired: w.staff.tired, energy: w.staff.energyPct);
      if (w.carrying && w.job != null) {
        box(c, p.dx - 7, p.dy - t * 0.62, 14, 14,
            Cfg.regionColor[w.job!.region]);
        strokeBox(c, Rect.fromLTWH(p.dx - 7, p.dy - t * 0.62, 14, 14),
            0xFF2A2438, 1.5);
      }
    }
  }
}