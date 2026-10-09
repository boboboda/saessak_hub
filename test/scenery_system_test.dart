import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/scenery.dart';

void main() {
  test('장식 배치 규칙: 차도 위 장식 없음, 나무는 풀밭에만, 인도 가운데 통로 비움, 마당 이름표 안 가림', () {
    for (final d in Scenery.items) {
      final s = Scenery.surface(d.x, d.y);
      expect(s, isNot('road'), reason: '${d.key} (${d.x}, ${d.y})');
      if (const {'tree', 'tree2', 'bush', 'flower'}.contains(d.key)) {
        expect(s, 'grass', reason: '${d.key} (${d.x}, ${d.y})');
      }
      if (d.key == 'cone' || d.key == 'pallet') expect(s, 'yard');
      expect(d.x >= Cfg.road.right + 1.0 && d.x <= Cfg.road.right + 2.3, isFalse, reason: '${d.key} 통로');
    }
    expect(Scenery.items.where((d) => d.key == 'pallet'), isNotEmpty);
  });
}
