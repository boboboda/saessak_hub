import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

HubGame _game() {
  final g = HubGame();
  g.buildings.add(Building(Cfg.types.firstWhere((t) => t.id == 'counter'), 10, 10));
  return g;
}

void main() {
  test('하루 사건 시각은 1~2개, 하루 구간 안', () {
    for (var i = 0; i < 50; i++) {
      final g = _game()..planEvents();
      expect(g.evtTimes.length, inInclusiveRange(1, 2));
      for (final t in g.evtTimes) {
        expect(t, inInclusiveRange(Cfg.evtWindow[0], Cfg.evtWindow[1]));
      }
    }
  });

  test('시각이 되면 저절로 팝업, 같은 사건은 7일 안에 다시 안 뜸', () {
    final g = _game()..planEvents();
    g.dayTimer = Cfg.evtWindow[1] + 1;
    g.updateEvents(0);
    expect(g.evtNow, isNotNull);
    final k = g.evtNow!.kind;
    g.chooseEvent(1);
    g.evtLast[k] = g.day;
    g.day += Cfg.evtCooldownDays - 1;
    for (var i = 0; i < 40; i++) {
      g.evtNow = null;
      g.evtTimes
        ..clear()
        ..add(0);
      g.updateEvents(0);
      expect(g.evtNow?.kind, isNot(k));
    }
  });

  test('TV 취재 수락: 오늘 접수량 ×1.5, 하루가 끝나면 결과가 나고 사라짐', () {
    final g = _game();
    final base = g.intakeNow;
    g.openEvent(0);
    g.chooseEvent(0);
    expect(g.intakeNow, closeTo(base * Cfg.evtTvIntake, 1e-9));
    final notes = g.resolveEvents(g.day);
    expect(notes.single, contains('TV 취재'));
    expect(g.evts, isEmpty);
    // 끝나면 배수가 빠짐 (성공하면 명성 +50으로 접수량 구간은 오를 수 있음)
    expect(g.intakeNow, closeTo(Cfg.intakeBase(g.fame), 1e-9));
  });

  test('명절 특근: 3일간 월급 ×1.3', () {
    final g = _game();
    g.staff.add(Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100));
    g.openEvent(1);
    g.chooseEvent(0);
    expect(g.dailyWages, 130);
    expect(g.resolveEvents(g.day + 1), isEmpty); // 아직 안 끝남
    expect(g.resolveEvents(g.day + Cfg.evtRushDays - 1), isNotEmpty);
    expect(g.dailyWages, 100);
  });

  test('직원 다툼 놔두기: 두 직원 능률 −15%', () {
    final g = _game();
    final a = Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100);
    final b = Staff(2, 'b', 3, 3, 3, 3, 3, 0, 100);
    for (final s in [a, b]) {
      s.post = g.buildings.first;
      g.buildings.first.crew.add(s);
      g.staff.add(s);
    }
    final before = a.workRate;
    g.openEvent(2);
    g.chooseEvent(1);
    g.updateEvents(0);
    expect(a.workRate, closeTo(before * Cfg.evtFightSlow, 1e-9));
    expect(b.workRate, closeTo(before * Cfg.evtFightSlow, 1e-9));
  });

  test('대량 주문: 기한까지 배송하면 돈, 못 하면 명성 −30', () {
    final g = _game()..fame = 100;
    g.openEvent(3);
    final need = g.evtNow!.need;
    g.chooseEvent(0);
    g.delivered += need;
    final money = g.money;
    expect(g.resolveEvents(g.day + 1).single, contains('성공'));
    expect(g.money, money + need * Cfg.evtBulkPay);

    final f = _game()..fame = 100;
    f.openEvent(3);
    f.chooseEvent(0);
    expect(f.resolveEvents(f.day + 1).single, contains('실패'));
    expect(f.fame, 100 - Cfg.evtBulkFail);
  });

  test('폭염 버티기: 체력 소모 ×1.3, 에어컨이 있으면 절반', () {
    final g = _game();
    g.openEvent(4);
    g.chooseEvent(1);
    expect(g.evtDrain, closeTo(Cfg.evtHeatDrain, 1e-9));
    g.buildings.add(Building(Cfg.types.firstWhere((t) => t.id == 'aircon'), 20, 20));
    expect(g.evtDrain, closeTo(1 + (Cfg.evtHeatDrain - 1) / 2, 1e-9));
  });

  test('신입 특별 채용: 능력 4~5, 고용비 없음', () {
    final g = _game();
    g.openEvent(5);
    g.chooseEvent(0);
    final s = g.staff.single;
    for (final v in [s.speed, s.walk, s.kind, s.stamina, s.care]) {
      expect(v, inInclusiveRange(4, 5));
    }
    expect(s.hireCost, 0);
  });
}
