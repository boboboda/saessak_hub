import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/game/region_map.dart';
import 'package:saessak_hub/models/models.dart';

void main() {
  test('구역: 배달 길을 거리순으로 셋으로 나누고, 구역을 맡기면 그 구역 집에만 감', () {
    final g = HubGame();
    final m = RegionMap.of(0);
    final zs = [for (var k = 0; k < m.courier.length; k++) g.zoneOf(0, k)];
    expect(zs.toSet(), {0, 1, 2});
    final u = g.makeUnit(2, 0)..zone = 2;
    for (var i = 0; i < 30; i++) {
      expect(g.zoneOf(0, g.pickHouse(u)), 2);
    }
  });

  test('적재 한도: 과적하면 많이 싣지만 느리고, 가볍게 실으면 빠름', () {
    final g = HubGame();
    final u = g.makeUnit(1, 0);
    final base = u.cap, sp = u.speed;
    g.setLoad(u, 3);
    expect(u.cap, (u.baseCap * 1.5).round());
    expect(u.cap, greaterThan(base));
    expect(u.speed, lessThan(sp));
    expect(g.evtChanceOf(u), greaterThan(Cfg.evtChance(false, 0)));
    g.setLoad(u, 0);
    expect(u.cap, lessThan(base));
    expect(u.speed, greaterThan(sp));
  });

  test('과적 단속: 150% 과적을 여러 번 하면 벌금이 나오고 차량 무리가 쌓임', () {
    final g = HubGame()..money = 1000000;
    final u = g.makeUnit(1, 1)..loadIdx = 3;
    for (var i = 0; i < 200; i++) {
      u.cargo = 10;
      g.checkPolice(u);
    }
    expect(g.rs.policeN, greaterThan(10));
    expect(g.money, lessThan(1000000));
    expect(u.wear, Cfg.wearMax);
  });

  test('단골 집: 같은 집에 배달하면 하트가 쌓여 단골이 되고 팁이 붙음', () {
    final g = HubGame();
    final u = g.makeUnit(2, 0)..house = 3;
    var tip = 0;
    for (var i = 0; i < Cfg.heartNeed[0]; i++) {
      tip = g.deliveryExtras(u, 4, 4).$2;
    }
    expect(g.regularLv(0, 3), 1);
    expect(tip, Cfg.heartTip[1] * 4);
    expect(g.regularCount(0), 1);
  });

  test('의뢰: 정시 배달을 채우면 보상·명성, 평판도 오름', () {
    final g = HubGame()..day = 3;
    g.rs.reqs.add(RouteRequest(0, 0, 5, 2000, 7, 4));
    final u = g.makeUnit(2, 0)..house = 0;
    final m0 = g.money;
    g.deliveryExtras(u, 3, 3);
    expect(g.rs.reqs.length, 1);
    g.deliveryExtras(u, 3, 3);
    expect(g.rs.reqs, isEmpty);
    expect(g.money, m0 + 2000);
    expect(g.fame, greaterThanOrEqualTo(7));
    expect(g.rs.rep[0], 6);
    // 기한이 지나면 사라지고 새 의뢰가 들어옴
    g.rs.reqs.add(RouteRequest(0, 0, 99, 100, 1, 3));
    g.day = 5;
    g.routeNewDay();
    expect(g.rs.reqs.any((q) => q.until < g.day), isFalse);
    expect(g.rs.reqs.length, Cfg.reqMax);
  });

  test('지도 시설: 냉장고는 기한을 늘리고, 신호 정비는 사건을 줄이고, 지름길은 시간을 줄임', () {
    final g = HubGame()..money = 100000;
    final u = g.makeUnit(0, 0);
    final d0 = g.deadlineOf(0), e0 = g.evtChanceOf(u);
    g.buyFac(0, 2);
    g.buyFac(0, 1);
    g.buyFac(0, 0);
    expect(g.deadlineOf(0), closeTo(d0 * 1.3, 1e-6));
    expect(g.evtChanceOf(u), lessThan(e0));
    expect(g.tripMul(0), 0.85);
    expect(g.money, 100000 - g.facCost(0, 0) - g.facCost(0, 1) - g.facCost(0, 2));
  });

  test('날씨·기사 개성: 비 오는 날 오토바이가 느리고, 비에 강한 기사는 괜찮음', () {
    final g = HubGame();
    final a = g.makeUnit(2, 0)..trait = 0;
    final b = g.makeUnit(2, 0)..trait = 1;
    final sunny = g.unitSpeed(a);
    g.rs.weather = 1;
    expect(g.unitSpeed(a), lessThan(sunny));
    expect(g.unitSpeed(b), sunny);
  });

  test('노선 기록 저장·불러오기', () {
    final g = HubGame();
    g.rs.hearts[2][5] = 9;
    g.rs.rep[1] = 77;
    g.rs.fac[3].add(2);
    g.rs.reqs.add(RouteRequest(1, 2, 8, 3000, 5, 10)..got = 3);
    g.rs.tomorrow = 2;
    final h = HubGame();
    h.rs.load(g.rs.toJson());
    expect(h.heartsOf(2, 5), 9);
    expect(h.rs.rep[1], 77);
    expect(h.hasFac(3, 2), isTrue);
    expect(h.rs.reqs.single.got, 3);
    expect(h.rs.tomorrow, 2);
  });

  test('집 직접 지정: 지정한 집에만 배달하고, 최대 개수까지만', () {
    final g = HubGame();
    final u = g.makeUnit(2, 0)..zone = 0;
    g.toggleHome(u, 5);
    g.toggleHome(u, 6);
    for (var i = 0; i < 30; i++) {
      expect({5, 6}, contains(g.pickHouse(u)));
    }
    for (var k = 0; k < 10; k++) {
      g.toggleHome(u, k);
    }
    expect(u.homes.length, lessThanOrEqualTo(Cfg.homesMax));
    g.clearHomes(u);
    expect(u.homes, isEmpty);
    final t = g.makeUnit(0, 0);
    g.toggleHome(t, 1);
    expect(t.homes, isEmpty); // 대형 트럭은 집 배달을 안 함
  });

  test('사건 성공률: 기사 능력별로 25~65%, 서둘러도 80%까지', () {
    expect(Cfg.evtSuccess(1), closeTo(0.25, 1e-9));
    expect(Cfg.evtSuccess(5), closeTo(0.65, 1e-9));
    final g = HubGame();
    expect(g.tvChance, lessThanOrEqualTo(0.7));
  });

  test('차량 지역을 옮기면 지정 집·구역이 비워지고, 과적 무리는 상한이 있고 정량 운행으로 회복', () {
    final g = HubGame();
    g.regionOpen[1] = true;
    final u = g.makeUnit(2, 0);
    g.makeUnit(2, 0);
    g.toggleHome(u, 2);
    u.zone = 1;
    g.cycleRegion(u);
    expect(u.region, 1);
    expect(u.homes, isEmpty);
    expect(u.zone, -1);
    u.loadIdx = 3;
    for (var i = 0; i < 100; i++) {
      u.cargo = 5;
      g.checkPolice(u);
    }
    expect(u.wear, Cfg.wearMax);
    u.loadIdx = 1;
    u.cargo = 5;
    g.checkPolice(u);
    expect(u.wear, Cfg.wearMax - 1);
  });
}
