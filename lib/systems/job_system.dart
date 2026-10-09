import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 직업: 맞는 자리 판정 · 효과 배수 · 직업 경험치·레벨 · 전직 · 직업 바꾸기
extension JobSystem on HubGame {
  /// 이 직원이 지금 자리에서 직업 효과를 내는지 (맞는 곳에서 일하는지)
  bool jobFits(Staff s) {
    if (s.carrier) return s.job == 2 || s.job == 7;
    final p = s.post;
    if (p == null) return false;
    switch (p.type.id) {
      case 'counter':
        return s.job == 0 || s.job == 4 || s.job == 7;
      case 'pack':
        return s.job == 1 || s.job == 5 || s.job == 7;
      case 'shelf':
        return s.job == 3;
      case 'dock':
        return s.job == 6;
    }
    return false;
  }

  /// 단계: 0 기본, 1 Lv2, 2 Lv4, 3 전직
  int _tier(Staff s) => s.promoted ? 3 : (s.jobLv >= 4 ? 2 : (s.jobLv >= 2 ? 1 : 0));

  /// 창구·포장대에서 이 직원의 일 속도 배수 (직업 반영)
  double jobRate(Staff s) {
    if (!jobFits(s)) return 1.0;
    final t = _tier(s);
    switch (s.job) {
      case 0:
        return const [1.0, 1.1, 1.1, 1.4][t];
      case 1:
        return const [1.0, 1.1, 1.1, 1.4][t];
      case 4:
        return 0.7; // 상담원: 손님 달래는 데 시간을 씀
      case 5:
        return t == 3 ? 0.85 : 0.7; // 검수원
      case 7:
        return 0.85; // 현장 반장
    }
    return 1.0;
  }

  /// 창구 손님 인내심 감소 배수 (자리에 있는 직원들의 직업)
  double jobCalm(Building b) {
    var m = 1.0;
    for (final s in b.active) {
      if (!jobFits(s)) continue;
      final t = _tier(s);
      if (s.job == 0 && t >= 2) m = min(m, 0.85);
      if (s.job == 4) m = min(m, const [0.8, 0.7, 0.7, 0.55][t]);
    }
    return m;
  }

  /// 창구에 VIP 전담(상담원 Lv4 이상)이 있으면 VIP 팁 2배
  bool vipDouble(Building b) =>
      b.active.any((s) => jobFits(s) && s.job == 4 && _tier(s) >= 2);

  /// 포장 실수 확률 배수
  double jobSlip(Building b) {
    var m = 1.0;
    for (final s in b.active) {
      if (!jobFits(s)) continue;
      final t = _tier(s);
      if (s.job == 1 && t >= 2) m = min(m, t == 3 ? 0.1 : 0.5);
      if (s.job == 5) m = min(m, const [0.5, 0.3, 0.1, 0.0][t]);
    }
    return m;
  }

  /// 운반 직원 걸음 배수
  double jobWalk(Staff s) {
    if (!jobFits(s)) return 1.0;
    if (s.job == 2) return const [1.0, 1.1, 1.25, 1.45][_tier(s)];
    if (s.job == 7) return 0.9;
    return 1.0;
  }

  /// 선반 용량 보너스 (보조 자리 분류사)
  int jobCap(Building b) {
    var p = 0;
    for (final s in b.crew) {
            if (jobFits(s) && s.job == 3) p = max(p, (const [3, 5, 8, 12][_tier(s)] * this.resSorter).round()); // 분류 자동화
    }
    return p;
  }

  /// 도크 싣기 배수 (보조 자리 정비사, 쉬러 가면 빠짐)
  double jobLoad(Building b) {
    var m = 1.0;
    for (final s in b.active) {
      if (jobFits(s) && s.job == 6) m = max(m, const [1.2, 1.3, 1.45, 1.7][_tier(s)]);
    }
    return m;
  }

  /// 모든 직원 체력 소모 배수 (일하는 현장 반장 중 가장 좋은 것 하나)
  double get jobDrain {
    var m = 1.0;
    for (final s in staff) {
      if (s.away || !jobFits(s) || s.job != 7) continue;
      m = min(m, const [0.92, 0.88, 0.82, 0.75][_tier(s)]);
    }
    return m;
  }

  /// 매 프레임: 보조 자리(선반·도크) 직원도 일하는 중이면 체력 소모, 맞는 자리면 직업 경험치
  void updateJobs(double dt) {
    for (final b in buildings) {
      if (b.type.id == 'shelf' || b.type.id == 'dock') {
        final busy = b.type.id == 'shelf' ? b.stored > 0 : b.vehicle != null;
        if (!busy) continue;
        for (final s in b.active) {
          s.working = true;
        }
      }
    }
    for (final s in staff) {
      if (!s.working || !jobFits(s) || s.jobLv >= Cfg.jobMaxLv) continue;
      s.jobXp += dt;
      if (s.jobXp >= s.jobXpNeed) {
        s.jobXp = 0;
        s.jobLv++;
        final sk = s.jobLv == 2 || s.jobLv == 4
            ? ' · 스킬: ${Cfg.jobSkills[s.job][s.jobLv == 2 ? 1 : 2]}'
            : (s.jobLv == Cfg.jobMaxLv ? ' · 전직서로 전직할 수 있어요' : '');
        showToast('${s.name} ${Cfg.jobName[s.job]} Lv${s.jobLv}$sk');
      }
    }
  }

  /// 전직: 직업 Lv5 + 전직서 1장
  void promote(Staff s) {
    if (!s.canPromote) return;
    if (tickets <= 0) {
      showToast('전직서가 없어요 (올해 목표·업적 보상으로 받아요)');
      return;
    }
    tickets--;
    s.promoted = true;
    rt.promotions++;
    showToast('${s.name} 전직! ${Cfg.jobPromo[s.job]} — ${Cfg.jobSkills[s.job][3]}');
    ui();
  }

  /// 직업 바꾸기: 새 직업은 Lv1부터 (예전 직업 레벨은 기록에 남음)
  void changeJob(Staff s, int job) {
    if (job == s.job) return;
    s.jobHist[s.job] = max(s.jobHist[s.job] ?? 0, s.jobLv);
    s.job = job;
    s.jobLv = 1;
    s.jobXp = 0;
    s.promoted = false;
    // 보조 자리(선반·도크)는 분류사·정비사만 일할 수 있어서, 맞지 않게 되면 대기로
    final p = s.post;
    if (p != null && (p.type.id == 'shelf' || p.type.id == 'dock') && !jobFits(s)) {
      this.unassign(s);
    }
    showToast('${s.name} → ${Cfg.jobName[job]} (직업 Lv1부터)');
    ui();
  }

  /// 능력치로 어울리는 직업 (새 후보·예전 저장 직원에게 붙임)
  int bestJob(Staff s) {
    final sc = [
      s.speed + s.kind, // 접수원
      s.speed + s.care, // 포장사
      s.walk * 2, // 운반원
      s.care + s.walk - 1, // 분류사
      s.kind * 2 - 1, // 상담원
      s.care * 2 - 1, // 검수원
      s.stamina + s.walk - 1, // 정비사
      s.stamina + s.kind - 2, // 현장 반장
    ];
    var best = 0;
    for (var i = 1; i < sc.length; i++) {
      if (sc[i] > sc[best]) best = i;
    }
    return best;
  }
}
