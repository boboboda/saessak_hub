import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

BuildingType _t(String id) => Cfg.types.firstWhere((t) => t.id == id);

void main() {
  test('숨은 손님: 조건을 채워야 오고, 처음 오면 도감 + 명성, 하루 한 번까지', () {
    final g = HubGame();
    expect(g.guestCond(3), isFalse); // 꼬마 손님: 화분 3개
    for (var i = 0; i < 3; i++) {
      g.buildings.add(Building(_t('plant'), 2 + i * 2, 2));
    }
    expect(g.guestCond(3), isTrue);
    var got = -1;
    for (var i = 0; i < 200 && got < 0; i++) {
      got = g.pickGuest();
    }
    expect(got, 3);
    expect(g.rt.foundGuests, contains(3));
    expect(g.fame, Cfg.guestFoundFame);
    for (var i = 0; i < 100; i++) {
      expect(g.pickGuest(), -1); // 오늘은 이미 왔음
    }
  });

  test('이삿짐 센터 사장: 대형 택배 3건 + 2,000원', () {
    final g = HubGame();
    final cnt = Building(_t('counter'), 2, 2);
    final c = Customer(const Offset(3, 4), 0)..guest = 2;
    final m = g.money;
    g.guestServed(c, cnt);
    expect(cnt.outbox.where((p) => p.kind == 3).length, 3);
    expect(g.money, m + 2000);
  });

  test('유튜버: 다음 날 접수량 ×1.3', () {
    final g = HubGame();
    final base = g.intakeNow;
    g.guestServed(Customer(const Offset(3, 4), 0)..guest = 1, Building(_t('counter'), 2, 2));
    expect(g.intakeNow, closeTo(base, 1e-9)); // 오늘은 그대로
    g.day++;
    expect(g.intakeNow, closeTo(base * Cfg.guestStreamIntake, 1e-9));
  });

  test('숨은 직업: 두 직업 Lv5 직원만, 발견하면 도감에', () {
    final g = HubGame();
    final s = Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100)..job = 1..jobLv = 5;
    g.staff.add(s);
    expect(g.hiddenJobOk(s, 8), isFalse); // 접수원 기록 없음
    s.jobHist[0] = 5;
    expect(g.hiddenJobOk(s, 8), isTrue);
    g.updateBook();
    expect(g.rt.seenJobs, contains(8));
    g.changeJob(s, 8);
    expect(s.job, 8);
    expect(s.canPromote, isFalse);
    final t = Staff(2, 'b', 3, 3, 3, 3, 3, 0, 100);
    g.staff.add(t);
    g.changeJob(t, 9);
    expect(t.job, isNot(9)); // 자격 없음
  });

  test('도감 보너스: 25% 수익 +3%, 50% 연구 +10%', () {
    final g = HubGame();
    expect(g.bookPerk, 1.0);
    for (var i = 0; i < 10; i++) {
      g.rt.foundSets.add(i);
    }
    g.rt.seenJobs.addAll([0, 1]); // 12/34 ≈ 35%
    expect(g.bookPerk, closeTo(1.03, 1e-9));
    expect(g.bookResearch, 1.0);
    g.rt.seenJobs.addAll([2, 3, 4, 5, 6, 7]); // 18/34
    expect(g.bookResearch, closeTo(1.1, 1e-9));
  });
}
