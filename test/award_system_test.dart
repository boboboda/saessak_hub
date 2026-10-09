import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';

void main() {
  test('시상식: 점수로 순위, 1위면 명성 +300·특별 후보, 3위 안이면 +100', () {
    final g = HubGame()..rt.yServed = 5000;
    g.runAward(1);
    expect(g.award!.rank, 1);
    expect(g.fame, Cfg.awardFirstFame);
    expect(g.awardWins, 1);
    expect(g.candidates.first.name, startsWith('★'));

    final m = HubGame()..rt.yServed = 900; // 800 < 900 < 1100 → 3위
    m.runAward(1);
    expect(m.award!.rank, 3);
    expect(m.fame, Cfg.awardTop3Fame);

    final low = HubGame();
    low.runAward(1);
    expect(low.award!.rank, 6);
    expect(low.fame, 0);
  });

  test('경쟁사는 해마다 커지고, 무한 모드면 더 셈', () {
    final g = HubGame();
    expect(g.rivalScore(0, 2), greaterThan(g.rivalScore(0, 1)));
    final y2 = g.rivalScore(4, 2);
    g.endless = true;
    expect(g.rivalScore(4, 2), greaterThan(y2));
  });

  test('회사 등급: 조건을 다 채우면 승급, 하나라도 모자라면 그대로', () {
    final g = HubGame()..fame = 150;
    g.checkGrade();
    expect(g.companyGrade, 0); // 하루 최고 접수 0
    g.rt.bestEver = Cfg.grade1Day;
    g.checkGrade();
    expect(g.companyGrade, 1);
    expect(g.gradeUp, 1);
    g.fame = 500;
    g.checkGrade();
    expect(g.companyGrade, 1); // 시상식 3위 안이 아직
    g.bestRank = 2;
    g.checkGrade();
    expect(g.companyGrade, 2);
  });

  test('등급 잠금: 지점 전엔 연구실을 못 짓고, 거점 허브 전엔 전직 불가', () {
    final g = HubGame();
    final lab = Cfg.types.firstWhere((t) => t.id == 'lab');
    g.startPlacing(lab);
    expect(g.placing, isNull);
    expect(g.gradeAllows('lab'), isFalse);
    g.companyGrade = 1;
    expect(g.gradeAllows('lab'), isTrue); // (화면이 없는 테스트라 배치 화면은 열지 않음)
    expect(g.gradeAllows('classroom'), isFalse);
    g.rp = 9999;
    g.money = 99999;
    g.researched.addAll([3, 4]);
    expect(g.resProblem(5), contains(Cfg.corpName[Cfg.nightShipGrade]));
  });
}
