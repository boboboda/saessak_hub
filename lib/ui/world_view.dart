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
  Rect _px(Rect r) => Rect.fromLTWH(r.left * Cfg.tile, r.top * Cfg.tile,
      r.width * Cfg.tile, r.height * Cfg.tile);

  int x0Of(HubGame g) => max(0, (g.cam.dx / Cfg.tile).floor());
  int x1Of(HubGame g) => min(Cfg.cols, ((g.cam.dx + g.size.x) / Cfg.tile).ceil());
  int y0Of(HubGame g) => max(0, (g.cam.dy / Cfg.tile).floor());
  int y1Of(HubGame g) => min(Cfg.rows, ((g.cam.dy + g.size.y) / Cfg.tile).ceil());

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
      for (var y = max(r.top.toInt(), y0Of(this)); y < min(r.bottom.toInt(), y1Of(this)); y++) {
        for (var x = max(r.left.toInt(), x0Of(this)); x < min(r.right.ceil(), x1Of(this)); x++) {
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
    final view = Rect.fromLTWH(cam.dx - 160, cam.dy - 160, size.x + 320, size.y + 320);
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
          box(c, x * t, y * t, t, t, (x + y) % 2 == 0 ? 0xFF69A857 : 0xFF6FAE5B);
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
    // 오래된 표정 기록 정리 (사라진 손님·직원)
    if (_faces.length > 64) {
      _faces.removeWhere((k, _) =>
          (k is Customer && !customers.contains(k)) ||
          (k is Staff && !staff.contains(k)));
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
        box(c, rd.left + 3 + i * (rd.width - 6) / 6, cy * t + 4,
            (rd.width - 6) / 6 - 3, t - 8, 0xDDFFFFFF);
      }
    }
    label(c, '→ 운송', rd.left + 4, area.top * t, size: 11);

    // 도크 마당 바닥
    final y = Cfg.yard;
    for (var ty = y.top.toInt(); ty < y.bottom.toInt(); ty++) {
      for (var tx = y.left.toInt(); tx < y.right.toInt(); tx++) {
        if (!Sprites.drawTile(c, Sprites.yard, tx * t, ty * t, t)) {
          box(c, tx * t, ty * t, t, t,
              (tx + ty) % 2 == 0 ? 0xFF55556A : 0xFF4D4D62);
        }
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
    for (var y = max(a.top.toInt(), y0Of(this)); y < min(a.bottom.toInt(), y1Of(this)); y++) {
      for (var x = max(a.left.toInt(), x0Of(this)); x < min(a.right.toInt(), x1Of(this)); x++) {
        if (!Sprites.drawFloor(c, x * t, y * t, t)) {
          box(c, x * t, y * t, t, t,
              (x + y) % 2 == 0 ? 0xFFE3D5B8 : 0xFFDCCDAE);
        }
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
      final sp = Sprites.forBuilding(b.type.id);
      if (sp != null) {
        Sprites.drawFitWidth(c, sp, r);
      } else {
        box(c, r.left, r.top, r.width, r.height, b.type.color);
        strokeBox(c, r, 0xFF2A2438, 2);
        if (b.type.id != 'lounge') labelIn(c, b.type.name, r, size: 12);
      }

      if (b.level > 1) {
        box(c, r.left + 2, r.top + 2, 28, 13, 0xFFFFD166);
        labelIn(c, 'Lv${b.level}', Rect.fromLTWH(r.left + 2, r.top + 2, 28, 13),
            size: 10, color: const Color(0xFF2A2438));
      }

      // 직원이 필요한 건물: 배치가 없으면 빨강, 전원 휴식 중이면 주황
      if (b.mine) {
        box(c, r.left + 2, r.bottom - 16, 40, 14, 0xFF3FB27F);
        labelIn(c, '내 자리', Rect.fromLTWH(r.left + 2, r.bottom - 16, 40, 14),
            size: 10);
      }
      // 배치된 직원이 없으면 건물 위쪽 바깥에 표시. (자리 비움은 직원 머리 위에 표시)
      if (b.type.slots > 0 && b.crew.isEmpty && !b.mine) {
        box(c, r.center.dx - 22, r.top - 17, 44, 15, 0xFFE5484D);
        labelIn(c, '직원 필요',
            Rect.fromLTWH(r.center.dx - 22, r.top - 17, 44, 15), size: 10);
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
            if (!Sprites.drawBox(
                c,
                Rect.fromLTWH(r.left + 2 + i * 12, r.top + 1, 13, 13),
                Cfg.regionColor[b.outbox[i].region])) {
              box(c, r.left + 4 + i * 11, r.top + 3, 9, 9,
                  Cfg.regionColor[b.outbox[i].region]);
            }
            if (b.outbox[i].kind > 0) {
              strokeBox(c, Rect.fromLTWH(r.left + 4 + i * 11, r.top + 3, 9, 9),
                  0xFFFF3B30, 1.5);
            }
          }
          break;
        case 'pack':
          break; // 상자·진행 막대는 직원 뒤에 다시 그림 (_drawPackContent)
        case 'shelf':
          // 들어온 택배 수만큼 선반 칸에 상자가 쌓임 (아래 칸부터)
          if (Sprites.shelf != null && Sprites.boxS != null) {
            final sh = Sprites.shelf!;
            final k = r.width / sh.width; // 선반 그림 배율
            final top = r.bottom - sh.height * k;
            const tierBase = [64.0, 37.0, 11.0]; // 각 칸 바닥(그림 기준 픽셀)
            const perTier = 4;
            final slots = (b.stored / b.cap * perTier * 3).ceil().clamp(0, perTier * 3);
            for (var i = 0; i < slots; i++) {
              final tier = i ~/ perTier, col = i % perTier;
              Sprites.drawSmallBox(
                  c,
                  r.left + 10 * k + col * 12.5 * k + 1,
                  top + tierBase[tier] * k - 11);
            }
          }
          box(c, r.left + 4, r.bottom - 10, r.width - 8, 6, 0xFF2A2438);
          box(c, r.left + 4, r.bottom - 10,
              (r.width - 8) * (b.stored / b.cap).clamp(0.0, 1.0), 6,
              b.stored >= b.cap ? 0xFFE5484D : 0xFF7BD389);
          label(c, '${b.stored}/${b.cap}', r.left + 5, r.bottom - 26,
              size: 11);
          break;
        case 'lounge':
          // 앉는 자리마다 벤치
          for (final o in Cfg.loungeSeats) {
            _bench(c, Offset((b.tx + o.dx) * Cfg.tile, (b.ty + o.dy) * Cfg.tile));
          }
          label(c, '휴게실', r.center.dx - 18, r.bottom - 15, size: 11);
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
            final vimg = Sprites.vehicleImg(v.type.name);
            if (vimg != null) {
              final vr = Rect.fromLTWH(vx, vy, vw, vh);
              final drawn = Sprites.containRect(vimg, vr);
              final fimg = Sprites.vehicleFullImg(v.type.name);
              if (fimg != null && v.loaded >= v.cap * 0.6) {
                // 거의 찼으면 상자 가득 실린 그림 (빈 그림과 같은 배율, 바닥·오른쪽 맞춤)
                final k = drawn.width / vimg.width;
                final fw = fimg.width * k, fh = fimg.height * k;
                final dst = Rect.fromLTWH(
                    drawn.right - fw, drawn.bottom - fh, fw, fh);
                c.drawImageRect(
                    fimg,
                    Rect.fromLTWH(
                        0, 0, fimg.width.toDouble(), fimg.height.toDouble()),
                    dst,
                    Paint()..filterQuality = FilterQuality.none);
              } else {
                Sprites.drawContain(c, vimg, vr);
                // 싣은 만큼 짐칸에 상자가 쌓임
                Sprites.drawCargo(
                    c, v.type.name, vimg, drawn, v.loaded, v.cap);
              }
              // 구역 색 띠 + 적재 현황 (차량 위쪽)
              box(c, drawn.left + 2, drawn.top - 7, 22, 4,
                  Cfg.regionColor[v.region]);
              labelIn(c, '${v.loaded}/${v.cap}',
                  Rect.fromLTWH(drawn.left + 26, drawn.top - 13, 44, 14),
                  size: 11, color: const Color(0xFFFFFFFF));
            } else {
              box(c, vx, vy, vw, vh, Cfg.regionColor[v.region]);
              box(c, vx + vw - vw * 0.25, vy, vw * 0.25, vh, 0xFF3D4466); // 운전석
              strokeBox(c, Rect.fromLTWH(vx, vy, vw, vh), 0xFF2A2438, 2);
              labelIn(c, '${v.loaded}/${v.cap}',
                  Rect.fromLTWH(vx, vy, vw * 0.75, vh),
                  size: 11, color: const Color(0xFF2A2438));
            }
          }
          break;
      }
      if (b == selected) strokeBox(c, r.inflate(2), 0xFFFFD166, 3);
    }
  }

  void _person(Canvas c, Offset p, String initial, int fill, int stroke,
      {bool tired = false, double energy = 1.0, Object? key, bool work = false, double workHz = 7}) {
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
      Sprites.drawStaff(c, p.dx, p.dy + t * 0.35, f.dir, clock < f.until, clock,
          look: key is Staff ? key.id : 0, work: work, workHz: workHz);
      if (tired) {
        label(c, 'Zz', p.dx + t * 0.18, p.dy - t * 0.7,
            size: 11, color: const Color(0xFF8EC5FF));
      }
      if (energy < 0.98) {
        box(c, p.dx - 12, p.dy + t * 0.42, 24, 3, 0xFF2A2438);
        box(c, p.dx - 12, p.dy + t * 0.42, 24 * energy.clamp(0.0, 1.0), 3,
            energy >= 0.6
                ? 0xFF7BD389
                : (energy >= 0.3 ? 0xFFF0963A : 0xFFE5484D));
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

  /// 길을 오가는 행인 (보기용). 시간만으로 위치가 정해지는 왕복 경로.
  static final List<List<Offset>> _walkRoutes = [
    // 윗길(가로) → 왼쪽 길(세로) → 아랫길(가로)
    [Offset(31, 6.6), Offset(1, 6.6), Offset(1, 29.4), Offset(31, 29.4)],
    // 오른쪽 인도(세로)
    [Offset(35.5, 1.5), Offset(35.5, 34.5)],
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
          dir = v.dx.abs() > v.dy.abs() ? (v.dx < 0 ? 1 : 2) : (v.dy < 0 ? 3 : 0);
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
      c.clipRect(Rect.fromLTRB(dst.left, dst.top + h * 9 / 21, dst.right, dst.bottom)); // 좌판·다리만 사람 앞에
    }
    c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.none);
    if (front) c.restore();
  }

  /// 포장대 위 상자(가운데)와 진행 막대. 직원·책상 앞면 위에 그린다.
  void _drawPackContent(Canvas c, Building b) {
    final p = b.slot;
    if (p == null) return;
    final r = _px(b.rect).deflate(1);
    final dyn = Sprites.packEmpty != null;
    final prog = (b.progress / Cfg.packTime).clamp(0.0, 1.0);
    if (p.stage == 3) {
      final rr = Rect.fromLTWH(r.center.dx - 10, r.top + 1, 20, 20);
      if (!Sprites.drawBox(c, rr, Cfg.regionColor[p.region])) {
        box(c, r.center.dx - 7, r.bottom - 20, 14, 14, Cfg.regionColor[p.region]);
      }
    } else {
      if (dyn && p.stage == 2 && Sprites.boxOpen != null) {
        final k = (0.45 + prog * 6).clamp(0.45, 1.0);
        final w = 20 * k, h = 20 * k;
        // 포장 중엔 상자가 살짝 들썩임
        final live = b.active.isNotEmpty; // 직원이 자리에 없으면 작업이 멈춘 상태
        final jx = live ? sin(clock * 22) * 0.8 * k : 0.0;
        final jy = live ? (sin(clock * 14) * 0.5 + 0.5) * -1.2 : 0.0;
        final br = Rect.fromLTWH(r.center.dx - w / 2 + jx, r.top + 21 - h + jy, w, h);
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
          box(c, sx, br.top + 4 - ph * 9, 2, 2,
              ph < 0.8 ? 0xFFFFF3C4 : 0x00FFFFFF);
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
        _person(c, p, s.initial, 0xFF8EC5FF, 0xFFFFFFFF,
            tired: true, energy: s.energyPct, key: s);
      } else if (s.post?.type.id == 'counter') {
        _person(c, p, s.initial, 0xFFFFE0B2, 0xFF8B4A00,
            tired: true, energy: s.energyPct, key: s);
      } else {
        _person(c, p, s.initial, 0xFFB9F6CA, 0xFF1B5E20,
            tired: true, energy: s.energyPct, key: s);
      }
    }

    // 접수 직원: 창구 뒤(위)에 서 있음. 자리에 있는 직원만 표시.
    for (final b in ofType('counter')) {
      final working = customers
          .any((cu) => cu.counter == b && cu.state != 2 && cu.serveT > 0);
      final w = b.type.w.toDouble();
      final spots = [Offset(w - 0.5, -0.5), Offset(0.5, -0.5)];
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        const bob = 0.0;
        final p =
        Offset((b.tx + spots[i].dx) * t, (b.ty + spots[i].dy) * t + bob);
        _person(c, p, act[i].initial, 0xFFFFE0B2, 0xFF8B4A00,
            tired: act[i].tired,
            energy: act[i].energyPct,
            key: act[i],
            work: working,
            workHz: 9); // 접수: 타이핑처럼 빠르고 작게
      }
    }

    // 포장 직원: 포장대 안쪽. 자리에 있는 직원만 표시.
    for (final b in ofType('pack')) {
      final working = b.slot != null && b.slot!.stage == 2;
      final w = b.type.w.toDouble();
      final spots = [Offset(w - 0.45, 0.12), Offset(0.45, 0.12)];
      final act = b.active;
      for (var i = 0; i < act.length && i < spots.length; i++) {
        const bob = 0.0;
        final p =
        Offset((b.tx + spots[i].dx) * t, (b.ty + spots[i].dy) * t + bob);
        _person(c, p, act[i].initial, 0xFFB9F6CA, 0xFF1B5E20,
            tired: act[i].tired,
            energy: act[i].energyPct,
            key: act[i],
            work: working,
            workHz: 7);
      }
    }

    // 책상 앞면을 직원 위에 다시 그려서 '책상 뒤에 서 있는' 모습으로
    for (final id in const ['counter', 'pack']) {
      for (final b in ofType(id)) {
        if (b.active.isEmpty) continue;
        final sp = Sprites.forBuilding(id);
        if (sp == null) continue;
        final r = _px(b.rect).deflate(1);
        final h = r.width * sp.height / sp.width;
        final top = r.bottom - h;
        c.save();
        c.clipRect(Rect.fromLTRB(
            r.left, top, r.right, r.bottom));
        Sprites.drawFitWidth(c, sp, r);
        c.restore();
      }
    }
    for (final b in ofType('pack')) {
      _drawPackContent(c, b);
    }

    // 자리 비움 표시: 쉬러 간 직원을 따라가지 않고, 그 직원이 서 있던 자리(머리 위)에 표시
    for (final b in [...ofType('counter'), ...ofType('pack')]) {
      final w = b.type.w.toDouble();
      final spots = b.type.id == 'counter'
          ? [Offset(w - 0.5, -0.5), Offset(0.5, -0.5)]
          : [Offset(w - 0.45, 0.12), Offset(0.45, 0.12)];
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
            c, p.dx, p.dy + t * 0.35, f.dir, clock < f.until, clock, cu.look);
      } else {
        c.drawCircle(p, t * 0.28, Paint()..color = const Color(0xFFE8B07A));
        c.drawCircle(
            p,
            t * 0.28,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = const Color(0xFF2A2438));
        box(c, p.dx - 4, p.dy - t * 0.5, 8, 8, Cfg.regionColor[cu.region]);
      }
      if (cu.vip) {
        c.drawCircle(
            p,
            t * 0.34,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = const Color(0xFFFFD166));
      }
      if (cu.kind > 0 && cu.state != 2) {
        label(c, Cfg.kindName[cu.kind], p.dx + 7, p.dy - t * 0.62,
            size: 10, color: const Color(0xFFFF8A80));
      }
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
      final carrying = w.carrying && w.job != null;
      final dir = _faces[w.staff]?.dir ?? 0; // 0 남, 1 서, 2 동, 3 북
      void carried() {
        // 상자를 가슴 앞에 안고 있는 모습 (머리 위가 아님)
        final cx = p.dx + (dir == 1 ? -9 : (dir == 2 ? 9 : 0));
        final cy = p.dy + (dir == 0 ? 3 : 0);
        final r = Rect.fromCenter(center: Offset(cx, cy), width: 17, height: 17);
        if (!Sprites.drawBox(c, r, Cfg.regionColor[w.job!.region])) {
          box(c, r.left, r.top, r.width, r.height, Cfg.regionColor[w.job!.region]);
          strokeBox(c, r, 0xFF2A2438, 1.5);
        }
      }

      if (carrying && dir == 3) carried(); // 뒤돌아 걸을 땐 몸에 가려지게 먼저
      _person(c, p, w.staff.initial, 0xFF8EC5FF, 0xFFFFFFFF,
          tired: w.staff.tired, energy: w.staff.energyPct, key: w.staff);
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
