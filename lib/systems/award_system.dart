import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 연말 '택배 대상' 시상식(가상 경쟁사 5곳)과 회사 등급(동네 영업소 → 전국 네트워크)
extension AwardSystem on HubGame {
  // ---------------- 시상식 ----------------
  /// 올해 점수 = 올해 접수 + 평균 별 × 60 + 명성 × 0.5
  int get yearScore {
    final avg = rt.yDays == 0 ? 0.0 : rt.yStarSum / rt.yDays;
    return rt.yServed + (avg * Cfg.awardStarW).round() + (fame * Cfg.awardFameW).round();
  }

  /// y년차 경쟁사 점수 (해마다 커짐, 무한 모드면 더 셈)
  int rivalScore(int i, int y) {
    final k = pow(Cfg.rivalGrowth, y - 1).toDouble() * (endless ? Cfg.endlessBoost : 1.0);
    return (Cfg.rivalBase[i] * k).round();
  }

  /// 해가 끝날 때(정산 카드 만들 때) 부름: 순위를 정하고 보상, 시상식 카드를 띄움
  void runAward(int endedYear) {
    final me = yearScore;
    final rows = <(String, int, bool)>[
      for (var i = 0; i < Cfg.rivalName.length; i++) (Cfg.rivalName[i], rivalScore(i, endedYear), false),
      ('새싹 택배 (나)', me, true),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final rank = rows.indexWhere((r) => r.$3) + 1;
    final rewards = <String>[];
    if (rank == 1) {
      fame += Cfg.awardFirstFame;
      awardWins++;
      candidates.insert(0, _starCandidate());
      rewards.add('대상! 명성 +${Cfg.awardFirstFame} · 특별 직원 후보가 고용 목록에');
    } else if (rank <= 3) {
      fame += Cfg.awardTop3Fame;
      rewards.add('$rank위 입상! 명성 +${Cfg.awardTop3Fame}');
    } else {
      rewards.add('$rank위 · 3위 안에 들면 명성 +${Cfg.awardTop3Fame}');
    }
    bestRank = bestRank == 0 ? rank : min(bestRank, rank);
    award = AwardResult(endedYear, rows, rank, rewards);
    ui();
  }

  Staff _starCandidate() {
    final name = Cfg.surnames[rnd.nextInt(Cfg.surnames.length)] +
        Cfg.givens[rnd.nextInt(Cfg.givens.length)];
    final s = Staff(nextStaffId++, '★$name', 5, 5, 5, 4, 5, 3000, 260);
    s.job = this.bestJob(s);
    return s;
  }

  // ---------------- 회사 등급 ----------------
  /// 다음 등급 조건 (글, 지금 값, 목표)
  List<(String, int, int)> gradeNeeds(int g) {
    switch (g) {
      case 1:
        return [('명성', fame, Cfg.gradeFameNeed[1]), ('하루 최고 접수', rt.bestEver, Cfg.grade1Day)];
      case 2:
        return [('명성', fame, Cfg.gradeFameNeed[2]), ('연말 시상식 3위 안', bestRank == 0 ? 0 : (bestRank <= 3 ? 1 : 0), 1)];
      case 3:
        return [('명성', fame, Cfg.gradeFameNeed[3]), ('직원 수', staff.length, Cfg.grade3Staff)];
      case 4:
        return [('명성', fame, Cfg.gradeFameNeed[4]), ('택배 대상 1위', awardWins > 0 ? 1 : 0, 1)];
    }
    return const [];
  }

  bool _gradeMet(int g) => gradeNeeds(g).every((n) => n.$2 >= n.$3);

  /// 0.2초마다: 조건을 채우면 한 단계씩 승급 (내려가지 않음)
  void checkGrade() {
    while (companyGrade < Cfg.corpName.length - 1 && _gradeMet(companyGrade + 1)) {
      companyGrade++;
      gradeUp = companyGrade;
      if (companyGrade == Cfg.corpName.length - 1) endless = true; // 엔딩 후 무한 모드
      ui();
    }
  }

  /// 이 건물을 지을 수 있는 등급인지
  bool gradeAllows(String id) => companyGrade >= (Cfg.gradeUnlock[id] ?? 0);

  String gradeNeedText(String id) => '${Cfg.corpName[Cfg.gradeUnlock[id] ?? 0]} 등급 필요';
}

/// 시상식 결과 (카드로 보여 줌)
class AwardResult {
  final int year;
  final List<(String, int, bool)> rows; // 이름, 점수, 나인지 (순위순)
  final int rank;
  final List<String> rewards;
  const AwardResult(this.year, this.rows, this.rank, this.rewards);
}
