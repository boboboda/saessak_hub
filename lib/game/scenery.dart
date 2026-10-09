import 'dart:math';
import 'dart:ui';

import 'config.dart';

/// 배경 장식 한 개. (x, y)는 발(바닥 중앙) 타일 좌표.
class Deco {
  final String key;
  final double x, y;
  final double wTiles; // 그림 가로 칸 수
  const Deco(this.key, this.x, this.y, this.wTiles);
}

/// 월드 장식 배치. 한 번 만들어 두고 계속 씀 (고정 시드 → 항상 같은 모습).
class Scenery {
  /// 인도(보도) 길. 타일 좌표 사각형. 창고 입구로 가는 길은 창고 크기에 따라 달라서 따로 그림.
  static final List<Rect> paths = [
    Rect.fromLTWH(0, 6, Cfg.road.left, 1), // 위쪽 큰길
    Rect.fromLTWH(0, 29, Cfg.road.left, 1), // 아래쪽 큰길
    Rect.fromLTWH(0, 6, 2, 24), // 왼쪽 세로길
  ];

  /// 길 위에 서도 되는 장식 (가로등·신호등·벤치·표지판)
  /// 서 있는 칸을 못 지나가는 장식 (직원·손님 길찾기에서 막음)
  static const Set<String> solid = {'lamp', 'light', 'sign', 'tree', 'tree2', 'cone', 'pallet', 'bench'};

  static const Set<String> onPath = {'lamp', 'light', 'bench', 'sign'};

  // ---- 장식 종류별로 놓을 수 있는 바닥 ----
  // grass: 풀밭, walk: 인도(보도블록·길), yard: 도크 마당, road: 차도
  static const Map<String, Set<String>> allowed = {
    'tree': {'grass'}, 'tree2': {'grass'}, 'bush': {'grass'}, 'flower': {'grass'},
    'house1': {'grass'}, 'house2': {'grass'}, 'house3': {'grass'},
    'lamp': {'grass', 'walk'}, 'light': {'grass', 'walk'}, 'sign': {'grass', 'walk'}, 'bench': {'grass', 'walk'},
    'cone': {'yard'}, 'pallet': {'yard'},
  };

  /// 오른쪽 인도에서 행인이 걷는 가운데 통로 (가로)
  static final Rect walkLane = Rect.fromLTRB(Cfg.road.right + 1.0, 0, Cfg.road.right + 2.3, Cfg.rows.toDouble());

  /// 도크 마당 왼쪽 위 '④ 출고 도크' 이름표 자리 (장식이 가리지 않게)
  static final Rect yardLabel = Rect.fromLTWH(Cfg.yard.left, Cfg.yard.top, 2.8, 1.0);

  /// (x, y) 칸의 바닥 종류. 창고 입구 길은 창고 크기에 따라 달라서 그릴 때 따로 거름
  static String surface(double x, double y) {
    final p = Offset(x, y - 0.01); // 발끝이 칸 경계에 걸리면 위 칸으로
    if (Cfg.road.contains(p)) return 'road';
    if (Cfg.yard.contains(p)) return 'yard';
    if (x >= Cfg.road.right) return 'walk';
    for (final q in paths) {
      if (q.contains(p)) return 'walk';
    }
    return 'grass';
  }

  /// 이 장식을 이 자리에 둬도 되는지: 바닥 종류 + 인도 가운데 통로 + 마당 이름표
  static bool fits(Deco d) {
    final ok = allowed[d.key];
    if (ok != null && !ok.contains(surface(d.x, d.y))) return false;
    final foot = Rect.fromCenter(center: Offset(d.x, d.y - 0.3), width: d.wTiles.clamp(0.6, 1.2), height: 0.6);
    if (foot.overlaps(walkLane)) return false;
    if (d.key == 'cone' || d.key == 'pallet') {
      final img = Rect.fromLTRB(d.x - 0.5, d.y - 1.2, d.x + 0.5, d.y);
      if (img.overlaps(yardLabel)) return false;
    }
    return true;
  }

  static final List<Deco> items = _build();

  static List<Deco> _build() {
    final rnd = Random(2024);
    final out = <Deco>[];
    final reserved = <Rect>[...paths];

    bool busy(double x, double y, [double pad = 0]) {
      // 도로·마당·길·건물 자리와 겹치면 두지 않는다 (창고 자리는 그릴 때 현재 창고와 겹치면 뺌)
      final r = Rect.fromLTWH(x - 1, y - 2, 2, 3).inflate(pad);
      if (r.overlaps(Cfg.road.inflate(1)) || r.overlaps(Cfg.yard)) return true;
      for (final q in reserved) {
        if (r.overlaps(q)) return true;
      }
      return false;
    }

    void house(String key, double x, double y) {
      out.add(Deco(key, x, y, 4));
      reserved.add(Rect.fromLTRB(x - 2.2, y - 3.4, x + 2.2, y + 0.2));
    }

    // 건물은 창고를 최대로 확장해도 안 겹치는 바깥(위쪽 블록)에만 둔다.
    // 확장 가능한 자리는 아래의 나무·덤불·꽃으로만 채움 (확장하면 덮여서 사라짐)
    const houses = ['house1', 'house2', 'house3'];
    const wTiles = {'house1': 3.4, 'house2': 3.0, 'house3': 3.3};
    // 위쪽 큰길을 따라 한 줄로 (길에 앞면이 닿게). 건물 사이 간격은 들쭉날쭉, 틈에는 작은 나무
    var hx = 2.6;
    var i = 0;
    while (true) {
      final k = houses[i++ % 3];
      final w = wTiles[k]!;
      if (hx + w > Cfg.road.left - 0.8) break;
      house(k, hx + w / 2, 6.0);
      hx += w + 0.4 + rnd.nextDouble() * 1.4;
      if (rnd.nextBool() && hx + 1 < Cfg.road.left - 1) {
        out.add(Deco(rnd.nextBool() ? 'bush' : 'flower', hx - 0.5, 6.0, 1));
      }
    }
    // 건물 뒤(맨 위)는 나무 울타리처럼
    for (var tx = 1.0; tx < Cfg.road.left; tx += 1.8 + rnd.nextDouble() * 1.5) {
      out.add(Deco(rnd.nextBool() ? 'tree' : 'tree2', tx, 2.4 + rnd.nextDouble() * 0.8, 2));
    }

    // 가로등: 큰길·왼쪽 길·도로 인도를 따라. 걷는 길 위가 아니라 길 바로 옆 풀밭에 세움 (가로등 칸은 못 지나감)
    void lamp(double x, double y) {
      out.add(Deco('lamp', x, y, 1));
      reserved.add(Rect.fromLTRB(x - 0.6, y - 1.2, x + 0.6, y + 0.3));
    }
    for (var x = 4.0; x < Cfg.road.left; x += 6) {
      lamp(x, 7.85);
      lamp(x, 30.85);
    }
    for (var y = 12.0; y < 29; y += 6) {
      lamp(2.4, y);
    }
    for (var y = 3.0; y < Cfg.rows; y += 6) {
      lamp(Cfg.road.right + 0.5, y); // 오른쪽 인도의 차도 쪽 끝 (행인은 안쪽으로 걸음)
    }
    // 신호등 + 표지판: 도로 횡단보도 옆
    out.add(Deco('light', Cfg.road.left - 0.4, 7.0, 1));
    out.add(Deco('light', Cfg.road.right + 0.4, 29.0, 1));
    out.add(Deco('sign', Cfg.road.left - 0.5, 30.0, 1));
    // 길가 벤치
    out.add(Deco('bench', 11.0, 7.9, 1));
    out.add(Deco('bench', 19.0, 30.9, 1));

    // 나무·덤불·꽃: 남는 풀밭에 흩뿌림
    for (var gy = 7; gy < Cfg.rows - 1; gy++) {
      for (var gx = 0; gx < Cfg.cols; gx++) {
        final x = gx + 0.5, y = gy + 1.0;
        if (busy(x, y, 0.2)) continue;
        final r = rnd.nextDouble();
        final park = gy >= 30; // 아래쪽은 공원처럼 빽빽하게
        if (r < (park ? 0.10 : 0.04)) {
          out.add(Deco(rnd.nextBool() ? 'tree' : 'tree2', x, y, 2));
        } else if (r < (park ? 0.18 : 0.08)) {
          out.add(Deco('bush', x, y, 1));
        } else if (r < (park ? 0.26 : 0.11)) {
          out.add(Deco('flower', x, y, 1));
        }
      }
    }
    // 마당: 라바콘·팔레트 (마당 구석, 이름표 아래. 도크 앞 주차칸에 걸리면 그릴 때 숨김)
    out.add(Deco('cone', Cfg.yard.right - 0.7, Cfg.yard.top + 1.1, 1));
    out.add(Deco('cone', Cfg.yard.left + 1.5, Cfg.yard.bottom - 0.3, 1));
    out.add(Deco('pallet', Cfg.yard.right - 1.2, Cfg.yard.bottom - 0.3, 1));
    // 규칙에 안 맞는 장식(차도 위 상자, 보도블록 위 나무 등)은 뺌
    out.removeWhere((d) => !fits(d));
    out.sort((a, b) => a.y.compareTo(b.y));
    return out;
  }
}
