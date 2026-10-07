import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

extension DockSystem on HubGame {
  /// 선반 전체에 쌓인 지역별 택배 수
  int regionStock(int r) =>
      ofType('shelf').fold<int>(0, (a, b) => a + b.regions[r]);

  /// 지역 r 택배 1건을 가장 많이 쌓인 선반에서 꺼냄
  bool _takeFromShelf(int r) {
    Building? best;
    for (final b in ofType('shelf')) {
      if (b.regions[r] > 0 && (best == null || b.regions[r] > best.regions[r])) {
        best = b;
      }
    }
    if (best == null) return false;
    best.regions[r]--;
    best.stored = max(0, best.stored - 1);
    return true;
  }

  /// 쌓인 양에 맞는 차량을 고름 (없으면 null)
  Vehicle? _callVehicle() {
    var region = -1;
    var most = 0;
    for (var r = 0; r < Cfg.regionColor.length; r++) {
      final n = regionStock(r);
      if (n > most) {
        most = n;
        region = r;
      }
    }
    if (region < 0) return null;
    for (final t in Cfg.vehicles) {
      if (most >= t.minStock) return Vehicle(t, region);
    }
    return null;
  }

  void updateDocks(double dt) {
    for (final dock in ofType('dock')) {
      final v = dock.vehicle;
      if (v == null) {
        dock.vehicle = _callVehicle();
        continue;
      }
      v.t += dt;
      switch (v.state) {
        case 0:
          if (v.t >= Cfg.vehicleMove) {
            v.state = 1;
            v.t = 0;
          }
          break;
        case 1:
          v.acc += dt * v.type.loadPerSec;
          while (v.acc >= 1 && v.loaded < v.type.cap) {
            v.acc -= 1;
            if (_takeFromShelf(v.region)) {
              v.loaded++;
              v.idle = 0;
            } else {
              v.acc = 0;
              break;
            }
          }
          final noStock = regionStock(v.region) == 0;
          if (noStock) v.idle += dt;
          if (v.loaded >= v.type.cap ||
              (noStock && v.idle >= Cfg.vehicleWait)) {
            v.state = 2;
            v.t = 0;
            final full = v.loaded >= v.type.cap;
            final pay = (v.loaded *
                    Cfg.parcelPay *
                    v.type.payMul *
                    (full ? Cfg.fullBonus : 1.0))
                .round();
            if (v.loaded > 0) {
              money += pay;
              delivered += v.loaded;
              showToast('${v.type.name} 출발! 택배 ${v.loaded}건 +${fmt(pay)}원');
            }
          }
          break;
        default:
          if (v.t >= Cfg.vehicleMove) dock.vehicle = null;
      }
    }
  }
}
