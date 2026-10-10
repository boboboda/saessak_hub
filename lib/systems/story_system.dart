import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/util.dart';
import '../models/models.dart';

/// 사연 택배 한 건 정의 (Cfg.storyDefs)
class StoryDef {
  final String item; // 사연 물건 아이콘 (assets/sprites/props/story_<item>.png)
  final String bubble; // 말풍선에 쓰는 짧은 글 (선택 카드 제목)
  final String who; // 보내는 사람
  final String text; // 사연
  final String need; // 요구 시설 id (1단계는 포장대만)
  final int needLv; // 요구 시설 레벨
  final List<String> fx; // 포장 연출 아이콘 순서 (ice · wrap · tape)
  final int pay, fame; // 숙련 포장 성공 보상 (일반·임시 포장 성공은 절반)
  final String thanks; // 성공 엽서 글
  final String sorry; // 실패 엽서 글 (따뜻하게)
  const StoryDef(this.item, this.bubble, this.who, this.text, this.need, this.needLv, this.fx, this.pay, this.fame,
      this.thanks, this.sorry);
}

/// 포장대에서 진행 중인 사연 택배
class StoryJob {
  final int story;
  final Building table;
  final int mode; // 0 숙련 포장 · 1 일반 포장 · 2 임시 포장
  double t = 0;
  StoryJob(this.story, this.table, this.mode);
}

/// 결과 엽서 (성공·실패). stamp: 0 배송 완료 · 1 파손 · 2 지연
class StoryResult {
  final int story;
  final bool ok;
  final int stamp;
  final bool skilled;
  final int pay, fame;
  const StoryResult(this.story, this.ok, this.stamp, this.skilled, this.pay, this.fame);
}

/// 사연 택배: 사연 손님만 말풍선을 달고 와서 문 앞에 멈춰 기다린다 (놓치면 일정 시간 뒤 돌아감).
/// 탭하면 접수 선택지: 포장대 레벨이 사연의 요구 레벨 이상이면 '숙련 포장!', 모자라면 일반 포장 / 임시 포장 / 정중히 거절.
/// 고르면 포장대 직원이 포장(아이콘 이펙트 + 상자 찌그러짐)하고, 끝나면 결과 엽서. 거절한 사연은 도감에 잠김으로 남고,
/// 포장대 레벨이 차면 다시 찾아온다.
extension StorySystem on HubGame {
  StoryDef storyOf(int k) => Cfg.storyDefs[k];

  /// 사연 손님이 서서 기다리는 자리: 손님 입구 바로 안쪽 칸 (건물을 못 놓는 칸)
  Offset get storySpot => Offset(door.left + 0.55, door.center.dy + 0.45);

  /// 사연 택배를 포장할 포장대: 가장 레벨 높고 일하는 직원이 많은 곳 (없으면 null)
  Building? packTable() {
    Building? best;
    for (final b in ofType('pack')) {
      if (best == null || b.level > best.level || (b.level == best.level && b.active.length > best.active.length)) {
        best = b;
      }
    }
    return best;
  }

  /// 요구 시설을 채웠는지: 레벨이 있는 시설(창구·포장대·선반·도크)은 그 레벨 이상, 나머지는 하나라도 있으면
  bool storyNeedMet(int k) {
    final d = storyOf(k);
    return ofType(d.need).any((b) => b.level >= d.needLv);
  }

  /// 요구 시설 글 ("포장대 Lv2", "에어컨")
  String storyNeedText(int k) {
    final d = storyOf(k);
    final name = Cfg.types.firstWhere((x) => x.id == d.need).name;
    return Building.levelled.contains(d.need) ? '$name Lv${d.needLv}' : name;
  }

  /// 지금 진행 중인 사연이 있는지 (문 앞 손님 · 선택 카드 · 포장 중 · 엽서)
  bool get storyBusy =>
      storyAsk != null ||
      storyJob != null ||
      postcard != null ||
      customers.any((c) => c.story >= 0 && c.state != 2);

  /// 새 손님이 사연 손님인지 정함. 사연 번호 또는 -1. 거절했던 사연은 조건이 차면 먼저 다시 찾아옴
  int pickStory() {
    if (storyBusy) return -1;
    if (rs.vipStory > 0) {
      // VIP 단골이 보낸 사연 손님: 확률·날짜 무시
      rs.vipStory--;
      final pool = [for (var k = 0; k < Cfg.storyDefs.length; k++) if (!rt.storyDone.contains(k)) k];
      final all = pool.isEmpty ? [for (var k = 0; k < Cfg.storyDefs.length; k++) k] : pool;
      showToast('VIP 단골이 소개한 사연 손님이 왔어요!');
      return all[rnd.nextInt(all.length)];
    }
    if (day < Cfg.storyFromDay) return -1;
    if (rnd.nextDouble() >= Cfg.storyChance) return -1;
    for (final k in rt.storyLocked) {
      if (storyNeedMet(k)) {
        showToast('예전에 돌려보낸 사연 손님이 다시 찾아왔어요');
        return k;
      }
    }
    final all = [for (var k = 0; k < Cfg.storyDefs.length; k++) k];
    final fresh = all.where((k) => !rt.storyDone.contains(k) && !rt.storyLocked.contains(k)).toList();
    final pool = fresh.isNotEmpty ? fresh : all.where((k) => !rt.storyLocked.contains(k)).toList();
    if (pool.isEmpty) return -1;
    return pool[rnd.nextInt(pool.length)];
  }

  /// 사연 손님 한 명 (매 프레임): 문 앞까지 걸어와 멈춰 기다림. 너무 오래 두면 돌아감
  void storyCustomerStep(Customer c, double dt) {
    final spot = storySpot;
    c.pos = stepToward(c.pos, spot, Cfg.customerSpeed, dt);
    // 기다리는 시간은 배속과 상관없이 실제 시간으로 (10배속에서도 35초는 기다려 줌)
    if ((c.pos - spot).distance < 0.05 && storyAsk != c) c.storyT += dt / speedMul;
    if (c.storyT >= Cfg.storyWait) {
      c.story = -1;
      c.state = 2;
      showToast('사연 손님이 기다리다 돌아갔어요');
    }
  }

  /// 맵 탭: 사연 손님(몸 또는 말풍선)을 눌렀으면 선택 카드를 엶. 손가락 크기(48dp)보다 작지 않게 판정
  bool tapStoryCustomer(Offset world) {
    final minR = Cfg.storyTouchDp / 2 / zoom; // 월드 픽셀
    for (final c in customers.reversed) {
      if (c.story < 0 || c.state == 2) continue;
      final body = Offset(c.pos.dx * Cfg.tile, (c.pos.dy - 0.2) * Cfg.tile);
      final r = c.bubble;
      var hit = (world - body).distance < max(minR, Cfg.tile * 0.7);
      if (!hit && r != null) {
        final hr = Rect.fromCenter(center: r.center, width: max(r.width, minR * 2), height: max(r.height, minR * 2));
        hit = hr.contains(world);
      }
      if (!hit) continue;
      storyAsk = c;
      sheet = null;
      selected = null;
      picking = null;
      ui();
      return true;
    }
    return false;
  }

  /// 선택지 (글, 설명, 고를 수 있는지). 카드에서 씀
  List<(int, String, String, bool)> storyChoices(int k) {
    final d = storyOf(k);
    final has = packTable() != null;
    final need = storyNeedText(k);
    if (storyNeedMet(k) && has) {
      return [
        (0, '숙련 포장!', '$need 있음 · 꼭 성공 · ${fmt(d.pay + Cfg.storySkillBonus)}원 · 명성 +${d.fame}', true),
        (3, '정중히 거절', '다음에 다시 와 달라고 해요', true),
      ];
    }
    return [
      (1, '일반 포장', has ? '성공 ${(Cfg.storyNormalOk * 100).round()}% · ${fmt(d.pay ~/ 2)}원' : '포장대가 없어요', has),
      (2, '임시 포장 (${fmt(Cfg.storyTempCost)}원)',
          has ? '성공 ${(Cfg.storyTempOk * 100).round()}% · ${fmt(d.pay ~/ 2)}원' : '포장대가 없어요', has),
      (3, '정중히 거절', '$need${_ga(need)} 준비되면 다시 찾아와요', true),
    ];
  }

  /// 받침에 맞는 조사 (이/가)
  String _ga(String w) {
    final c = w.codeUnitAt(w.length - 1);
    if (c >= 0x30 && c <= 0x39) return const ['이', '이', '가', '이', '가', '가', '이', '이', '이', '가'][c - 0x30]; // 영·일·이·삼·사·오·육·칠·팔·구
    if (c < 0xAC00 || c > 0xD7A3) return '이';
    return (c - 0xAC00) % 28 == 0 ? '가' : '이';
  }

  /// 선택 카드에서 고름
  void chooseStory(int mode) {
    final c = storyAsk;
    if (c == null) return;
    final k = c.story;
    if (mode == 3) {
      if (!rt.storyDone.contains(k)) rt.storyLocked.add(k);
      showToast('정중히 돌려보냈어요. 준비가 되면 다시 찾아와요');
    } else {
      final t = packTable();
      if (t == null || (mode == 0 && !storyNeedMet(k))) return;
      if (mode == 2) {
        if (money < Cfg.storyTempCost) {
          showToast('돈이 모자라요');
          return;
        }
        money -= Cfg.storyTempCost;
      }
      storyJob = StoryJob(k, t, mode);
      c.pre = true; // 사연을 들어 준 손님 (별점 +0.5)
      done++;
      this.rateServed(c);
    }
    rt.storySeen.add(k);
    c.story = -1;
    c.state = 2;
    storyAsk = null;
    ui();
  }

  /// 포장 진행 (매 프레임, 게임 속도 반영된 d). 포장대에 직원이 있어야 진행
  void updateStory(double d) {
    final j = storyJob;
    if (j == null) return;
    if (!buildings.contains(j.table)) {
      storyJob = null; // 포장대를 철거함
      showToast('포장대가 없어져 사연 택배를 돌려드렸어요');
      return;
    }
    final act = j.table.active;
    if (act.isEmpty) return; // 직원이 돌아올 때까지 기다림
    for (final s in act) {
      s.working = true;
    }
    j.t += d / speedMul; // 연출 시간은 배속과 상관없이 실제 시간 (10배속에서도 포장하는 모습이 보이게)
    if (j.t < Cfg.storyPackTime) return;
    final def = storyOf(j.story);
    final chance = j.mode == 0 ? 1.0 : (j.mode == 2 ? Cfg.storyTempOk : Cfg.storyNormalOk);
    final ok = rnd.nextDouble() < chance;
    final pay = ok ? (j.mode == 0 ? def.pay + Cfg.storySkillBonus : def.pay ~/ 2) : 0;
    final fm = ok ? (j.mode == 0 ? def.fame : def.fame ~/ 2) : 0;
    money += pay;
    dayEarn += pay;
    fame += fm;
    if (ok) {
      rt.storyDone.add(j.story);
      rt.storyLocked.remove(j.story);
    } else {
      rt.storyTried.add(j.story);
    }
    postcard = StoryResult(j.story, ok, ok ? 0 : (j.mode == 2 ? 2 : 1), j.mode == 0, pay, fm);
    storyJob = null;
    ui();
  }

  /// 엽서를 띄워도 되는지 (시트·배치 중이면 기다림)
  bool get postcardShown => postcard != null && sheet == null && selected == null && mode == 0 && picking == null;

  void closePostcard() {
    postcard = null;
    ui();
  }
}
