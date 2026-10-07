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
  static final List<Deco> items = _build();

  static List<Deco> _build() {
    final rnd = Random(2024);
    final out = <Deco>[];
    final big = Cfg.areas.last; // 최대로 확장한 창고 영역
    bool busy(double x, double y, [double pad = 0]) {
      // 도로·마당·최대 창고 영역과 겹치면 장식을 두지 않는다
      final r = Rect.fromLTWH(x - 1, y - 2, 2, 3).inflate(pad);
      return r.overlaps(Cfg.road.inflate(1)) ||
          r.overlaps(Cfg.yard) ||
          r.overlaps(big.inflate(1));
    }

    // 위쪽 줄: 이웃 가게/집 (북쪽 인도 뒤)
    const houses = ['house1', 'house2', 'house3'];
    var hx = 0.5;
    var i = 0;
    while (hx < Cfg.cols - 4) {
      if (!busy(hx + 2, 5.2)) {
        out.add(Deco(houses[i % 3], hx + 2, 5.2, 4));
      }
      hx += 4.5;
      i++;
    }
    // 아래쪽 줄
    hx = 1.5;
    while (hx < Cfg.cols - 4) {
      if (!busy(hx + 2, Cfg.rows - 0.4)) {
        out.add(Deco(houses[(i + 1) % 3], hx + 2, Cfg.rows - 0.4, 4));
      }
      hx += 4.5;
      i++;
    }

    // 가로등: 도로 오른쪽 인도를 따라
    for (var y = 3.0; y < Cfg.rows; y += 6) {
      out.add(Deco('lamp', Cfg.road.right + 0.5, y, 1));
    }
    // 신호등: 도로 양끝 횡단보도 옆
    out.add(Deco('light', Cfg.road.left - 0.4, 7.0, 1));
    out.add(Deco('light', Cfg.road.right + 0.4, 29.0, 1));

    // 나무·덤불·꽃: 남는 풀밭에 흩뿌림
    for (var gy = 6; gy < Cfg.rows - 1; gy++) {
      for (var gx = 0; gx < Cfg.cols; gx++) {
        final x = gx + 0.5, y = gy + 1.0;
        if (busy(x, y, 0.2)) continue;
        final r = rnd.nextDouble();
        if (r < 0.05) {
          out.add(Deco('tree', x, y, 2));
        } else if (r < 0.10) {
          out.add(Deco('bush', x, y, 1));
        } else if (r < 0.13) {
          out.add(Deco('flower', x, y, 1));
        } else if (r < 0.135) {
          out.add(Deco('bench', x, y, 1));
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
