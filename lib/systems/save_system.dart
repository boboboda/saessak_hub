import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

// v2: 접수량·배송 기한 경제로 바뀌며 예전 저장(v1)은 쓰지 않음 (새로 시작)
// v3: 허브 개편(창구 2x2·통로·마당 크기)으로 예전 배치와 겹칠 수 있어 새로 시작
// v4: 접수 창구가 3x2(오른쪽 칸 적재대)로 넓어져 예전 배치와 겹칠 수 있어 새로 시작
const String _saveKey = 'hub_save_v4';

extension SaveSystem on HubGame {
  Map<String, dynamic> _toJson() {
    return {
      'money': money,
      'area': areaLevel,
      'day': day,
      'dayTimer': dayTimer,
      'done': done,
      'lost': lost,
      'delivered': delivered,
      'dayEarn': dayEarn,
      'upgrades': upgrades,
      'urgentOk': urgentOk,
      'nextStaffId': nextStaffId,
      'regions': regionOpen,
      'fame': fame,
      'streak': streak,
      'bestStreak': bestStreak,
      'onTime': onTimeCount,
      'late': lateCount,
      'cstock': centerStock,
      'nextUnitId': nextUnitId,
      'fleet': [
        for (final u in fleet)
          {
            'id': u.id,
            'ty': u.type,
            'dr': u.driver,
            'sk': u.skill,
            'lv': u.level,
            'rg': u.region,
            // 운행 중 상태는 저장하지 않고 불러오면 대기로 돌아감. 싣고 가던 택배는 지역센터에 도착한 것으로 처리
            'cg': u.state == 1 ? u.cargo : _dockLoaded(u),
          }
      ],
            'claimed': claimed.toList(),
      'rate': rt.toJson(),
      'tickets': tickets,
      'routes': [
        for (final r in routes)
          {'on': r.on, 'v': r.vehicle, 'w': r.wait, 'p': r.prio}
      ],
      'staff': [
        for (final s in staff)
          {
            'id': s.id,
            'name': s.name,
            'st': [s.speed, s.walk, s.kind, s.stamina, s.care],
            'hire': s.hireCost,
            'wage': s.wage,
            'energy': s.energy,
            'mistakes': s.mistakes,
            'carrier': s.carrier,
            'lv': s.level,
            'xp': s.xp,
                        'spec': s.spec,
            'job': [s.job, s.jobLv, s.jobXp, s.promoted ? 1 : 0],
            'jh': {for (final e in s.jobHist.entries) '${e.key}': e.value},
          }
      ],
      'aisles': aisles.toList(),
      'buildings': [
        for (final b in buildings)
          {
            'type': b.type.id,
            'x': b.tx,
            'y': b.ty,
            'mine': b.mine,
            'lv': b.level,
            'regions': b.regions,
            'crew': [for (final s in b.crew) s.id],
          }
      ],
    };
  }

  Future<void> saveGame() async {
    if (noSave) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_saveKey, jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('저장 실패: $e');
    }
  }

  /// 저장된 게임을 불러옴. 저장이 없거나 깨졌으면 false (새 게임)
  /// 도크에서 싣는 중인 트럭의 택배 수 (저장 때 잃지 않도록)
  int _dockLoaded(FleetUnit u) {
    for (final b in buildings) {
      final v = b.vehicle;
      if (v != null && v.unit == u) return v.loaded;
    }
    return 0;
  }

  Future<bool> loadGame() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_saveKey);
      if (raw == null) return false;
      final j = jsonDecode(raw) as Map<String, dynamic>;

            final loadedStaff = <Staff>[];
      final noJob = <Staff>[]; // 예전 저장에서 직업이 없던 직원 (건물을 읽은 뒤 맡은 일로 정함)
      for (final m in (j['staff'] as List)) {
        final st = (m['st'] as List).map((e) => e as int).toList();
        final s = Staff(m['id'] as int, m['name'] as String, st[0], st[1], st[2],
            st[3], st[4], m['hire'] as int, m['wage'] as int);
        s.energy = (m['energy'] as num).toDouble();
        s.mistakes = m['mistakes'] as int;
        s.carrier = m['carrier'] as bool;
        s.level = (m['lv'] as int?) ?? 1;
        s.xp = ((m['xp'] as num?) ?? 0).toDouble();
                s.spec = (m['spec'] as int?) ?? 0;
        final jb = m['job'] as List?;
        if (jb != null && jb.length >= 4) {
          s.job = ((jb[0] as num).toInt()).clamp(0, Cfg.jobName.length - 1);
          s.jobLv = ((jb[1] as num).toInt()).clamp(1, Cfg.jobMaxLv);
          s.jobXp = (jb[2] as num).toDouble();
          s.promoted = (jb[3] as num) == 1;
        } else {
          // 예전 저장: 특기는 직업 Lv3으로 옮기고, 없으면 지금 하는 일·능력치로 직업을 정함
                    s.job = s.spec > 0 ? s.spec - 1 : (s.carrier ? 2 : bestJob(s));
          s.jobLv = s.spec > 0 ? 3 : 1;
          if (s.spec == 0 && !s.carrier) noJob.add(s);
        }
        final jh = m['jh'] as Map?;
        if (jh != null) {
          for (final e in jh.entries) {
            s.jobHist[int.parse(e.key as String)] = (e.value as num).toInt();
          }
        }
        loadedStaff.add(s);
      }
      final byId = {for (final s in loadedStaff) s.id: s};

      final loadedB = <Building>[];
      for (final m in (j['buildings'] as List)) {
        final type = Cfg.types.firstWhere((t) => t.id == m['type']);
        final b = Building(type, m['x'] as int, m['y'] as int);
        b.mine = m['mine'] as bool;
        b.level = (m['lv'] as int?) ?? 1;
        final rg = (m['regions'] as List).map((e) => e as int).toList();
        for (var i = 0; i < b.regions.length && i < rg.length; i++) {
          b.regions[i] = rg[i];
        }
        b.stored = b.regions.fold(0, (a, x) => a + x);
        for (final id in (m['crew'] as List)) {
          final s = byId[id];
          if (s != null) {
            b.crew.add(s);
            s.post = b;
          }
        }
                loadedB.add(b);
      }
      for (final s in noJob) {
        final id = s.post?.type.id;
        if (id == 'counter') s.job = 0;
        if (id == 'pack') s.job = 1;
      }

      money = j['money'] as int;
      areaLevel = j['area'] as int;
      day = j['day'] as int;
      dayTimer = (j['dayTimer'] as num).toDouble();
      done = j['done'] as int;
      lost = j['lost'] as int;
      delivered = j['delivered'] as int;
      dayEarn = j['dayEarn'] as int;
      upgrades = (j['upgrades'] as int?) ?? 0;
      urgentOk = (j['urgentOk'] as int?) ?? 0;
      nextStaffId = j['nextStaffId'] as int;
      final ro = j['regions'] as List?;
      if (ro != null) {
        for (var i = 0; i < regionOpen.length && i < ro.length; i++) {
          regionOpen[i] = ro[i] as bool;
        }
      }
      final rl = j['routes'] as List?;
      if (rl != null) {
        for (var i = 0; i < routes.length && i < rl.length; i++) {
          final m = rl[i] as Map<String, dynamic>;
          routes[i].on = m['on'] as bool;
          routes[i].vehicle = m['v'] as int;
          routes[i].wait = (m['w'] as num).toDouble();
          routes[i].prio = m['p'] as int;
        }
      }
      fame = (j['fame'] as int?) ?? 0;
      streak = (j['streak'] as int?) ?? 0;
      bestStreak = (j['bestStreak'] as int?) ?? 0;
      onTimeCount = (j['onTime'] as int?) ?? 0;
      lateCount = (j['late'] as int?) ?? 0;
      final cs = j['cstock'] as List?;
      if (cs != null) {
        for (var i = 0; i < centerStock.length && i < cs.length; i++) {
          centerStock[i] = cs[i] as int;
        }
      }
      nextUnitId = (j['nextUnitId'] as int?) ?? 1;
      fleet.clear();
      final fl = j['fleet'] as List?;
      if (fl != null) {
        for (final e in fl) {
          final m = e as Map<String, dynamic>;
          final u = FleetUnit(m['id'] as int, m['ty'] as int, m['dr'] as String,
              m['sk'] as int, m['rg'] as int);
          u.level = (m['lv'] as int?) ?? 1;
          final cg = (m['cg'] as int?) ?? 0;
          if (cg > 0) centerStock[u.region] += cg; // 가던 택배는 센터에 도착한 것으로 처리
          fleet.add(u);
          if (u.id >= nextUnitId) nextUnitId = u.id + 1;
        }
      }
      if (fleet.isEmpty) {
        // 예전 저장: 열린 지역마다 기본 차량 지급
        for (var i = 0; i < regionOpen.length; i++) {
          if (regionOpen[i]) grantStarterUnits(i);
        }
      }
      claimed
        ..clear()
        ..addAll(((j['claimed'] as List?) ?? const []).map((e) => e as int));
            // 하루 평가·업적 기록 (예전 저장엔 없음 → 새로 시작)
      try {
        final r = j['rate'];
        if (r is Map<String, dynamic>) rt.load(r);
      } catch (e) {
        debugPrint('평가 기록 불러오기 실패: $e');
      }
      tickets = (j['tickets'] as num?)?.toInt() ?? 0;
      aisles
        ..clear()
        ..addAll(((j['aisles'] as List?) ?? const []).map((e) => e as int));
      aisleVer++;
      staff
        ..clear()
        ..addAll(loadedStaff);
      buildings
        ..clear()
        ..addAll(loadedB);
      syncCarriers();
      return true;
    } catch (e) {
      debugPrint('불러오기 실패: $e');
      staff.clear();
      buildings.clear();
      fleet.clear();
      return false;
    }
  }

  /// 저장을 지움. 다시 실행하면 새 게임으로 시작.
  Future<void> resetSave() async {
    noSave = true;
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveKey);
    showToast('저장을 지웠어요. 앱을 다시 켜면 새로 시작해요');
  }
}
