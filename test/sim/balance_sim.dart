// 밸런스 시뮬레이션: 게임 전체(HubGame.update)를 화면 없이 돌리고, 평범한 플레이어처럼 행동하는 봇을 붙여
// 단계별로 걸리는 시간(일차·실제 시간)과 돈·명성 흐름을 잰다.
// 실행: flutter test test/sim/balance_sim.dart   (일반 테스트 묶음(*_system_test.dart)에는 안 들어감)
// 결과: build/balance_sim.csv (하루 단위) + 콘솔에 이정표 요약
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

const double dt = 0.2; // 게임 초 (10배속 60fps ≈ 0.17)
final bool idleBot = Platform.environment['SIM_IDLE'] == '1'; // 시작 구성만 놓고 아무것도 안 하는 플레이어 (지역 열기·카드 닫기만)
final double botEvery = double.tryParse(Platform.environment['SIM_BOT'] ?? '') ?? 5; // 봇이 판단하는 간격(게임 초): 클수록 느긋한 플레이어
final int years = int.tryParse(Platform.environment['SIM_YEARS'] ?? '') ?? 6;
const bool tapMine = true; // 내 자리 창구 손님을 직접 탭해 접수하는 플레이어 (초반에 많이 함)

BuildingType ty(String id) => Cfg.types.firstWhere((t) => t.id == id);

/// 놓을 자리 찾기: 같은 종류 아래 → 앞 단계 오른쪽 → 구역 안 아무 데나 (통로 한 칸 띄움은 게임 규칙이 검사)
bool place(HubGame g, String id) {
  final t = ty(id);
  if (!g.gradeAllows(id) || g.money < g.costOf(t)) return false;
  if (id == 'conveyor' && !g.conveyorOpen) return false;
  g.placing = t;
  g.mode = 2;
  (int, int)? best;
  var bestD = double.infinity;
  Offset anchor = Offset(g.area.left + 1, g.area.top + 1);
  const prev = {'pack': 'counter', 'shelf': 'pack'};
  if (g.ofType(id).isNotEmpty) {
    final b = g.ofType(id).last;
    anchor = Offset(b.tx.toDouble(), b.ty + b.type.h + 1.0);
  } else if (prev[id] != null && g.ofType(prev[id]!).isNotEmpty) {
    final b = g.ofType(prev[id]!).last;
    anchor = Offset(b.tx + b.type.w + 1.0, b.ty.toDouble());
  }
  if (t.zone == 3) {
    for (var y = g.area.top.toInt(); y <= g.area.bottom - t.h; y++) {
      g.ghostX = Cfg.wallX.toInt();
      g.ghostY = y;
      if (g.ghostProblem == null) {
        final d = (y - anchor.dy).abs().toDouble();
        if (d < bestD) {
          bestD = d;
          best = (g.ghostX, y);
        }
      }
    }
  } else {
    final z = t.zone >= 0 ? g.zoneRect(t.zone) : g.area;
    for (var y = z.top.toInt(); y <= z.bottom - t.h; y++) {
      for (var x = z.left.toInt(); x <= z.right - t.w; x++) {
        g.ghostX = x;
        g.ghostY = y;
        if (g.ghostProblem != null) continue;
        final d = (Offset(x.toDouble(), y.toDouble()) - anchor).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = (x, y);
        }
      }
    }
  }
  if (best == null) {
    g.placing = null;
    g.mode = 0;
    return false;
  }
  g.ghostX = best.$1;
  g.ghostY = best.$2;
  g.confirmPlace();
  g.mode = 0;
  return true;
}

class Log {
  final rows = <String>[];
  final miles = <String>[];
  final seen = <String>{};
  void mile(HubGame g, String k, [String extra = '']) {
    if (!seen.add(k + (k.contains('시상식') ? extra : ''))) return;
    final realMin = g.gt / 60; // 1배속 기준 실제 분
    miles.add('${g.day}일차(${g.year}년차 ${g.dayOfYear}일) · 1배속 ${realMin.toStringAsFixed(0)}분 · $k $extra');
  }
}

void main() {
  test('밸런스 시뮬레이션', () {
    final g = HubGame();
    g.noSave = true;
    g.addStarters();
    g.genCandidates();
    g.planEvents();
    g.debugStarterLayout(); // 안내 ①~④를 따라 놓은 것과 같은 시작 구성
    final log = Log();
    final rnd = Random(7);
    var botT = 0.0;
    int lastDay = 1, dayLost0 = 0, dayDone0 = 0, dayDeliv0 = 0, dayMoney0 = g.money;
    var minMoney = g.money;
    var debtDays = 0;
    var idleMoneyDays = 0; // 돈이 남아도는 날 (할 게 없음)
    final file = StringBuffer('day,year,money,fame,grade,area,regions,staff,buildings,fleet,done,lost,delivered,earned,rating,research,intake,dayEarn,wages,claimed\n');

    void closeCards() {
      if (g.report != null) {
        final r = g.report!;
        file.write('${r.day},${g.year},${g.money},${g.fame},${g.companyGrade},${g.areaLevel},${g.openRegions},${g.staff.length},'
            '${g.buildings.length},${g.fleet.length},${g.done - dayDone0},${g.lost - dayLost0},${g.delivered - dayDeliv0},'
            '${g.money - dayMoney0},${r.grade},${g.researched.length},${g.intakeNow.toStringAsFixed(1)},${r.earned},${r.wages},${g.claimed.length}\n');
        dayDone0 = g.done;
        dayLost0 = g.lost;
        dayDeliv0 = g.delivered;
        dayMoney0 = g.money;
        g.report = null;
      }
      if (g.award != null) {
        final a = g.award!;
        log.mile(g, '${a.year}년 시상식 ${a.rank}위', a.rows.map((r) => '${r.$3 ? '나' : r.$1.substring(0, 2)} ${r.$2}').join(' · '));
      }
      g.award = null;
      if (g.gradeUp != null) {
        log.mile(g, '승급: ${Cfg.corpName[g.gradeUp!]}');
        g.gradeUp = null;
      }
      g.postcard = null;
      if (g.evtNow != null) g.chooseEvent(g.money > 5000 ? 0 : 1);
      if (g.storyAsk != null) {
        final k = g.storyAsk!.story;
        final ch = g.storyChoices(k).firstWhere((c) => c.$4 && c.$1 != 3, orElse: () => (3, '', '', true));
        g.chooseStory(ch.$1);
      }
    }

    int need(String id) => g.ofType(id).length;

    void staffUp() {
      // 빈 자리(1명) 채우기 + 운반 담당 (시설 3개당 1명, 최소 1명)
      for (final b in g.buildings) {
        if (b.type.slots == 0) continue;
        final want = (b.type.id == 'counter' || b.type.id == 'pack') && g.staff.length >= 6 ? min(2, b.type.slots) : 1;
        while (b.crew.length < want) {
          final s = g.staff.where((s) => s.idle).firstOrNull;
          if (s == null) break;
          g.assignTo(s, b);
        }
      }
      final work = g.buildings.where((b) => const {'counter', 'pack', 'shelf', 'dock'}.contains(b.type.id)).length;
      final wantCarry = max(1, (work / 3).ceil());
      var carry = g.staff.where((s) => s.carrier).length;
      for (final s in g.staff.where((s) => s.idle).toList()) {
        if (carry >= wantCarry) break;
        g.setCarrier(s);
        carry++;
      }
      // 일손이 모자라면 고용 (월급 3일치는 남김)
      final wage = g.staff.fold(0, (a, s) => a + s.wage);
      final empty = g.buildings.where((b) => b.type.slots > 0 && b.crew.isEmpty).length + max(0, wantCarry - carry);
      if (empty > 0 && g.candidates.isNotEmpty) {
        final c = (g.candidates.toList()..sort((a, b) => a.hireCost.compareTo(b.hireCost))).first;
        if (g.money - c.hireCost > wage * 3) g.hireCandidate(c);
      }
    }

    void bot() {
      final wage = g.staff.fold(0, (a, s) => a + s.wage);
      final reserve = wage * 3 + 1000;
      // 보상·지역·연구
      for (var i = 0; i < Cfg.missions.length; i++) {
        if (!g.claimed.contains(i) && g.missionDone(i)) g.claimMission(i);
      }
      for (var i = 1; i < 5; i++) {
        if (g.canUnlockRegion(i)) {
          g.unlockRegion(i);
          log.mile(g, '지역 열림: ${Cfg.regionName[i]}', '(명성 ${g.fame})');
        }
      }
      if (g.resNow == null && !idleBot) {
        for (var i = 0; i < Cfg.research.length; i++) {
          if (g.resProblem(i) == null && g.money - Cfg.research[i].cost > reserve) {
            g.startResearch(i);
            log.mile(g, '연구 시작 ${g.researched.length + 1}번째: ${Cfg.research[i].name}');
            break;
          }
        }
      }
      if (idleBot) return;
      // 병목 보고 짓기 (한 번에 하나)
      final queue = g.customers.where((c) => c.state == 0).length;
      final outFull = g.ofType('counter').where((b) => b.outbox.length >= b.outCap - 1).length;
      final shelfFill = g.ofType('shelf').fold(0, (a, b) => a + b.stored) /
          max(1, g.ofType('shelf').fold(0, (a, b) => a + b.cap));
      final spare = g.money - reserve;
      bool tryBuild(String id) {
        if (spare < g.costOf(ty(id))) return false;
        if (place(g, id)) {
          log.mile(g, '${ty(id).name} ${g.ofType(id).length}개째', '');
          staffUp();
          return true;
        }
        // 자리가 없으면 창고 확장
        if (g.canExpand && spare > g.nextAreaCost) {
          g.confirmExpand();
          log.mile(g, '창고 확장: ${Cfg.areaName[g.areaLevel]}');
          return place(g, id);
        }
        return false;
      }

      var built = false;
      if (queue > 3 * need('counter')) built = tryBuild('counter');
      if (!built && outFull > 0 && need('pack') <= need('counter') + 1) built = tryBuild('pack');
      if (!built && shelfFill > 0.7) built = tryBuild('shelf');
      if (!built && need('dock') < need('shelf') && shelfFill > 0.5) built = tryBuild('dock');
      if (!built && need('lounge') == 0 && g.staff.length >= 5) built = tryBuild('lounge');
      if (!built && need('lab') == 0 && g.gradeAllows('lab')) built = tryBuild('lab');
      if (!built && need('classroom') == 0 && g.gradeAllows('classroom') && g.staff.length >= 8) built = tryBuild('classroom');
      if (!built && need('vending') == 0 && g.gradeAllows('vending') && spare > 8000) built = tryBuild('vending');
      // 업그레이드: 돈이 넉넉하면 싼 것부터
      if (!built) {
        final up = g.buildings.where((b) => b.upgradable).toList()..sort((a, b) => a.upgradeCost.compareTo(b.upgradeCost));
        if (up.isNotEmpty && spare > up.first.upgradeCost * 2) {
          g.upgradeBuilding(up.first);
          built = true;
        }
      }
      // 장비: 열린 것 중 그 시설에 맞는 가장 좋은(비싼) 것을 달거나 바꿈
      for (final b in g.buildings) {
        final opts = Cfg.equips.where((e) => e.forType == b.type.id && g.equipOpen(e.id)).toList()
          ..sort((a, c) => c.cost.compareTo(a.cost));
        if (opts.isEmpty) continue;
        final e = opts.first;
        final cur = b.equipDef;
        if (cur != null && cur.cost >= e.cost) {
          if (!b.equipMax && g.money - reserve > b.equipUpCost * 3) g.upgradeEquip(b);
          continue;
        }
        if (g.money - reserve > e.cost * (cur == null ? 2 : 4)) {
          g.buyEquip(b, e);
          log.mile(g, '장비 처음: ${e.name}');
        }
      }
      // 차량: 지역마다 센터에 쌓이면 배달 차, 허브 선반에 그 지역 택배가 많으면 간선
      for (var r = 0; r < 5; r++) {
        if (!g.regionOpen[r]) continue;
        if (g.centerStock[r] > 12 && g.money - reserve > Cfg.unitCost[2] * 2) {
          g.buyUnit(2, r);
        } else if (g.regionStock(r) > 30 && g.money - reserve > Cfg.unitCost[0] * 2 && g.trunkCount(r) < 3) {
          g.buyUnit(0, r);
        }
      }
      // 지도 시설 (돈이 넉넉하면 싼 것부터)
      for (var r = 0; r < 5; r++) {
        if (!g.regionOpen[r]) continue;
        for (var f = 0; f < Cfg.facName.length; f++) {
          if (!g.hasFac(r, f) && g.money - reserve > g.facCost(r, f) * 3) {
            g.buyFac(r, f);
            log.mile(g, '지도 시설 처음');
          }
        }
      }
      // 차량 업그레이드 (돈이 많이 남을 때)
      if (g.money - reserve > 30000) {
        final u = (g.fleet.where((u) => u.level < Cfg.maxLevel).toList()..sort((a, b) => a.level.compareTo(b.level))).firstOrNull;
        if (u != null) g.upgradeUnit(u);
      }
      staffUp();
      // 지친 직원 간식 (알림 버튼)
      for (final a in List.of(g.alerts)) {
        if (a.action == '간식' || a.action.contains('달래')) g.runAlert(a);
      }
    }

    final total = years * Cfg.yearDays;
    var steps = 0;
    while (g.day <= total) {
      closeCards();
      g.update(dt);
      steps++;
      botT += dt;
      // 내 자리 창구: 손님이 오면 바로 탭 (초반 손으로 일하는 느낌)
      if (tapMine && g.day <= 3) {
        for (final c in g.customers) {
          if (c.state == 0 && c.story < 0 && rnd.nextDouble() < 0.02) {
            final w = Offset(c.pos.dx * Cfg.tile, (c.pos.dy - 0.2) * Cfg.tile);
            if (g.tapCustomer(w)) break;
          }
        }
      }
      // 사연 손님: 문 앞에 서면 몇 초 안에 탭 (말풍선을 보고 누르는 플레이어)
      for (final c in g.customers) {
        if (c.story >= 0 && c.state != 2 && c.storyT > 3 && g.storyAsk == null) {
          final w = Offset(c.pos.dx * Cfg.tile, (c.pos.dy - 0.2) * Cfg.tile);
          if (g.tapStoryCustomer(w)) {
            log.mile(g, '첫 사연 손님');
            break;
          }
        }
      }
      if (botT >= botEvery) {
        botT = 0;
        bot();
      }
      minMoney = min(minMoney, g.money);
      if (g.day != lastDay) {
        lastDay = g.day;
        if (g.money < 0) debtDays++;
        if (g.money > 200000) idleMoneyDays++;
        if (g.areaLevel >= 1) log.mile(g, '중형 창고 도달');
        if (g.fame >= 100) log.mile(g, '명성 100');
        if (g.fame >= 400) log.mile(g, '명성 400');
        if (g.fame >= 1200) log.mile(g, '명성 1200');
        if (g.fame >= 2500) log.mile(g, '명성 2500');
        if (g.money >= 100000) log.mile(g, '돈 10만');
        if (g.money >= 1000000) log.mile(g, '돈 100만');
        if (g.researched.length == Cfg.research.length) log.mile(g, '연구 전부 완료');
        if (g.dayOfYear == 1 && g.day > 1) {
          log.mile(g, '${g.year - 1}년차 끝', '돈 ${g.fmt(g.money)} · 명성 ${g.fame} · 직원 ${g.staff.length} · 건물 ${g.buildings.length} · 차량 ${g.fleet.length} · 접수 ${g.done} · 놓침 ${g.lost} · 시상식 최고 ${g.bestRank}위');
        }
        if (g.openRegions == 5) log.mile(g, '모든 지역 열림');
        if (g.claimed.length >= Cfg.missions.length / 2) log.mile(g, '업적 절반');
      }
    }
    Directory('build').createSync(recursive: true);
    File('build/balance_sim.csv').writeAsStringSync(file.toString());
    // ignore: avoid_print
    print('==== 이정표 ====\n${log.miles.join('\n')}');
    // ignore: avoid_print
    print('==== 끝 (${years}년, ${steps} 스텝) ====\n'
        '돈 ${g.money} · 최저 $minMoney · 빚진 날 $debtDays · 20만 넘게 남은 날 $idleMoneyDays\n'
        '명성 ${g.fame} · 등급 ${Cfg.corpName[g.companyGrade]} · 창고 ${Cfg.areaName[g.areaLevel]} · 지역 ${g.openRegions}\n'
        '직원 ${g.staff.length} · 건물 ${g.buildings.length} · 차량 ${g.fleet.length} · 연구 ${g.researched.length}/${Cfg.research.length}\n'
        '누적 접수 ${g.done} · 놓침 ${g.lost} · 배송 ${g.delivered} · 업적 ${g.claimed.length}/${Cfg.missions.length} · 대상 ${g.awardWins} · 최고순위 ${g.bestRank}\n'
        '도감 ${(g.bookPct * 100).round()}% · 사연 완료 ${g.rt.storyDone.length}/${Cfg.storyDefs.length}\n'
        '노선: 정시 ${g.onTimeCount} · 지각 ${g.lateCount} · 의뢰 완료 ${g.rs.reqDone} · 단속 ${g.rs.policeN} · 평판 ${g.rs.rep} · 단골 ${[for (var r = 0; r < 5; r++) g.regularCount(r)]}');
  }, timeout: Timeout.none);
}
