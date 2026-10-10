import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/util.dart';
import '../models/models.dart';

extension StaffSystem on HubGame {
  int _roll() {
    var v = 1 + rnd.nextInt(4); // 1~4
    if (rnd.nextDouble() < 0.3) v++; // 가끔 5
    return v > 5 ? 5 : v;
  }

  Staff _makeCandidate() {
    final sp = _roll();
    final wk = _roll();
    final kd = _roll();
    final st = _roll();
    final cr = _roll();
    final total = sp + wk + kd + st + cr;
    final name = Cfg.surnames[rnd.nextInt(Cfg.surnames.length)] +
        Cfg.givens[rnd.nextInt(Cfg.givens.length)];
        final s = Staff(nextStaffId++, name, sp, wk, kd, st, cr, 600 + total * 250,
        40 + total * 11);
    s.job = this.bestJob(s); // 능력치에 어울리는 직업으로 들어옴 (바꿀 수 있음)
    return s;
  }

  /// 게임 시작 때 이미 있는 직원 3명. 모두 대기(휴식 벤치)에서 시작하고, 유저가 직접 배치한다.
  void addStarters() {
        staff.add(Staff(nextStaffId++, '김신입', 3, 2, 3, 3, 2, 0, 100)..job = 0);
    staff.add(Staff(nextStaffId++, '이성실', 2, 3, 4, 2, 4, 0, 110)..job = 1);
    staff.add(Staff(nextStaffId++, '박쾌속', 4, 4, 2, 4, 1, 0, 130)..job = 2);
    syncCarriers();
    if (fleet.isEmpty) grantStarterUnits(0); // 기본 차량: 대형 트럭 + 오토바이
  }

  /// (디버그 시작 구성 전용) 대기 중인 직원을 한 명 배치. 일반 건설은 유저가 직접 배치한다.
  void autoAssign(Building b) {
    if (b.type.slots == 0) return;
    for (final s in staff) {
      if (s.idle) {
        assignTo(s, b);
        return;
      }
    }
  }

  void genCandidates() {
    candidates.clear();
    for (var i = 0; i < Cfg.candidateCount; i++) {
      candidates.add(_makeCandidate());
    }
    ui();
  }

  /// 후보를 돈 내고 새로 뽑기
  void refreshCandidates() {
    if (money < Cfg.refreshCost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= Cfg.refreshCost;
    candTimer = 0;
    genCandidates();
  }

  void hireCandidate(Staff s) {
    if (!candidates.contains(s)) return;
    if (money < s.hireCost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= s.hireCost;
    candidates.remove(s);
    staff.add(s);
    showToast('${s.name} 고용! (대기 중)');
  }

  // 현재 배치에서 떼어냄 (UI 갱신 없음). 쉬던 중이면 휴식도 끝냄.
  void _detach(Staff s) {
    final p = s.post;
    if (p != null) {
      p.crew.remove(s);
      s.post = null;
    }
    s.carrier = false;
    s.rest = 0;
    s.lounge = null;
  }

  void unassign(Staff s) {
    _detach(s);
    syncCarriers();
    ui();
  }

  void setCarrier(Staff s) {
    _detach(s);
    s.carrier = true;
    syncCarriers();
    ui();
  }

  void assignTo(Staff s, Building b) {
        if (b.seats == 0 || b.crew.length >= b.seats) return;
    if (s.training != null) {
      showToast('${s.name}은(는) 훈련 중이에요');
      return;
    }
    // 선반·도크 보조 자리는 분류사·정비사만 (직접 일은 안 하고 보너스만 냄)
    if (b.type.id == 'shelf' && s.job != 3) {
      showToast('선반 보조 자리에는 분류사만 배치할 수 있어요');
      return;
    }
    if (b.type.id == 'dock' && s.job != 6) {
      showToast('도크 보조 자리에는 정비사만 배치할 수 있어요');
      return;
    }
    if (b.crew.contains(s)) return;
    _detach(s);
    b.crew.add(s);
    s.post = b;
    syncCarriers();
    ui();
  }

  void fire(Staff s) {
    _detach(s);
    staff.remove(s);
    syncCarriers();
    showToast('${s.name} 해고');
  }

  /// 건물 철거 때 근무 직원을 대기로 돌려보냄
  void releaseCrew(Building b) {
    for (final s in List<Staff>.from(b.crew)) {
      s.post = null;
      s.rest = 0;
      s.lounge = null;
    }
    b.crew.clear();
  }

  /// 빈 자리가 있는 건물들
  Iterable<Building> openPosts() =>
      buildings.where((b) => b.seats > 0 && b.crew.length < b.seats);

  int get dailyWages => (staff.fold<int>(0, (a, s) => a + s.wage) * this.evtWage).round(); // 특근이면 ×1.3

  /// 효과가 있는 휴게실 개수 (최대 Cfg.loungeMax)
  int get loungeBonus => min(Cfg.loungeMax, ofType('lounge').length);

  /// 창고 밖 휴식 자리 (휴게실이 없거나 꽉 찼을 때)
  Offset get breakSpot => Offset(area.left - 2.0, area.center.dy + 2.7);

  /// 대기 직원이 서 있는 자리: 휴식 벤치 둘레 (발끝 위치, 타일 좌표)
  Offset benchSpot(Staff s) {
    final idle = staff.where((x) => x.idle).toList();
    final i = max(0, idle.indexOf(s));
    // 벤치 앞에 3명씩 줄지어 섬
    final o = Offset(-0.9 + 0.9 * (i % 3), 1.25 + 0.95 * (i ~/ 3));
    return breakSpot + o;
  }

  /// 대기 직원이 지금 서 있는 곳: 벤치 앞 제자리 + 어슬렁거린 만큼
  Offset idleSpot(Staff s) => benchSpot(s) + s.idleOff;

  /// 대기 직원 어슬렁 (매 프레임, 실제 시간 dt): 제자리 둘레를 천천히 걷다 멈춰 둘러보고, 가끔 혼잣말.
  /// 고른 직원(배치할 시설을 기다리는 중)은 멈춰 있음
  void updateIdle(double dt) {
    for (final s in staff) {
      if (s.idleSayT > 0) s.idleSayT -= dt;
      if (!s.idle) {
        s.idleOff = Offset.zero;
        s.idleGoal = null;
        s.idleSayT = 0;
        continue;
      }
      if (picking == s) continue;
      final goal = s.idleGoal;
      if (goal == null) {
        // 처음엔 다 같이 움직이지 않게 기다리는 시간을 흩어 둠
        s.idleGoal = s.idleOff;
        s.idleWait = rnd.nextDouble() * Cfg.idleWaitMax;
        continue;
      }
      if (s.idleWait > 0) {
        s.idleWait -= dt;
        continue;
      }
      s.idleOff = stepToward(s.idleOff, goal, Cfg.idleWalkSpeed, dt);
      if (s.idleOff != goal) continue;
      // 도착: 잠깐 서 있다가 다음 곳으로. 가끔은 제자리로 돌아오고, 가끔은 한 발짝만 떼서 고개를 돌림
      s.idleWait = Cfg.idleWaitMin + rnd.nextDouble() * (Cfg.idleWaitMax - Cfg.idleWaitMin);
      // 다른 사람(대기 직원·벤치에서 쉬는 직원)과 몸이 겹치지 않는 곳만 고름. 몇 번 해 봐도 없으면 제자리에서 고개만 돌림
      final home = benchSpot(s);
      Offset? next;
      for (var k = 0; k < 6 && next == null; k++) {
        final r = rnd.nextDouble();
        final o = r < 0.3
            ? Offset.zero
            : r < 0.5
                ? _clampRoam(s.idleOff + Offset((rnd.nextBool() ? 1 : -1) * 0.12, 0))
                : Offset(
                    (rnd.nextDouble() * 2 - 1) * Cfg.idleRoamX,
                    -Cfg.idleRoamUp + rnd.nextDouble() * (Cfg.idleRoamUp + Cfg.idleRoamDown),
                  );
        if (_roomAt(s, home + o)) next = o;
      }
      s.idleGoal = next ?? s.idleOff;
      if (rnd.nextDouble() < Cfg.idleSayChance) {
        s.idleSay = Cfg.idleSays[rnd.nextInt(Cfg.idleSays.length)];
        s.idleSayT = 2.2;
      }
    }
  }

  /// 이 자리에 서도 다른 사람과 안 겹치는지 (지금 선 곳과 가는 곳 둘 다 피함)
  bool _roomAt(Staff s, Offset p) {
    for (final o in staff) {
      if (o == s) continue;
      if (o.idle) {
        final g = o.idleGoal;
        if ((idleSpot(o) - p).distance < Cfg.idleGap) return false;
        if (g != null && (benchSpot(o) + g - p).distance < Cfg.idleGap) return false;
      } else if (o.rest != 0 && (o.pos - p).distance < Cfg.idleGap) {
        return false; // 쉬러 오가는 직원·벤치 옆에서 쉬는 직원
      }
    }
    return true;
  }

  Offset _clampRoam(Offset o) => Offset(
        o.dx.clamp(-Cfg.idleRoamX, Cfg.idleRoamX).toDouble(),
        o.dy.clamp(-Cfg.idleRoamUp, Cfg.idleRoamDown).toDouble(),
      );

  /// 화면을 탭한 곳에 있는 직원 (대기 직원·운반 직원). 없으면 null
  Staff? staffAt(Offset world) {
    final tp = Offset(world.dx / Cfg.tile, world.dy / Cfg.tile);
    bool hit(Offset feet) =>
        (tp - (feet - const Offset(0, 0.45))).distance < 0.6;
    for (final s in staff) {
      if (s.idle && hit(idleSpot(s))) return s;
    }
    for (final c in carriers) {
      if (!c.staff.away && hit(c.pos)) return c.staff;
    }
    return null;
  }

  /// 먼저 고른 직원을 시설에 배치. 선반·도크를 고르면 운반 담당. 배치했으면 true
  bool placePicked(Building b) {
    final s = picking;
    if (s == null) return false;
    picking = null;
        final helper = (b.type.id == 'shelf' && s.job == 3) || (b.type.id == 'dock' && s.job == 6);
    if (b.type.slots > 0 || helper) {
      if (b.crew.length >= b.seats && !b.crew.contains(s)) {
        showToast('${b.type.name}에 빈 자리가 없어요');
        return true;
      }
      assignTo(s, b);
      showToast('${s.name} → ${b.type.name} 배치');
      return true;
    }
    if (b.type.id == 'shelf' || b.type.id == 'dock') {
      setCarrier(s);
      showToast('${s.name} → 운반 담당');
      return true;
    }
    showToast('직원을 배치할 수 없는 시설이에요');
    return true;
  }

  Offset _homeOf(Staff s) {
    final p = s.post;
    if (p != null) return Offset(p.tx + p.type.w / 2, p.ty + p.type.h / 2);
    return staffSpawn; // 운반 직원
  }

  Offset _restTarget(Staff s) {
    final l = s.lounge;
    if (l == null) return breakSpot + Cfg.benchRestSlots[s.seat % Cfg.benchRestSlots.length];
    final o = Cfg.loungeSeats[s.seat];
    return Offset(l.tx + o.dx, l.ty + o.dy);
  }

  /// 빈 자리가 있는 휴게실을 고름. 없으면 lounge = null (창고 밖에서 쉼)
  void _pickRest(Staff s) {
    s.lounge = null;
    // 휴게실이 없으면 창고 밖 벤치 옆 빈 칸에 서서 쉼 (벤치 대기 줄과 안 겹치게)
    final outside = staff.where((x) => x != s && x.rest != 0 && x.lounge == null).map((x) => x.seat).toSet();
    s.seat = 0;
    while (outside.contains(s.seat) && s.seat < Cfg.benchRestSlots.length - 1) {
      s.seat++;
    }
    for (final l in ofType('lounge')) {
      final used = staff
          .where((x) => x != s && x.rest != 0 && x.lounge == l)
          .map((x) => x.seat)
          .toSet();
      for (var i = 0; i < Cfg.loungeSeats.length; i++) {
        if (!used.contains(i)) {
          s.lounge = l;
          s.seat = i;
          return;
        }
      }
    }
  }

  /// 지친 직원은 자리를 떠나 쉬러 가고, 회복하면 걸어서 돌아온다.
  void updateRest(double dt) {
    for (final s in staff) {
      // 배치가 없으면(대기·해제) 쉬는 연출 없이 제자리 회복
      if (s.idle) {
        s.rest = 0;
        s.lounge = null;
        continue;
      }

      if (s.rest == 0) {
        if (s.energyPct > Cfg.restBelow) continue;
        Carrier? car;
        for (final c in carriers) {
          if (c.staff == s) car = c;
        }
        if (car != null && car.job != null) continue; // 운반 중이면 끝내고 쉼
        s.pos = car != null ? car.pos : _homeOf(s);
        _pickRest(s);
        s.rest = 1;
        continue;
      }

      // 쉬는 중 휴게실이 철거됐으면 다시 고름
      final l = s.lounge;
      if (l != null && !buildings.contains(l)) {
        _pickRest(s);
        if (s.rest == 2) s.rest = 1;
      }

      final speed = Cfg.carrierSpeed * s.walkMul;
      if (s.rest == 1) {
        final t = _restTarget(s);
        s.pos = stepToward(s.pos, t, speed, dt);
        if ((s.pos - t).distance < 0.05) s.rest = 2;
      } else if (s.rest == 2) {
        if (s.energyPct >= Cfg.restUntil) s.rest = 3;
      } else {
        final h = _homeOf(s);
        s.pos = stepToward(s.pos, h, speed, dt);
        if ((s.pos - h).distance < 0.05) {
          s.rest = 0;
          s.lounge = null;
          for (final c in carriers) {
            if (c.staff == s) c.pos = s.pos;
          }
        }
      }
    }
  }

  /// 체력 계산: 일한 직원은 줄고, 쉰 직원은 찬다. (매 프레임, 일 처리 뒤에 호출)
  void updateStaffEnergy(double dt) {
    final n = loungeBonus;
    final drain = Cfg.drainPerSec * (1.0 - Cfg.loungeDrain * n) * this.jobDrain * this.evtDrain; // 현장 반장·폭염
    for (final s in staff) {
      // 회복 속도: 대기·휴식 자리 > 휴게실(×3) > 자리에서 서서 쉬기(아주 느림)
      double gain;
      if (s.idle || s.rest == 2) {
        final inLounge = s.rest == 2 && s.lounge != null;
                gain = Cfg.restPerSec * (inLounge ? Cfg.loungeRestMul * s.lounge!.setRest : 1.0);
      } else {
        gain = Cfg.idleRestPerSec;
      }
            s.energy += (s.working ? -drain * this.drainAt(s) : gain) * dt; // 화분·에어컨·세트
      s.energy = s.energy.clamp(0.0, s.maxEnergy).toDouble();
      if (s.working) _grow(s, dt);
      s.working = false;
    }
  }

  /// 일한 시간만큼 경험치가 쌓이고, 차면 레벨업 (3레벨부터 맡은 일에 맞는 특기)
  void _grow(Staff s, double dt) {
    if (s.level < Staff.maxLevel) {
      s.xp += dt;
      if (s.xp >= s.xpNeed) {
        s.xp -= s.xpNeed;
        s.level++;
        s.wage += 15;
        showToast('${s.name} 레벨 ${s.level}! 일급 +15원');
      }
    }
  }

  /// 하루가 끝날 때 월급 지급 + 밤새 체력 회복
  void payroll() {
    for (final s in staff) {
      s.energy = min(s.maxEnergy, s.energy + s.maxEnergy * Cfg.overnightRest);
    }
    final total = dailyWages;
    lastPayroll = total;
        final earned = dayEarn;
    dayEarn = 0;
    var paidAll = true;
    if (money >= total) {
      money -= total;
    } else {
      paidAll = false;
      money = 0; // 파산은 없음: 다 못 준 만큼은 사라지고 정산 카드에 표시
    }
    this.finishReport(earned, total, paidAll); // 하루 정산 카드 (등급·수익·월급)
  }

  /// 운반 담당 직원 ↔ 맵의 Carrier 맞추기
  void syncCarriers() {
    for (var i = carriers.length - 1; i >= 0; i--) {
      final c = carriers[i];
      if (!staff.contains(c.staff) || !c.staff.carrier) {
        this.dropCarrier(c);
        carriers.removeAt(i);
      }
    }
    for (final s in staff) {
      if (s.carrier && !carriers.any((c) => c.staff == s)) {
        carriers.add(Carrier(s, staffSpawn));
      }
    }
  }
}