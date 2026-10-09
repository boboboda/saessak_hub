import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

/// 도감 3권(세트·직업·손님)과 숨은 손님·숨은 직업, 도감 완성 보너스
extension BookSystem on HubGame {
  // ---------------- 숨은 손님 ----------------
  /// 숨은 손님 k가 올 조건을 채웠는지
  bool guestCond(int k) {
    switch (k) {
      case 0: // 단골 할머니: 대기 공간 세트 + 친절 4 이상 직원이 창구에
        return ofType('counter').any((b) => b.sets.contains(1) && b.active.any((s) => s.kind >= 4));
      case 1: // 유튜버: 명성 300 이상 + 수익 부스트 중
        return fame >= 300 && fever > 0;
      case 2: // 이삿짐 센터 사장: 대형 택배 누적 50건 접수
        return rt.bulkDone >= 50;
      case 3: // 꼬마 손님: 화분 3개 이상
        return ofType('plant').length >= 3;
      default: // 해외 바이어: 지역 3곳 이상 + 프리미엄 배송 연구
        return openRegions >= 3 && this.resDone(8);
    }
  }

  /// 새 손님을 만들 때: 조건을 채운 숨은 손님이 (하루 한 번까지) 확률로 옴. 아니면 -1
  int pickGuest() {
    final pool = [
      for (var k = 0; k < Cfg.guestName.length; k++)
        if (guestLast[k] != day && guestCond(k)) k,
    ];
    if (pool.isEmpty || rnd.nextDouble() > Cfg.guestChance) return -1;
    final k = pool[rnd.nextInt(pool.length)];
    guestLast[k] = day;
    if (!rt.foundGuests.contains(k)) {
      rt.foundGuests.add(k);
      fame += Cfg.guestFoundFame;
      showToast('새 손님 발견! ${Cfg.guestName[k]} (손님 도감, 명성 +${Cfg.guestFoundFame})');
    }
    return k;
  }

  /// 숨은 손님 접수를 끝냈을 때 효과
  void guestServed(Customer c, Building cnt) {
    final k = c.guest;
    if (k < 0) return;
    String t;
    switch (k) {
      case 0:
        money += 500;
        dayEarn += 500;
        t = '김치 택배 + 팁 500원';
        break;
      case 1:
        evts.add(ActiveEvt(6, 0, day + 1, day + 1));
        t = '방송에 나갔어요! 내일 손님 ×${Cfg.guestStreamIntake}';
        break;
      case 2:
        var n = 0;
        while (n < 3 && cnt.outbox.length < cnt.outCap) {
          cnt.outbox.add(Parcel(c.region)
            ..kind = 3
            ..born = gt);
          n++;
        }
        done += n;
        money += 2000;
        dayEarn += 2000;
        t = '이삿짐 대형 택배 $n건 + 2,000원';
        break;
      case 3:
        fame += 10;
        t = '그림 편지를 받았어요. 명성 +10';
        break;
      default:
        money += 1500;
        dayEarn += 1500;
        rp += 100;
        t = '해외 배송 계약 +1,500원 · RP +100';
    }
    hubFx.add((Offset(c.pos.dx * Cfg.tile, c.pos.dy * Cfg.tile - 40), t, 0xFFFFD166, clock));
    showToast('${Cfg.guestName[k]}: $t');
  }

  // ---------------- 숨은 직업 ----------------
  /// 이 직원이 숨은 직업 h(8~10)로 바꿀 자격이 있는지 (두 직업을 Lv5까지 키움, 지금 직업 포함)
  bool hiddenJobOk(Staff s, int h) {
    int lv(int j) => max(s.jobHist[j] ?? 0, s.job == j ? s.jobLv : 0);
    final (a, b) = Cfg.hiddenJobNeed[h - Cfg.baseJobs];
    return lv(a) >= Cfg.jobMaxLv && lv(b) >= Cfg.jobMaxLv;
  }

  /// 0.2초마다: 지금 직원들로 도감 기록 (본 직업·상위 직업·숨은 직업 자격)
  void updateBook() {
    for (final s in staff) {
      rt.seenJobs.add(s.job);
      if (s.promoted) rt.seenPromo.add(s.job);
      for (var h = Cfg.baseJobs; h < Cfg.jobName.length; h++) {
        if (!rt.seenJobs.contains(h) && hiddenJobOk(s, h)) {
          rt.seenJobs.add(h);
          showToast('숨은 직업 발견! ${Cfg.jobName[h]} — ${s.name}이(가) 될 수 있어요 (직업 바꾸기)');
        }
      }
    }
    // 도감 완성 보너스: 100%면 전설 직원 후보 (한 번)
    if (bookPct >= 1.0 && !rt.legendGiven) {
      rt.legendGiven = true;
      final s = Staff(nextStaffId++, '★전설 ${Cfg.surnames[rnd.nextInt(Cfg.surnames.length)]}반장', 5, 5, 5, 5, 5, 5000, 300);
      s.job = 7;
      candidates.insert(0, s);
      showToast('도감 100%! 전설 직원 후보가 고용 목록에 왔어요');
    }
  }

  // ---------------- 도감 ----------------
  int get bookTotal => Cfg.sets.length + Cfg.jobName.length + Cfg.baseJobs + Cfg.guestName.length;
  int get bookFound =>
      rt.foundSets.length + rt.seenJobs.length + rt.seenPromo.length + rt.foundGuests.length;
  double get bookPct => bookFound / bookTotal;

  /// 도감 보너스: 25% 수익 +3%, 50% 연구 속도 +10%
  double get bookPerk => bookPct >= 0.25 ? 1.03 : 1.0;
  double get bookResearch => bookPct >= 0.5 ? 1.1 : 1.0;
}
