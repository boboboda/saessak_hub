import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

BuildingType _t(String id) => Cfg.types.firstWhere((t) => t.id == id);

void main() {
  test('연구: RP·돈을 쓰고 시간이 지나면 완료, 같은 갈래는 앞 단계부터', () {
    final g = HubGame()
      ..rp = 5000
      ..money = 100000;
    expect(g.resProblem(1), '앞 연구 먼저'); // 자동 테이프는 바코드 접수 다음
    g.startResearch(0);
    expect(g.rp, 5000 - Cfg.research[0].rp);
    expect(g.money, 100000 - Cfg.research[0].cost);
    expect(g.resProblem(3), '다른 연구 중'); // 한 번에 하나
    g.updateResearch(Cfg.research[0].time - 1);
    expect(g.resDone(0), isFalse);
    g.updateResearch(2);
    expect(g.resDone(0), isTrue);
    expect(g.resCounter, closeTo(1.1, 1e-9));
    expect(g.resProblem(1), isNull);
  });

  test('RP 가 모자라면 못 함', () {
    final g = HubGame()..rp = 10;
    expect(g.resProblem(0), 'RP 부족');
  });

  test('연구실: 하루 끝에 1곳당 +30 RP', () {
    final g = HubGame();
    g.buildings
      ..add(Building(_t('lab'), 2, 2))
      ..add(Building(_t('lab'), 6, 2));
    g.researchDayEnd();
    expect(g.rp, 2 * Cfg.labRpDay);
  });

  test('컨베이어는 연구 전엔 못 지음', () {
    final g = HubGame();
    g.startPlacing(_t('conveyor'));
    expect(g.placing, isNull);
    g.researched.add(3);
    expect(g.conveyorOpen, isTrue);
  });

  test('포장 라인 2세대: 세트 효과 ×1.5', () {
    final g = HubGame();
    expect(g.resAmp(1.15), closeTo(1.15, 1e-9));
    g.researched.add(2);
    expect(g.resAmp(1.15), closeTo(1.225, 1e-9));
    expect(g.resAmp(0.8), closeTo(0.7, 1e-9));
    expect(g.resAmpCap(5), 8);
  });

  test('야간 출고: 하루 끝에 선반 택배 최대 10건을 지역센터로', () {
    final g = HubGame()..researched.add(5);
    final sh = Building(_t('shelf'), 18, 10);
    sh.regions[0] = 14;
    sh.stored = 14;
    g.buildings.add(sh);
    g.researchDayEnd();
    expect(g.centerStock[0], Cfg.nightShip);
    expect(sh.stored, 14 - Cfg.nightShip);
  });

  test('훈련: 교육실이 있어야 하고, 하루 지나면 능력치 +1, 훈련 중엔 배치 안 됨', () {
    final g = HubGame()..money = 10000;
    final s = Staff(1, 'a', 3, 3, 3, 3, 3, 0, 100);
    g.staff.add(s);
    expect(g.trainProblem(s, 0), '교육실을 먼저 지으세요');
    final room = Building(_t('classroom'), 2, 2);
    final counter = Building(_t('counter'), 8, 2);
    g.buildings.addAll([room, counter]);
    g.startTraining(s, 0);
    expect(s.training, room);
    expect(g.money, 10000 - Cfg.trainBase * 3);
    expect(s.idle, isFalse);
    g.assignTo(s, counter);
    expect(s.post, isNull); // 훈련 중이라 배치 안 됨
    g.finishTraining(); // 아직 같은 날
    expect(s.speed, 3);
    g.day++;
    g.finishTraining();
    expect(s.speed, 4);
    expect(s.training, isNull);
  });

  test('교육실은 2명까지', () {
    final g = HubGame()..money = 100000;
    g.buildings.add(Building(_t('classroom'), 2, 2));
    final ss = [for (var i = 0; i < 3; i++) Staff(i + 1, 's$i', 2, 2, 2, 2, 2, 0, 100)];
    g.staff.addAll(ss);
    g.startTraining(ss[0], 1);
    g.startTraining(ss[1], 1);
    expect(g.trainProblem(ss[2], 1), '교육실 자리가 없어요');
  });
}
