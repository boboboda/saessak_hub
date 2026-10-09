import 'dart:math';

import '../game/ad_service.dart';
import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

extension OpsSystem on HubGame {
  // ---- 수익 부스트 (광고). 접수량은 명성·성수기로만 정해지므로 손님 수는 그대로 ----
  void updateFever(double d) {
    if (adCd > 0) adCd = max(0.0, adCd - d);
    if (fever > 0) {
      fever -= d;
      if (fever <= 0) {
        fever = 0;
        showToast('수익 부스트 끝!');
      }
    }
  }

  void startFever() {
    fever = Cfg.feverLen;
    showToast('수익 부스트! ${Cfg.feverLen.round()}초 동안 수익 ×${Cfg.feverPay}');
  }

  /// 광고를 보고 수익 부스트를 켠다
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
    showToast('${Cfg.regionName[i]} 배송 시작! 노선 지도에서 새 지역을 볼 수 있어요');
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
      case 9:
        return rt.grades[0];
      case 10:
        return rt.bestClean;
      case 11:
        return rt.fiveStars;
      case 12:
        return rt.yearsAll;
      case 13:
        return rt.promotions;
      case 14:
        return rt.foundSets.length;
      case 15:
        return done;
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
    final m = Cfg.missions[i];
    money += m.reward;
    tickets += m.ticket;
    final extra = [
      if (m.ticket > 0) '전직서 +${m.ticket}',
      if (m.perk > 0) '수익 +${m.perk}% 영구',
    ];
    showToast('업적 달성! +${fmt(m.reward)}원${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}');
    ui();
  }
}
