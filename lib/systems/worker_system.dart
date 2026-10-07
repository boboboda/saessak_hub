import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/util.dart';
import '../models/models.dart';

extension WorkerSystem on HubGame {
  void updateWorkers(double dt) {
    for (final c in carriers) {
      if (c.staff.away) continue; // 쉬러 간 직원은 일 안 함
      _validate(c);
      if (c.idle) _assign(c);
      if (!c.idle) _move(c, dt);
    }
    // 이번 프레임의 일(접수·포장·운반)이 끝났으니 휴식과 체력 계산
    this.updateRest(dt);
    this.updateStaffEnergy(dt);
  }

  /// 운반 담당에서 빠질 때 맡은 일 정리 (직원 배치 변경·해고 때 호출)
  void dropCarrier(Carrier c) {
    final p = c.job;
    if (p == null) return;
    if (!c.carrying) {
      p.reserved = false;
      final d = c.dst;
      if (d != null && buildings.contains(d)) _release(d);
    }
    _clear(c);
  }

  // ---- 예약 관리 ----
  void _reserveDst(Building d) {
    if (d.type.id == 'pack') {
      d.reservedIn = true;
    } else {
      d.incoming++;
    }
  }

  void _release(Building d) {
    if (d.type.id == 'pack') {
      d.reservedIn = false;
    } else {
      d.incoming = max(0, d.incoming - 1);
    }
  }

  void _clear(Carrier c) {
    c.job = null;
    c.src = null;
    c.dst = null;
    c.carrying = false;
  }

  Building? _nearest(Iterable<Building> list, Offset from) {
    Building? best;
    var bd = 1e9;
    for (final b in list) {
      final d = (frontOf(b) - from).distance;
      if (d < bd) {
        bd = d;
        best = b;
      }
    }
    return best;
  }

  /// 택배 단계에 맞는 목적지 찾기 (접수 대기 → 자리에 직원 있는 포장대, 포장 완료 → 선반)
  Building? _findDst(Parcel p, Offset from) {
    if (p.stage == 0) {
      return _nearest(
          ofType('pack').where(
                  (b) => b.slot == null && !b.reservedIn && b.active.isNotEmpty),
          from);
    }
    return _nearest(
        ofType('shelf').where((b) => b.stored + b.incoming < Cfg.shelfCap),
        from);
  }

  /// 건물이 철거됐는지 확인하고 일 정리
  void _validate(Carrier c) {
    if (c.job == null) return;
    final srcOk = c.carrying || (c.src != null && buildings.contains(c.src));
    final dstOk = c.dst != null && buildings.contains(c.dst);
    if (srcOk && dstOk) return;

    if (!c.carrying) {
      c.job!.reserved = false;
      if (dstOk) _release(c.dst!);
      _clear(c);
      return;
    }
    // 들고 가는 중 목적지가 사라짐 → 새 목적지, 없으면 택배 소실
    final nd = _findDst(c.job!, c.pos);
    if (nd == null) {
      _clear(c);
      return;
    }
    c.dst = nd;
    _reserveDst(nd);
  }

  /// 일감 찾기: 포장 끝난 택배 먼저, 그다음 접수 대기 택배
  void _assign(Carrier c) {
    Building? bestSrc;
    Parcel? bestP;
    Building? bestDst;
    var bestD = 1e9;

    for (final b in ofType('pack')) {
      final p = b.slot;
      if (p == null || p.stage != 3 || p.reserved) continue;
      final d = (frontOf(b) - c.pos).distance;
      if (d >= bestD) continue;
      final dst = _findDst(p, frontOf(b));
      if (dst == null) continue;
      bestSrc = b;
      bestP = p;
      bestDst = dst;
      bestD = d;
    }

    if (bestSrc == null) {
      for (final b in ofType('counter')) {
        Parcel? p;
        for (final q in b.outbox) {
          if (!q.reserved) {
            p = q;
            break;
          }
        }
        if (p == null) continue;
        final d = (frontOf(b) - c.pos).distance;
        if (d >= bestD) continue;
        final dst = _findDst(p, frontOf(b));
        if (dst == null) continue;
        bestSrc = b;
        bestP = p;
        bestDst = dst;
        bestD = d;
      }
    }

    if (bestSrc == null || bestP == null || bestDst == null) return;
    bestP.reserved = true;
    _reserveDst(bestDst);
    c.job = bestP;
    c.src = bestSrc;
    c.dst = bestDst;
    c.carrying = false;
  }

  void _move(Carrier c, double dt) {
    c.staff.working = true; // 걷는 동안 체력 소모
    final target = c.carrying ? frontOf(c.dst!) : frontOf(c.src!);
    c.pos = stepToward(c.pos, target, Cfg.carrierSpeed * c.staff.walkMul, dt);
    if ((c.pos - target).distance > 0.05) return;

    final p = c.job!;
    if (!c.carrying) {
      final s = c.src!;
      if (s.type.id == 'counter') {
        s.outbox.remove(p);
      } else {
        s.slot = null;
        s.progress = 0;
      }
      c.carrying = true;
    } else {
      final d = c.dst!;
      if (d.type.id == 'pack') {
        d.slot = p;
        p.stage = 2;
        p.reserved = false;
        d.progress = 0;
        d.reservedIn = false;
      } else {
        d.stored++;
        d.incoming = max(0, d.incoming - 1);
        money += Cfg.shelfIncome; // 임시 수익 (배송 수익 단계에서 교체)
      }
      _clear(c);
    }
  }
}