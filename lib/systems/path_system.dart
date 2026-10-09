import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/scenery.dart';
import '../models/models.dart';

/// 직원 통로와 길찾기.
/// 통로는 유저가 칸 단위로 깐다. 통로 칸 위에서는 빠르게(Cfg.aisleFast), 밖에서는 느리게(Cfg.aisleSlow) 걷고,
/// 길찾기는 걸리는 시간이 가장 짧은 길을 고르므로 통로가 이어져 있으면 통로를 따라간다.
extension PathSystem on HubGame {
  int tileKey(int x, int y) => y * Cfg.cols + x;

  bool isAisle(int x, int y) => aisles.contains(tileKey(x, y));

  /// 이 위치의 걸음 배수 (통로 위 / 밖)
  double walkFactor(Offset p) =>
      isAisle(p.dx.floor(), p.dy.floor()) ? Cfg.aisleFast : Cfg.aisleSlow;

  /// 창고 오른쪽 벽의 문 (창고 안 ↔ 도크 마당을 오가는 곳), 왼쪽 벽은 손님 입구. 가운데 줄 2칸
  Rect get door {
    final a = area;
    final top = (a.center.dy - Cfg.doorH / 2).floorToDouble();
    return Rect.fromLTRB(a.left, top, a.right, top + Cfg.doorH);
  }

  /// 문 바로 안쪽 칸 (건물로 막으면 안 됨)
  List<Rect> get doorways {
    final d = door;
    return [
      Rect.fromLTWH(d.left, d.top, 1, d.height),
      Rect.fromLTWH(d.right - 1, d.top, 1, d.height),
    ];
  }

  /// 통로를 깔 수 있는 칸: 창고 안, 건물이 없는 곳
  String? aisleProblem(int x, int y) {
    final p = Offset(x + 0.5, y + 0.5);
    if (!area.contains(p)) return '창고 안에만 깔 수 있어요';
    for (final b in buildings) {
      if (b.rect.contains(p)) return '건물 아래에는 깔 수 없어요';
    }
    return null;
  }

  /// 통로 한 칸 깔기(erase=false) / 철거(true). 바뀌었으면 true
  bool paintAisle(int x, int y, {required bool erase}) {
    final k = tileKey(x, y);
    if (erase) {
      if (!aisles.remove(k)) return false;
      final back = (Cfg.aisleCost * Cfg.aisleRefund).round();
      money += back;
      aisleVer++;
      return true;
    }
    if (aisles.contains(k) || aisleProblem(x, y) != null) return false;
    if (money < Cfg.aisleCost) {
      if (toastTime <= 0) showToast('돈이 부족해요');
      return false;
    }
    money -= Cfg.aisleCost;
    aisles.add(k);
    aisleVer++;
    return true;
  }

  /// 두 칸 사이를 빈틈없이 칠함 (드래그가 빨라도 끊기지 않게)
  void paintAisleLine(int x0, int y0, int x1, int y1, {required bool erase}) {
    final n = max((x1 - x0).abs(), (y1 - y0).abs());
    for (var i = 0; i <= n; i++) {
      final t = n == 0 ? 0.0 : i / n;
      paintAisle(
        (x0 + (x1 - x0) * t).round(),
        (y0 + (y1 - y0) * t).round(),
        erase: erase,
      );
    }
    ui();
  }

  // ---------------- 걷기 격자 ----------------

  /// 배치가 바뀌었는지 보는 값 (건물 위치·창고 크기·통로)
  int get _layoutSig => Object.hash(
    areaLevel,
    aisleVer,
    Object.hashAll([
      for (final b in buildings) Object.hash(b.tx, b.ty, b.type.id),
    ]),
  );

  void _ensureGrid() {
    final sig = _layoutSig;
    if (sig == walkSig && walkGrid.isNotEmpty) return;
    walkSig = sig;
    walkGrid = List<bool>.filled(Cfg.cols * Cfg.rows, false);
    final a = area, y = Cfg.yard;
    for (var j = 0; j < Cfg.rows; j++) {
      for (var i = 0; i < Cfg.cols; i++) {
        final p = Offset(i + 0.5, j + 0.5);
        if (a.contains(p) || y.contains(p)) walkGrid[tileKey(i, j)] = true;
      }
    }
    // 가로등·나무 같은 장식이 서 있는 칸 (마당 등 걸을 수 있는 곳에 있으면 막음)
    for (final d in Scenery.items) {
      if (!Scenery.solid.contains(d.key)) continue;
      if (a.inflate(0.6).contains(Offset(d.x, d.y - 0.3))) continue; // 창고에 덮여 안 보이는 장식
      if ((d.key == 'cone' || d.key == 'pallet') &&
          ofType('dock').any((b) => d.y > b.ty - 0.3 && d.y - 1.0 < b.ty + b.type.h + 0.3)) {
        continue; // 도크 앞이라 숨긴 마당 장식
      }
      final k = tileKey(d.x.floor(), (d.y - 0.05).floor());
      if (k >= 0 && k < walkGrid.length) walkGrid[k] = false;
    }
    for (final b in buildings) {
      for (var j = b.ty; j < b.ty + b.type.h; j++) {
        for (var i = b.tx; i < b.tx + b.type.w; i++) {
          if (i >= 0 && j >= 0 && i < Cfg.cols && j < Cfg.rows)
            walkGrid[tileKey(i, j)] = false;
        }
      }
    }
  }

  bool _open(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < Cfg.cols &&
      y < Cfg.rows &&
      walkGrid[tileKey(x, y)];

  /// 벽을 지나는지: 창고 오른쪽 벽(wallX)은 문 줄에서만 지날 수 있다
  bool _wallBlocks(int x0, int y0, int x1, int y1) {
    final w = Cfg.wallX.toInt();
    final crosses = (x0 < w) != (x1 < w);
    if (!crosses) return false;
    final d = door;
    return y0 != y1 || y0 < d.top || y0 >= d.bottom;
  }

  double _cost(int x, int y) =>
      1 / (isAisle(x, y) ? Cfg.aisleFast : Cfg.aisleSlow);

  /// from → to 걷는 길 (지나갈 칸 가운데들 + 마지막에 to). 길이 없으면 곧장 [to]
  List<Offset> findPath(Offset from, Offset to) {
    _ensureGrid();
    final sx = from.dx.floor(), sy = from.dy.floor();
    final gx = to.dx.floor(), gy = to.dy.floor();
    if (sx == gx && sy == gy) return [to];
    final n = Cfg.cols * Cfg.rows;
    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int>.filled(n, -1);
    final start = tileKey(sx, sy), goal = tileKey(gx, gy);
    if (start < 0 || start >= n || goal < 0 || goal >= n) return [to];
    // 출발·도착 칸은 건물 안이어도 들어갈 수 있게 (서는 자리가 건물에 붙어 있음)
    bool open(int x, int y) =>
        _open(x, y) || (x == gx && y == gy) || (x == sx && y == sy);
    final heap = _Heap();
    dist[start] = 0;
    heap.push(start, 0);
    const dirs = [
      (1, 0),
      (-1, 0),
      (0, 1),
      (0, -1),
      (1, 1),
      (1, -1),
      (-1, 1),
      (-1, -1),
    ];
    while (heap.isNotEmpty) {
      final (k, d) = heap.pop();
      if (d > dist[k]) continue;
      if (k == goal) break;
      final x = k % Cfg.cols, y = k ~/ Cfg.cols;
      final cx = _cost(x, y);
      for (final (dx, dy) in dirs) {
        final nx = x + dx, ny = y + dy;
        if (!open(nx, ny) || _wallBlocks(x, y, nx, ny)) continue;
        // 대각선은 양옆 칸이 모두 열려 있어야 (건물 모서리를 파고들지 않게)
        if (dx != 0 &&
            dy != 0 &&
            (!open(x + dx, y) || !open(x, y + dy) || _wallBlocks(x, y, nx, y)))
          continue;
        final step = (dx != 0 && dy != 0) ? 1.4142 : 1.0;
        final nd = d + step * (cx + _cost(nx, ny)) / 2;
        final nk = tileKey(nx, ny);
        if (nd < dist[nk]) {
          dist[nk] = nd;
          prev[nk] = k;
          heap.push(nk, nd);
        }
      }
    }
    if (prev[goal] < 0) return [to];
    final tiles = <int>[];
    for (var k = goal; k != start; k = prev[k]) {
      tiles.add(k);
    }
    final pts = <Offset>[];
    var lastDir = (0, 0);
    var px = sx, py = sy;
    for (final k in tiles.reversed) {
      final x = k % Cfg.cols, y = k ~/ Cfg.cols;
      final dir = (x - px, y - py);
      // 방향이 그대로면 앞 점을 지워 꺾이는 곳만 남김
      if (dir == lastDir && pts.isNotEmpty) pts.removeLast();
      pts.add(Offset(x + 0.5, y + 0.5));
      lastDir = dir;
      px = x;
      py = y;
    }
    if (pts.isNotEmpty) pts.removeLast(); // 도착 칸 가운데 대신 정확한 서는 자리로
    pts.add(to);
    return pts;
  }

  /// 운반 직원을 길 따라 움직임. speed 는 통로 배수를 곱하기 전 속도(칸/초)
  void walkCarrier(Carrier c, Offset target, double speed, double dt) {
    _ensureGrid();
    // 목적지가 바뀌었거나 배치(건물·통로)가 바뀌면 길을 다시 찾음
    if (c.pathGoal != target || c.pathSig != walkSig) {
      c.path = findPath(c.pos, target);
      c.pathGoal = target;
      c.pathSig = walkSig;
    }
    var remain = dt;
    while (remain > 1e-6 && c.path.isNotEmpty) {
      final f = walkFactor(c.pos);
      final sp = speed * f;
      final next = c.path.first;
      final d = (next - c.pos).distance;
      final before = c.pos;
      if (d <= sp * remain) {
        c.pos = next;
        c.path.removeAt(0);
        remain -= d / sp;
      } else {
        c.pos = c.pos + (next - c.pos) / d * (sp * remain);
        remain = 0;
      }
      // 동선 기록: 많이 지나간 칸일수록 진하게 (통로 화면에서 보여 줌)
      final moved = (c.pos - before).distance;
      final tx = before.dx.floor(), ty = before.dy.floor();
      if (tx >= 0 && ty >= 0 && tx < Cfg.cols && ty < Cfg.rows)
        traffic[tileKey(tx, ty)] += moved;
      walkAll += moved;
      if (f == Cfg.aisleFast) walkOnAisle += moved;
    }
    if (c.path.isEmpty) c.pos = target;
  }

  /// 동선 기록이 서서히 옅어짐 (최근 동선이 보이게)
  void decayTraffic(double dt) {
    trafficTimer += dt;
    if (trafficTimer < 1) return;
    final k = pow(0.5, trafficTimer / Cfg.trafficHalfLife).toDouble();
    trafficTimer = 0;
    for (var i = 0; i < traffic.length; i++) {
      traffic[i] *= k;
    }
    walkAll *= k;
    walkOnAisle *= k;
  }
}

/// 작은 최소 힙 (칸 번호, 거리)
class _Heap {
  final List<int> _k = [];
  final List<double> _d = [];
  bool get isNotEmpty => _k.isNotEmpty;

  void push(int k, double d) {
    _k.add(k);
    _d.add(d);
    var i = _k.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_d[p] <= _d[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (int, double) pop() {
    final r = (_k[0], _d[0]);
    final lk = _k.removeLast(), ld = _d.removeLast();
    if (_k.isNotEmpty) {
      _k[0] = lk;
      _d[0] = ld;
      var i = 0;
      while (true) {
        final l = i * 2 + 1, rr = l + 1;
        var m = i;
        if (l < _k.length && _d[l] < _d[m]) m = l;
        if (rr < _k.length && _d[rr] < _d[m]) m = rr;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return r;
  }

  void _swap(int a, int b) {
    final tk = _k[a];
    _k[a] = _k[b];
    _k[b] = tk;
    final td = _d[a];
    _d[a] = _d[b];
    _d[b] = td;
  }
}
