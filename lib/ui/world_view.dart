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
import 'floor_view.dart';
import 'structure_view.dart';

/// 게임 맵(캔버스). 메뉴·패널은 위젯이 따로 그림.
extension WorldView on HubGame {
  Rect _px(Rect r) => Rect.fromLTWH(
    r.left * Cfg.tile,
    r.top * Cfg.tile,
    r.width * Cfg.tile,
    r.height * Cfg.tile,
  );

  /// 발끝 y(월드 px)에 서 있는 오브젝트를 정렬 큐에 넣음 (같은 y면 넣은 순서대로)
  void _at(double footY, void Function() f) =>
      _q.add((footY + _q.length * 1e-6, f));

  /// 모든 오브젝트 위에 그리는 표시 (말풍선·수량표·이름표)
  void _tag(void Function() f) => _tags.add(f);

  int x0Of(HubGame g) => max(0, (g.cam.dx / Cfg.tile).floor());
  int x1Of(HubGame g) =>
      min(Cfg.cols, ((g.cam.dx + g.viewW) / Cfg.tile).ceil());
  int y0Of(HubGame g) => max(0, (g.cam.dy / Cfg.tile).floor());
  int y1Of(HubGame g) =>
      min(Cfg.rows, ((g.cam.dy + g.viewH) / Cfg.tile).ceil());

  // ---------------- 인도(길) ----------------
  /// 창고 입구(왼쪽 벽 가운데)에서 왼쪽 세로길까지 이어지는 길. 창고가 커지면 같이 이동.
  Rect get entrancePath {
    final a = area;
    final cy = (a.center.dy - 1).floorToDouble();
    return Rect.fromLTRB(1, cy, a.left + 0.15, cy + 2);
  }

  /// 창고 밖 휴식 자리 (벤치 · 대기 직원 · 벤치 옆에서 쉬는 직원). 이 안에는 배경 장식을 두지 않음
  Rect get restYard {
    final b = breakSpot;
    return Rect.fromLTRB(b.dx - 3.0, b.dy - 1.4, area.left, b.dy + 4.6);
  }

  /// 인도 칸인지 (왼쪽·위·아래 보도, 입구 길, 도로 오른쪽 인도)
  bool _walkTile(int x, int y) {
    if (x >= Cfg.road.right) return true;
    final p = Offset(x + 0.5, y + 0.5);
    if (entrancePath.contains(p)) return true;
    for (final r in Scenery.paths) {
      if (r.contains(p)) return true;
    }
    return false;
  }

  void _drawPaths(Canvas c) {
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
          _paver(c, x, y);
        }
      }
    }
  }

  /// 보도블록 한 칸: 따뜻한 베이지 블록을 엇갈려 쌓고, 풀밭·차도와 맞닿은 쪽엔 연석
  void _paver(Canvas c, int x, int y) {
    const t = Cfg.tile;
    final px = x * t, py = y * t;
    box(c, px, py, t, t, 0xFFB5A386); // 줄눈
    for (var row = 0; row < 2; row++) {
      final off = (y * 2 + row).isOdd ? 8.0 : 0.0;
      for (var k = -1; k < 2; k++) {
        final bx = px + off + k * 16.0;
        final l = max(px, bx + 1), r = min(px + t, bx + 16);
        if (r - l < 1) continue;
        final by = py + row * 16.0 + 1;
        final hsh = ((x * 31 + k) * 17 + (y * 2 + row) * 13) & 7;
        final fill = hsh == 0 ? 0xFFD9C7A5 : (hsh == 1 ? 0xFFE8DABF : 0xFFE2D2B3);
        box(c, l, by, r - l, 14, fill);
        box(c, l, by, r - l, 1, 0xFFF2E8D3); // 위 밝은 면
        box(c, l, by + 13, r - l, 1, 0xFFC6B28F); // 아래 그늘
      }
    }
    // 연석: 이웃 칸이 인도가 아니면 그쪽 가장자리를 진하게
    const curb = 0xFF9A8B73, dark = 0xFF6E6352;
    if (!_walkTile(x - 1, y)) {
      box(c, px, py, 4, t, curb);
      box(c, px, py, 1, t, dark);
    }
    if (!_walkTile(x + 1, y)) {
      box(c, px + t - 4, py, 4, t, curb);
      box(c, px + t - 1, py, 1, t, dark);
    }
    if (!_walkTile(x, y - 1)) {
      box(c, px, py, t, 4, curb);
      box(c, px, py, t, 1, dark);
    }
    if (!_walkTile(x, y + 1)) {
      box(c, px, py + t - 4, t, 4, curb);
      box(c, px, py + t - 1, t, 1, dark);
      box(c, px, py + t, t, 2, 0x33000000); // 풀밭에 떨어지는 그림자
    }
  }

  // ---------------- 배경 장식 ----------------
  void _drawDecor(Canvas c) {
    const t = Cfg.tile;
    final a = _px(area.inflate(0.6)); // 지금 창고(+여백)와 겹치는 장식은 숨김
    final view = Rect.fromLTWH(
      cam.dx - 160,
      cam.dy - 160,
      viewW + 320,
      viewH + 320,
    );
    for (final d in Scenery.items) {
      final img = Sprites.decor[d.key];
      if (img == null) continue;
      final k = key == 'extinguisher' ? 0.5 : 1.0; // 소화기는 문틀 옆이라 작게 (2:1 축소)
      final w = img.width * k, h = img.height * k; // 도트 원본 크기 그대로
      final r = Rect.fromLTWH(d.x * t - w / 2, d.y * t - h, w, h);
      if (!r.overlaps(view) || r.overlaps(a)) continue;
      if (restYard.contains(Offset(d.x, d.y - 0.3))) continue; // 창고 밖 휴식 자리는 벤치만 (나무·덤불·꽃 숨김)
      if (!Scenery.onPath.contains(d.key) &&
          entrancePath.contains(Offset(d.x, d.y - 0.3))) {
        continue; // 입구 길 위의 나무 등은 숨김
      }
      if ((d.key == 'cone' || d.key == 'pallet') &&
          ofType('dock').any((b) => d.y > b.ty - 0.3 && d.y - 1.0 < b.ty + b.type.h + 0.3)) {
        continue; // 도크 앞 주차칸(차가 서는 줄)에 걸리면 숨김
      }
      _at(d.y * t, () {
        if (d.key != 'flower') {
          shadowAt(c, Offset(d.x * t, d.y * t), min(w * 0.75, t * 2.6));
        }
        Sprites.drawContain(c, img, r);
      });
    }
  }

  void renderWorld(Canvas c) {
    const t = Cfg.tile;
    box(c, 0, 0, size.x, size.y, 0xFF2A2438);

    c.save();
    c.scale(zoom);
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

    // 서 있는 것들(외벽·나무·가로등·시설·사람)은 발끝 y 순서로: 뒤(화면 위)에 있는 것부터 그림
    _q.clear();
    _tags.clear();
    _drawPaths(c);
    _drawRoadAndYard(c);
    _drawWarehouse(c);
    _drawDecor(c);
    _drawBuildings(c);
    _drawEquips(c);
    _drawPeople(c);
    _q.sort((a, b) => a.$1.compareTo(b.$1));
    for (final e in _q) {
      e.$2();
    }
    _drawLights(c);
    // 표시를 그리다가 표시가 더 생길 수 있어서(사연 말풍선 등) 번호로 돎
    for (var i = 0; i < _tags.length; i++) {
      _tags[i]();
    }

    // 배치 목업
    if (mode == 2 && placing != null) {
      final ok = this.ghostProblem == null;
      final r = _px(this.ghostRect);
      box(c, r.left, r.top, r.width, r.height, ok ? 0x9936C46A : 0x99E5484D);
            strokeBox(c, r, ok ? 0xFF2E9E57 : 0xFFE5484D, 3);
      labelIn(c, placing!.name, r, size: 12);
      // 맞닿는 이웃(세트 판정 대상)은 초록 테두리
      final (near, _) = this.previewSets(placing!, ghostX, ghostY);
      for (final b in near) {
        strokeBox(c, _px(b.rect).inflate(1), 0xFF7BD389, 2);
      }
    }

    c.restore();
    _drawVignette(c);
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

  /// 창고 천장 조명: 4칸마다 따뜻한 빛 웅덩이 (사람·시설 위에 살짝)
  void _drawLights(Canvas c) {
    const t = Cfg.tile;
    final a = area;
    final glow = Paint()..blendMode = BlendMode.softLight;
    for (var y = a.top + 2; y < a.bottom - 0.5; y += 4) {
      for (var x = a.left + 2; x < a.right - 0.5; x += 4) {
        final p = Offset(x * t, y * t);
        const r = Cfg.tile * 2.6;
        glow.shader = RadialGradient(
          colors: const [Color(0x66FFE9B0), Color(0x00FFE9B0)],
        ).createShader(Rect.fromCircle(center: p, radius: r));
        c.drawCircle(p, r, glow);
      }
    }
  }

  /// 화면 가장자리를 살짝 어둡게 (화면 좌표, 위·아래 메뉴에 가리지 않는 부분 기준)
  void _drawVignette(Canvas c) {
    final top = insetTop, bot = size.y - insetBottom;
    const w = 70.0;
    void edge(Rect r, Alignment from) {
      c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: from,
            end: -from,
            colors: const [Color(0x48000000), Color(0x00000000)],
          ).createShader(r),
      );
    }
    edge(Rect.fromLTWH(0, 0, w, size.y), Alignment.centerLeft);
    edge(Rect.fromLTWH(size.x - w, 0, w, size.y), Alignment.centerRight);
    edge(Rect.fromLTWH(0, top - 10, size.x, w), Alignment.topCenter);
    edge(Rect.fromLTWH(0, bot - w + 10, size.x, w), Alignment.bottomCenter);
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
        _paver(c, tx, ty);
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
    final view = Rect.fromLTWH(cam.dx, cam.dy, viewW, viewH).inflate(t * 2);
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
  // 구역은 바닥 재질·색과 바닥 글씨로 구분하고, 직원 통로는 유저가 직접 깐다.
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
    final ai = this.door; // 양쪽 벽 문 (가운데 줄)
    final ar = _px(a);
    // 바닥: 구역별 재질 + 유저가 깐 통로 + 바닥 구역 글씨 (floor_view.dart)
    c.save();
    c.clipRect(ar);
    this.drawFloor(c, x0Of(this), y0Of(this), x1Of(this), y1Of(this));
    c.restore();

    // 배치 중이면 들어갈 구역만 진하게
    for (var z = 0; z < 3; z++) {
      if (mode == 2 && placing != null && placing!.zone == z) {
        final r = _px(this.zoneRect(z));
        box(c, r.left, r.top, r.width, r.height, Cfg.zoneHot[z]);
      }
    }
    // 도크 마당에 깐 통로: 창고 안 통로와 같은 보행 차선
    bool onYard(int x, int y) => Cfg.yard.contains(Offset(x + 0.5, y + 0.5)) && isAisle(x, y);
    for (final k in aisles) {
      final x = k % Cfg.cols, y = k ~/ Cfg.cols;
      if (onYard(x, y)) drawAisleTile(c, x, y, onYard);
    }
    if (mode == 4) _drawAisleOverlay(c);
    // 건물 구조: 옆벽·남쪽 벽·모서리 기둥·입구 문틀 (바닥에 붙은 것), 북쪽 외벽과 입구 간판은 발끝 정렬
    final door = _px(ai);
    drawSideWalls(c, ar, door, [
      door,
      for (final d in ofType('dock')) _px(d.rect),
    ]);
    for (final d in ofType('dock')) {
      drawDockStripes(c, _px(d.rect), ar.right);
    }
    _at(ar.top, () => drawFacade(c, ar));
    final sf = Offset(ar.left - 1.4 * t, door.top - 0.15 * t);
    _at(sf.dy, () => drawEntranceSign(c, sf));
    label(c, '입구', ar.left - 40, door.center.dy - 7, size: 12, color: const Color(0xFF6B5638));
  }

  /// 통로 모드: 칸 격자 + 직원이 자주 다닌 길(동선) 강조
  void _drawAisleOverlay(Canvas c) {
    const t = Cfg.tile;
    final grid = Paint()
      ..color = const Color(0x332A2438)
      ..strokeWidth = 1;
    for (final r in [area]) {
      for (var x = r.left; x <= r.right; x++) {
        c.drawLine(Offset(x * t, r.top * t), Offset(x * t, r.bottom * t), grid);
      }
      for (var y = r.top; y <= r.bottom; y++) {
        c.drawLine(Offset(r.left * t, y * t), Offset(r.right * t, y * t), grid);
      }
    }
    var top = 0.0;
    for (final v in traffic) {
      if (v > top) top = v;
    }
    if (top < 0.5) return;
    for (var k = 0; k < traffic.length; k++) {
      final v = traffic[k] / top;
      if (v < 0.08) continue;
      final x = k % Cfg.cols, y = k ~/ Cfg.cols;
      // 많이 다닌 칸일수록 진한 주황 (통로가 없으면 이 길을 따라 깔면 좋다)
      c.drawRect(
        Rect.fromLTWH(x * t + 3, y * t + 3, t - 6, t - 6),
        Paint()..color = Color.fromRGBO(240, 90, 40, 0.15 + 0.45 * v),
      );
    }
  }

  // ---------------- 건물 ----------------
  /// 시설에 단 장비 그림. 지게차는 도크와 가장 가까운 선반 사이를 천천히 오감
  void _drawEquips(Canvas c) {
    const t = Cfg.tile;
    for (final b in buildings) {
      final id = b.equip;
      if (id == null) continue;
      final img = Sprites.equips[id];
      if (img == null) continue;
      final r = Rect.fromLTWH(b.tx * t, b.ty * t, b.type.w * t, b.type.h * t);
      switch (b.type.id) {
        case 'counter': // 책상 왼쪽 끝에 올려 둠 (오른쪽 칸은 상자 적재대). 번호표 발권기는 창구 왼쪽 바닥에 세움
          final d = id == 'ticket'
              ? Rect.fromLTWH(r.left - t * 0.45, r.bottom - 34, 18, 34)
              : Rect.fromCenter(center: Offset(r.left + t * 0.22, r.top + t * 0.95), width: 20, height: 20);
          _at(r.bottom + 1, () => Sprites.drawContain(c, img, d));
          break;
        case 'pack': // 포장대 앞 오른쪽 모서리
          final big = id == 'robot' || id == 'bubble';
          final d = Rect.fromCenter(
              center: Offset(r.right - t * 0.2, r.top + t * (big ? 1.25 : 1.45)), width: big ? 26 : 20, height: big ? 28 : 20);
          _at(r.bottom + 1, () => Sprites.drawContain(c, img, d));
          break;
        case 'shelf': // 사다리는 선반 옆에 기대 두고, 스마트 태그 스캐너는 옆에 걸어 둠
          final d = id == 'ladder' ? Rect.fromLTWH(r.right - 8, r.bottom - 36, 22, 36) : Rect.fromLTWH(r.right - 4, r.bottom - 30, 14, 20);
          _at(r.bottom + 1, () => Sprites.drawContain(c, img, d));
          break;
        case 'dock':
          final dockP = pickOf(b);
          if (id == 'forklift') {
            // 가장 가까운 선반 앞 ↔ 도크 앞을 오감 (보이기용, 실제 싣기는 loadMul)
            Offset? shelfP;
            var best = double.infinity;
            for (final sh in ofType('shelf')) {
              final q = pickOf(sh);
              final dd = (q - dockP).distanceSquared;
              if (dd < best) {
                best = dd;
                shelfP = q;
              }
            }
            final from = shelfP ?? dockP - const Offset(3, 0);
            final ph = (clock * 0.25 + b.ty * 0.13) % 1.0;
            final k = ph < 0.5 ? ph * 2 : 2 - ph * 2; // 0→1→0
            final e = Curves.easeInOut.transform(k);
            final p = Offset.lerp(from, dockP - const Offset(0.8, 0), e)!;
            final goingRight = ph < 0.5 ? (dockP.dx > from.dx) : (dockP.dx < from.dx);
            final px = Offset(p.dx * t, p.dy * t);
            final d = Rect.fromCenter(center: px - const Offset(0, 14), width: 44, height: 36);
            _at(px.dy + 2, () {
              shadowAt(c, px, 30);
              c.save();
              if (!goingRight) { // 가는 쪽으로 포크가 보이게 뒤집음
                c.translate(px.dx * 2, 0);
                c.scale(-1, 1);
              }
              Sprites.drawContain(c, img, d);
              c.restore();
            });
          } else {
            final px = Offset((dockP.dx - 0.5) * t, (b.ty + b.type.h - 0.2) * t);
            final d = Rect.fromCenter(center: px - const Offset(0, 10), width: 34, height: 22);
            _at(px.dy, () => Sprites.drawContain(c, img, d));
          }
          break;
      }
    }
  }

  void _drawBuildings(Canvas c) {
    for (final b in buildings) {
      final r = _px(b.rect).deflate(1);
      final sp = Sprites.forBuilding(b.type.id);
      _tag(() => _buildingTags(c, b, r));
      // 발끝 = 건물 아래 끝. 그 뒤(위)에 선 직원은 먼저 그려져 책상에 가려짐
      // 휴게실(그림)은 바닥 깔개라 소파 줄 기준으로 먼저 그림 → 소파에 앉은 직원이 위에 보이고, 앞면만 다시 덮음
      final key = b.type.id == 'lounge' && sp != null ? (b.ty + 1.2) * Cfg.tile : (b.ty + b.type.h) * Cfg.tile;
      _at(key, () {
        if (sp != null) {
          final dr = _px(_deskRect(b)).deflate(1);
          if (b.type.id != 'dock' && b.type.id != 'lounge') {
            shadowUnder(c, Sprites.fitBottom(sp, dr));
          }
          Sprites.drawFitBottom(c, sp, dr, left: b.type.id == 'dock');
          if (b.type.id == 'counter') {
            final dd = Sprites.fitBottom(sp, dr);
            drawCounterProps(c, dd);
            // 접수 중이면 자리에 있는 직원마다 키보드를 두드리는 손
            final busy = customers.any(
              (cu) => cu.counter == b && cu.state != 2 && cu.serveT > 0,
            );
            final sx = _spots(b);
            for (var i = 0; i < b.active.length && i < sx.length; i++) {
              typingHands(
                c,
                Offset((b.tx + sx[i].dx) * Cfg.tile, dd.top + 17),
                busy,
                i * 0.37,
              );
            }
          }
          if (b.type.id == 'pack')
            drawPackProps(c, Sprites.fitBottom(sp, dr), r);
        } else {
          box(c, r.left, r.top, r.width, r.height, b.type.color);
          strokeBox(c, r, 0xFF2A2438, 2);
          if (b.type.id != 'lounge') labelIn(c, b.type.name, r, size: 12);
        }

        switch (b.type.id) {
          case 'counter':
            _drawStack(c, b);
            break;
          case 'pack':
            break; // 상자·진행 막대는 직원 뒤에 다시 그림 (_drawPackContent)
          case 'shelf':
            // 들어온 택배 수만큼 선반 판 위에 상자가 쌓임 (아래 판부터). 수량 표시는 선반 위 빈칸에
            final sh = Sprites.forBuilding('shelf');
            if (sh != null && Sprites.boxS != null) {
              final d = Sprites.fitBottom(sh, r);
              final k = d.width / sh.width;
              // 각 판 윗면 앞쪽 = 상자 바닥 (그림 기준 픽셀, 탑뷰 3/4 선반 hub_shelf 57x56: 아래·가운데·맨 위 판)
              const tierBase = [47.0, 27.0, 11.0];
              const hs = [12.0, 9.0, 11.0, 10.0]; // 상자마다 높이를 다르게
              const perTier = 4;
              final slots = (b.stored / b.cap * perTier * 3).ceil().clamp(
                0,
                perTier * 3,
              );
              for (var i = 0; i < slots; i++) {
                final tier = i ~/ perTier, col = i % perTier;
                final bh = hs[(i * 3 + b.tx) % hs.length];
                Sprites.drawSmallBox(
                  c,
                  d.left + (6 + col * 12) * k,
                  d.top + tierBase[tier] * k - bh,
                  w: 11,
                  h: bh,
                );
              }
            }
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
                  Sprites.drawCargo(
                    c,
                    v.type.name,
                    vimg,
                    drawn,
                    v.loaded,
                    v.cap,
                  );
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
                box(
                  c,
                  vx + vw - vw * 0.25,
                  vy,
                  vw * 0.25,
                  vh,
                  0xFF3D4466,
                ); // 운전석
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
        final sj = storyJob;
        if (b.type.id == 'pack' && sj != null && sj.table == b) {
          _drawStoryPack(c, b, sj);
        } else if (b.type.id == 'pack') {
          _drawPackContent(c, b);
        }
      });
    }
  }

  /// 건물 위 표시: 레벨·내 자리·직원 없음·선반 수량·선택 테두리 (모든 오브젝트 위)
    void _buildingTags(Canvas c, Building b, Rect r) {
    // 세트 발동 중: 오른쪽 위에 초록 고리 표시
    if (b.sets.isNotEmpty) {
      final tag = Rect.fromLTWH(r.right - 30, r.bottom - 15, 28, 13);
      c.drawRRect(
        RRect.fromRectAndRadius(tag, const Radius.circular(6)),
        Paint()..color = const Color(0xEE3FA34D),
      );
      labelIn(c, '세트${b.sets.length > 1 ? b.sets.length : ''}', tag, size: 9);
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
    if (b.type.slots > 0 && b.crew.isEmpty) {
      final blink = 0.75 + 0.25 * sin(clock * 4);
      final tag = Rect.fromLTWH(r.center.dx - 26, r.top - 18, 52, 16);
      c.drawRRect(
        RRect.fromRectAndRadius(tag, const Radius.circular(4)),
        Paint()..color = Color(0xFFE5484D).withValues(alpha: blink),
      );
      labelIn(c, '직원 없음', tag, size: 10);
    }
    // 직원을 고른 중이면 배치할 수 있는 시설을 테두리로 강조
    if (picking != null &&
                (b.seats > b.crew.length ||
            b.type.id == 'shelf' ||
            b.type.id == 'dock')) {
      strokeBox(c, r.inflate(2), 0xFFFFD166, 2);
    }

    // 포장 실수 표시
    if (b.flash > 0) {
      box(c, r.left, r.top, r.width, r.height, 0x66E5484D);
      labelIn(c, '실수!', r, size: 13);
    }

    if (b.type.id == 'shelf') {
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
    }
    if (b == selected) strokeBox(c, r.inflate(2), 0xFFFFD166, 3);
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
      // 프레임마다가 아니라 마지막으로 방향을 정한 자리부터 쌓인 이동으로 판단 (느리게 걸어도 앞을 보지 않게)
      final moved = dx * dx + dy * dy > 2.0;
      if (moved) {
        f.dir = dx.abs() > dy.abs() ? (dx < 0 ? 1 : 2) : (dy < 0 ? 3 : 0);
        f.until = clock + 0.25;
        f.last = p;
      }
      if (!moved && clock > f.until + Cfg.faceIdle) f.dir = 0; // 한참 멈춰 있어야 정면(남쪽)을 봄
      shadowAt(c, Offset(p.dx, p.dy + t * 0.35), 20);
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
    [Offset(Cfg.road.right + 1.6, 1.5), Offset(Cfg.road.right + 1.6, 34.5)],
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
      _at(e.$2.dy * t, () {
        shadowAt(c, e.$2 * t, 18);
        Sprites.drawPerson(
          c,
          e.$2.dx * t,
          e.$2.dy * t,
          e.$3,
          true,
          clock,
          e.$5,
        );
      });
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

  /// 사연 손님 말풍선: 머리 위 둥근 말풍선 안에 사연 물건 아이콘 + 느낌표, 테두리 고리는 남은 기다림.
  /// 말풍선은 손님이 문 앞에 멈춰 있어서 같이 흔들리지 않음 (살짝 위아래로만 떠 있음)
  void _storyBubble(Canvas c, Customer cu, Offset p) {
    const t = Cfg.tile;
    final d = Cfg.storyDefs[cu.story];
    final bob = sin(clock * 3) * 1.5;
    final r = Rect.fromCenter(center: Offset(p.dx, p.dy - t * 1.6 + bob), width: 34, height: 30);
    final bub = Sprites.storyBubble;
    if (bub != null) {
      Sprites.drawContain(c, bub, r.inflate(3));
    } else {
      c.drawPath(
        Path()
          ..moveTo(r.center.dx - 4, r.bottom - 1)
          ..lineTo(r.center.dx, r.bottom + 6)
          ..lineTo(r.center.dx + 5, r.bottom - 1)
          ..close(),
        Paint()..color = const Color(0xFFFFFBF0),
      );
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(9));
      c.drawRRect(rr, Paint()..color = const Color(0xFFFFFBF0));
      c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF2A2438),
      );
    }
    final icon = Sprites.storyItems[d.item];
    if (icon != null) Sprites.drawContain(c, icon, r.deflate(5).translate(0, -1));
    // 남은 기다림: 말풍선 위 막대
    final left = (1 - cu.storyT / Cfg.storyWait).clamp(0.0, 1.0);
    box(c, r.left + 3, r.top - 6, r.width - 6, 3, 0xFF2A2438);
    box(c, r.left + 3, r.top - 6, (r.width - 6) * left, 3, left > 0.35 ? 0xFFFFD166 : 0xFFE5484D);
    // 느낌표 배지 (오른쪽 위, 깜빡임)
    final ex = Sprites.storyAlert;
    final er = Rect.fromCenter(center: r.topRight + const Offset(-2, 2), width: 16, height: 16);
    if (ex != null) {
      Sprites.drawContain(c, ex, er.translate(0, sin(clock * 6) * 1.2));
    } else {
      c.drawCircle(er.center, 7, Paint()..color = const Color(0xFFE5484D));
      labelIn(c, '!', er, size: 11);
    }
    cu.bubble = r.inflate(4);
  }

  /// 포장대 위 사연 택배: 상자가 눌렸다 펴지며(찌그러짐) 포장 아이콘(얼음·뽁뽁이·테이프)이 차례로 튀어나옴
  void _drawStoryPack(Canvas c, Building b, StoryJob j) {
    final r0 = _px(b.rect).deflate(1);
    final sp = Sprites.forBuilding('pack');
    final top = sp == null ? r0.top : Sprites.fitBottom(sp, r0).top - 6;
    final cx = r0.center.dx;
    final live = b.active.isNotEmpty;
    final k = (j.t / Cfg.storyPackTime).clamp(0.0, 1.0);
    // 찌그러짐: 가로로 퍼지고 세로로 눌림 (직원이 일할 때만)
    final sq = live ? sin(clock * 9).abs() * 0.18 : 0.0;
    final w = 22 * (1 + sq * 0.6), h = 20 * (1 - sq);
    final br = Rect.fromLTWH(cx - w / 2, top + 21 - h, w, h);
    final img = Sprites.boxOpen ?? Sprites.box;
    if (img != null) {
      Sprites.drawContain(c, k > 0.8 && Sprites.box != null ? Sprites.box! : img, br);
    } else {
      box(c, br.left, br.top, br.width, br.height, 0xFFC8955E);
    }
    // 사연 물건 (상자 위로 살짝)
    final d = Cfg.storyDefs[j.story];
    final it = Sprites.storyItems[d.item];
    if (it != null && k < 0.8) Sprites.drawContain(c, it, Rect.fromCenter(center: Offset(cx, br.top - 4), width: 16, height: 16));
    // 아이콘 이펙트: 단계마다 하나씩 위로 떠오르며 사라짐
    final n = d.fx.length;
    for (var i = 0; i < n; i++) {
      final t0 = i / n * 0.85;
      final u = ((k - t0) / 0.3);
      if (u < 0 || u > 1) continue;
      final ic = Sprites.fxIcons[d.fx[i]];
      final rr = Rect.fromCenter(center: Offset(cx + (i - (n - 1) / 2) * 14, br.top - 10 - u * 22), width: 18, height: 18);
      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, (1 - u * u).clamp(0.0, 1.0));
      if (ic != null) {
        c.saveLayer(rr.inflate(2), paint);
        Sprites.drawContain(c, ic, rr);
        c.restore();
      }
    }
    // 진행 막대 + 직원이 없을 때 안내
    box(c, r0.left + 6, r0.bottom - 6, r0.width - 12, 4, 0xFF2A2438);
    box(c, r0.left + 6, r0.bottom - 6, (r0.width - 12) * k, 4, 0xFFFFD166);
    if (!live) {
      final tag = Rect.fromCenter(center: Offset(cx, top - 14), width: 70, height: 14);
      _tag(() {
        box(c, tag.left, tag.top, tag.width, tag.height, 0xEE2A2438);
        labelIn(c, '직원을 기다려요', tag, size: 9);
      });
    }
  }

  /// 창구·포장대에서 직원이 서는 자리 (건물 왼쪽 위 기준, 칸). 책상 그림 뒤쪽, 칸 안.
  List<Offset> _spots(Building b) {
    final w = _deskRect(b).width, h = b.type.h.toDouble();
    final sp = Sprites.forBuilding(b.type.id);
    if (sp == null) return [Offset(w - 0.5, 0.1), Offset(0.5, 0.1)];
    // 발 = 책상 그림 위 끝 + _deskBack(px). 발끝 정렬로 책상이 직원 다음에 그려져 아래쪽을 가린다
    final spriteTop = h * Cfg.tile - 1 - sp.height;
    final feet = spriteTop + (_deskBack[b.type.id] ?? 4);
    final topY =
        (feet - Cfg.tile * 0.35) / Cfg.tile; // drawStaff 는 (위치 + 0.35칸)을 발로 그림
    // 접수 창구: 첫 자리는 모니터와 저울 사이 (얼굴이 소품에 가리지 않게)
    if (b.type.id == 'counter') {
      return [Offset(1.12, topY), Offset(0.42, topY)];
    }
    return [Offset(w - 0.5, topY), Offset(0.5, topY)];
  }

  /// 책상 그림별 직원 발 위치 — 그림 위 끝 기준 px. 책상 뒤쪽 바닥(윗면 뒤 끝 + 앞면 높이 근처)에 서서
  /// 발끝 정렬로 책상이 나중에 그려지며 다리를 가림 → 책상 뒤에 서서 일하는 모습 (책상 위에 올라선 것처럼 안 보임)
  static const Map<String, double> _deskBack = {'counter': 22, 'pack': 14};

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
        // 테이프 건이 상자 윗면을 왔다 갔다 (직원이 있을 때)
        if (live) tapeGun(c, br, clock);
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

    // 입구 안쪽 소화기 (창고 밖 휴식 자리는 벤치만 둠)
    for (final (key, x, y) in [
      ('extinguisher', door.left + 0.25, door.top + 0.4),
    ]) {
      final img = Sprites.decor[key];
      if (img == null) continue;
      final k = key == 'extinguisher' ? 0.5 : 1.0; // 소화기는 문틀 옆이라 작게 (2:1 축소)
      final w = img.width * k, h = img.height * k; // 그 밖은 도트 원본 크기
      final r = Rect.fromLTWH(x * t - w / 2, y * t - h, w, h);
      _at(y * t, () {
        shadowAt(c, Offset(x * t, y * t), w * 0.8);
        Sprites.drawContain(c, img, r);
      });
    }

    // 창고 밖 휴식 자리 (벤치)
    final bs = breakSpot;
    final bsPos = Offset(bs.dx * t, bs.dy * t);
    _at(bsPos.dy + 4, () => _bench(c, bsPos));
    if (!staff.any((s) => s.idle)) {
      _tag(() => label(c, '휴식', bs.dx * t - 12, bs.dy * t + 14, size: 11));
    }

    // 대기 직원: 휴식 벤치 둘레에 서 있음 (탭해서 고른 뒤 시설을 탭하면 배치)
    for (final s in staff) {
      if (!s.idle) continue;
      final fp = this.idleSpot(s);
      final p = Offset(fp.dx * t, fp.dy * t);
      if (s.idleSayT > 0) {
        final say = s.idleSay;
        _tag(() {
          final w = 14.0 + say.length * 10.0;
          final r = Rect.fromCenter(center: Offset(p.dx, p.dy - t * 1.15), width: w, height: 15);
          c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)), Paint()..color = const Color(0xEEFFFFFF));
          labelIn(c, say, r, size: 10, color: const Color(0xFF2A2438));
        });
      }
      _at(p.dy + t * 0.35, () {
        if (picking == s) {
          c.drawOval(
            Rect.fromCenter(
              center: p + const Offset(0, 9),
              width: 30,
              height: 12,
            ),
            Paint()
              ..color = const Color(0xFFFFD166)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        _person(
          c,
          p,
          s.initial,
          0xFFE0E0E0,
          0xFF555555,
          energy: s.energyPct,
          key: s,
        );
      });
    }
    if (staff.any((s) => s.idle)) {
      final bp = this.benchSpot(staff.firstWhere((s) => s.idle));
      final tag = Rect.fromCenter(
        center: Offset(breakSpot.dx * t, (bp.dy - 2.3) * t),
        width: 64,
        height: 15,
      );
      final n = staff.where((s) => s.idle).length;
      _tag(() {
        c.drawRRect(
          RRect.fromRectAndRadius(tag, const Radius.circular(4)),
          Paint()..color = const Color(0xCC2A2438),
        );
        labelIn(c, '대기 $n명 · 탭', tag, size: 10);
      });
    }

    // 자리를 비운 직원 (쉬러 가는 중·쉬는 중·돌아오는 중)
    for (final s in staff) {
      if (!s.away) continue;
      final p = Offset(s.pos.dx * t, s.pos.dy * t);
      _at(p.dy + t * 0.35, () {
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
      });
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
        final st = act[i];
        _at(
          p.dy + t * 0.35,
          () => _person(
            c,
            p,
            st.initial,
            0xFFFFE0B2,
            0xFF8B4A00,
            tired: st.tired,
            energy: st.energyPct,
            key: st,
            work: working,
            workHz: 9,
          ),
        ); // 접수: 타이핑처럼 빠르고 작게
      }
    }

        // 훈련 중 직원: 교육실 책상 앞에서 공부
    for (final b in ofType('classroom')) {
      final tr = staff.where((s) => s.training == b).toList();
      for (var i = 0; i < tr.length; i++) {
        final st = tr[i];
        // 책상 앞 의자 자리 (화이트보드에 가리지 않게 교육실 그림 다음에 그림)
        final p = Offset((b.tx + 0.77 + i * 0.78) * t, (b.ty + 2.6) * t);
        _at((b.ty + b.type.h) * t + 1, () => _person(c, p, st.initial, 0xFFE0E0E0, 0xFF555555,
            energy: st.energyPct, key: st, work: true, workHz: 3));
      }
    }

    // 보조 자리 직원: 분류사는 선반 오른쪽 옆, 정비사는 도크 문 안쪽 (운반 직원이 서는 자리는 비워 둠)
    for (final b in [...ofType('shelf'), ...ofType('dock')]) {
      for (final st in b.active) {
        final sp = b.type.id == 'shelf'
            ? Offset(b.tx + b.type.w + 0.35, b.ty + b.type.h - 0.45)
            : Offset(b.tx - 1.5, b.ty + 0.4);
        final p = Offset(sp.dx * t, sp.dy * t);
        final busy = b.type.id == 'shelf' ? b.stored > 0 : b.vehicle != null;
        _at(p.dy + t * 0.35, () => _person(c, p, st.initial, 0xFFB9F6CA, 0xFF1B5E20,
            tired: st.tired, energy: st.energyPct, key: st, work: busy, workHz: 5));
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
        final st = act[i];
        _at(
          p.dy + t * 0.35,
          () => _person(
            c,
            p,
            st.initial,
            0xFFB9F6CA,
            0xFF1B5E20,
            tired: st.tired,
            energy: st.energyPct,
            key: st,
            work: working,
            workHz: 7,
          ),
        );
      }
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
        _tag(() {
          box(c, bub.left, bub.top, bub.width, bub.height, 0xFFD98B2B);
          labelIn(c, '자리 비움', bub, size: 10);
        });
      }
    }

    // 앉아서 쉬는 직원: 휴게실 소파 앞쪽을 다시 그려 '앉은' 느낌 (창고 밖 벤치 옆은 서서 쉼)
    for (final s in staff) {
      if (!s.away || s.rest != 2) continue;
      final l = s.lounge;
      if (l != null) {
        final o = Cfg.loungeSeats[s.seat];
        final sp = Sprites.hubLounge;
        final sitKey = (l.ty + o.dy) * t + t * 0.35 + 0.5; // 앉은 직원 바로 다음
        if (sp == null) {
          _at(
            sitKey,
            () => _bench(
              c,
              Offset((l.tx + o.dx) * t, (l.ty + o.dy) * t),
              front: true,
            ),
          );
        } else if (s.seat < 2) {
          // 소파 자리: 소파 앞면(방석 아래)을 직원 위에 다시 그려 다리를 가림 → 앉은 모습
          final r = _px(l.rect).deflate(1);
          final d = Sprites.fitBottom(sp, r);
          final x = (l.tx + o.dx) * t;
          _at(sitKey, () {
            c.save();
            c.clipRect(Rect.fromLTWH(x - 13, d.top + 41, 26, 14)); // 방석 앞면·팔걸이 아래 (다리를 가림)
            Sprites.drawFitBottom(c, sp, r);
            c.restore();
          });
        }
      }
    }

    // 손님
    for (final cu in customers) {
      final p = Offset(cu.pos.dx * t, cu.pos.dy * t);
      _at(p.dy + t * 0.35, () {
        if (Sprites.staffWalk != null) {
          final f = _faces.putIfAbsent(cu, () => _Face(p));
          final dx = p.dx - f.last.dx, dy = p.dy - f.last.dy;
          final moved = dx * dx + dy * dy > 2.0;
          if (moved) {
            f.dir = dx.abs() > dy.abs() ? (dx < 0 ? 1 : 2) : (dy < 0 ? 3 : 0);
            f.until = clock + 0.25;
            f.last = p;
          }
          if (!moved && clock > f.until + Cfg.faceIdle) f.dir = cu.story >= 0 ? 0 : 3; // 서서 기다릴 땐 창구(위)를 봄, 사연 손님은 화면 쪽
          shadowAt(c, Offset(p.dx, p.dy + t * 0.35), 20);
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
      });
      _tag(() {
                if (cu.guest >= 0 && cu.state != 2) {
          final nm = Cfg.guestName[cu.guest];
          final r = Rect.fromCenter(
            center: Offset(p.dx, p.dy - t * 1.25),
            width: textWidth(nm, 10) + 12,
            height: 15,
          );
          c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)),
              Paint()..color = const Color(0xEEFFD166));
          labelIn(c, nm, r, size: 10, color: const Color(0xFF2A2438));
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
        if (cu.kind > 0 && cu.state != 2 && cu.story < 0) {
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
        } else if (cu.state != 2 &&
            cu.patience / Cfg.patience < Cfg.alertAngry) {
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
        if (cu.state != 2 && cu.story >= 0) _storyBubble(c, cu, p); // 이미 표시(맨 위) 단계
        if (cu.state != 2 && cu.story < 0) {
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
      });
    }

    // 떠오르는 글 (사연 보너스)
    hubFx.removeWhere((f) => clock - f.$4 > 1.4);
    for (final f in List.of(hubFx)) {
      _tag(() {
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
      });
    }

    // 운반 직원 (쉬러 간 직원은 위에서 따로 그림)
    for (final w in carriers) {
      if (w.staff.away) continue;
      final p = Offset(w.pos.dx * t, w.pos.dy * t);
      final carrying = w.carrying && w.job != null;
      final dir = _faces[w.staff]?.dir ?? 0; // 0 남, 1 서, 2 동, 3 북
      void carried() {
        // 상자를 가슴 앞에 안고 있는 모습 (머리 위가 아님)
        // 걸을 때 상자가 걸음에 맞춰 살짝 들썩임
        final bob = w.path.isNotEmpty ? sin(clock * 14).abs() * -1.5 : 0.0;
        final cx = p.dx + (dir == 1 ? -9 : (dir == 2 ? 9 : 0));
        final cy = p.dy + (dir == 0 ? 3 : 0) + bob;
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
        if (dir != 3) liftHands(c, r); // 두 손으로 상자 양옆을 받쳐 듦
      }

      _at(p.dy + t * 0.35, () {
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
      });
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

// 발끝(바닥 접점) y 순서로 그리는 오브젝트 (나무·가로등·시설·사람)와, 그 위에 그리는 표시(말풍선·수량표)
final List<(double, void Function())> _q = [];
final List<void Function()> _tags = [];
double _stackClock = 0; // 지난 프레임 시각 (적재대 연출용)
