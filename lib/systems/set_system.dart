import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 시설 배치 세트: 맞닿은(테두리 한 칸 이상 공유) 건물끼리 묶음을 만들고, 묶음 안 종류 수로 세트를 판정한다.
/// 세트 효과는 건물 필드(setSpeed·setCalm·setRest·setCap·setLoad·setDrain)에 넣고 매 프레임 일 계산에 곱한다.
extension SetSystem on HubGame {
  /// 두 칸 사각형이 테두리를 맞대고 있는지 (겹치지 않고, 맞닿은 길이 > 0)
  bool touching(Rect a, Rect b) {
    final vx = min(a.bottom, b.bottom) - max(a.top, b.top);
    final hx = min(a.right, b.right) - max(a.left, b.left);
    if ((a.right == b.left || b.right == a.left) && vx > 0) return true;
    if ((a.bottom == b.top || b.bottom == a.top) && hx > 0) return true;
    return false;
  }

  /// 맞닿은 건물 묶음들 (rects 는 건물별 칸, 배치 미리보기 때는 가짜 건물 포함)
  List<List<int>> _groups(List<Rect> rects) {
    final n = rects.length;
    final seen = List<bool>.filled(n, false);
    final out = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (seen[i]) continue;
      final g = <int>[i];
      seen[i] = true;
      for (var k = 0; k < g.length; k++) {
        for (var j = 0; j < n; j++) {
          if (!seen[j] && touching(rects[g[k]], rects[j])) {
            seen[j] = true;
            g.add(j);
          }
        }
      }
      out.add(g);
    }
    return out;
  }

  /// 묶음(ids = 건물 종류 목록)이 세트 조건을 채우는지
  bool _meets(SetDef d, List<String> ids) {
    for (final e in d.need.entries) {
      if (ids.where((x) => x == e.key).length < e.value) return false;
    }
    return true;
  }

  /// 매 프레임(가볍게 0.5초마다): 세트 효과를 건물에 다시 계산, 처음 발동한 세트는 발견
  void updateSets(double dt) {
    setTimer -= dt;
    if (setTimer > 0) return;
    setTimer = 0.5;
    for (final b in buildings) {
      b.setSpeed = 1;
      b.setCalm = 1;
      b.setRest = 1;
      b.setCap = 0;
      b.setLoad = 1;
      b.setDrain = 1;
      b.sets.clear();
    }
    final rects = [for (final b in buildings) b.rect];
    for (final g in _groups(rects)) {
      if (g.length < 2) continue;
      final ids = [for (final i in g) buildings[i].type.id];
      for (var si = 0; si < Cfg.sets.length; si++) {
        final d = Cfg.sets[si];
        if (!_meets(d, ids)) continue;
        for (final i in g) {
          final b = buildings[i];
          if (b.type.id != d.target) continue;
          b.sets.add(si);
                    // 포장 라인 2세대(연구): 세트 효과 ×1.5
          b.setSpeed *= this.resAmp(d.speed);
          b.setCalm *= this.resAmp(d.calm);
          b.setRest *= this.resAmp(d.rest);
          b.setCap += this.resAmpCap(d.cap);
          b.setLoad *= this.resAmp(d.load);
          b.setDrain *= this.resAmp(d.drain);
        }
        if (!rt.foundSets.contains(si)) {
          rt.foundSets.add(si);
          if (d.hidden) fame += Cfg.hiddenSetFame;
          showToast(d.hidden
              ? '새 조합 발견! ${d.name} — ${d.effect} (명성 +${Cfg.hiddenSetFame})'
              : '세트 완성! ${d.name} — ${d.effect}');
        }
      }
    }
  }

  /// 반경형 소품(화분·에어컨)과 세트로 줄어든 이 직원의 체력 소모 배수
  double drainAt(Staff s) {
    Offset? at;
    var m = 1.0;
    final p = s.post;
    if (p != null) {
      at = p.rect.center;
      m *= p.setDrain;
    } else if (s.carrier) {
      for (final c in carriers) {
        if (c.staff == s) at = c.pos;
      }
    }
    if (at == null) return m;
    var plants = 0;
    var cool = false;
    for (final b in buildings) {
      final d = (b.rect.center - at).distance;
      if (b.type.id == 'plant' && d <= Cfg.plantRadius) plants++;
      if (b.type.id == 'aircon' && d <= Cfg.airconRadius) cool = true;
    }
    m *= pow(1 - Cfg.plantDrain, min(plants, Cfg.plantMax)).toDouble();
    if (cool) {
      final summer = (dayOfYear - 1) ~/ 7 == 1; // 여름엔 효과 2배
      m *= 1 - Cfg.airconDrain * (summer ? 2 : 1);
    }
    return m;
  }

  /// 배치 미리보기: 이 자리에 놓으면 맞닿는 건물, 새로 발동할 세트 (숨김·미발견은 이름 대신 ???)
  (List<Building>, List<String>) previewSets(BuildingType t, int gx, int gy) {
    final r = Rect.fromLTWH(gx.toDouble(), gy.toDouble(), t.w.toDouble(), t.h.toDouble());
    final near = [for (final b in buildings) if (touching(b.rect, r)) b];
    final rects = [for (final b in buildings) b.rect, r];
    final idsAll = [for (final b in buildings) b.type.id, t.id];
    final names = <String>[];
    for (final g in _groups(rects)) {
      if (!g.contains(rects.length - 1)) continue;
      final ids = [for (final i in g) idsAll[i]];
      final without = [for (final i in g) if (i != rects.length - 1) idsAll[i]];
      for (var si = 0; si < Cfg.sets.length; si++) {
        final d = Cfg.sets[si];
        if (!_meets(d, ids) || _meets(d, without)) continue;
        names.add(d.hidden && !rt.foundSets.contains(si) ? '??? (숨은 조합)' : d.name);
      }
    }
    return (near, names);
  }
}

/// 세트 하나: 조건(종류별 개수, 맞닿은 묶음 안), 효과를 받는 건물 종류, 효과 배수
class SetDef {
  final String name;
  final Map<String, int> need;
  final String target; // 효과를 받는 건물 종류
  final String effect; // 효과 설명
  final String hint; // 도감에서 숨김일 때 보이는 힌트
  final bool hidden;
  final double speed, calm, rest, load, drain;
  final int cap;
  const SetDef(this.name, this.need, this.target, this.effect,
      {this.hint = '',
      this.hidden = false,
      this.speed = 1,
      this.calm = 1,
      this.rest = 1,
      this.load = 1,
      this.drain = 1,
      this.cap = 0});
}
