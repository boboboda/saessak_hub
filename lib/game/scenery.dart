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
  static const Set<String> onPath = {'lamp', 'light', 'bench', 'sign'};

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

    const houses = ['house1', 'house2', 'house3'];
    // 위쪽 큰길 뒤 줄 (길 바로 위에 앞면이 닿게)
    var i = 0;
    for (var x = 2.8; x < Cfg.road.left - 1; x += 4.6) {
      house(houses[i++ % 3], x, 6.0);
    }
    // 아래쪽 큰길 아래 줄
    for (var x = 4.0; x < Cfg.road.left - 1; x += 4.6) {
      house(houses[i++ % 3], x, Cfg.rows - 0.4);
    }
    // 창고 위쪽 동네 (창고를 확장하면 이 자리부터 덮여서 사라짐)
    for (var x = 5.0; x < Cfg.yard.left - 2; x += 5.2) {
      house(houses[i++ % 3], x, 11.4);
    }

    // 가로등: 큰길·왼쪽 길·도로 인도를 따라
    for (var x = 4.0; x < Cfg.road.left; x += 6) {
      out.add(Deco('lamp', x, 7.0, 1));
      out.add(Deco('lamp', x, 30.0, 1));
    }
    for (var y = 12.0; y < 29; y += 6) {
      out.add(Deco('lamp', 2.3, y, 1));
    }
    for (var y = 3.0; y < Cfg.rows; y += 6) {
      out.add(Deco('lamp', Cfg.road.right + 0.5, y, 1));
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
        if (r < 0.04) {
          out.add(Deco(rnd.nextBool() ? 'tree' : 'tree2', x, y, 2));
        } else if (r < 0.08) {
          out.add(Deco('bush', x, y, 1));
        } else if (r < 0.11) {
          out.add(Deco('flower', x, y, 1));
        }
      }
    }
    // 마당: 라바콘·팔레트
    out.add(Deco('cone', Cfg.yard.left + 1.5, Cfg.yard.top + 1.2, 1));
    out.add(Deco('cone', Cfg.yard.left + 1.5, Cfg.yard.bottom - 0.3, 1));
    out.add(Deco('pallet', Cfg.yard.left + 8, Cfg.yard.top + 1.5, 1));
    out.sort((a, b) => a.y.compareTo(b.y));
    return out;
  }
}
