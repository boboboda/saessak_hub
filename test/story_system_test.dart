import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

BuildingType _t(String id) => Cfg.types.firstWhere((t) => t.id == id);

HubGame _game({int packLv = 1}) {
  final g = HubGame();
  final p = Building(_t('pack'), 10, 10)..level = packLv;
  g.buildings.add(p);
  final s = Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100);
  g.staff.add(s);
  g.assignTo(s, p);
  return g;
}

Customer _ask(HubGame g, int k) {
  final c = Customer(const Offset(3, 4), 0)..story = k;
  g.customers.add(c);
  g.storyAsk = c;
  return c;
}

void main() {
  test('사연 손님만 말풍선: 일반 손님은 사연 없음, 사연 손님은 한 번에 한 명', () {
    final g = _game()..day = Cfg.storyFromDay;
    var n = 0;
    for (var i = 0; i < 300; i++) {
      final k = g.pickStory();
      if (k >= 0) {
        n++;
        g.customers.add(Customer(const Offset(3, 4), 0)..story = k);
        expect(g.pickStory(), -1); // 이미 한 명 있음
        g.customers.clear();
      }
    }
    expect(n, inInclusiveRange(10, 90)); // 약 12%
    final g1 = _game()..day = 1;
    for (var i = 0; i < 100; i++) {
      expect(g1.pickStory(), -1); // 첫날은 없음
    }
  });

  test('문 앞에서 기다리다 시간이 지나면 돌아감', () {
    final g = _game();
    final c = Customer(g.storySpot, 0)..story = 0;
    g.customers.add(c);
    g.storyCustomerStep(c, Cfg.storyWait + 1);
    expect(c.state, 2);
    expect(c.story, -1);
  });

  test('조건 충족: 숙련 포장! → 꼭 성공, 보너스, 엽서', () {
    final g = _game(packLv: 2);
    _ask(g, 2); // 김장 김치: 포장대 Lv2
    expect(g.storyChoices(2).first.$1, 0);
    final m = g.money;
    g.chooseStory(0);
    expect(g.storyAsk, isNull);
    expect(g.storyJob, isNotNull);
    g.updateStory(Cfg.storyPackTime + 0.1);
    expect(g.storyJob, isNull);
    final r = g.postcard!;
    expect(r.ok, isTrue);
    expect(r.stamp, 0);
    expect(g.money, m + Cfg.storyDefs[2].pay + Cfg.storySkillBonus);
    expect(g.rt.storyDone, contains(2));
  });

  test('조건 미달: 일반/임시/거절 3개, 임시 포장은 재료비, 거절하면 잠기고 레벨이 차면 다시 옴', () {
    final g = _game(packLv: 1);
    _ask(g, 4); // 도자기: 포장대 Lv3
    final ch = g.storyChoices(4).map((e) => e.$1).toList();
    expect(ch, [1, 2, 3]);
    final m = g.money;
    g.chooseStory(2);
    expect(g.money, m - Cfg.storyTempCost);
    expect(g.storyJob!.mode, 2);
    g.storyJob = null;

    _ask(g, 4);
    g.chooseStory(3);
    expect(g.rt.storyLocked, contains(4));
    expect(g.storyJob, isNull);
    // 레벨이 모자라면 잠긴 사연은 안 옴, 차면 먼저 옴
    g.day = 5;
    for (var i = 0; i < 200; i++) {
      final k = g.pickStory();
      expect(k, isNot(4));
    }
    g.ofType('pack').first.level = 3;
    var got = -1;
    for (var i = 0; i < 300 && got < 0; i++) {
      got = g.pickStory();
    }
    expect(got, 4);
  });

  test('포장대 직원이 자리에 없으면 포장이 멈춤, 철거하면 취소', () {
    final g = _game(packLv: 1);
    _ask(g, 0);
    g.chooseStory(1);
    final s = g.staff.first..rest = 2; // 쉬러 감
    expect(g.ofType('pack').first.active, isEmpty);
    g.updateStory(Cfg.storyPackTime + 1);
    expect(g.storyJob, isNotNull);
    expect(g.storyJob!.t, 0);
    s.rest = 0;
    g.buildings.clear();
    g.updateStory(0.1);
    expect(g.storyJob, isNull);
  });

  test('사연 기록은 저장·불러오기 됨', () {
    final g = _game();
    g.rt.storyDone.add(1);
    g.rt.storyLocked.add(4);
    g.rt.storySeen.addAll([1, 4]);
    final j = g.rt.toJson();
    final g2 = HubGame();
    g2.rt.load(j);
    expect(g2.rt.storyDone, {1});
    expect(g2.rt.storyLocked, {4});
    expect(g2.rt.storySeen, {1, 4});
  });

  test('다른 시설 요구: 에어컨이 있어야 생선 숙련 포장, 포장은 포장대에서', () {
    final g = _game();
    _ask(g, 5); // 갓 잡은 생선: 에어컨
    expect(g.storyNeedText(5), '에어컨');
    expect(g.storyChoices(5).map((e) => e.$1), [1, 2, 3]);
    g.buildings.add(Building(_t('aircon'), 2, 2));
    expect(g.storyChoices(5).first.$1, 0);
    g.chooseStory(0);
    expect(g.storyJob!.table.type.id, 'pack');
  });

  test('요구 시설 글: 레벨 있는 시설만 Lv 붙임, 거절 안내 조사', () {
    final g = _game();
    expect(g.storyNeedText(6), '도크 Lv2');
    expect(g.storyNeedText(7), '화분');
    final ch = g.storyChoices(7);
    expect(ch.last.$3, '화분이 준비되면 다시 찾아와요');
    expect(g.storyChoices(6).last.$3, '도크 Lv2가 준비되면 다시 찾아와요');
  });

  test('포장대가 없으면 일반·임시 포장 못 함', () {
    final g = HubGame();
    final ch = g.storyChoices(0);
    expect(ch.where((e) => e.$1 != 3).every((e) => !e.$4), isTrue);
  });
}
