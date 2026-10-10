import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/region_map.dart';
import '../models/models.dart';

/// 노선 의뢰 한 건 (의뢰 게시판)
class RouteRequest {
  final int kind; // 0 지역 정시 N건 · 1 먼 동네 N건 · 2 우대 차량으로 N건 · 3 단골 집 배달 N번
  final int region;
  final int need;
  final int reward, fame;
  final int until; // 이 날(일차)이 끝나기 전까지
  int got = 0;
  RouteRequest(this.kind, this.region, this.need, this.reward, this.fame, this.until);

  String get text => switch (kind) {
        0 => '${Cfg.regionName[region]} 정시 배달 $need건',
        1 => '${Cfg.regionName[region]} 먼 동네에 $need건',
        2 => '${Cfg.regionName[region]}에 ${Cfg.vehicles[Cfg.regionFavor[region]].name}로 $need건',
        _ => '${Cfg.regionName[region]} 단골 집에 $need번 배달',
      };

  Map<String, dynamic> toJson() => {'k': kind, 'r': region, 'n': need, 'rw': reward, 'f': fame, 'u': until, 'g': got};
  static RouteRequest fromJson(Map<String, dynamic> m) =>
      RouteRequest(m['k'] as int, m['r'] as int, m['n'] as int, m['rw'] as int, m['f'] as int, m['u'] as int)..got = (m['g'] as int?) ?? 0;
}

/// 노선 재미 요소 상태 (저장됨)
class RouteState {
  final List<Map<int, int>> hearts = List.generate(5, (_) => {}); // 지역별 집(배달 번호) → 하트
  final List<int> rep = List.filled(5, 0); // 지역별 평판 점수 (정시 배달 수)
  final List<Set<int>> fac = List.generate(5, (_) => {}); // 지역별 지은 시설 (Cfg.facName 번호)
  final List<RouteRequest> reqs = [];
  int reqDone = 0;
  int weather = 0, tomorrow = 0; // 오늘·내일 날씨
  int policeN = 0, breakN = 0; // 기록 (단속·과적 파손)

  Map<String, dynamic> toJson() => {
        'h': [for (final m in hearts) m.map((k, v) => MapEntry('$k', v))],
        'rep': rep,
        'fac': [for (final f in fac) f.toList()],
        'req': [for (final r in reqs) r.toJson()],
        'rd': reqDone,
        'w': weather,
        'tw': tomorrow,
        'pn': policeN,
        'bn': breakN,
      };

  void load(Map<String, dynamic> j) {
    final h = j['h'] as List?;
    for (var i = 0; h != null && i < h.length && i < 5; i++) {
      hearts[i]
        ..clear()
        ..addAll((h[i] as Map).map((k, v) => MapEntry(int.parse(k as String), v as int)));
    }
    final rp = j['rep'] as List?;
    for (var i = 0; rp != null && i < rp.length && i < 5; i++) {
      rep[i] = rp[i] as int;
    }
    final f = j['fac'] as List?;
    for (var i = 0; f != null && i < f.length && i < 5; i++) {
      fac[i]
        ..clear()
        ..addAll((f[i] as List).map((e) => e as int));
    }
    reqs
      ..clear()
      ..addAll([for (final r in (j['req'] as List? ?? const [])) RouteRequest.fromJson(r as Map<String, dynamic>)]);
    reqDone = (j['rd'] as int?) ?? 0;
    weather = (j['w'] as int?) ?? 0;
    tomorrow = (j['tw'] as int?) ?? 0;
    policeN = (j['pn'] as int?) ?? 0;
    breakN = (j['bn'] as int?) ?? 0;
  }
}

/// 노선의 재미: 지역 개성 · 구역 · 적재 한도(과적) · 단골 집 · 의뢰 · 지역 평판 · 지도 시설 · 날씨 · 기사 개성 · 사건 선택
extension RouteSystem on HubGame {
  // ---------------- 구역 ----------------
  /// 배달 번호 k가 속한 구역 (그 지역 배달 길을 거리순으로 셋으로 나눔)
  int zoneOf(int region, int k) {
    final m = RegionMap.of(region);
    final n = m.courier.length;
    if (n < 3) return 0;
    final order = [for (var i = 0; i < n; i++) i]..sort((a, b) => m.deliverSec(a).compareTo(m.deliverSec(b)));
    final pos = order.indexOf(k % n);
    return min(2, pos * 3 ~/ n);
  }

  /// 차량이 이번에 배달 갈 길 고르기 (맡은 구역 안에서, 자동이면 아무 데나)
  int pickHouse(FleetUnit u) {
    final m = RegionMap.of(u.region);
    final n = m.courier.length;
    if (u.zone < 0 || n < 3) return rnd.nextInt(n);
    final ks = [for (var k = 0; k < n; k++) if (zoneOf(u.region, k) == u.zone) k];
    return ks.isEmpty ? rnd.nextInt(n) : ks[rnd.nextInt(ks.length)];
  }

  void setZone(FleetUnit u, int z) {
    u.zone = z;
    ui();
  }

  void setLoad(FleetUnit u, int i) {
    if (u.busy && u.state != 0) {
      showToast('다음 운행부터 적용돼요');
    }
    u.loadIdx = i.clamp(0, Cfg.loadPct.length - 1);
    ui();
  }

  // ---------------- 시설 ----------------
  bool hasFac(int region, int f) => rs.fac[region].contains(f);
  int facCost(int region, int f) => (Cfg.facCost[f] * Cfg.facRegionCost[region] / 100).round() * 100;

  void buyFac(int region, int f) {
    if (hasFac(region, f) || !regionOpen[region]) return;
    final c = facCost(region, f);
    if (money < c) {
      showToast('돈이 부족해요');
      return;
    }
    money -= c;
    rs.fac[region].add(f);
    note('${Cfg.regionName[region]}에 ${Cfg.facName[f]}! ${Cfg.facDesc[f]}', 0xFF8E5BD0);
    showToast('${Cfg.regionName[region]} ${Cfg.facName[f]} 완료 · ${Cfg.facDesc[f]}');
    ui();
  }

  // ---------------- 평판 ----------------
  int repLv(int region) {
    var lv = 0;
    for (var i = 0; i < Cfg.repNeed.length; i++) {
      if (rs.rep[region] >= Cfg.repNeed[i]) lv = i;
    }
    return lv;
  }

  // ---------------- 단골 ----------------
  int heartsOf(int region, int k) => rs.hearts[region][k] ?? 0;
  int regularLv(int region, int k) {
    final h = heartsOf(region, k);
    var lv = 0;
    for (var i = 0; i < Cfg.heartNeed.length; i++) {
      if (h >= Cfg.heartNeed[i]) lv = i + 1;
    }
    return lv;
  }

  int regularCount(int region) => rs.hearts[region].keys.where((k) => regularLv(region, k) > 0).length;

  // ---------------- 날씨 ----------------
  int _rollWeather(int dayNo) {
    final winter = ((dayNo - 1) % Cfg.yearDays) ~/ 7 == 3;
    final r = rnd.nextDouble();
    var acc = 0.0;
    for (var i = 0; i < Cfg.weatherChance.length; i++) {
      acc += Cfg.weatherChance[i] + (i == 2 && winter ? Cfg.weatherChance[1] : 0) - (i == 1 && winter ? Cfg.weatherChance[1] : 0);
      if (r < acc) return i;
    }
    return 0;
  }

  /// 하루가 바뀔 때: 날씨 넘기고 내일 예보, 기한 지난 의뢰 정리, 새 의뢰, 차량 무리 회복
  void routeNewDay() {
    rs.weather = rs.tomorrow;
    rs.tomorrow = _rollWeather(day + 1);
    if (rs.weather != 0) {
      note('오늘 날씨: ${Cfg.weatherName[rs.weather]} · 오토바이 속도 ×${Cfg.weatherMoto[rs.weather]}', 0xFF56CCF2);
    }
    final gone = rs.reqs.where((r) => r.until < day).length;
    rs.reqs.removeWhere((r) => r.until < day);
    if (gone > 0) note('기한이 지난 의뢰 $gone건이 사라졌어요', 0xFFE5484D);
    fillRequests();
    for (final u in fleet) {
      u.wear = max(0, u.wear - 2);
    }
  }

  /// 의뢰 채우기 (열린 지역에서, 최대 Cfg.reqMax)
  void fillRequests() {
    final open = [for (var i = 0; i < 5; i++) if (regionOpen[i]) i];
    if (open.isEmpty) return;
    var guard = 0;
    while (rs.reqs.length < Cfg.reqMax && guard++ < 20) {
      final r = open[rnd.nextInt(open.length)];
      var kind = rnd.nextInt(4);
      if (kind == 3 && regularCount(r) == 0) kind = 0;
      if (rs.reqs.any((q) => q.kind == kind && q.region == r)) continue;
      final lv = repLv(r);
      final need = switch (kind) {
        0 => 15 + 5 * lv + rnd.nextInt(10),
        1 => 6 + 2 * lv + rnd.nextInt(5),
        2 => 8 + 2 * lv + rnd.nextInt(6),
        _ => 3 + lv,
      };
      final k = (1 + 0.3 * lv) * (hasFac(r, 3) ? 1.3 : 1.0) * Cfg.regionPayMul[r];
      final reward = ((need * 120 * k) / 100).round() * 100;
      rs.reqs.add(RouteRequest(kind, r, need, reward, 5 + 2 * lv, day + Cfg.reqDays - 1));
    }
  }

  void _reqProgress(int region, int kind, int n) {
    for (final q in List.of(rs.reqs)) {
      if (q.region != region || q.kind != kind) continue;
      q.got += n;
      if (q.got >= q.need) {
        rs.reqs.remove(q);
        rs.reqDone++;
        money += q.reward;
        dayEarn += q.reward;
        fame += q.fame;
        note('의뢰 완료! ${q.text} +${fmt(q.reward)}원 · 명성 +${q.fame}', 0xFFFFD166);
        showToast('의뢰 완료! ${q.text} (+${fmt(q.reward)}원)');
      }
    }
  }

  // ---------------- 차량 운행에 쓰는 배수 ----------------
  /// 날씨·기사 개성·과적을 반영한 차량 속도
  double unitSpeed(FleetUnit u) {
    final w = u.trait == 1 ? 0 : rs.weather;
    final wk = Cfg.regionWeather[u.region];
    final base = u.type == 2 ? Cfg.weatherMoto[w] : Cfg.weatherTruck[w];
    final weather = 1 - (1 - base) * wk;
    return u.speed * weather;
  }

  /// 노선 시간 배수 (지름길)
  double tripMul(int region) => hasFac(region, 0) ? 0.85 : 1.0;

  /// 이번 운행에 사건이 생길 확률
  double evtChanceOf(FleetUnit u) {
    final w = u.trait == 1 ? 0 : rs.weather;
    var p = Cfg.evtChance(u.isTrunk, u.region) + Cfg.weatherEvt[w] * Cfg.regionWeather[u.region];
    p += Cfg.loadEvt[u.loadIdx] * (u.trait == 4 ? 0.5 : 1.0);
    p += u.wear * 0.01;
    if (hasFac(u.region, 1)) p *= 0.7;
    return p.clamp(0.02, 0.85).toDouble();
  }

  /// 배송 기한 (지역 개성·냉장고)
  double deadlineOf(int region) => Cfg.deadline(region) * Cfg.regionDeadlineMul[region] * (hasFac(region, 2) ? 1.3 : 1.0);

  /// 출발할 때 과적 단속 (벌금) 확인
  void checkPolice(FleetUnit u) {
    if (!u.overloaded || u.cargo <= 0) return;
    u.wear += u.loadIdx == 3 ? 3 : 1;
    final p = Cfg.loadPolice[u.loadIdx] * Cfg.regionPolice[u.region] * (u.trait == 4 ? 0.5 : 1.0);
    if (rnd.nextDouble() >= p) return;
    final fine = Cfg.policeFinePer * u.cargo;
    money = max(0, money - fine);
    rs.policeN++;
    u.evtKind = 4;
    u.evtOk = false;
    u.evtT = Cfg.evtShow;
    u.evtText = '과적 단속! 벌금 -${fmt(fine)}원';
    note('${u.driver} 과적 단속에 걸림 · 벌금 -${fmt(fine)}원', 0xFFE5484D);
  }

  /// 배달 도착 정산 보조: (택배 1건 수익 배수, 팁 합계, 파손 수). 단골·평판·의뢰도 여기서 반영
  (double, int, int) deliveryExtras(FleetUnit u, int n, int ok) {
    final r = u.region;
    var mul = Cfg.regionPayMul[r] * Cfg.zonePay[zoneOf(r, u.house)] * (1 + Cfg.repPay * repLv(r));
    if (u.type == Cfg.regionFavor[r]) mul *= Cfg.favorPay;
    if (u.trait == 5 && Cfg.regionDeadlineMul[r] < 1) mul *= 1.15;
    // 과적 파손
    var broke = 0;
    final bp = Cfg.loadBreak[u.loadIdx] * (u.trait == 4 ? 0.5 : 1.0);
    for (var i = 0; i < n; i++) {
      if (rnd.nextDouble() < bp) broke++;
    }
    if (broke > 0) {
      rs.breakN += broke;
      fame = max(0, fame - broke);
      note('${u.driver} 과적으로 택배 $broke건 파손 · 명성 -$broke', 0xFFE5484D);
    }
    // 단골: 하트 + 팁
    final before = regularLv(r, u.house);
    final gain = (u.trait == 3 ? 2 : 1) * (hasFac(r, 3) ? 1.5 : 1.0);
    rs.hearts[r][u.house] = heartsOf(r, u.house) + max(1, gain.round());
    final after = regularLv(r, u.house);
    if (after > before) {
      note('${Cfg.regionName[r]} ${u.house + 1}번 집이 ${Cfg.regularName[after]}이 됐어요!', 0xFFFF7EB6);
      showToast('${Cfg.regionName[r]} ${u.house + 1}번 집이 ${Cfg.regularName[after]}! 팁 +${Cfg.heartTip[after]}원/건');
    }
    final tip = Cfg.heartTip[after] * (n - broke);
    // 평판·의뢰
    final lv0 = repLv(r);
    rs.rep[r] += ok;
    if (repLv(r) > lv0) {
      note('${Cfg.regionName[r]} 평판 상승: ${Cfg.repName[repLv(r)]} (수익 +${(Cfg.repPay * repLv(r) * 100).round()}%)', 0xFF3FB27F);
      showToast('${Cfg.regionName[r]} 평판 ${Cfg.repName[repLv(r)]}!');
    }
    _reqProgress(r, 0, ok);
    if (zoneOf(r, u.house) == 2) _reqProgress(r, 1, n - broke);
    if (u.type == Cfg.regionFavor[r]) _reqProgress(r, 2, n - broke);
    if (after > 0) _reqProgress(r, 3, 1);
    return (mul, tip, broke);
  }

  // ---------------- 사건 선택 ----------------
  /// 플레이어가 지금 이 차량의 지역 지도를 보고 있는지 (보고 있으면 사건 때 고를 수 있음)
  bool watching(FleetUnit u) => screen == 1 && mapSel == u.region;

  /// 지금 골라야 하는 사건이 있는 차량
  FleetUnit? get pendingEvt {
    for (final u in fleet) {
      if (u.evtWaitT > 0) return u;
    }
    return null;
  }

  void chooseRouteEvt(FleetUnit u, int c) {
    if (u.evtWaitT <= 0) return;
    u.evtChoice = c;
    u.evtWaitT = 0;
    ui();
  }

  /// 기사 개성 하나 뽑기 (새 차량)
  int rollTrait() => rnd.nextDouble() < 0.6 ? 1 + rnd.nextInt(Cfg.traitName.length - 1) : 0;
}
