import 'dart:math';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';

extension DockSystem on HubGame {
  /// 선반 전체에 쌓인 지역별 택배 수
  int regionStock(int r) =>
      ofType('shelf').fold<int>(0, (a, b) => a + b.regions[r]);

  /// 지역 r 택배 중 아직 운반 예약이 안 된 수
  int _availStock(int r) =>
      ofType('shelf').fold<int>(0, (a, b) => a + max(0, b.regions[r] - b.pickRes[r]));

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

  /// 노선 설정에 맞는 차량을 고름 (없으면 null)
  Vehicle? _callVehicle() {
    var region = -1;
    var bestPrio = 0;
    var most = 0;
    VehicleType? type;
    FleetUnit? unit;
    for (var r = 0; r < Cfg.regionColor.length; r++) {
      if (!regionOpen[r]) continue;
      final rt = routes[r];
      if (!rt.on) continue;
      final n = _availStock(r); // 이미 운반 예약된 택배는 빼고 센다
      if (n <= 0) continue;
      // 허브 도크에는 간선 대형 트럭만 온다 (동네 배송 차량은 지역센터 단계)
      // 선반이 거의 찼으면 적은 양이라도 트럭을 불러 비운다 (허브가 막히지 않게)
      final shelfCap = ofType('shelf').fold<int>(0, (a, b) => a + b.cap);
      final crowded = shelfCap > 0 && totalStored >= shelfCap * 0.8;
      if (n < (crowded ? 1 : Cfg.hubTruckMin)) continue;
      final u = freeTrunk(r);
      if (u == null) continue; // 이 노선에 배정된 놀고 있는 대형 트럭이 없음
      final VehicleType t = Cfg.vehicles[0];
      if (rt.prio > bestPrio || (rt.prio == bestPrio && n > most)) {
        bestPrio = rt.prio;
        most = n;
        region = r;
        type = t;
        unit = u;
      }
    }
    if (region < 0 || type == null) return null;
    unit!.state = 3; // 허브 도크에서 싣는 중
    return Vehicle(type, region, unit.cap, routes[region].wait, unit);
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
          // 싣기는 운반 직원이 선반에서 가져와 채움 (worker_system 의 적재 일)
          final noStock = _availStock(v.region) == 0 && v.incoming == 0;
          if (v.incoming > 0) v.idle = 0;
          if (noStock) v.idle += dt;
          if (v.loaded >= v.cap ||
              (noStock && v.idle >= v.wait)) {
            v.state = 2;
            v.t = 0;
            final u = v.unit;
            if (u != null) {
              if (v.loaded > 0) {
                u.cargo = v.loaded;
                u.load
                  ..clear()
                  ..addAll(v.borns);
                u.full = v.loaded >= v.cap;
                this.startTrunkTrip(u);
                showToast('${Cfg.regionName[v.region]}행 ${u.driver} 출발! 택배 ${v.loaded}건');
              } else {
                u.state = 0; // 실을 게 없어 허브로 돌아감
              }
            }
          }
          break;
        default:
          if (v.t >= Cfg.vehicleMove) dock.vehicle = null;
      }
    }
  }
}
