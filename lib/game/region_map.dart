import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';


import 'config.dart';

/// 지역 지도 한 장 (칸 좌표). 설정값(config.dart 의 지역 규격)으로 만든다.
/// 큰길 격자 → 일부 구간 빼기 → 간선 경로 고르기 → 차도 옆 보도 → 건널목 → 동네 블록에 집 → 배달 길찾기 → 소품.
class RegionMap {
  final int region;
  final int gw, gh;
  final Uint8List cell; // 0 잔디, 1 차도, 2 보도, 3 바다
  final Uint8List side; // 1: 간선이 아닌 차도 (교차로 찾기용)
  final Set<int> cross = {}; // 건널목 칸
  final List<Offset> trunk = []; // 허브 → 센터 간선 중심선
  final List<List<Offset>> roads = []; // 다른 차도 중심선 (차선 표시용)
  final List<MapHouse> houses = [];
  final List<int> deliver = []; // 배달 번호 → houses 번호
  final List<List<Offset>> courier = []; // 배달 번호별 센터 → 집 앞 길
  final List<List<double>> courierStops = []; // 배달 길의 건널목 위치(길 따라 거리)
  final List<double> trunkStops = []; // 간선의 교차로·건널목 위치(길 따라 거리)
  final List<Offset> lights = []; // 신호등을 세울 교차로
  final List<MapDec> decor = [];
  double hubX = 1.4, hubFoot = 0; // 허브 건물 왼쪽, 바닥
  double cx0 = 0, cFoot = 0; // 센터 건물 왼쪽, 바닥
  Offset courierHome = Offset.zero; // 배달 차량이 기다리는 보도 칸 중심
  Rect? landmark; // 랜드마크(공원·광장) 블록 (칸 좌표), 없을 수도 있음

  RegionMap._(this.region, this.gw, this.gh)
    : cell = Uint8List(gw * gh),
      side = Uint8List(gw * gh);

  static final Map<int, RegionMap> _cache = {};

  /// 지역 r 의 지도 (한 번 만들어 둠)
  static RegionMap of(int r) => _cache[r] ??= _build(r);

  int at(int x, int y) =>
      (x < 0 || y < 0 || x >= gw || y >= gh) ? 0 : cell[y * gw + x];
  void set(int x, int y, int v) {
    if (x >= 0 && y >= 0 && x < gw && y < gh) cell[y * gw + x] = v;
  }

  bool nearPath(double x, double y) {
    final cx = x.floor(), cy = y.floor();
    for (var dy = -1; dy <= 0; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (at(cx + dx, cy + dy) != 0) return true;
      }
    }
    return false;
  }

  // ---- 길이·운행 시간 ----
  static double pathLen(List<Offset> p) {
    var s = 0.0;
    for (var i = 0; i + 1 < p.length; i++) {
      s += (p[i + 1] - p[i]).distance;
    }
    return s;
  }

  double get trunkLen => pathLen(trunk);

  /// 간선 편도 시간(초): 도로 길이 x 1칸당 시간
  double get tripSec => trunkLen * Cfg.trunkSecPerTile;

  /// 배달 k 번 편도 시간(초)
  double deliverSec(int k) =>
      max(4.0, pathLen(courier[k % courier.length]) * Cfg.courierSecPerTile);

  double get avgDeliverSec {
    if (courier.isEmpty) return 8;
    var s = 0.0;
    for (var k = 0; k < courier.length; k++) {
      s += deliverSec(k);
    }
    return s / courier.length;
  }

  // ======================================================================
  //                               만들기
  // ======================================================================
  static RegionMap _build(int r) {
    final (gw, gh) = Cfg.regionSize[r];
    final m = RegionMap._(r, gw, gh);
    final rnd = Random(Cfg.regionSeed[r]);
    // 바다(항구): 지도 위쪽 띠. 땅은 그 아래 전체 폭
    final sea = Cfg.regionSea[r];
    final land = gw;
    for (var y = 0; y < sea; y++) {
      for (var x = 0; x < gw; x++) {
        m.set(x, y, 3);
      }
    }
    final (sx, sy) = Cfg.regionGrid[r];

    // 1) 큰길 격자 (세로선 xs, 가로선 ys). 맨 아래 가로선이 허브 앞을 지난다
    final xs = <int>[];
    for (var x = 9; x < land - 6; x += sx + rnd.nextInt(3) - 1) {
      xs.add(x);
    }
    final ys = <int>[];
    for (var y = gh - 4; y > 5 + sea; y -= sy + rnd.nextInt(3) - 1) {
      ys.add(y);
    }
    ys.sort();
    final nodes = [
      for (final x in xs)
        for (final y in ys) (x, y),
    ];
    var edges = <((int, int), (int, int))>{};
    for (var i = 0; i < xs.length; i++) {
      for (var j = 0; j < ys.length; j++) {
        if (i + 1 < xs.length) edges.add(((xs[i], ys[j]), (xs[i + 1], ys[j])));
        if (j + 1 < ys.length) edges.add(((xs[i], ys[j]), (xs[i], ys[j + 1])));
      }
    }
    Map<(int, int), List<(int, int)>> adjOf(Set<((int, int), (int, int))> es) {
      final adj = {for (final n in nodes) n: <(int, int)>[]};
      for (final (a, b) in es) {
        adj[a]!.add(b);
        adj[b]!.add(a);
      }
      return adj;
    }

    bool connected(Set<((int, int), (int, int))> es) {
      final adj = adjOf(es);
      final seen = {nodes.first};
      final q = [nodes.first];
      while (q.isNotEmpty) {
        for (final n in adj[q.removeLast()]!) {
          if (seen.add(n)) q.add(n);
        }
      }
      return seen.length == nodes.length;
    }

    // 2) 지역마다 큰길 일부를 빼서 모양을 다르게 (모든 교차로는 이어진 채로)
    final cut = Cfg.regionRoadCut[r];
    for (final e in edges.toList()) {
      if (rnd.nextDouble() < cut) {
        final trial = {...edges}..remove(e);
        if (connected(trial)) edges = trial;
      }
    }
    final adj = adjOf(edges);
    final s0 = (xs.first, ys.last);

    // 3) 센터 자리 + 간선 경로: 목표 길이에 가장 가까운 단순 경로
    int rightOf(int x) {
      final i = xs.indexOf(x);
      return (i + 1 < xs.length ? xs[i + 1] : land) - x;
    }

    int above(int y) {
      final j = ys.indexOf(y);
      return y - (j > 0 ? ys[j - 1] : sea);
    }

    final target = Cfg.regionTrunkTarget[r];
    int dist((int, int) a, (int, int) b) =>
        (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();
    (int, List<(int, int)>)? walk((int, int) goal, int tries) {
      (int, List<(int, int)>)? best;
      for (var t = 0; t < tries; t++) {
        final path = [s0];
        final seen = {s0};
        var length = 0;
        var ok = false;
        for (var step = 0; step < 200; step++) {
          final c = path.last;
          if (c == goal) {
            ok = true;
            break;
          }
          final nb = adj[c]!.where((n) => !seen.contains(n)).toList();
          if (nb.isEmpty) break;
          final far = length + dist(c, goal) < target;
          final keys = {
            for (final n in nb)
              n: dist(n, goal) + rnd.nextDouble() * (far ? 40 : 3),
          };
          nb.sort((a, b) => keys[a]!.compareTo(keys[b]!));
          final n = nb.first;
          length += dist(n, c);
          path.add(n);
          seen.add(n);
        }
        if (ok &&
            (best == null ||
                (length - target).abs() < (best.$1 - target).abs())) {
          best = (length, path);
        }
      }
      return best;
    }

    (int, List<(int, int)>)? bestPath;
    (int, int)? goal;
    for (final n in nodes) {
      if (n == s0 || rightOf(n.$1) < 8 || above(n.$2) < 7) continue;
      final b = walk(n, 100);
      if (b != null &&
          (bestPath == null ||
              (b.$1 - target).abs() < (bestPath.$1 - target).abs())) {
        bestPath = b;
        goal = n;
      }
    }
    goal ??= nodes.last;
    final tpath = bestPath?.$2 ?? [s0, goal];
    m.trunk
      ..add(Offset(5, ys.last.toDouble()))
      ..addAll([
        for (final n in tpath) Offset(n.$1.toDouble(), n.$2.toDouble()),
      ]);
    final tEdges = <((int, int), (int, int))>{};
    for (var i = 0; i + 1 < tpath.length; i++) {
      tEdges
        ..add((tpath[i], tpath[i + 1]))
        ..add((tpath[i + 1], tpath[i]));
    }

    // 4) 차도 그리기 (2칸 폭). 간선이 아닌 차도는 side 에 표시
    void road((int, int) a, (int, int) b, bool isSide) {
      void mark(int x, int y) {
        if (x < 0 || y < 0 || x >= gw || y >= gh || m.at(x, y) == 3) return;
        m.set(x, y, 1);
        if (isSide) m.side[y * gw + x] = 1;
      }

      if (a.$2 == b.$2) {
        for (var x = min(a.$1, b.$1) - 1; x <= max(a.$1, b.$1); x++) {
          mark(x, a.$2 - 1);
          mark(x, a.$2);
        }
      } else {
        for (var y = min(a.$2, b.$2) - 1; y <= max(a.$2, b.$2); y++) {
          mark(a.$1 - 1, y);
          mark(a.$1, y);
        }
      }
    }

    // 지도 가장자리로 나가는 길 (위·왼쪽·오른쪽, 허브 쪽 왼쪽 아래 제외)
    final stubs = <((int, int), (int, int))>[
      // 위로 나가는 길: 바다가 있으면 부두(바다 바로 아래)까지
      for (final x in [for (var i = 1; i < xs.length; i += 2) xs[i]])
        ((x, sea == 0 ? 0 : sea + 3), (x, ys.first)),
      for (var j = 0; j < ys.length - 2; j += 2)
        ((0, ys[j]), (xs.first, ys[j])),
      for (var j = 0; j < ys.length; j += 2) ((xs.last, ys[j]), (gw, ys[j])),
    ];
    for (final e in edges) {
      final onTrunk = tEdges.contains(e);
      road(e.$1, e.$2, !onTrunk);
      if (!onTrunk) {
        m.roads.add([
          Offset(e.$1.$1.toDouble(), e.$1.$2.toDouble()),
          Offset(e.$2.$1.toDouble(), e.$2.$2.toDouble()),
        ]);
      }
    }
    for (final e in stubs) {
      road(e.$1, e.$2, true);
      m.roads.add([
        Offset(e.$1.$1.toDouble(), e.$1.$2.toDouble()),
        Offset(e.$2.$1.toDouble(), e.$2.$2.toDouble()),
      ]);
    }
    road((5, ys.last), s0, false);
    // 허브 (왼쪽 아래)와 앞마당
    m.hubFoot = gh - 3.0;
    for (var y = gh - 6; y < gh - 3; y++) {
      m.set(5, y, 1);
      m.set(6, y, 1);
    }
    final hubRect = Rect.fromLTRB(0, gh - 8.0, 8, gh.toDouble());
    m.cx0 = goal.$1 + 1.2;
    m.cFoot = goal.$2 - 1.0;

    // 5) 보도: 차도 옆 칸 (허브 자리·바다 제외)
    final walkCells = <int>[];
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        if (m.at(x, y) != 0 || hubRect.contains(Offset(x + 0.5, y + 0.5)))
          continue;
        // 바다 바로 옆에는 보도를 깔지 않음 (한 타일에 바다·보도가 섞이지 않게)
        if (sea > 0 && y <= sea) continue;
        if (m.at(x + 1, y) == 1 ||
            m.at(x - 1, y) == 1 ||
            m.at(x, y + 1) == 1 ||
            m.at(x, y - 1) == 1) {
          walkCells.add(y * gw + x);
        }
      }
    }
    for (final k in walkCells) {
      m.cell[k] = 2;
    }

    // 6) 건널목: 꺾이는 곳·교차로의 각 갈래 입구, 긴 구간 가운데. 양 끝이 보도일 때만
    final arms = {
      for (final n in nodes) n: [...adj[n]!],
    };
    for (final (a, b) in stubs) {
      final inner = arms.containsKey(a) ? a : b;
      arms[inner]?.add(inner == a ? b : a);
    }
    void addCross(List<(int, int)> cs, bool vertical) {
      final ends = vertical
          ? [
              (cs.first.$1, cs.map((c) => c.$2).reduce(min) - 1),
              (cs.first.$1, cs.map((c) => c.$2).reduce(max) + 1),
            ]
          : [
              (cs.map((c) => c.$1).reduce(min) - 1, cs.first.$2),
              (cs.map((c) => c.$1).reduce(max) + 1, cs.first.$2),
            ];
      if (ends.every((e) => m.at(e.$1, e.$2) == 2)) {
        for (final c in cs) {
          if (m.at(c.$1, c.$2) == 1) m.cross.add(c.$2 * gw + c.$1);
        }
      }
    }

    for (final (a, b) in [...edges, ...stubs]) {
      if (dist(a, b) < 9) continue;
      final mx = (a.$1 + b.$1) ~/ 2, my = (a.$2 + b.$2) ~/ 2;
      if (a.$2 == b.$2) {
        addCross([(mx, a.$2 - 1), (mx, a.$2)], true);
      } else {
        addCross([(a.$1 - 1, my), (a.$1, my)], false);
      }
    }
    for (final n in nodes) {
      final am = arms[n]!;
      if (am.length < 2) continue;
      final (x0, y0) = n;
      for (final o in am) {
        if (o.$1 > x0) {
          addCross([(x0 + 1, y0 - 1), (x0 + 1, y0)], true);
        } else if (o.$1 < x0) {
          addCross([(x0 - 2, y0 - 1), (x0 - 2, y0)], true);
        } else if (o.$2 < y0) {
          addCross([(x0 - 1, y0 - 2), (x0, y0 - 2)], false);
        } else {
          addCross([(x0 - 1, y0 + 1), (x0, y0 + 1)], false);
        }
      }
    }

    // 7) 블록과 동네: 센터에서 가까운 블록부터 동네로, 블록 아래쪽 보도 위에 집 (문이 차도를 봄)
    final bx = [0, ...xs, land];
    final by = [sea, ...ys, gh];
    final blocks = <Rect>[];
    for (var i = 0; i + 1 < bx.length; i++) {
      for (var j = 0; j + 1 < by.length; j++) {
        blocks.add(
          Rect.fromLTRB(
            bx[i] + 1.0,
            by[j] + 1.0,
            bx[i + 1] - 1.0,
            by[j + 1] - 1.0,
          ),
        );
      }
    }
    final centerRect = Rect.fromLTWH(m.cx0 - 0.5, m.cFoot - 5, 6.5, 5.5);
    final cpt = Offset(m.cx0 + 2, m.cFoot - 2);
    final cand = blocks
        .where(
          (b) =>
              !b.overlaps(centerRect) &&
              !b.overlaps(hubRect) &&
              b.width >= 5 &&
              b.height >= 5,
        )
        .toList();
    final key = {
      for (final b in cand) b: (b.center - cpt).distance + rnd.nextDouble() * 6,
    };
    cand.sort((a, b) => key[a]!.compareTo(key[b]!));
    // 분위기 블록은 동네로 쓰지 않고 남김: 항구는 바닷가 줄, 산업단지는 센터에서 먼 블록 몇 개
    final style = Cfg.regionStyle[r];
    final moodBlocks = <Rect>{
      if (style == 'harbor') ...(cand.where((b) => b.top <= sea + 2).toList()
        ..sort((a, b) => b.left.compareTo(a.left))).take(2),
      if (style == 'industrial') ...cand.reversed.take(3),
    };
    final towns = cand.where((b) => !moodBlocks.contains(b)).take(Cfg.regionTowns[r]).toList();
    // 랜드마크 자리: 동네·분위기 블록이 아닌 빈 블록 중 센터에 가장 가까운 곳 (평판이 오르면 공원 → 광장)
    final spare = cand.where((b) => !moodBlocks.contains(b) && !towns.contains(b)).toList();
    if (spare.isNotEmpty) m.landmark = spare.first;
    final pool = housePool[r % housePool.length];
    var hi = rnd.nextInt(pool.length);
    // 높은 동네 블록은 가운데에 골목을 하나 내서 집 줄을 늘림 (양옆 보도와 이어짐)
    for (final b in towns) {
      if (b.height < 9) continue;
      final row = (b.top + b.height / 2).toInt() + 1;
      for (var x = b.left.toInt(); x <= b.right.toInt(); x++) {
        if (m.at(x, row) == 0) m.set(x, row, 2);
      }
    }
    for (final b in towns) {
      // 블록 안의 보도 줄 (아래쪽 보도, 가운데 골목) 위에 집
      final rows = <int>[
        for (var yy = b.bottom.toInt(); yy > b.top; yy--)
          if (m.at(b.left.toInt() + 2, yy) == 2 &&
              m.at(b.right.toInt() - 2, yy) == 2)
            yy,
      ];
      for (final row in rows) {
        for (var x = b.left + 1.6; x < b.right - 0.6;) {
          var ok = m.at(x.toInt(), row) == 2;
          for (var yy = row - 3; yy < row && ok; yy++) {
            for (var xx = (x - 1).floor(); xx <= (x + 0.99).floor(); xx++) {
              if (yy < 0 || m.at(xx, yy) != 0) ok = false;
            }
          }
          if (ok) {
            m.houses.add(MapHouse(x, row.toDouble(), pool[hi++ % pool.length]));
            x += 2.3;
          } else {
            x += 0.5;
          }
        }
      }
    }

    // 8) 배달 길: 센터 문에서 가장 가까운 보도 → 집 앞 보도 (보도·건널목만)
    final door = Offset(m.cx0 + 2.2, m.cFoot);
    var start = walkCells.isEmpty ? 0 : walkCells.first;
    var sd = 1e9;
    for (final k in walkCells) {
      final d = (Offset(k % gw + 0.5, k ~/ gw + 0.5) - door).distance;
      if (d < sd) {
        sd = d;
        start = k;
      }
    }
    m.courierHome = Offset(start % gw + 0.5, start ~/ gw + 0.5);
    for (var hk = 0; hk < m.houses.length; hk++) {
      final h = m.houses[hk];
      final cells = _bfs(m, start, h.y.toInt() * gw + h.x.floor());
      if (cells == null) continue;
      final path = <Offset>[];
      final stops = <double>[];
      var d = 0.0;
      var inCross = false;
      for (final c in cells) {
        final p = Offset(c % gw + 0.5, c ~/ gw + 0.5);
        if (path.isNotEmpty) d += (p - path.last).distance;
        final isCross = m.cross.contains(c);
        if (isCross && !inCross) stops.add(max(0.0, d - 0.6));
        inCross = isCross;
        if (path.length >= 2) {
          final a = path[path.length - 2], b = path.last;
          if ((a.dx == b.dx && b.dx == p.dx) || (a.dy == b.dy && b.dy == p.dy))
            path.removeLast();
        }
        path.add(p);
      }
      path.add(Offset(h.x, h.y + 0.5));
      m.deliver.add(hk);
      m.courier.add(path);
      m.courierStops.add(stops);
    }
    if (m.courier.isEmpty) {
      m.courier.add([m.courierHome, m.courierHome.translate(1, 0)]);
      m.courierStops.add([]);
    }

    // 9) 간선의 교차로·건널목: 정차 지점과 신호등 (가까이 붙은 정차는 하나로)
    bool sideAt(int x, int y) =>
        x >= 0 && y >= 0 && x < gw && y < gh && m.side[y * gw + x] == 1;
    final tl = m.trunkLen;
    var run = false, hitRun = false;
    var lastStop = -10.0;
    Offset? lastLight;
    for (var d = 0.5; d < tl; d += 0.5) {
      final p = _pointAt(m.trunk, d);
      final q = _pointAt(m.trunk, min(tl, d + 0.01));
      final horiz = (q.dy - p.dy).abs() < (q.dx - p.dx).abs();
      final x = p.dx.floor(), y = p.dy.floor();
      final hit = horiz ? (sideAt(x, y - 2) || sideAt(x, y + 1)) : (sideAt(x - 2, y) || sideAt(x + 1, y));
      final cw = m.cross.contains(y * gw + x) ||
          m.cross.contains(y * gw + x - 1) ||
          m.cross.contains((y - 1) * gw + x) ||
          m.cross.contains((y - 1) * gw + x - 1);
      final on = hit || cw;
      if (on && !run && d > 2 && d - lastStop > 4) {
        m.trunkStops.add(max(0.0, d - 1.4));
        lastStop = d;
      }
      // 신호등은 정차와 따로: 다른 차도가 붙는 교차로마다 하나
      if (hit && !hitRun && (lastLight == null || (p - lastLight).distance > 3)) {
        m.lights.add(p);
        lastLight = p;
      }
      run = on;
      hitRun = hit;
    }

    // 10) 소품·장식
    final blocked = <Rect>[
      hubRect.inflate(0.5),
      Rect.fromLTRB(m.cx0 - 0.5, m.cFoot - 5.4, m.cx0 + 6.4, m.cFoot + 0.3),
      for (final h in m.houses)
        Rect.fromLTRB(h.x - 1.4, h.y - 3.0, h.x + 1.4, h.y + 0.2),
    ];
    bool place(
      String k,
      double x,
      double y, {
      double w = 1.0,
      double h = 1.0,
      int pad = 1,
      bool water = false,
    }) {
      for (var cy = (y - h).floor(); cy <= y.floor(); cy++) {
        for (
          var cx = (x - w / 2).floor() - pad;
          cx <= (x + w / 2).floor() + pad;
          cx++
        ) {
          final v = m.at(cx, cy);
          if (cy < 1 || cy >= gh || cx < 0 || cx >= gw) return false;
          if (water ? v != 3 : v != 0) return false;
        }
      }
      final area = Rect.fromLTRB(x - w / 2, y - h, x + w / 2, y);
      for (final b in blocked) {
        if (b.overlaps(area)) return false;
      }
      for (final d in m.decor) {
        if ((d.x - x).abs() < (w + 1) / 2 && (d.y - y).abs() < 0.9)
          return false;
      }
      m.decor.add(MapDec(k, x, y));
      return true;
    }

    // 교차로 모서리 신호등
    for (final p in m.lights) {
      for (final o in const [
        Offset(2.2, -1.6),
        Offset(-2.2, -1.6),
        Offset(2.2, 2.6),
        Offset(-2.2, 2.6),
      ]) {
        if (place('light', p.dx + o.dx, p.dy + o.dy, pad: 0)) break;
      }
    }
    // 동네가 아닌 블록: 지역 분위기대로 채움
    for (final b in blocks) {
      if (towns.contains(b) || b.overlaps(centerRect) || b.overlaps(hubRect))
        continue;
      // 블록 안쪽 = 둘레 보도 한 칸을 뺀 잔디. 큰 소품부터 바닥에 붙여 놓음
      final inner = b.deflate(1.0);
      if (inner.width < 2 || inner.height < 2) continue;
      final c = inner.center;
      final foot = inner.bottom - 0.05;
      var mood = false;
      switch (style) {
        case 'harbor':
          if (b.top <= sea + 2) {
            // 바닷가 블록: 크레인 + 컨테이너 줄
            mood = true;
            place('p:crane', inner.right - 1.4, foot, w: 2.6, h: 2.6, pad: 0);
            for (var row = 0; row < 3; row++) {
              for (var x = inner.left + 0.9; x < inner.right - 3.0; x += 1.8) {
                place('p:container', x, foot - row * 1.0, w: 1.6, h: 0.9, pad: 0);
              }
            }
          }
        case 'industrial':
          if (moodBlocks.contains(b)) {
            mood = true;
            place('p:factory', c.dx, foot, w: 3.0, h: 2.6, pad: 0);
            place('p:tank', inner.left + 0.8, foot, w: 1.0, h: 1.0, pad: 0);
            place('p:tank', inner.right - 0.8, foot, w: 1.0, h: 1.0, pad: 0);
          }
        case 'newtown':
          place('p:fountain', c.dx, c.dy + 0.8, w: 2.0, h: 1.6, pad: 0);
          place('bench', c.dx - 2.0, c.dy + 0.8, pad: 0);
          place('bench', c.dx + 2.0, c.dy + 0.8, pad: 0);
        case 'commercial':
          place('p:billboard', c.dx, c.dy + 0.8, w: 1.8, pad: 0);
        default:
          break;
      }
      // 분위기 블록에는 나무를 채우지 않음
      if (mood) blocked.add(inner);
    }
    // 바다에 배
    if (sea > 0) {
      for (var k = 0; k < 4; k++) {
        place(
          'p:boat',
          4 + k * (gw - 8) / 3,
          sea - 1.0,
          w: 2.0,
          pad: 0,
          water: true,
        );
      }
    }
    // 차도변 6칸마다 가로등·지역 소품
    final roadKeys = roadside[r % roadside.length];
    var ri = 0;
    for (final pts in [m.trunk, ...m.roads]) {
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        final len = (b - a).distance;
        for (var d = 3.0; d < len - 1; d += 6) {
          final q = Offset.lerp(a, b, d / len)!;
          final k = roadKeys[ri % roadKeys.length];
          final ok = a.dy == b.dy
              ? (place(k, q.dx, q.dy - 2.2) || place(k, q.dx, q.dy + 3.2))
              : (place(k, q.dx + 2.8, q.dy + 0.5) ||
                    place(k, q.dx - 2.8, q.dy + 0.5));
          if (ok) ri++;
        }
      }
    }
    // 나무·덤불·꽃
    final kinds = decorKinds[r % decorKinds.length];
    final want = gw * gh ~/ 12;
    var tries = 0;
    var placed = 0;
    while (placed < want && tries < want * 25) {
      tries++;
      final x = 0.6 + rnd.nextDouble() * (gw - 1.2);
      final y = 1.6 + rnd.nextDouble() * (gh - 1.8);
      if (m.nearPath(x, y)) continue;
      if (blocked.any(
        (b) => b.contains(Offset(x, y)) || b.contains(Offset(x, y - 1)),
      ))
        continue;
      if (m.decor.any((d) => (d.x - x).abs() < 1.2 && (d.y - y).abs() < 0.9))
        continue;
      m.decor.add(MapDec(kinds[rnd.nextInt(kinds.length)], x, y));
      placed++;
    }
    m.decor.sort((a, b) => a.y.compareTo(b.y));
    return m;
  }

  /// 보도·건널목 칸만 지나는 최단 길 (칸 번호 목록). 못 찾으면 null
  static List<int>? _bfs(RegionMap m, int s, int goal) {
    final gw = m.gw, n = m.gw * m.gh;
    bool ok(int k) => m.cell[k] == 2 || m.cross.contains(k);
    if (!ok(goal)) return null;
    final prev = Int32List(n)..fillRange(0, n, -1);
    prev[s] = s;
    final q = <int>[s];
    for (var qi = 0; qi < q.length; qi++) {
      final c = q[qi];
      if (c == goal) break;
      final x = c % gw;
      for (final nk in [
        if (x + 1 < gw) c + 1,
        if (x > 0) c - 1,
        c + gw,
        c - gw,
      ]) {
        if (nk < 0 || nk >= n || prev[nk] != -1 || !ok(nk)) continue;
        prev[nk] = c;
        q.add(nk);
      }
    }
    if (prev[goal] == -1) return null;
    final out = <int>[];
    for (var c = goal; ; c = prev[c]) {
      out.add(c);
      if (c == s) break;
    }
    return out.reversed.toList();
  }

  static Offset _pointAt(List<Offset> p, double dist) {
    var d = dist;
    for (var i = 0; i + 1 < p.length; i++) {
      final seg = (p[i + 1] - p[i]).distance;
      if (d <= seg || i + 2 == p.length) {
        final f = seg <= 0 ? 0.0 : (d / seg).clamp(0.0, 1.0).toDouble();
        return Offset.lerp(p[i], p[i + 1], f)!;
      }
      d -= seg;
    }
    return p.last;
  }

  // ---- 지역 분위기별 그림 이름 ----
  /// 집 모양 ('house1~3' 가게, 'd' 단독주택, 'v' 빌라, 'apt' 아파트)
  static const List<List<String>> housePool = [
    ['d0', 'd1', 'd2', 'd3', 'd4', 'd7'], // 주택가
    ['house1', 'v0', 'house3', 'v1', 'house2', 'v2'], // 상가
    ['d8', 'v1', 'd9', 'd5', 'v0', 'd11'], // 항구
    ['v2', 'd5', 'v0', 'd10', 'v1', 'd6'], // 산업단지
    ['apt', 'v0', 'apt', 'v1', 'apt', 'v2'], // 신도시
  ];

  /// 차도변 소품 ('p:이름'은 지도 소품, 나머지는 장식 폴더)
  static const List<List<String>> roadside = [
    ['lamp', 'p:mailbox', 'lamp', 'bench'],
    ['lamp', 'p:busstop', 'p:vending', 'p:billboard'],
    ['lamp', 'p:container', 'sign', 'lamp'],
    ['lamp', 'cone', 'pallet', 'p:hwsign'],
    ['lamp', 'p:busstop', 'bench', 'lamp'],
  ];
  static const List<List<String>> decorKinds = [
    ['tree', 'tree2', 'bush', 'flower', 'tree', 'bush', 'tree'],
    ['tree2', 'bush', 'bush', 'flower', 'lamp'],
    ['tree', 'bush', 'tree2', 'bush'],
    ['bush', 'tree2', 'bush', 'tree'],
    ['tree', 'tree2', 'flower', 'tree', 'flower', 'bush'],
  ];
}

class MapHouse {
  final double x, y; // 발 밑(아래 가운데)
  final String key;
  MapHouse(this.x, this.y, this.key);
}

class MapDec {
  final String key;
  final double x, y; // 발 밑(아래 가운데) 칸 좌표
  MapDec(this.key, this.x, this.y);
}
