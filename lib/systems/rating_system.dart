import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 하루 정산 카드에 보여 줄 내용
class DayReport {
  final int day; // 끝난 날 (일차)
  final int grade; // 0 S … 4 D, -1 손님 없음
  final int served, lost, mistakes;
  final double stars; // 평균 별
  final int fameD; // 등급으로 바뀐 명성
  final int earned, wages;
  final bool paidAll;
    final String? yearText; // 해가 바뀌었으면 올해 목표 결과
  final List<String> notes; // 오늘 끝난 사건 결과
  const DayReport(this.day, this.grade, this.served, this.lost, this.mistakes,
            this.stars, this.fameD, this.earned, this.wages, this.paidAll, this.yearText,
      [this.notes = const []]);
}

/// 하루 평가(별점·등급) + 올해 목표 + 업적 진행 기록
extension RatingSystem on HubGame {
  /// 손님 한 명 접수를 끝냈을 때: 남은 인내심으로 별점
  void rateServed(Customer c) {
    final maxP = Cfg.patience * (c.vip ? Cfg.vipPatience : 1.0);
    final f = (c.patience / maxP).clamp(0.0, 1.0);
    var st = 1.0;
    for (var i = 0; i < Cfg.starCut.length; i++) {
      if (f >= Cfg.starCut[i]) {
        st = 5.0 - i;
        break;
      }
    }
    if (c.pre) st = min(5.0, st + 0.5); // 사연을 들어 준 손님은 조금 더 만족
        rt.served++;
    if (c.kind == 3) rt.bulkDone++;
    rt.stars += st;
    if (st >= 5) rt.fiveStars++;
    if (rt.served > rt.bestDay) rt.bestDay = rt.served;
  }

  void rateLost() => rt.lost++;
  void rateMistake() => rt.mistakes++;

  /// 오늘 지금까지 평균 별 (손님이 없으면 null)
  double? get todayStars {
    final n = rt.served + rt.lost + rt.mistakes;
    if (n == 0) return null;
    return (rt.stars + rt.lost + rt.mistakes) / n;
  }

  /// 평균 별·놓친 비율로 등급 (0 S … 4 D)
  int gradeOf(double avg, double miss) {
    for (var i = 0; i < Cfg.gradeStar.length; i++) {
      if (avg >= Cfg.gradeStar[i] && miss <= Cfg.gradeMiss[i]) return i;
    }
    return 4;
  }

  /// 하루가 끝날 때 (월급 정산 전에 부름): 등급·명성, 해가 바뀌면 올해 목표 결과
  void endOfDay(int endedDay) {
    final avg = todayStars;
    var grade = -1, fameD = 0;
    if (avg != null) {
      final n = rt.served + rt.lost;
      grade = gradeOf(avg, n == 0 ? 0 : rt.lost / n);
      fameD = Cfg.gradeFame[grade];
      fame = max(0, fame + fameD);
            rt.grades[grade]++;
      if (grade <= 2) rt.yGood++;
      rt.yDays++;
      rt.yStarSum += avg;
    }
    // 포장 실수 없는 날 연속 (포장을 한 날만 셈)
    if (rt.mistakes == 0 && rt.packed > 0) {
      rt.cleanStreak++;
      rt.bestClean = max(rt.bestClean, rt.cleanStreak);
    } else if (rt.mistakes > 0) {
      rt.cleanStreak = 0;
    }
        rt.yServed += rt.served;
    rt.bestEver = max(rt.bestEver, rt.served);
    pendingReport = (endedDay, grade, rt.served, rt.lost, rt.mistakes,
        avg ?? 0, fameD);
    rt.served = 0;
    rt.lost = 0;
    rt.mistakes = 0;
    rt.stars = 0;
    rt.packed = 0;
  }

  /// 월급 정산까지 끝난 뒤 정산 카드 만들기 (해가 바뀌었으면 올해 목표 결과도)
  void finishReport(int earned, int wages, bool paidAll) {
    final p = pendingReport;
    if (p == null) return;
    pendingReport = null;
    String? yt;
    if (dayOfYear == 1 && day > 1) {
      final got = rt.yearDone.length;
      yt = '${year - 1}년차 목표 $got/3 달성${got == 3 ? ' · 명성 +${Cfg.yearAllFame} · 전직서 +${Cfg.yearAllTicket}' : ''}';
            this.runAward(year - 1); // 연말 시상식 (올해 기록으로 순위)
      rt.yearDone.clear();
      rt.yGood = 0;
      rt.bestDay = 0;
      rt.yServed = 0;
      rt.yStarSum = 0;
      rt.yDays = 0;
    }
        report = DayReport(p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, p.$7, earned, wages,
        paidAll, yt, List.of(evtNotes));
    evtNotes.clear();
    ui();
  }

  // ---------------- 올해 목표 ----------------
  List<YearGoal> get goals => Cfg.yearGoals(year);

  int goalProgress(YearGoal g) {
    switch (g.kind) {
      case 0:
        return rt.bestDay;
      case 1:
        return rt.yGood;
      default:
        return openRegions;
    }
  }

  /// 달성한 목표는 바로 보상 (셋 다면 명성·전직서)
  void checkGoals() {
    final gs = goals;
    for (var i = 0; i < gs.length; i++) {
      if (rt.yearDone.contains(i) || goalProgress(gs[i]) < gs[i].target) continue;
      rt.yearDone.add(i);
      money += gs[i].reward;
      if (rt.yearDone.length == gs.length) {
        fame += Cfg.yearAllFame;
        tickets += Cfg.yearAllTicket;
        rt.yearsAll++;
        showToast('올해 목표 모두 달성! 명성 +${Cfg.yearAllFame} · 전직서 +${Cfg.yearAllTicket}');
      } else {
        showToast('올해 목표 달성: ${gs[i].text} (+${fmt(gs[i].reward)}원)');
      }
    }
  }

  // ---------------- 업적 보너스 ----------------
  /// 받은 업적의 영구 수익 보너스 배수 (상한 Cfg.perkCap%)
  double get perkMul {
    var p = 0;
    for (final i in claimed) {
      if (i < Cfg.missions.length) p += Cfg.missions[i].perk;
    }
        return (1 + min(p, Cfg.perkCap) / 100) * this.bookPerk; // 도감 25%: +3%
  }

  int get perkPct => ((perkMul - 1) * 100).round();
}

/// 평가 기록 (저장됨)
class RateState {
  int served = 0, lost = 0, mistakes = 0, packed = 0; // 오늘
  double stars = 0;
  final List<int> grades = List<int>.filled(5, 0); // 등급별 날 수 (누적)
  int fiveStars = 0; // 별 5점 손님 (누적)
  int cleanStreak = 0, bestClean = 0; // 포장 실수 없는 날 연속
  int bestDay = 0, yGood = 0; // 올해: 하루 최고 접수, B 이상인 날
  final Set<int> yearDone = {}; // 올해 달성한 목표
  int yearsAll = 0; // 목표 셋 다 달성한 해 수
  int promotions = 0; // 전직 횟수
      final Set<int> foundSets = {}; // 발견한 세트
  final Set<int> foundGuests = {}; // 만난 숨은 손님
  final Set<int> seenJobs = {}; // 본 직업 (숨은 직업은 자격이 생기면)
  final Set<int> seenPromo = {}; // 본 상위 직업
  int bulkDone = 0; // 대형 택배 누적 접수
  bool legendGiven = false; // 도감 100% 보상을 줬는지
  int yServed = 0, yDays = 0, bestEver = 0; // 올해 접수·평가한 날 수, 지금까지 하루 최고 접수
  double yStarSum = 0; // 올해 하루 평균 별의 합

  Map<String, dynamic> toJson() => {
    'sv': served, 'ls': lost, 'mi': mistakes, 'pk': packed, 'st': stars,
    'gr': grades, 'fs': fiveStars, 'cs': cleanStreak, 'bc': bestClean,
    'bd': bestDay, 'yg': yGood, 'yd': yearDone.toList(), 'ya': yearsAll,
        'pr': promotions, 'set': foundSets.toList(),
        'fg': foundGuests.toList(), 'sj': seenJobs.toList(), 'sp': seenPromo.toList(),
    'bk': bulkDone, 'lg': legendGiven,
    'ys': yServed, 'yd2': yDays, 'be': bestEver, 'yst': yStarSum,
  };

  void load(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    served = i('sv');
    lost = i('ls');
    mistakes = i('mi');
    packed = i('pk');
    stars = ((j['st'] as num?) ?? 0).toDouble();
    final g = (j['gr'] as List?) ?? const [];
    for (var k = 0; k < grades.length && k < g.length; k++) {
      grades[k] = (g[k] as num).toInt();
    }
    fiveStars = i('fs');
    cleanStreak = i('cs');
    bestClean = i('bc');
    bestDay = i('bd');
    yGood = i('yg');
    yearDone
      ..clear()
      ..addAll(((j['yd'] as List?) ?? const []).map((e) => (e as num).toInt()));
    yearsAll = i('ya');
        promotions = i('pr');
        Set<int> setOf(String k) => ((j[k] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    foundGuests
      ..clear()
      ..addAll(setOf('fg'));
    seenJobs
      ..clear()
      ..addAll(setOf('sj'));
    seenPromo
      ..clear()
      ..addAll(setOf('sp'));
    bulkDone = i('bk');
    legendGiven = (j['lg'] as bool?) ?? false;
    yServed = i('ys');
    yDays = i('yd2');
    bestEver = max(i('be'), bestDay); // 예전 저장엔 없어서 올해 하루 최고로 시작
    yStarSum = ((j['yst'] as num?) ?? 0).toDouble();
    foundSets
      ..clear()
      ..addAll(((j['set'] as List?) ?? const []).map((e) => (e as num).toInt()));
  }
}
