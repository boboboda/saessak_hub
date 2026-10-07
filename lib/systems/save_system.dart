import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

const String _saveKey = 'hub_save_v1';

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
      'nextStaffId': nextStaffId,
      'regions': regionOpen,
      'claimed': claimed.toList(),
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
          }
      ],
      'buildings': [
        for (final b in buildings)
          {
            'type': b.type.id,
            'x': b.tx,
            'y': b.ty,
            'mine': b.mine,
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
  Future<bool> loadGame() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_saveKey);
      if (raw == null) return false;
      final j = jsonDecode(raw) as Map<String, dynamic>;

      final loadedStaff = <Staff>[];
      for (final m in (j['staff'] as List)) {
        final st = (m['st'] as List).map((e) => e as int).toList();
        final s = Staff(m['id'] as int, m['name'] as String, st[0], st[1], st[2],
            st[3], st[4], m['hire'] as int, m['wage'] as int);
        s.energy = (m['energy'] as num).toDouble();
        s.mistakes = m['mistakes'] as int;
        s.carrier = m['carrier'] as bool;
        loadedStaff.add(s);
      }
      final byId = {for (final s in loadedStaff) s.id: s};

      final loadedB = <Building>[];
      for (final m in (j['buildings'] as List)) {
        final type = Cfg.types.firstWhere((t) => t.id == m['type']);
        final b = Building(type, m['x'] as int, m['y'] as int);
        b.mine = m['mine'] as bool;
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

      money = j['money'] as int;
      areaLevel = j['area'] as int;
      day = j['day'] as int;
      dayTimer = (j['dayTimer'] as num).toDouble();
      done = j['done'] as int;
      lost = j['lost'] as int;
      delivered = j['delivered'] as int;
      dayEarn = j['dayEarn'] as int;
      nextStaffId = j['nextStaffId'] as int;
      final ro = j['regions'] as List?;
      if (ro != null) {
        for (var i = 0; i < regionOpen.length && i < ro.length; i++) {
          regionOpen[i] = ro[i] as bool;
        }
      }
      claimed
        ..clear()
        ..addAll(((j['claimed'] as List?) ?? const []).map((e) => e as int));
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
