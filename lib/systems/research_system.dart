import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 연구(RP: 배송 1건 = 1, 연구실 1개당 하루 +30)와 직원 훈련(교육실에서 하루, 능력치 +1)
extension ResearchSystem on HubGame {
  bool resDone(int i) => researched.contains(i);

  /// 앞 단계(같은 갈래의 앞 연구)를 마쳤는지
  bool resOpen(int i) {
    final d = Cfg.research[i];
    if (d.tier == 0) return true;
    final prev = Cfg.research.indexWhere((x) => x.branch == d.branch && x.tier == d.tier - 1);
    return prev < 0 || resDone(prev);
  }

  /// 지금 시작할 수 없는 이유 (없으면 null)
  String? resProblem(int i) {
    if (resDone(i)) return '완료';
    if (resNow != null) return '다른 연구 중';
        if (!resOpen(i)) return '앞 연구 먼저';
    if (i == 5 && companyGrade < Cfg.nightShipGrade) return '${Cfg.corpName[Cfg.nightShipGrade]} 필요';
    final d = Cfg.research[i];
    if (rp < d.rp) return 'RP 부족';
    if (money < d.cost) return '돈 부족';
    return null;
  }

  void startResearch(int i) {
    final why = resProblem(i);
    if (why != null) {
      showToast(why);
      return;
    }
    final d = Cfg.research[i];
    rp -= d.rp;
    money -= d.cost;
    resNow = i;
    resLeft = d.time;
    showToast('연구 시작: ${d.name} (${d.time.round()}초)');
    ui();
  }

  /// 매 프레임: 연구 진행 (게임 시간)
  void updateResearch(double d) {
    final i = resNow;
    if (i == null) return;
    resLeft -= d;
    if (resLeft > 0) return;
    researched.add(i);
    resNow = null;
    resLeft = 0;
    showToast('연구 완료! ${Cfg.research[i].name} — ${Cfg.research[i].effect}');
    aisleVer++; // 건설 목록 등 다시 그리게
    ui();
  }

  // ---------------- 연구 효과 ----------------
  double get resCounter => resDone(0) ? 1.1 : 1.0; // 바코드 접수
  double get resPack => resDone(1) ? 1.15 : 1.0; // 자동 테이프
  /// 포장 라인 2세대: 세트 효과 ×1.5 (1에서 벗어난 만큼을 늘림)
  double resAmp(double v) => resDone(2) ? 1 + (v - 1) * 1.5 : v;
  int resAmpCap(int v) => resDone(2) ? (v * 1.5).round() : v;
  bool get conveyorOpen => resDone(3); // 컨베이어 해금
  double get resSorter => resDone(4) ? 1.5 : 1.0; // 분류 자동화
  double get resCalm => resDone(6) ? 0.9 : 1.0; // 번호표
  double get resIntake => resDone(7) ? 1.08 : 1.0; // 단골 카드
  int get resUrgent => resDone(8) ? 2 : 1; // 프리미엄 배송

  /// 하루 끝: 연구실 RP, 야간 출고(선반 택배 일부를 지역센터로), 훈련 끝난 직원 능력치 +1
  List<String> researchDayEnd() {
    final notes = <String>[];
    final labs = ofType('lab').length;
    if (labs > 0) {
      rp += labs * Cfg.labRpDay;
      notes.add('연구실 ${labs}곳 RP +${labs * Cfg.labRpDay}');
    }
    if (resDone(5)) {
      var left = Cfg.nightShip;
      var moved = 0;
      for (final b in ofType('shelf')) {
        for (var r = 0; r < b.regions.length && left > 0; r++) {
          if (!regionOpen[r]) continue;
          while (b.regions[r] - b.pickRes[r] > 0 && left > 0) {
            b.regions[r]--;
            b.stored = max(0, b.stored - 1);
            final hb = hubBorn[r];
            centerBorn[r].add(hb.isEmpty ? gt : hb.removeAt(0));
            centerStock[r]++;
            left--;
            moved++;
          }
        }
      }
      if (moved > 0) notes.add('야간 출고 $moved건');
    }
    return notes;
  }

  // ---------------- 훈련 ----------------
  int statOf(Staff s, int k) => [s.speed, s.walk, s.kind, s.stamina, s.care][k];
  int trainCost(Staff s, int k) => Cfg.trainBase * statOf(s, k);

  /// 빈자리가 있는 교육실 (없으면 null)
  Building? freeClassroom() {
    for (final b in ofType('classroom')) {
      final n = staff.where((s) => s.training == b).length;
      if (n < Cfg.classSeats) return b;
    }
    return null;
  }

  String? trainProblem(Staff s, int k) {
    if (s.training != null) return '이미 훈련 중';
    if (statOf(s, k) >= 5) return '이미 최대(5)';
    if (ofType('classroom').isEmpty) return '교육실을 먼저 지으세요';
    if (freeClassroom() == null) return '교육실 자리가 없어요';
    if (money < trainCost(s, k)) return '돈 부족';
    return null;
  }

  void startTraining(Staff s, int k) {
    final why = trainProblem(s, k);
    if (why != null) {
      showToast(why);
      return;
    }
    money -= trainCost(s, k);
    this.unassign(s); // 훈련하는 동안 일 못 함
    s.training = freeClassroom();
    s.trainStat = k;
    s.trainUntil = day + 1;
    showToast('${s.name} ${Cfg.statName[k]} 훈련 시작 (내일까지)');
    ui();
  }

  /// 날이 바뀐 뒤: 훈련 끝난 직원은 능력치 +1 하고 대기로
  void finishTraining() {
    for (final s in staff) {
      if (s.training == null || day < s.trainUntil) continue;
      final k = s.trainStat;
      switch (k) {
        case 0:
          s.speed = min(5, s.speed + 1);
        case 1:
          s.walk = min(5, s.walk + 1);
        case 2:
          s.kind = min(5, s.kind + 1);
        case 3:
          s.stamina = min(5, s.stamina + 1);
        default:
          s.care = min(5, s.care + 1);
      }
      s.training = null;
      s.trainStat = -1;
      showToast('${s.name} 훈련 끝! ${Cfg.statName[k]} +1');
    }
  }
}

/// 연구 하나
class ResearchDef {
  final String name;
  final int branch, tier; // 갈래(0 작업, 1 물류, 2 서비스), 단계(0부터)
  final int rp, cost;
  final double time; // 게임 초
  final String effect;
  const ResearchDef(this.name, this.branch, this.tier, this.rp, this.cost, this.time, this.effect);
}
