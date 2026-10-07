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
    return Staff(nextStaffId++, name, sp, wk, kd, st, cr, 600 + total * 250,
        40 + total * 11);
  }

  /// 게임 시작 때 이미 있는 직원 3명 (건물과 무관, 대기 상태)
  void addStarters() {
    staff.add(Staff(nextStaffId++, '김신입', 3, 2, 3, 3, 2, 0, 100));
    staff.add(Staff(nextStaffId++, '이성실', 2, 3, 4, 2, 4, 0, 110));
    staff.add(Staff(nextStaffId++, '박쾌속', 4, 4, 2, 4, 1, 0, 130));
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
    if (b.type.slots == 0 || b.crew.length >= b.type.slots) return;
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
      buildings.where((b) => b.type.slots > 0 && b.crew.length < b.type.slots);

  int get dailyWages => staff.fold<int>(0, (a, s) => a + s.wage);

  /// 효과가 있는 휴게실 개수 (최대 Cfg.loungeMax)
  int get loungeBonus => min(Cfg.loungeMax, ofType('lounge').length);

  /// 창고 밖 휴식 자리 (휴게실이 없거나 꽉 찼을 때)
  Offset get breakSpot => Offset(area.left - 1.6, area.center.dy + 2.2);

  Offset _homeOf(Staff s) {
    final p = s.post;
    if (p != null) return Offset(p.tx + p.type.w / 2, p.ty + p.type.h / 2);
    return staffSpawn; // 운반 직원
  }

  Offset _restTarget(Staff s) {
    final l = s.lounge;
    if (l == null) return breakSpot;
    final o = Cfg.loungeSeats[s.seat];
    return Offset(l.tx + o.dx, l.ty + o.dy);
  }

  /// 빈 자리가 있는 휴게실을 고름. 없으면 lounge = null (창고 밖에서 쉼)
  void _pickRest(Staff s) {
    s.lounge = null;
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
    final drain = Cfg.drainPerSec * (1.0 - Cfg.loungeDrain * n);
    for (final s in staff) {
      // 회복 속도: 대기·휴식 자리 > 휴게실(×3) > 자리에서 서서 쉬기(아주 느림)
      double gain;
      if (s.idle || s.rest == 2) {
        final inLounge = s.rest == 2 && s.lounge != null;
        gain = Cfg.restPerSec * (inLounge ? Cfg.loungeRestMul : 1.0);
      } else {
        gain = Cfg.idleRestPerSec;
      }
      s.energy += (s.working ? -drain : gain) * dt;
      s.energy = s.energy.clamp(0.0, s.maxEnergy).toDouble();
      s.working = false;
    }
  }

  /// 하루가 끝날 때 월급 지급 + 밤새 체력 회복
  void payroll() {
    for (final s in staff) {
      s.energy = min(s.maxEnergy, s.energy + s.maxEnergy * Cfg.overnightRest);
    }
    final total = dailyWages;
    lastPayroll = total;
    if (total == 0) return;
    if (money >= total) {
      money -= total;
      showToast('월급 지급 -${fmt(total)}원');
    } else {
      final paid = money;
      money = 0;
      showToast('월급을 다 못 줬어요! (${fmt(paid)}/${fmt(total)}원)');
    }
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