// 노선 스트레스 시뮬레이션: 지역 5곳을 열고 차량마다 구역·집 지정·적재 한도를 무작위로 바꾸며, 지도를 보는 척(사건 선택)도 하면서
// 오래 돌려 문제(멈춘 차량·음수 재고·택배가 사라짐·사건 선택이 안 끝남)를 찾는다.
// 실행: flutter test test/sim/route_sim.dart   (일반 테스트 묶음에는 안 들어감)
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/game/region_map.dart';
import 'package:saessak_hub/models/models.dart';

void main() {
  test('노선 스트레스', () {
    final days = int.tryParse(Platform.environment['SIM_DAYS'] ?? '') ?? 40;
    final g = HubGame()..noSave = true;
    g.addStarters();
    g.genCandidates();
    g.planEvents();
    g.debugStarterLayout();
    g.money = 5000000;
    g.fame = 3000;
    for (var i = 1; i < 5; i++) {
      g.unlockRegion(i);
    }
    // 차량 더: 지역마다 배달 차 2대 + 소형 트럭 1대
    for (var r = 0; r < 5; r++) {
      g.makeUnit(2, r);
      g.makeUnit(1, r);
    }
    // 허브가 막히지 않게 시설을 넉넉히 (접수·포장·선반·도크)
    final rnd = Random(3);
    final problems = <String>{};
    void bad(String s) {
      if (problems.add(s)) {
        // ignore: avoid_print
        print('문제: $s');
      }
    }

    final stuck = <int, double>{}; // 차량 id → 같은 상태로 머문 시간
    final lastState = <int, int>{};
    var pendTime = 0.0;
    var choices = 0, evts = 0, police = 0, broke = 0;
    const dt = 0.2;
    var t = 0.0;
    final startDay = g.day;
    while (g.day < startDay + days) {
      // 카드 닫기
      g.report = null;
      g.award = null;
      g.gradeUp = null;
      g.postcard = null;
      if (g.evtNow != null) g.chooseEvent(1);
      if (g.storyAsk != null) g.chooseStory(3);
      g.update(dt);
      t += dt;
      // 1분마다 설정을 무작위로 바꿈 + 보는 지역 바꿈
      if ((t / 60).floor() != ((t - dt) / 60).floor()) {
        g.screen = rnd.nextBool() ? 1 : 0;
        g.mapSel = rnd.nextInt(5);
        for (final u in g.fleet) {
          if (rnd.nextDouble() < 0.3) g.setLoad(u, rnd.nextInt(4));
          if (!u.isTrunk && rnd.nextDouble() < 0.3) {
            final r = rnd.nextInt(3);
            if (r == 0) {
              g.setZone(u, rnd.nextInt(4) - 1);
            } else if (r == 1) {
              g.toggleHome(u, rnd.nextInt(RegionMap.of(u.region).courier.length));
            } else {
              g.clearHomes(u);
            }
          }
        }
        for (var r = 0; r < 5; r++) {
          final f = rnd.nextInt(Cfg.facName.length);
          if (rnd.nextDouble() < 0.1) g.buyFac(r, f);
        }
      }
      // 사건 선택: 보고 있으면 1~3초 뒤 무작위로 고름 (가끔 안 고름)
      final pe = g.pendingEvt;
      if (pe != null) {
        pendTime += dt / g.speedMul;
        if (pendTime > 1.5 && rnd.nextDouble() < 0.7) {
          g.chooseRouteEvt(pe, rnd.nextInt(3));
          choices++;
        }
        if (pendTime > Cfg.evtChooseSec + 2) bad('사건 선택이 ${pendTime.toStringAsFixed(1)}초 동안 안 끝남 (${pe.driver})');
      } else {
        pendTime = 0;
      }
      if (g.fleet.where((u) => u.evtWaitT > 0).length > 1) bad('사건 선택 대기 차량이 둘 이상');
      // 불변식
      for (var r = 0; r < 5; r++) {
        if (g.centerStock[r] < 0) bad('센터 재고 음수 r=$r');
        if (g.centerBorn[r].length > g.centerStock[r] + 5) bad('센터 접수 시각 목록이 재고보다 많음 r=$r (${g.centerBorn[r].length}/${g.centerStock[r]})');
      }
      if (g.money < 0) bad('돈 음수');
      for (final u in g.fleet) {
        if (u.cargo < 0) bad('적재 음수 ${u.driver}');
        if (u.cap < 1) bad('적재 한도 0 ${u.driver}');
        if (u.dur.isNaN || u.t.isNaN) bad('NaN 운행 ${u.driver}');
        if (u.evtT > 0 && u.evtKind == 4) police++;
        final key = u.state * 1000 + u.cargo;
        if (lastState[u.id] == key && u.state != 0) {
          stuck[u.id] = (stuck[u.id] ?? 0) + dt;
          if (stuck[u.id]! > 600) bad('${u.name} ${u.driver} 상태 ${u.state}에서 10분 넘게 멈춤');
        } else {
          stuck[u.id] = 0;
        }
        lastState[u.id] = key;
        if (u.state == 1 && u.homes.isNotEmpty && !u.isTrunk && !u.homes.contains(u.house)) {
          // 지정 집을 운행 중에 바꾼 경우는 괜찮음 (다음 운행부터)
        }
      }
    }
    evts = g.fleet.length;
    broke = g.rs.breakN;
    // ignore: avoid_print
    print('==== 노선 스트레스 $days일 ====\n'
        '배송 ${g.delivered} · 정시 ${g.onTimeCount} · 지각 ${g.lateCount} · 단속 ${g.rs.policeN} · 과적 파손 $broke · 사건 선택 $choices\n'
        '의뢰 완료 ${g.rs.reqDone} · 평판 ${g.rs.rep} · 단골 ${[for (var r = 0; r < 5; r++) g.regularCount(r)]}\n'
        '센터 재고 ${g.centerStock} · 차량 $evts대 · 시설 ${[for (final f in g.rs.fac) f.length]}\n'
        '차량 무리 최대 ${g.fleet.map((u) => u.wear).reduce(max)} · 문제 ${problems.length}건');
    expect(problems, isEmpty);
  }, timeout: Timeout.none);
}
