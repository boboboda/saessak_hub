import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

extension BuildSystem on HubGame {
  /// 구역 영역 (타일 좌표). 0 접수, 1 포장, 2 보관·출고, 3 도크 마당, 그 외는 창고 전체
  Rect zoneRect(int z) {
    final a = area;
    switch (z) {
      case 0:
        return Rect.fromLTRB(a.left, a.top, Cfg.zoneX1, a.bottom);
      case 1:
        return Rect.fromLTRB(Cfg.zoneX1, a.top, Cfg.zoneX2, a.bottom);
      case 2:
        return Rect.fromLTRB(Cfg.zoneX2, a.top, a.right, a.bottom);
      case 3:
        return Cfg.yard;
      default:
        return a;
    }
  }

  /// 같은 종류 건물 중 몇 번째인지 (1부터)
  int typeIndex(Building b) {
    var i = 0;
    for (final x in buildings) {
      if (x.type.id == b.type.id) {
        i++;
        if (identical(x, b)) return i;
      }
    }
    return i;
  }

  /// 배치 중인 목업의 타일 영역
  Rect get ghostRect => Rect.fromLTWH(
    ghostX.toDouble(),
    ghostY.toDouble(),
    placing!.w.toDouble(),
    placing!.h.toDouble(),
  );

  bool inRect(Rect r, Rect a) {
    return r.left >= a.left &&
        r.top >= a.top &&
        r.right <= a.right &&
        r.bottom <= a.bottom;
  }

  /// 월드 좌표(픽셀)로 목업 이동. 도크는 벽에 붙어 위아래로만 움직임.
  void moveGhost(Offset w) {
    final t = placing;
    if (t == null) return;
    ghostX = (w.dx / Cfg.tile - t.w / 2).round();
    ghostY = (w.dy / Cfg.tile - t.h / 2).round();
    if (t.zone == 3) {
      ghostX = Cfg.wallX.toInt();
      ghostY = ghostY
          .clamp(area.top.toInt(), (area.bottom - t.h).toInt())
          .toInt();
    }
    ui();
  }

  /// null이면 설치 가능. 아니면 이유 문구.
  String? get ghostProblem {
    final t = placing;
    if (t == null) return '선택된 건물이 없어요';
    final r = ghostRect;
    if (t.zone == 3) {
      if (!inRect(r, Cfg.yard)) return '도크 구역 밖이에요';
      if (r.left != Cfg.wallX) return '도크는 창고 벽에 붙여야 해요';
      if (r.top < area.top || r.bottom > area.bottom) {
        return '창고 벽이 있는 곳에만 놓을 수 있어요';
      }
    } else {
      if (!inRect(r, area)) return '창고 밖이에요';
      if (t.zone >= 0 && !inRect(r, zoneRect(t.zone))) {
        return '${Cfg.zoneName[t.zone]}에만 놓을 수 있어요';
      }
    }
    if (t.zone != 3 && doorways.any((d) => d.overlaps(r)))
      return '문 바로 앞은 비워 두세요';
    for (var y = r.top.toInt(); y < r.bottom; y++) {
      for (var x = r.left.toInt(); x < r.right; x++) {
        if (isAisle(x, y)) return '통로 위에는 놓을 수 없어요 (통로를 먼저 철거)';
      }
    }
    for (final b in buildings) {
      if (b.rect.overlaps(r)) return '다른 건물과 겹쳐요';
      if (t.zone != 3 && b.type.zone != 3) {
        if (frontRow(b.rect).overlaps(r)) return '다른 건물 앞줄(서는 자리)을 막아요';
        if (frontRow(r).overlaps(b.rect)) return '이 건물 앞줄이 막혀요';
      }
    }
    if (money < t.cost) return '돈이 부족해요';
    return null;
  }

  void startPlacing(BuildingType t) {
    placing = t;
    mode = 2;
    selected = null;
    sheet = null;
    // 보이는 화면 가운데에서 시작 (놓을 수 있는 구역 안으로 보정)
    final visibleH = size.y - insetTop - insetBottom;
    final c = this.toWorld(Offset(size.x / 2, insetTop + visibleH / 2));
    if (t.zone == 3) {
      moveGhost(c);
      return;
    }
    final z = t.zone >= 0 ? zoneRect(t.zone) : area;
    var gx = (c.dx / Cfg.tile - t.w / 2).round();
    var gy = (c.dy / Cfg.tile - t.h / 2).round();
    gx = gx.clamp(z.left.toInt(), (z.right - t.w).toInt()).toInt();
    gy = gy.clamp(z.top.toInt(), (z.bottom - t.h).toInt()).toInt();
    ghostX = gx;
    ghostY = gy;
    ui();
  }

  /// 통로 깔기 모드 시작
  void startAisle() {
    mode = 4;
    aisleTool = 0;
    selected = null;
    sheet = null;
    ui();
  }

  void endAisle() {
    mode = 0;
    aisleLast = null;
    ui();
  }

  /// 통로 모드에서 화면을 눌렀거나 끌었을 때 (월드 픽셀)
  void aisleAt(Offset world, {bool drag = false}) {
    final x = (world.dx / Cfg.tile).floor(), y = (world.dy / Cfg.tile).floor();
    final last = aisleLast;
    if (drag && last != null && last == (x, y)) return;
    if (drag && last != null) {
      paintAisleLine(last.$1, last.$2, x, y, erase: aisleTool == 1);
    } else {
      final why = aisleTool == 0 ? aisleProblem(x, y) : null;
      if (why != null && !drag) showToast(why);
      paintAisleLine(x, y, x, y, erase: aisleTool == 1);
    }
    aisleLast = (x, y);
  }

  void cancelPlacing() {
    placing = null;
    mode = 0;
    draggingGhost = false;
    ui();
  }

  void confirmPlace() {
    final t = placing;
    if (t == null) return;
    final problem = ghostProblem;
    if (problem != null) {
      showToast(problem);
      return;
    }
    money -= t.cost;
    final nb = Building(t, ghostX, ghostY);
    if (t.id == 'counter' && !ofType('counter').any((b) => b.mine)) {
      nb.mine = true; // 첫 접수 창구는 내 자리
    }
    buildings.add(nb);
    this.autoAssign(nb);
    final needStaff = t.slots > 0;
    cancelPlacing();
    showToast(
      needStaff ? '${t.name} 설치! 직원이 모자라면 건물을 눌러 배치하세요' : '${t.name} 설치 완료!',
    );
  }

  /// (디버그) 시작 구성 자동 배치: 접수 창구·포장대·선반·도크 1개씩, 남는 직원은 운반
  void debugStarterLayout() {
    // 통로 바로 위에 앞줄 한 칸을 비우고 나란히 (접수 → 포장 → 선반 → 도크)
    final top = door.top.toInt();
    final plan = <(String, int, int)>[
      ('counter', Cfg.zoneX1.toInt() - 3, top - 3),
      ('pack', Cfg.zoneX1.toInt() + 1, top - 3),
      ('shelf', Cfg.zoneX2.toInt() + 1, top - 4),
      ('dock', Cfg.wallX.toInt(), top - 1),
    ];
    for (final (id, x, yy) in plan) {
      final t = Cfg.types.firstWhere((t) => t.id == id);
      final r = Rect.fromLTWH(
        x.toDouble(),
        yy.toDouble(),
        t.w.toDouble(),
        t.h.toDouble(),
      );
      if (buildings.any((b) => b.rect.overlaps(r))) continue;
      final nb = Building(t, x, yy);
      if (id == 'counter' && !ofType('counter').any((b) => b.mine))
        nb.mine = true;
      buildings.add(nb);
      this.autoAssign(nb);
    }
    for (final s in staff) {
      if (s.idle) this.setCarrier(s);
    }
    showToast('시작 구성 배치 완료');
    ui();
  }

  /// (디버그) 빈자리에 휴게실을 하나 놓고 모든 직원을 지치게 해서 쉬러 가는 모습을 확인
  void debugRestCheck() {
    if (ofType('lounge').isEmpty) {
      final t = Cfg.types.firstWhere((t) => t.id == 'lounge');
      final a = area;
      outer:
      for (var y = a.bottom.toInt() - t.h; y >= a.top; y--) {
        for (var x = a.left.toInt(); x + t.w <= a.right; x++) {
          final r = Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            t.w.toDouble(),
            t.h.toDouble(),
          );
          if (buildings.any(
            (b) => b.rect.overlaps(r) || frontRow(b.rect).overlaps(r),
          ))
            continue;
          buildings.add(Building(t, x, y));
          break outer;
        }
      }
    }
    for (final s in staff) {
      s.energy = s.maxEnergy * Cfg.restBelow * 0.5;
    }
    showToast('휴게실 확인용: 직원이 쉬러 가요');
    ui();
  }

  Building? buildingAt(int tx, int ty) {
    final p = Offset(tx + 0.5, ty + 0.5);
    for (var i = buildings.length - 1; i >= 0; i--) {
      if (buildings[i].rect.contains(p)) return buildings[i];
    }
    return null;
  }

  void demolish() {
    final b = selected;
    if (b == null) return;
    final refund = b.type.cost ~/ 2;
    money += refund;
    this.releaseCrew(b);
    final dv = b.vehicle; // 도크를 철거하면 싣던 택배는 지역센터로 보내고 트럭은 풀어줌
    if (dv != null) {
      centerStock[dv.region] += dv.loaded;
      centerBorn[dv.region].addAll(dv.borns);
      dv.unit?.state = 0;
    }
    buildings.remove(b);
    if (b.mine) {
      for (final o in ofType('counter')) {
        o.mine = true; // 내 자리가 철거되면 다른 접수 창구로 이전
        break;
      }
    }
    selected = null;
    showToast('${b.type.name} 철거 (+${fmt(refund)}원)');
  }

  void upgradeBuilding(Building b) {
    if (!b.upgradable) return;
    final cost = b.upgradeCost;
    if (money < cost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= cost;
    b.level++;
    upgrades++;
    showToast('${b.type.name} Lv.${b.level} 업그레이드!');
    ui();
  }

  void confirmExpand() {
    if (!canExpand) return;
    final cost = nextAreaCost;
    if (money < cost) {
      showToast('돈이 부족해요');
      return;
    }
    money -= cost;
    areaLevel++;
    mode = 0;
    showToast('${Cfg.areaName[areaLevel]}(으)로 확장!');
  }
}
