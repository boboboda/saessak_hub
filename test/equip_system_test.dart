import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

BuildingType _t(String id) => Cfg.types.firstWhere((t) => t.id == id);
EquipDef _e(String id) => Cfg.equips.firstWhere((e) => e.id == id);
int _res(String equip) => Cfg.research.indexWhere((r) => r.equip == equip);

void main() {
  test('장비는 연구로 열리고, 맞는 시설에만 하나씩 달림 (바꾸면 앞 장비는 사라짐)', () {
    final g = HubGame()..money = 100000;
    final pack = Building(_t('pack'), 10, 10);
    final shelf = Building(_t('shelf'), 20, 10);
    g.buildings.addAll([pack, shelf]);
    g.buyEquip(pack, _e('tape'));
    expect(pack.equip, isNull); // 아직 연구 안 함
    g.researched.add(_res('tape'));
    g.buyEquip(shelf, _e('tape'));
    expect(shelf.equip, isNull); // 선반엔 못 닮
    g.buyEquip(pack, _e('tape'));
    expect(pack.equip, 'tape');
    expect(g.money, 100000 - _e('tape').cost);
    expect(pack.equipSpeed, closeTo(1.2, 1e-9));
    g.researched.add(_res('robot'));
    g.buyEquip(pack, _e('robot'));
    expect(pack.equip, 'robot');
    expect(pack.equipSpeed, closeTo(1.6, 1e-9));
  });

  test('장비 효과: 선반 보관 칸, 도크 싣기, 장비 강화(Lv3까지 효과 +50%씩)', () {
    final g = HubGame()..money = 1000000;
    final shelf = Building(_t('shelf'), 20, 10);
    final dock = Building(_t('dock'), 30, 10);
    g.buildings.addAll([shelf, dock]);
    g.researched.addAll([_res('ladder'), _res('forklift')]);
    final cap0 = shelf.cap, load0 = dock.loadMul;
    g.buyEquip(shelf, _e('ladder'));
    g.buyEquip(dock, _e('forklift'));
    expect(shelf.cap, cap0 + 12);
    expect(dock.loadMul, closeTo(load0 * 1.8, 1e-9));
    g.upgradeEquip(dock);
    g.upgradeEquip(dock);
    g.upgradeEquip(dock); // Lv3 이 끝
    expect(dock.equipLv, 3);
    expect(dock.loadMul, closeTo(load0 * (1 + 0.8 * 2), 1e-9));
  });

  test('같은 시설을 더 지을수록 비싸지고, 뒤쪽 연구는 회사 등급이 있어야 시작', () {
    final g = HubGame();
    final c = _t('counter');
    expect(g.costOf(c), c.cost);
    g.buildings.add(Building(c, 2, 2));
    g.buildings.add(Building(c, 2, 6));
    expect(g.costOf(c), greaterThan(c.cost * 1.5));
    expect(g.costOf(_t('plant')), _t('plant').cost); // 소품은 그대로
    g.rp = 99999;
    g.money = 999999;
    final fork = _res('forklift');
    for (var i = 0; i < Cfg.research.length; i++) {
      if (Cfg.research[i].branch == Cfg.research[fork].branch && Cfg.research[i].tier < Cfg.research[fork].tier) {
        g.researched.add(i);
      }
    }
    expect(g.resProblem(fork), contains(Cfg.corpName[Cfg.research[fork].grade]));
    g.companyGrade = Cfg.research[fork].grade;
    expect(g.resProblem(fork), isNull);
  });
}
