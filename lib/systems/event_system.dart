import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 허브 안 선택형 사건: 하루 1~2번 팝업, 같은 사건은 일주일에 한 번 이하.
/// 고르는 동안 게임은 멈추고, 고른 결과는 기간 동안 배수(접수량·월급·체력 소모·직원 능률)로 걸린다.
extension EventSystem on HubGame {
  // ---------------- 하루 일정 ----------------
  /// 새 날이 시작될 때: 오늘 사건이 뜰 시각 1~2개를 정함 (하루 초 단위)
  void planEvents() {
    evtTimes.clear();
    if (day <= Cfg.evtQuietDays) return; // 처음 이틀은 조용히
    final n = Cfg.evtPerDay[0] + rnd.nextInt(Cfg.evtPerDay[1] - Cfg.evtPerDay[0] + 1);
    for (var i = 0; i < n; i++) {
            final t = Cfg.evtWindow[0] + rnd.nextDouble() * (Cfg.evtWindow[1] - Cfg.evtWindow[0]);
      if (t > dayTimer) evtTimes.add(t); // 불러온 게임은 이미 지난 시각은 건너뜀
    }
    evtTimes.sort();
  }

  /// 매 프레임: 시각이 되면 고를 수 있는 사건 하나를 팝업
  void updateEvents(double d) {
    if (evtNow != null || buildings.isEmpty) return;
    if (evtTimes.isNotEmpty && dayTimer >= evtTimes.first && !uiBusy) {
      evtTimes.removeAt(0);
      final pool = [for (var k = 0; k < Cfg.hubEvtName.length; k++) if (_eligible(k)) k];
      if (pool.isNotEmpty && gameTime - evtLastAt >= Cfg.evtMinGap) {
        openEvent(pool[rnd.nextInt(pool.length)]);
      }
    }
    // 진행 중 사건의 직원 능률(다툼) 반영
    for (final s in staff) {
      s.eventMul = 1;
    }
    for (final e in evts) {
      if (e.kind != 2 || e.choice != 1) continue;
      for (final s in staff) {
        if (e.staffIds.contains(s.id)) s.eventMul = Cfg.evtFightSlow;
      }
    }
  }

  /// 지금까지 흐른 게임 시간 (초, 날짜 포함)
  double get gameTime => (day - 1) * Cfg.dayLength + dayTimer;

  /// 팝업을 띄우면 안 되는 때: 시트·건물 시트가 열렸거나, 배치·통로 모드, 직원을 고르는 중, 방금 화면을 만짐
  bool get uiBusy =>
      sheet != null ||
      selected != null ||
      mode != 0 ||
      picking != null ||
      storyAsk != null ||
      postcard != null ||
      DateTime.now().millisecondsSinceEpoch - lastTouchMs < Cfg.evtTouchGrace;

  bool _eligible(int k) {
    final last = evtLast[k];
    if (last != null && day - last < Cfg.evtCooldownDays) return false;
    if (evts.any((e) => e.kind == k)) return false;
    switch (k) {
      case 2: // 직원 다툼: 배치된 직원이 2명 이상
        return staff.where((s) => !s.idle).length >= 2;
      case 5: // 신입 지원자: 직원이 너무 많지 않을 때
        return staff.length < 12;
    }
    return true;
  }

  /// 사건 팝업 열기 (디버그에서도 씀)
  void openEvent(int k) {
    final ids = <int>[];
    if (k == 2) {
      final busy = staff.where((s) => !s.idle).toList()..shuffle(rnd);
      if (busy.length < 2) return;
      ids.addAll([busy[0].id, busy[1].id]);
    }
    final need = k == 3 ? max(8, (intakeNow * 5 * 0.8).round()) : 0;
    evtNow = HubEvent(k, ids, need);
    evtLastAt = gameTime;
    evtLast[k] = day;
    ui();
  }

  // ---------------- 확률·예상 결과 ----------------
  /// TV 취재 성공 확률: 바탕 + 창구 수 × 0.15 + 가장 높은 상담원 직업 Lv × 0.1
  double get tvChance {
    final counters = ofType('counter').length;
    var lv = 0;
    for (final s in staff) {
      if (s.job == 4) lv = max(lv, s.jobLv);
    }
    return (Cfg.evtTvBase + counters * 0.15 + lv * 0.1).clamp(0.05, 0.95).toDouble();
  }

  /// 팝업에 보여 줄 선택지 (글, 예상 결과)
  List<(String, String)> evtChoices(HubEvent e) {
    switch (e.kind) {
      case 0:
        return [
          ('받는다', '오늘 손님 ×${Cfg.evtTvIntake} · 성공 ${(tvChance * 100).round()}%: 명성 +${Cfg.evtTvFame} / 실패: 명성 −${Cfg.evtTvFail}'),
          ('거절', '변화 없음'),
        ];
      case 1:
        return [
          ('특근', '${Cfg.evtRushDays}일간 손님 ×${Cfg.evtRushIntake}, 월급 ×${Cfg.evtRushWage}'),
          ('평소대로', '몰려온 손님을 못 받아 명성 −${Cfg.evtRushFame}'),
        ];
      case 2:
        final names = [for (final s in staff) if (e.staffIds.contains(s.id)) s.name].join('·');
        return [
          ('중재 (${fmt(Cfg.evtFightCost)}원)', '$names 체력 가득 회복'),
          ('놔둔다', '${Cfg.evtFightDays}일간 $names 능률 −${((1 - Cfg.evtFightSlow) * 100).round()}%'),
        ];
      case 3:
        return [
          ('수락', '내일 하루 끝까지 배송 ${e.need}건 (손님 ×${Cfg.evtBulkIntake}) · 성공 +${fmt(e.need * Cfg.evtBulkPay)}원 / 실패 명성 −${Cfg.evtBulkFail}'),
          ('거절', '변화 없음'),
        ];
      case 4:
        final ac = ofType('aircon').isNotEmpty;
        return [
          ('에어컨 임대 (${fmt(Cfg.evtHeatCost)}원)', '오늘 체력 소모 그대로'),
          ('버틴다', '오늘 체력 소모 +${((Cfg.evtHeatDrain - 1) * 100).round()}%${ac ? ' (에어컨이 있어 절반)' : ''}'),
        ];
      default:
        return [
          ('특별 채용', '능력 4~5인 직원이 바로 들어옴 (고용비 없음, 월급 ×${Cfg.evtRookieWage})'),
          ('다음 기회에', '변화 없음'),
        ];
    }
  }

  // ---------------- 고르기 ----------------
  void chooseEvent(int choice) {
    final e = evtNow;
    if (e == null) return;
    evtNow = null;
    switch (e.kind) {
      case 0: // TV 취재
        if (choice == 0) evts.add(ActiveEvt(0, 0, day, day));
        break;
      case 1: // 명절 특수
        if (choice == 0) {
          evts.add(ActiveEvt(1, 0, day, day + Cfg.evtRushDays - 1));
        } else {
          fame = max(0, fame - Cfg.evtRushFame);
          showToast('특근을 안 해서 명성 −${Cfg.evtRushFame}');
        }
        break;
      case 2: // 직원 다툼
        if (choice == 0) {
          if (money < Cfg.evtFightCost) {
            showToast('돈이 부족해서 중재를 못 했어요');
            evts.add(ActiveEvt(2, 1, day, day + Cfg.evtFightDays - 1, staffIds: e.staffIds));
            break;
          }
          money -= Cfg.evtFightCost;
          for (final s in staff) {
            if (e.staffIds.contains(s.id)) s.energy = s.maxEnergy;
          }
          showToast('화해했어요! 둘 다 체력 가득');
        } else {
          evts.add(ActiveEvt(2, 1, day, day + Cfg.evtFightDays - 1, staffIds: e.staffIds));
        }
        break;
      case 3: // 대량 주문
        if (choice == 0) {
          evts.add(ActiveEvt(3, 0, day, day + 1, need: e.need, base: delivered));
        }
        break;
      case 4: // 폭염
        if (choice == 0) {
          if (money >= Cfg.evtHeatCost) {
            money -= Cfg.evtHeatCost;
            showToast('에어컨을 빌렸어요');
          } else {
            showToast('돈이 부족해서 그냥 버텨요');
            evts.add(ActiveEvt(4, 1, day, day));
          }
        } else {
          evts.add(ActiveEvt(4, 1, day, day));
        }
        break;
      default: // 신입 지원자
        if (choice == 0) _hireRookie();
    }
    ui();
  }

  void _hireRookie() {
    int r() => 4 + rnd.nextInt(2);
    final name = Cfg.surnames[rnd.nextInt(Cfg.surnames.length)] +
        Cfg.givens[rnd.nextInt(Cfg.givens.length)];
    final s = Staff(nextStaffId++, name, r(), r(), r(), r(), r(), 0, 0);
    final total = s.speed + s.walk + s.kind + s.stamina + s.care;
    s.wage = ((40 + total * 11) * Cfg.evtRookieWage).round();
    s.job = this.bestJob(s);
    staff.add(s);
    showToast('${s.name} 특별 채용! (${Cfg.jobName[s.job]}, 대기 중)');
  }

  // ---------------- 효과 배수 ----------------
  double get evtIntake {
    var m = 1.0;
    for (final e in evts) {
      if (e.kind == 0) m *= Cfg.evtTvIntake;
      if (e.kind == 1) m *= Cfg.evtRushIntake;
            if (e.kind == 3) m *= Cfg.evtBulkIntake;
      if (e.kind == 6 && e.from <= day) m *= Cfg.guestStreamIntake; // 유튜버 방송 다음 날
    }
    return m;
  }

  double get evtWage => evts.any((e) => e.kind == 1) ? Cfg.evtRushWage : 1.0;

  double get evtDrain {
    if (!evts.any((e) => e.kind == 4)) return 1.0;
    final half = ofType('aircon').isNotEmpty;
    return half ? 1 + (Cfg.evtHeatDrain - 1) / 2 : Cfg.evtHeatDrain;
  }

  // ---------------- 하루 끝 ----------------
  /// 하루가 끝날 때(정산 전): 끝나는 사건 결과를 정하고 정산 카드에 남길 글을 돌려줌
  List<String> resolveEvents(int endedDay) {
    final notes = <String>[];
    for (final e in List.of(evts)) {
      if (e.until > endedDay) continue;
      evts.remove(e);
      switch (e.kind) {
        case 0:
          if (rnd.nextDouble() < tvChance) {
            fame += Cfg.evtTvFame;
            notes.add('TV 취재 성공! 명성 +${Cfg.evtTvFame}');
          } else {
            fame = max(0, fame - Cfg.evtTvFail);
            notes.add('TV 취재 반응이 별로였어요. 명성 −${Cfg.evtTvFail}');
          }
          break;
        case 1:
          notes.add('명절 특근이 끝났어요');
          break;
        case 2:
          notes.add('직원 다툼이 풀렸어요');
          break;
        case 3:
          final got = delivered - e.base;
          if (got >= e.need) {
            final pay = e.need * Cfg.evtBulkPay;
            money += pay;
            notes.add('대량 주문 성공! 배송 $got/${e.need}건 +${fmt(pay)}원');
          } else {
            fame = max(0, fame - Cfg.evtBulkFail);
            notes.add('대량 주문 실패 (배송 $got/${e.need}건). 명성 −${Cfg.evtBulkFail}');
          }
          break;
                case 4:
          notes.add('폭염이 지나갔어요');
          break;
        case 6:
          notes.add('유튜버 방송 효과가 끝났어요');
          break;
      }
    }
    return notes;
  }

  /// 상단 바에 보여 줄 진행 중 사건
  List<String> get evtLabels => [
    for (final e in evts)
      switch (e.kind) {
        0 => 'TV 취재 중',
        1 => '명절 특근 ~${e.until}일차',
        2 => '직원 다툼 ~${e.until}일차',
                3 => '대량 주문 ${delivered - e.base}/${e.need}',
        6 => e.from <= day ? '방송 효과 손님 ×1.3' : '내일 방송 효과',
        _ => '폭염',
      },
  ];
}

/// 팝업에 뜬 사건
class HubEvent {
  final int kind;
  final List<int> staffIds; // 직원 다툼: 두 사람
  final int need; // 대량 주문: 배송 건수
  const HubEvent(this.kind, this.staffIds, this.need);
}

/// 진행 중인 사건 (from~until 일차, 저장됨)
class ActiveEvt {
  final int kind, choice, from, until;
  final List<int> staffIds;
  final int need, base; // 대량 주문: 목표, 시작 때 배송 수
  ActiveEvt(this.kind, this.choice, this.from, this.until,
      {this.staffIds = const [], this.need = 0, this.base = 0});

  Map<String, dynamic> toJson() => {
    'k': kind, 'c': choice, 'f': from, 'u': until, 's': staffIds, 'n': need, 'b': base,
  };

  static ActiveEvt fromJson(Map<String, dynamic> j) => ActiveEvt(
    (j['k'] as num).toInt(),
    (j['c'] as num).toInt(),
    (j['f'] as num).toInt(),
    (j['u'] as num).toInt(),
    staffIds: ((j['s'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
    need: (j['n'] as num?)?.toInt() ?? 0,
    base: (j['b'] as num?)?.toInt() ?? 0,
  );
}
