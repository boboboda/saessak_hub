import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 사용자가 직접 개입하는 부분: 내 자리 접수(탭) + 위기 알림 조치
extension InteractSystem on HubGame {
  // ---------------- 1. 내 자리에서 손님 탭 접수 ----------------

  /// 손님 말풍선을 탭: 미리 처리 + 사연 보너스. 접수량(손님 수)은 바뀌지 않는다.
  bool tapStory(Offset world) {
    for (final c in customers.reversed) {
      final r = c.bubble;
      if (c.state == 2 || c.pre || c.story < 0 || r == null) continue;
      if (!r.inflate(6).contains(world)) continue;
      c.pre = true;
      final eff = Cfg.stories[c.story].$2;
      String txt;
      switch (eff) {
        case 0:
          money += Cfg.storyTip;
          dayEarn += Cfg.storyTip;
          txt = '팁 +${Cfg.storyTip}원';
          break;
        case 1:
          c.patience = Cfg.patience * (c.vip ? Cfg.vipPatience : 1.0);
          txt = '만족!';
          break;
        default:
          fame += Cfg.storyFame;
          txt = '명성 +${Cfg.storyFame}';
      }
      hubFx.add((r.topCenter, txt, Cfg.storyColor[eff], clock));
      ui();
      return true;
    }
    return false;
  }

  /// 맵을 탭했을 때 '내 자리' 손님을 눌렀으면 접수 처리. 처리했으면 true.
  bool tapCustomer(Offset world) {
    if (mode != 0) return false;
    if (tapStory(world)) return true;
    final tp = Offset(world.dx / Cfg.tile, world.dy / Cfg.tile);
    for (final c in customers) {
      final cnt = c.counter;
      if (c.state == 2 || cnt == null || !cnt.mine) continue;
      if ((c.pos - tp).distance > 0.9) continue;

      // 줄 맨 앞에 서서 기다리는 손님을 접수
      Customer? first;
      for (final o in customers) {
        if (o.counter == cnt && o.state != 2 && o.ready) {
          first = o;
          break;
        }
      }
      if (first == null) {
        showToast('손님이 자리로 오는 중이거나 택배함이 가득 찼어요');
      } else {
        first.tapped = true;
      }
      return true;
    }
    return false;
  }

  /// 이 창구를 내 자리로 지정 (기존 내 자리는 해제)
  void setMine(Building b) {
    if (b.type.id != 'counter') return;
    for (final o in ofType('counter')) {
      o.mine = false;
    }
    b.mine = true;
    showToast('내 자리로 지정! 손님을 탭하면 바로 접수돼요');
    ui();
  }

  // ---------------- 2. 위기 알림 ----------------

  /// 지금 상황에서 알림 목록을 다시 만든다 (0.2초마다 호출)
  void refreshAlerts() {
    alerts.clear();

    var angry = 0;
    for (final c in customers) {
      if (c.state == 2) continue;
      if (c.patience / Cfg.patience < Cfg.alertAngry) angry++;
    }
    if (angry > 0) {
      final cd = sootheCd > 0 ? ' (${sootheCd.ceil()}초)' : '';
      alerts.add(Alert(Alert.angry, '화난 손님 $angry명', '달래기$cd'));
    }

    var shown = 0;
    for (final s in staff) {
      if (s.away || s.idle) continue;
      if (s.energyPct < Cfg.alertTired) {
        alerts.add(Alert(Alert.tired, '${s.name} 지침', '간식 ${Cfg.snackCost}원',
            staff: s));
        if (++shown >= 2) break;
      }
    }

    for (final b in ofType('counter')) {
      if (b.outbox.length >= b.outCap) {
        alerts.add(Alert(Alert.jam, '접수 택배가 가득 찼어요', '운반 직원', building: b));
        break;
      }
    }
  }

  /// 알림을 눌렀을 때 조치
  void runAlert(Alert a) {
    switch (a.kind) {
      case Alert.angry:
        if (sootheCd > 0) {
          showToast('아직 달랠 수 없어요 (${sootheCd.ceil()}초)');
          return;
        }
        var n = 0;
        for (final c in customers) {
          if (c.state == 2) continue;
          if (c.patience / Cfg.patience < Cfg.alertAngry) {
            c.patience = max(c.patience, Cfg.patience * Cfg.sootheTo);
            n++;
          }
        }
        sootheCd = Cfg.sootheCooldown;
        showToast('손님 $n명을 달랬어요');
        break;
      case Alert.tired:
        final s = a.staff;
        if (s == null || !staff.contains(s)) return;
        if (money < Cfg.snackCost) {
          showToast('돈이 부족해요');
          return;
        }
        money -= Cfg.snackCost;
        s.energy = min(s.maxEnergy, s.energy + s.maxEnergy * Cfg.snackRestore);
        showToast('${s.name}에게 간식을 줬어요');
        break;
      case Alert.jam:
        sheet = 'staff';
        staffTab = 0;
        break;
    }
    refreshAlerts();
    ui();
  }
}
