import 'dart:math';

import '../game/ad_service.dart';
import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

extension OpsSystem on HubGame {
  // ---- 피버 타임 ----
  void updateFever(double d) {
    if (adCd > 0) adCd = max(0.0, adCd - d);
    if (fever > 0) {
      fever -= d;
      if (fever <= 0) {
        fever = 0;
        showToast('피버 타임 끝!');
      }
      return;
    }
    // 가게가 돌아가기 시작한 뒤에만 시계가 간다
    if (ofType('counter').isEmpty) return;
    feverCd -= d;
    if (feverCd <= 0) startFever();
  }

  void startFever() {
    fever = Cfg.feverLen;
    feverCd = Cfg.feverMin + rnd.nextDouble() * (Cfg.feverMax - Cfg.feverMin);
    showToast('피버 타임! 손님이 몰리고 수익이 ×${Cfg.feverPay}');
  }

  /// 광고를 보고 피버를 바로 켠다
  Future<void> adFever() async {
    if (adCd > 0 || fever > 0) return;
    final ok = await AdService.showRewarded();
    if (!ok) {
      showToast('광고를 끝까지 봐야 보상을 받아요');
      return;
    }
    adCd = Cfg.adCooldown;
    startFever();
  }

  // ---- 배송 지역 ----
  bool canUnlockRegion(int i) =>
      i > 0 && !regionOpen[i] && regionOpen[i - 1] && fame >= Cfg.regionFame[i];

  void unlockRegion(int i) {
    if (i <= 0 || regionOpen[i]) return;
    if (!regionOpen[i - 1]) {
      showToast('앞 지역을 먼저 열어야 해요');
      return;
    }
    if (fame < Cfg.regionFame[i]) {
      showToast('명성이 부족해요 (${Cfg.regionFame[i]} 필요)');
      return;
    }
    regionOpen[i] = true;
    grantStarterUnits(i);
    showToast('${Cfg.regionName[i]} 배송 시작! (수익 ×${Cfg.regionPay[i]})');
    ui();
  }

  int get openRegions => regionOpen.where((e) => e).length;

  // ---- 목표 ----
  int missionProgress(Mission m) {
    switch (m.kind) {
      case 0:
        return delivered;
      case 1:
        return buildings.length;
      case 2:
        return staff.length;
      case 3:
        return day;
      case 4:
        return openRegions;
      case 6:
        return staff.fold<int>(0, (a, s) => s.level > a ? s.level : a);
      case 7:
        return upgrades;
      case 8:
        return urgentOk;
      default:
        return areaLevel;
    }
  }

  bool missionDone(int i) =>
      missionProgress(Cfg.missions[i]) >= Cfg.missions[i].target;

  int get claimableCount {
    var n = 0;
    for (var i = 0; i < Cfg.missions.length; i++) {
      if (!claimed.contains(i) && missionDone(i)) n++;
    }
    return n;
  }

  void claimMission(int i) {
    if (claimed.contains(i) || !missionDone(i)) return;
    claimed.add(i);
    money += Cfg.missions[i].reward;
    showToast('목표 달성! +${fmt(Cfg.missions[i].reward)}원');
    ui();
  }
}
