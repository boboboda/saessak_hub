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
    if (p.stage == 4) {
      _abortLoad(c);
      return;
    }
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
    } else if (d.type.id == 'dock') {
      d.vehicle?.incoming++;
    } else {
      d.incoming++;
    }
  }

  void _release(Building d) {
    if (d.type.id == 'pack') {
      d.reservedIn = false;
    } else if (d.type.id == 'dock') {
      final v = d.vehicle;
      if (v != null) v.incoming = max(0, v.incoming - 1);
    } else {
      d.incoming = max(0, d.incoming - 1);
    }
  }

  /// 적재 일 취소: 예약 풀기, 이미 들고 있으면 선반에 되돌려 놓음
  void _abortLoad(Carrier c) {
    final p = c.job;
    if (p == null) return;
    final src = c.src;
    if (!c.carrying) {
      if (src != null && buildings.contains(src)) {
        src.pickRes[p.region] = max(0, src.pickRes[p.region] - 1);
      }
    } else {
      final shelf = _nearest(
          ofType('shelf').where((b) => b.stored < b.cap + 5), c.pos);
      if (shelf != null) {
        shelf.stored++;
        shelf.regions[p.region]++;
      }
    }
    final v = c.veh;
    if (v != null) v.incoming = max(0, v.incoming - 1);
    c.veh = null;
    _clear(c);
  }

  /// 차량에 싣는 일 찾기: 선반(해당 지역 택배) → 도크의 차량
  bool _assignLoad(Carrier c) {
    Building? bestDock;
    var bestD = 1e9;
    for (final d in ofType('dock')) {
      final v = d.vehicle;
      if (v == null || v.state != 1) continue;
      if (v.loaded + v.incoming >= v.type.cap) continue;
      final dist = (frontOf(d) - c.pos).distance;
      if (dist >= bestD) continue;
      final shelf = _nearest(
          ofType('shelf').where((b) => b.regions[v.region] - b.pickRes[v.region] > 0),
          c.pos);
      if (shelf == null) continue;
      bestDock = d;
      bestD = dist;
    }
    if (bestDock == null) return false;
    final v = bestDock.vehicle!;
    final shelf = _nearest(
        ofType('shelf').where((b) => b.regions[v.region] - b.pickRes[v.region] > 0),
        c.pos)!;
    shelf.pickRes[v.region]++;
    v.incoming++;
    final p = Parcel(v.region)..stage = 4;
    c.job = p;
    c.src = shelf;
    c.dst = bestDock;
    c.veh = v;
    c.carrying = false;
    return true;
  }

  void _clear(Carrier c) {
    c.job = null;
    c.src = null;
    c.dst = null;
    c.veh = null;
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
        ofType('shelf').where((b) => b.stored + b.incoming < b.cap),
        from);
  }

  /// 건물이 철거됐는지 확인하고 일 정리
  void _validate(Carrier c) {
    if (c.job == null) return;
    if (c.job!.stage == 4) {
      final srcOk = c.carrying || (c.src != null && buildings.contains(c.src));
      final dst = c.dst;
      final vehOk = dst != null &&
          buildings.contains(dst) &&
          dst.vehicle != null &&
          dst.vehicle == c.veh &&
          dst.vehicle!.state == 1;
      if (!srcOk || !vehOk) _abortLoad(c);
      return;
    }
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
      final d = (frontOf(b) - c.pos).distance - (p.kind == 1 ? 100 : 0);
      if (d >= bestD) continue;
      final dst = _findDst(p, frontOf(b));
      if (dst == null) continue;
      bestSrc = b;
      bestP = p;
      bestDst = dst;
      bestD = d;
    }

    if (bestSrc == null && _assignLoad(c)) return;

    if (bestSrc == null) {
      for (final b in ofType('counter')) {
        Parcel? p;
        for (final q in b.outbox) {
          if (q.reserved) continue;
          if (p == null || (q.kind == 1 && p.kind != 1)) p = q;
        }
        if (p == null) continue;
        final d = (frontOf(b) - c.pos).distance - (p.kind == 1 ? 100 : 0);
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
    var slow = (c.carrying && c.job!.kind == 3) ? Cfg.bulkySlow : 1.0;
    if (c.job!.stage == 4) slow *= c.dst!.loadMul; // 도크 업그레이드: 싣는 속도
    c.pos = stepToward(
        c.pos, target, Cfg.carrierSpeed * c.staff.walkMul * slow, dt);
    if ((c.pos - target).distance > 0.05) return;

    final p = c.job!;
    if (p.stage == 4) {
      if (!c.carrying) {
        // 선반에서 집기
        final sh = c.src!;
        if (sh.regions[p.region] <= 0) {
          _abortLoad(c);
          return;
        }
        sh.regions[p.region]--;
        sh.pickRes[p.region] = max(0, sh.pickRes[p.region] - 1);
        sh.stored = max(0, sh.stored - 1);
        c.carrying = true;
      } else {
        // 차량에 싣기
        final v = c.dst!.vehicle;
        if (v != null && v == c.veh && v.state == 1) {
          v.loaded++;
          v.incoming = max(0, v.incoming - 1);
          v.idle = 0;
        } else {
          _abortLoad(c);
          return;
        }
        _clear(c);
      }
      return;
    }
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
        d.regions[p.region]++;
        d.incoming = max(0, d.incoming - 1);
        if (p.kind == 1) {
          if (gt - p.born <= Cfg.urgentLimit) {
            money += Cfg.urgentBonus;
            dayEarn += Cfg.urgentBonus;
            urgentOk++;
            showToast('급송 성공! +${Cfg.urgentBonus}원');
          } else {
            showToast('급송이 늦었어요');
          }
        } else if (p.kind == 3) {
          money += Cfg.bulkyBonus;
          dayEarn += Cfg.bulkyBonus;
        }
      }
      _clear(c);
    }
  }
}