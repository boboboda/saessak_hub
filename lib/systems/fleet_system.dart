import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/region_map.dart';
import '../models/models.dart';

/// 내 차량(플릿)의 운행: 허브 → 지역센터(대형 트럭) → 동네 배달(소형 트럭·오토바이)
extension FleetSystem on HubGame {
  // ---- 조회 ----
  /// 지역 r 노선에 배정된, 놀고 있는 대형 트럭
  FleetUnit? freeTrunk(int r) {
    for (final u in fleet) {
      if (u.isTrunk && u.region == r && u.state == 0) return u;
    }
    return null;
  }

  Iterable<FleetUnit> unitsOf(int region) => fleet.where((u) => u.region == region);

  int trunkCount(int region) => unitsOf(region).where((u) => u.isTrunk).length;
  int courierCount(int region) => unitsOf(region).where((u) => !u.isTrunk).length;

  // ---- 새 차량 ----
  FleetUnit makeUnit(int type, int region) {
    final name = Cfg.driverFirst[rnd.nextInt(Cfg.driverFirst.length)] +
        Cfg.driverLast[rnd.nextInt(Cfg.driverLast.length)];
    final u = FleetUnit(nextUnitId++, type, name, 1 + rnd.nextInt(3), region);
    fleet.add(u);
    return u;
  }

  /// 처음 시작·지역 개설 때 주는 기본 차량 (대형 트럭 1 + 오토바이 1)
  void grantStarterUnits(int region) {
    makeUnit(0, region);
    makeUnit(2, region);
  }

  bool buyUnit(int type, int region) {
    final cost = Cfg.unitCost[type];
    if (money < cost) {
      showToast('돈이 부족해요');
      return false;
    }
    money -= cost;
    final u = makeUnit(type, region);
    showToast('${u.name} 구입! 기사 ${u.driver}(${Cfg.skillName[u.skill]})');
    ui();
    return true;
  }

  void upgradeUnit(FleetUnit u) {
    if (u.level >= Cfg.maxLevel) return;
    final cost = Cfg.upgradeCost(u.type, u.level);
    if (money < cost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= cost;
    u.level++;
    showToast('${u.name} Lv.${u.level} (속도·적재량 증가)');
    ui();
  }

  void trainDriver(FleetUnit u) {
    if (u.skill >= 5) return;
    final cost = Cfg.trainCost(u.skill);
    if (money < cost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= cost;
    u.skill++;
    showToast('${u.driver} 기사 ${Cfg.skillName[u.skill]}로 성장!');
    ui();
  }

  /// 배정 지역을 다음 열린 지역으로 돌림 (달리는 중이면 못 바꿈)
  void cycleRegion(FleetUnit u) {
    if (u.busy) {
      showToast('운행이 끝나면 바꿀 수 있어요');
      return;
    }
    final left = u.isTrunk ? trunkCount(u.region) : courierCount(u.region);
    if (left <= 1) {
      showToast('이 노선의 마지막 ${u.name}라 옮길 수 없어요');
      return;
    }
    for (var k = 1; k <= regionOpen.length; k++) {
      final r = (u.region + k) % regionOpen.length;
      if (regionOpen[r]) {
        u.region = r;
        break;
      }
    }
    ui();
  }

  // ---- 운행 ----
  void note(String text, int color) {
    notes.insert(0, MapNote(text, color));
    if (notes.length > 5) notes.removeLast();
  }

  void _planEvent(FleetUnit u) {
    u.evtDone = false;
    u.delay = 0;
    u.willEvt = rnd.nextDouble() < Cfg.evtChance(u.isTrunk, u.region);
    u.evtAt = 0.25 + rnd.nextDouble() * 0.5;
  }

  void startTrunkTrip(FleetUnit u) {
    u.state = 1;
    u.t = 0;
    u.dur = RegionMap.of(u.region).tripSec;
    _planEvent(u);
  }

  void _startCourier(FleetUnit u, int n) {
    u.cargo = n;
    final cb = centerBorn[u.region];
    final k = min(n, cb.length);
    u.load
      ..clear()
      ..addAll(cb.take(k));
    cb.removeRange(0, k);
    u.full = n >= u.cap;
    u.state = 1;
    u.t = 0;
    final m = RegionMap.of(u.region);
    u.house = rnd.nextInt(m.courier.length);
    u.dur = m.deliverSec(u.house);
    _planEvent(u);
  }

  /// 이벤트 발생: 기사 능력으로 성공/실패가 갈림
  void _runEvent(FleetUnit u) {
    u.evtDone = true;
    final k = rnd.nextInt(Cfg.evtName.length);
    final ok = rnd.nextDouble() < Cfg.evtSuccess(u.skill);
    u.evtKind = k;
    u.evtOk = ok;
    u.evtT = Cfg.evtShow;
    final who = '${u.driver}(${Cfg.skillName[u.skill]})';
    if (ok) {
      fame += 1;
      u.evtText = '${Cfg.evtName[k]}! 대응 성공';
      note('$who ${Cfg.evtName[k]} 대응 성공 +명성1', 0xFF3FB27F);
    } else {
      u.delay += Cfg.evtDelay[k];
      var extra = '';
      if (k == 2) {
        final fee = 150 * (u.region + 1);
        money = max(0, money - fee);
        extra = ' 수리비 -$fee원';
      } else if (k == 3 && u.cargo > 1) {
        final lost = max(1, (u.cargo * 0.15).round());
        u.cargo -= lost;
        if (u.load.length > u.cargo) u.load.removeRange(u.cargo, u.load.length);
        extra = ' 택배 $lost건 분실';
      }
      u.evtText = '${Cfg.evtName[k]}… 대응 실패';
      note('$who ${Cfg.evtName[k]} 대응 실패 +${Cfg.evtDelay[k].round()}초 지연$extra', 0xFFE5484D);
    }
  }

  /// (디버그) 달리는 차량 하나에 사건을 일으킴: 정체·폭우·펑크·분실 실패 → 성공 차례로. 일으켰으면 true
  bool debugRouteEvent(int n) {
    var list = fleet.where((u) => u.state == 1 || u.state == 2).toList();
    if (list.isEmpty) list = fleet.toList(); // 달리는 차가 없으면 서 있는 차에
    if (list.isEmpty) return false;
    final u = list[n % list.length];
    final k = n % 5;
    u.evtDone = true;
    u.evtKind = k % 4;
    u.evtOk = k == 4;
    u.evtT = Cfg.evtShow;
    u.evtText = '${Cfg.evtName[u.evtKind]}${u.evtOk ? '! 대응 성공' : '… 대응 실패'}';
    mapSel = u.region;
    mapFollow = u.id; // 노선 지도를 열면 이 차량을 따라감
    return true;
  }

  void updateFleet(double d) {
    for (final n in notes) {
      n.t -= d;
    }
    notes.removeWhere((n) => n.t <= 0);
    for (final f in mapFx) {
      f.t += d;
    }
    mapFx.removeWhere((f) => f.t >= 2.2);

    for (final u in fleet) {
      if (u.evtT > 0) u.evtT -= d;
      switch (u.state) {
        case 3:
          // 도크에서 싣다가 도크가 사라졌으면 대기로
          final onDock = ofType('dock').any((b) => b.vehicle?.unit == u);
          if (!onDock) u.state = 0;
          break;
        case 1:
          u.t += d * u.speed;
          if (u.willEvt && !u.evtDone && u.t >= u.dur * u.evtAt) _runEvent(u);
          if (u.t >= u.dur + u.delay) _arrive(u);
          break;
        case 2:
          u.t += d * u.speed;
          if (u.t >= u.dur) {
            u.state = 0;
            u.t = 0;
          }
          break;
        default:
          if (!u.isTrunk && regionOpen[u.region] && routes[u.region].on) {
            final stock = centerStock[u.region];
            if (stock > 0) {
              final n = min(stock, u.cap);
              centerStock[u.region] -= n;
              _startCourier(u, n);
            }
          }
      }
    }
  }

  void _arrive(FleetUnit u) {
    if (u.isTrunk) {
      centerStock[u.region] += u.cargo;
      centerBorn[u.region].addAll(u.load);
      u.load.clear();
      note('${Cfg.regionName[u.region]} 센터에 ${u.cargo}건 도착', 0xFF56CCF2);
      mapFx.add(MapFx(u.region, true, 0, '+${u.cargo}건', 0xFF56CCF2));
      u.cargo = 0;
      u.state = 2;
      u.t = 0;
      u.dur = RegionMap.of(u.region).tripSec * 0.8;
    } else {
      final n = u.cargo;
      final unit = Cfg.parcelPay *
          Cfg.vehicles[u.type].payMul *
          Cfg.regionPay[u.region] *
          (fever > 0 ? Cfg.feverPay : 1.0) *
          (u.full ? Cfg.fullBonus : 1.0);
      // 택배마다 기한 확인: 정시면 정상 + 연속 보너스, 늦으면 수익 감소·명성 하락
      final limit = Cfg.deadline(u.region);
      var payD = 0.0, ok = 0, late = 0, fameD = 0;
      for (var i = 0; i < n; i++) {
        final born = i < u.load.length ? u.load[i] : gt; // 불러온 저장 등 시각을 모르면 정시로
        if (gt - born <= limit) {
          ok++;
          streak++;
          if (streak > bestStreak) bestStreak = streak;
          payD += unit * (1 + Cfg.streakStep * min(streak, Cfg.streakCap));
          fameD += Cfg.onTimeFame;
          if (streak % Cfg.streakEvery == 0) {
            fameD += Cfg.streakFame;
            note('연속 정시 배송 $streak건! 명성 +${Cfg.streakFame}', 0xFF3FB27F);
          }
        } else {
          late++;
          streak = 0;
          payD += unit * Cfg.latePay;
          fameD -= Cfg.lateFame;
        }
      }
      u.load.clear();
      final pay = (payD * this.perkMul).round(); // 업적 영구 수익 보너스
      money += pay;
      dayEarn += pay;
            delivered += n;
      rp += n * Cfg.rpPerParcel; // 연구 포인트
      onTimeCount += ok;
      lateCount += late;
      fame = max(0, fame + fameD);
      note(
          late == 0
              ? '${u.driver} 정시 배달 ${n}건 +${fmt(pay)}원'
              : '${u.driver} 배달 ${n}건 (지각 $late) +${fmt(pay)}원',
          late == 0 ? 0xFFFFD166 : 0xFFE5484D);
      mapFx.add(MapFx(u.region, false, u.house, '+${fmt(pay)}', 0xFFFFD166));
      u.cargo = 0;
      u.state = 2;
      u.t = 0;
      u.dur = RegionMap.of(u.region).deliverSec(u.house) * 0.7;
    }
  }
}
