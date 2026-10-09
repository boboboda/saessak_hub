import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/util.dart';
import '../models/models.dart';

extension FlowSystem on HubGame {
  void spawnCustomer({int behind = 0}) {
    final open = <int>[
      for (var i = 0; i < regionOpen.length; i++)
        if (regionOpen[i] && routes[i].on) i,
    ];
    if (open.isEmpty) return; // 켜진 노선이 없으면 손님도 오지 않음
    // 함께 온 손님은 조금 뒤에서 따라 들어옴
    final cu = Customer(
      exitPoint.translate(-0.9 * behind, 0),
      open[rnd.nextInt(open.length)],
    );
        cu.look = rnd.nextInt(6);
    cu.guest = this.pickGuest();
    if (cu.guest >= 0) {
      cu.look = Cfg.guestLook0 + cu.guest; // 숨은 손님은 사연 대신 이름표
    } else if (behind == 0) {
      cu.story = this.pickStory(); // 사연 손님만 말풍선 (일반 손님은 없음)
    }
    final r = rnd.nextDouble();
    if (day >= 2) {
      cu.kind = r < 0.08 ? 1 : (r < 0.16 ? 2 : (r < 0.22 ? 3 : 0));
    }
    if (day >= 3 && rnd.nextDouble() < 0.06) {
      cu.vip = true;
      cu.patience *= Cfg.vipPatience;
    }
    customers.add(cu);
  }

  Building? _bestCounter(List<Building> counters, Map<Building, int> load) {
    Building? best;
    var bl = 1 << 30;
    for (final b in counters) {
      final l = load[b] ?? 0;
      if (l < bl) {
        bl = l;
        best = b;
      }
    }
    if (best != null) load[best] = (load[best] ?? 0) + 1;
    return best;
  }

  /// 자리에 있는 직원들의 합산 처리 속도 (지친 직원은 느림, 건물 레벨·특기 반영)
  double _rate(Building b) =>
      b.active.fold<double>(
        0,
        (a, s) =>
            a +
            s.workRate * this.jobRate(s),
            ) *
            b.speedMul *
      b.setSpeed * // 세트 (포장 라인·공지 게시판 등)
      (b.type.id == 'counter' ? this.resCounter : this.resPack); // 연구

  /// 손님이 맡긴 택배 만들기 (VIP 팁 포함)
  Parcel _mkParcel(Customer c) {
    final p = Parcel(c.region);
    p.kind = c.kind;
    p.born = gt;
        if (c.vip) {
      final cnt = c.counter;
      final tip = Cfg.vipTip * (cnt != null && this.vipDouble(cnt) ? 2 : 1);
      money += tip;
      dayEarn += tip;
    }
    return p;
  }

  /// 손님이 짜증 내는 속도 배수 (직원이 친절할수록 낮음)
  double _calm(Building b) {
    final act = b.active;
    final vend = ofType('vending').length.clamp(0, Cfg.vendingMax);
    final vm = 1.0 - Cfg.vendingCalm * vend;
        if (act.isEmpty) return 1.0 * vm * b.setCalm * this.resCalm;
    final avg = act.fold<int>(0, (a, s) => a + s.kind) / act.length;
    return (1.25 - 0.1 * avg) * vm * this.jobCalm(b) * b.setCalm * this.resCalm; // 상담원·접수원 Lv4·세트·번호표
  }

  /// 포장 실수 판정: 꼼꼼할수록 줄고, 지친 직원이 있으면 늘어남
  bool _slipped(Building b) {
    final act = b.active;
    if (act.isEmpty) return false;
    final care = act.fold<int>(0, (a, s) => a + s.care) / act.length;
    var chance = Cfg.slipBase - Cfg.slipPerCare * care;
    if (act.any((s) => s.tired)) chance += Cfg.slipTired;
    chance *= this.jobSlip(b); // 포장사 Lv4·검수원
    return rnd.nextDouble() < chance.clamp(0.0, 0.9);
  }

  /// 손님 입장·접수·퇴장 + 포장대 포장 진행
  void updateFlow(double dt) {
    // 내 자리이거나 자리에 직원이 있는 접수 창구만 손님을 받음 (쉬러 간 직원은 빠짐)
    final counters = ofType('counter')
        .where((b) => b.mine || b.active.isNotEmpty)
        .toList();

    // 손님 생성
    if (counters.isNotEmpty) {
      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        // 도착 간격은 접수량(명성 구간 × 성수기)으로만 정해진다. 창구를 늘려도 손님이 더 오지 않음
        final j = Cfg.intakeJitter;
        // 손님은 1~groupMax 명씩 함께 온다. 간격을 평균 인원만큼 늘려서 분당 접수량은 그대로
        final g = 1 + rnd.nextInt(Cfg.groupMax);
        final avg = (1 + Cfg.groupMax) / 2;
        spawnTimer = 60 / intakeNow * avg * (1 - j + rnd.nextDouble() * 2 * j);
        for (var k = 0; k < g; k++) {
          if (customers.length < 4 + counters.length * 3) {
            spawnCustomer(behind: k);
          } else {
                        lost++; // 줄이 너무 길어 그냥 돌아감
            this.rateLost();
          }
        }
      }
    }

    // 창구별 대기 인원
    final load = <Building, int>{};
    for (final c in customers) {
      if (c.state == 2) continue;
      final b = c.counter;
      if (b != null && buildings.contains(b)) {
        load[b] = (load[b] ?? 0) + 1;
      }
    }

    final lineIdx = <Building, int>{};
    final remove = <Customer>[];
    final exit = exitPoint;

    for (final c in customers) {
      if (c.state == 2) {
        c.pos = stepToward(c.pos, exit, Cfg.customerSpeed, dt);
        if ((c.pos - exit).distance < 0.05) remove.add(c);
        continue;
      }

      // 사연 손님: 줄을 서지 않고 문 앞에서 기다림 (탭하면 선택 카드)
      if (c.story >= 0) {
        this.storyCustomerStep(c, dt);
        continue;
      }

      // 창구 배정 (없거나 철거되거나 자리 직원이 없으면 다시)
      final cur = c.counter;
      if (cur == null ||
          !buildings.contains(cur) ||
          !(cur.mine || cur.active.isNotEmpty)) {
        c.counter = _bestCounter(counters, load);
        c.serveT = 0;
        if (c.counter == null) {
                    lost++; // 받아 줄 창구가 없어 그냥 돌아감
          this.rateLost();
          c.state = 2;
          continue;
        }
      }
      final cnt = c.counter!;
      final idx = lineIdx[cnt] ?? 0;
      lineIdx[cnt] = idx + 1;

      final target = frontOf(cnt) + Offset(0, idx * 0.8);
      c.pos = stepToward(c.pos, target, Cfg.customerSpeed, dt);
      final arrived = (c.pos - target).distance < 0.05;
      final canServe = arrived && idx == 0 && cnt.outbox.length < cnt.outCap;
      c.ready = canServe && cnt.mine;

      if (canServe && cnt.mine && c.tapped) {
        // 내가 직접 탭해서 접수: 기다리지 않고 바로 끝, 보너스
                        cnt.outbox.add(_mkParcel(c));
        done++;
        this.rateServed(c);
        this.guestServed(c, cnt);
        money += Cfg.tapBonus;
        dayEarn += Cfg.tapBonus;
        c.tapped = false;
        c.ready = false;
        c.state = 2;
      } else if (canServe && cnt.active.isNotEmpty) {
        // 직원이 빠를수록, 많을수록 접수가 빨라짐 (일하는 동안 체력 소모)
        for (final s in cnt.active) {
          s.working = true;
        }
        c.serveT += dt * _rate(cnt);
        if (c.serveT >= Cfg.serveTime) {
                              cnt.outbox.add(_mkParcel(c));
          done++;
          this.rateServed(c);
          this.guestServed(c, cnt);
          c.state = 2;
        }
      } else {
        c.patience -= dt * _calm(cnt);
                if (c.patience <= 0) {
          lost++;
          this.rateLost();
          c.state = 2;
        }
      }
    }
    customers.removeWhere((c) => remove.contains(c));

    // 포장대 진행 (자리에 직원이 있어야 함)
    for (final b in ofType('pack')) {
      if (b.flash > 0) b.flash -= dt;
      final p = b.slot;
      if (p != null && p.stage == 2 && b.active.isNotEmpty) {
        for (final s in b.active) {
          s.working = true;
        }
        b.progress += dt * _rate(b);
        if (b.progress >= Cfg.packTime) {
          if (_slipped(b)) {
            // 포장 실수: 처음부터 다시 (파손주의 택배는 배상)
                        b.progress = 0;
            b.flash = 1.5;
            this.rateMistake();
            final act = b.active;
            act[rnd.nextInt(act.length)].mistakes++;
            if (p.kind == 2) {
              final pen = money < Cfg.breakPenalty ? money : Cfg.breakPenalty;
              money -= pen;
              showToast('파손! 배상 -$pen원');
            }
          } else {
                        p.stage = 3;
            p.reserved = false;
            rt.packed++;
            if (p.kind == 2) {
              money += Cfg.fragileBonus;
              dayEarn += Cfg.fragileBonus;
            }
          }
        }
      }
    }
  }
}
