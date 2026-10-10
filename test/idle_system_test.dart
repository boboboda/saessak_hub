import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

void main() {
  test('대기 직원은 제자리 둘레를 어슬렁거리고, 배치되면 제자리로 돌아감', () {
    final g = HubGame();
    final s = Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100);
    g.staff.add(s);
    var moved = false;
    for (var i = 0; i < 1200; i++) {
      g.updateIdle(0.05); // 60초
      if (s.idleOff != Offset.zero) moved = true;
      expect(s.idleOff.dx.abs(), lessThanOrEqualTo(Cfg.idleRoamX + 1e-9));
      expect(s.idleOff.dy, inInclusiveRange(-Cfg.idleRoamUp - 1e-9, Cfg.idleRoamDown + 1e-9));
    }
    expect(moved, isTrue);
    expect(g.staffAt(Offset(g.idleSpot(s).dx * Cfg.tile, (g.idleSpot(s).dy - 0.45) * Cfg.tile)), s); // 지금 선 곳을 탭하면 고름

    final p = Building(Cfg.types.firstWhere((t) => t.id == 'pack'), 10, 10);
    g.buildings.add(p);
    g.assignTo(s, p);
    g.updateIdle(0.05);
    expect(s.idleOff, Offset.zero);
  });

  test('대기 직원끼리는 어슬렁거려도 몸이 겹치지 않음', () {
    final g = HubGame();
    for (var i = 0; i < 5; i++) {
      g.staff.add(Staff(i + 1, 'a$i', 3, 3, 3, 3, 3, 0, 100));
    }
    for (var i = 0; i < 2400; i++) {
      g.updateIdle(0.05);
      for (final a in g.staff) {
        for (final b in g.staff) {
          if (a.id < b.id) {
            // 처음 제자리 간격(0.9칸)보다 가까워질 수는 있어도, 서로 피하므로 겹치진 않음
            expect((g.idleSpot(a) - g.idleSpot(b)).distance, greaterThan(0.3));
          }
        }
      }
    }
  });
}
