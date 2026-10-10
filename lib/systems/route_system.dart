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
  int step = 1; // 연속 의뢰 단계 (1~3)
  int rival = 0; // 대결 의뢰: 상대 경쟁사 번호
  RouteRequest(this.kind, this.region, this.need, this.reward, this.fame, this.until);

  String get text => switch (kind) {
        0 => '${Cfg.regionName[region]} 정시 배달 $need건',
        1 => '${Cfg.regionName[region]} 먼 동네에 $need건',
        2 => '${Cfg.regionName[region]}에 ${Cfg.vehicles[Cfg.regionFavor[region]].name}로 $need건',
        3 => '${Cfg.regionName[region]} 단골 집에 $need번 배달',
        4 => '${Cfg.regionName[region]} 연속 의뢰 $step/3 · 정시 $need건',
        5 => '${Cfg.regionName[region]} 궂은 날씨에 $need건 (비·눈·안개 날만)',
        _ => '${Cfg.rivalName[rival]}와 대결! ${Cfg.regionName[region]} $need건',
      };

  /// 특별 의뢰 (연속·날씨·대결)는 게시판에서 색을 다르게
  bool get special => kind >= 4;

  Map<String, dynamic> toJson() => {'k': kind, 'r': region, 'n': need, 'rw': reward, 'f': fame, 'u': until, 'g': got, 's': step, 'rv': rival};
  static RouteRequest fromJson(Map<String, dynamic> m) =>
      RouteRequest(m['k'] as int, m['r'] as int, m['n'] as int, m['rw'] as int, m['f'] as int, m['u'] as int)
        ..got = (m['g'] as int?) ?? 0
        ..step = (m['s'] as int?) ?? 1
        ..rival = (m['rv'] as int?) ?? 0;
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
  final List<int> today = List.filled(5, 0), yday = List.filled(5, 0); // 지역별 오늘·어제 배달 수 (의뢰 크기)
  final Set<String> vipGiven = {}; // VIP 선물을 받은 집 ('지역:번호')
  List<String> summary = []; // 어제 노선 결산 (정산 카드)

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
        'yd': yday,
        'vip': vipGiven.toList(),
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
    vipGiven
      ..clear()
      ..addAll(((j['vip'] as List?) ?? const []).map((e) => e as String));
    final yd = j['yd'] as List?;
    for (var i = 0; yd != null && i < yd.length && i < 5; i++) {
      yday[i] = yd[i] as int;
    }
  }
}

final Map<int, List<int>> _rank = {};

/// 노선의 재미: 지역 개성 · 구역 · 적재 한도(과적) · 단골 집 · 의뢰 · 지역 평판 · 지도 시설 · 날씨 · 기사 개성 · 사건 선택
extension RouteSystem on HubGame {
  // ---------------- 구역 ----------------
  /// 배달 번호 k가 속한 구역 (그 지역 배달 길을 거리순으로 셋으로 나눔)
  int zoneOf(int region, int k) {
    final n = RegionMap.of(region).courier.length;
    if (n < 3) return 0;
    return min(2, distRank(region, k) * 3 ~/ n);
  }

  /// 센터에서 가까운 순위 (0이 가장 가까움). 지역마다 한 번 계산
  int distRank(int region, int k) {
    final rk = _rank.putIfAbsent(region, () {
      final m = RegionMap.of(region);
      final order = [for (var i = 0; i < m.courier.length; i++) i]..sort((a, b) => m.deliverSec(a).compareTo(m.deliverSec(b)));
      final out = List.filled(order.length, 0);
      for (var i = 0; i < order.length; i++) {
        out[order[i]] = i;
      }
      return out;
    });
    return rk.isEmpty ? 0 : rk[k % rk.length];
  }

  /// 차량이 이번에 배달 갈 길 고르기 (맡은 구역 안에서, 자동이면 아무 데나)
  int pickHouse(FleetUnit u) {
    final m = RegionMap.of(u.region);
    final n = m.courier.length;
    // 아직 안 생긴 집(빈 집터)은 빼고
    final openKs = [for (var k = 0; k < n; k++) if (houseOpen(u.region, k)) k];
    if (openKs.isEmpty) return rnd.nextInt(n);
    final hs = u.homes.where((k) => k < n && houseOpen(u.region, k)).toList();
    if (hs.isNotEmpty) return hs[rnd.nextInt(hs.length)]; // 직접 지정한 집
    if (u.zone < 0 || n < 3) return openKs[rnd.nextInt(openKs.length)];
    final ks = openKs.where((k) => zoneOf(u.region, k) == u.zone).toList();
    return ks.isEmpty ? openKs[rnd.nextInt(openKs.length)] : ks[rnd.nextInt(ks.length)];
  }

  /// 이 구역에 지금 배달할 수 있는 집이 있는지 (먼 동네는 평판이 올라야 생김)
  bool zoneOpen(int region, int z) {
    final n = RegionMap.of(region).courier.length;
    for (var k = 0; k < n; k++) {
      if (zoneOf(region, k) == z && houseOpen(region, k)) return true;
    }
    return false;
  }

  /// 지도에서 집을 눌러 이 차량의 배달 집으로 지정·해제
  void toggleHome(FleetUnit u, int k) {
    if (u.isTrunk) return;
    if (!u.homes.contains(k) && !houseOpen(u.region, k)) {
      showToast('아직 빈 집터예요. 평판이 오르면 집이 생겨요');
      return;
    }
    if (!u.homes.remove(k)) {
      if (u.homes.length >= Cfg.homesMax) {
        showToast('한 차량에 집은 ${Cfg.homesMax}채까지 지정할 수 있어요');
        return;
      }
      u.homes.add(k);
      showToast('${u.driver} 기사 배달 집: ${houseName(u.region, k)} 추가 (${u.homes.length}채)');
    } else {
      showToast('${k + 1}번 집 지정 해제 (${u.homes.length}채)');
    }
    ui();
  }

  void clearHomes(FleetUnit u) {
    u.homes.clear();
    ui();
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

  // ---------------- 동네 성장 ----------------
  /// 지금 배달할 수 있는 집 수 (평판이 오를수록 늘어남)
  int activeHouses(int region) {
    final n = RegionMap.of(region).courier.length;
    return min(n, max(3, (n * Cfg.townOpen[repLv(region)]).ceil()));
  }

  /// 동네는 센터 가까운 집부터 생겨 밖으로 넓어짐
  /// 한 번이라도 배달한 집(하트가 있는 집)은 계속 열려 있음
  bool houseOpen(int region, int k) => distRank(region, k) < activeHouses(region) || heartsOf(region, k) > 0;

  /// 집 이름 (지역·번호로 고정)
  String houseName(int region, int k) => Cfg.houseNames[(region * 7 + k * 3) % Cfg.houseNames.length];

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

  /// 어제 노선 결산 글 만들기 (정산 카드에 표시) 후 기록을 비움
  void _makeSummary() {
    final out = <String>[];
    for (var r = 0; r < 5; r++) {
      final us = fleet.where((u) => u.region == r && !u.isTrunk).toList();
      final n = us.fold(0, (a, u) => a + u.dN);
      if (n == 0) continue;
      final pay = us.fold(0, (a, u) => a + u.dPay);
      final late = us.fold(0, (a, u) => a + u.dLate);
      final fine = fleet.where((u) => u.region == r).fold(0, (a, u) => a + u.dFine);
      final broke = us.fold(0, (a, u) => a + u.dBroke);
      final gain = us.fold(0, (a, u) => a + u.dOverGain);
      us.sort((a, b) => b.dPay.compareTo(a.dPay));
      final best = us.first;
      var line = '${Cfg.regionName[r]} $n건 +${fmt(pay)}원';
      if (late > 0) line += ' · 지각 $late';
      if (gain > 0 || fine > 0 || broke > 0) {
        final net = gain - fine;
        line += ' · 과적 손익 ${net >= 0 ? '+' : ''}${fmt(net)}원${broke > 0 ? '(파손 $broke)' : ''}';
      }
      line += ' · 최고 ${best.driver} ${fmt(best.dPay)}원';
      out.add(line);
    }
    rs.summary = out;
    for (final u in fleet) {
      u.dPay = 0;
      u.dN = 0;
      u.dLate = 0;
      u.dFine = 0;
      u.dBroke = 0;
      u.dOverGain = 0;
    }
  }

  /// 하루가 바뀔 때: 날씨 넘기고 내일 예보, 기한 지난 의뢰 정리, 새 의뢰, 차량 무리 회복
  void routeNewDay() {
    final open0 = [for (var r = 0; r < 5; r++) activeHouses(r)];
    _makeSummary();
    for (var i = 0; i < 5; i++) {
      rs.yday[i] = rs.today[i];
      rs.today[i] = 0;
    }
    rs.weather = rs.tomorrow;
    rs.tomorrow = _rollWeather(day + 1);
    if (rs.weather != 0) {
      note('오늘 날씨: ${Cfg.weatherName[rs.weather]} · 오토바이 속도 ×${Cfg.weatherMoto[rs.weather]}', 0xFF56CCF2);
    }
    final gone = rs.reqs.where((r) => r.until < day).length;
    for (final q in rs.reqs.where((r) => r.until < day && r.kind == 6)) {
      fame = max(0, fame - 5);
      note('${Cfg.rivalName[q.rival]}와의 대결에서 졌어요… 명성 -5', 0xFFE5484D);
    }
    rs.reqs.removeWhere((r) => r.until < day);
    // 평판이 올라 새 집이 생겼으면 알림
    for (var r = 0; r < 5; r++) {
      if (regionOpen[r] && activeHouses(r) > open0[r]) {
        note('${Cfg.regionName[r]}에 새 집 ${activeHouses(r) - open0[r]}채가 생겼어요!', 0xFF3FB27F);
      }
    }
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
      var kind = rnd.nextInt(7);
      if (kind == 3 && regularCount(r) == 0) kind = 0;
      if (kind == 5 && rs.weather == 0 && rs.tomorrow == 0) kind = 1; // 궂은 날이 올 때만
      if (kind == 6 && repLv(r) < 1) kind = 2; // 대결은 알려진 뒤부터
      if (kind == 4 && rs.reqs.any((q) => q.kind == 4)) kind = 0; // 연속 의뢰는 하나씩
      if (rs.reqs.any((q) => q.kind == kind && q.region == r)) continue;
      final lv = repLv(r);
      // 의뢰 크기: 그 지역 어제 배달 수 기준 (기한 2일). 막 연 지역도 해낼 만하게
      final base = max(6, rs.yday[r]);
      final need = switch (kind) {
        0 => (base * (1.1 + 0.1 * lv) + rnd.nextInt(5)).round().clamp(6, 80),
        1 => (base * 0.4 + rnd.nextInt(3)).round().clamp(3, 30),
        2 => (base * 0.5 + rnd.nextInt(3)).round().clamp(3, 40),
        3 => 2 + lv,
        4 => (base * 0.8).round().clamp(5, 50),
        5 => (base * 0.6).round().clamp(4, 40),
        _ => (base * 1.6).round().clamp(10, 100),
      };
      final k = (1 + 0.15 * lv) * (hasFac(r, 3) ? 1.3 : 1.0) * Cfg.regionPayMul[r];
      final reward = ((need * 70 * k) / 100).round() * 100;
      final mulK = switch (kind) { 4 => 1.2, 5 => 1.5, 6 => 2.0, _ => 1.0 };
      final q = RouteRequest(kind, r, need, (reward * mulK / 100).round() * 100, ((3 + lv) * mulK).round(), day + Cfg.reqDays - 1);
      if (kind == 6) q.rival = rnd.nextInt(Cfg.rivalName.length);
      rs.reqs.add(q);
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
        if (q.kind == 4 && q.step < 3) {
          // 연속 의뢰: 다음 단계가 바로 이어짐 (더 크고 보상도 큼)
          final nx = RouteRequest(4, q.region, (q.need * 1.4).round(), (q.reward * 1.6 / 100).round() * 100, q.fame + 4, day + Cfg.reqDays - 1)
            ..step = q.step + 1;
          rs.reqs.add(nx);
          note('연속 의뢰 ${nx.step}/3 단계가 이어졌어요!', 0xFFFFD166);
        } else if (q.kind == 4) {
          fame += 20;
          note('연속 의뢰 3단계 모두 완료! 명성 +20', 0xFFFFD166);
        }
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
    if (u.cargo <= 0) return;
    if (!u.overloaded) {
      u.wear = max(0, u.wear - 1); // 무리 안 한 운행은 조금씩 회복
      return;
    }
    u.wear = min(Cfg.wearMax, u.wear + (u.loadIdx == 3 ? 3 : 1));
    final p = Cfg.loadPolice[u.loadIdx] * Cfg.regionPolice[u.region] * (u.trait == 4 ? 0.5 : 1.0);
    if (rnd.nextDouble() >= p) return;
    final fine = Cfg.policeFinePer * u.cargo;
    money = max(0, money - fine);
    u.dFine += fine;
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
      final nm = houseName(r, u.house);
      note('$nm이(가) ${Cfg.regularName[after]}이 됐어요!', 0xFFFF7EB6);
      showToast('$nm ${Cfg.regularName[after]}! 팁 +${Cfg.heartTip[after]}원/건');
      if (after == 3 && rs.vipGiven.add('$r:${u.house}')) {
        final gift = Cfg.vipGift[r];
        money += gift;
        dayEarn += gift;
        fame += Cfg.vipGiftFame;
        note('$nm이(가) 감사 선물을 보냈어요! +${fmt(gift)}원 · 명성 +${Cfg.vipGiftFame}', 0xFFFF4F8B);
        showToast('$nm의 감사 편지: "늘 고마워요!" +${fmt(gift)}원');
      }
    }
    final tip = Cfg.heartTip[after] * (n - broke);
    // 평판·의뢰
    final lv0 = repLv(r);
    rs.rep[r] += ok;
    rs.today[r] += n;
    if (repLv(r) > lv0) {
      note('${Cfg.regionName[r]} 평판 상승: ${Cfg.repName[repLv(r)]} (수익 +${(Cfg.repPay * repLv(r) * 100).round()}%)', 0xFF3FB27F);
      showToast('${Cfg.regionName[r]} 평판 ${Cfg.repName[repLv(r)]}!');
    }
    _reqProgress(r, 0, ok);
    if (zoneOf(r, u.house) == 2) _reqProgress(r, 1, n - broke);
    if (u.type == Cfg.regionFavor[r]) _reqProgress(r, 2, n - broke);
    if (after > 0) _reqProgress(r, 3, 1);
    _reqProgress(r, 4, ok);
    if (rs.weather != 0) _reqProgress(r, 5, ok);
    _reqProgress(r, 6, n - broke);
    // 오늘 기록 (결산)
    u.dN += n;
    u.dLate += n - ok;
    u.dBroke += broke;
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
