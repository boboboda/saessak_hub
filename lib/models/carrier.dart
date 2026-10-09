import 'package:flutter/material.dart';

import 'building.dart';
import 'parcel.dart';
import 'staff.dart';
import 'vehicle.dart';

/// 운반 담당 직원의 몸 (맵에서 걸어 다니는 쪽)
class Carrier {
  final Staff staff;
  Offset pos;
  Parcel? job; // 맡은 택배
  Building? src; // 가지러 갈 곳
  Building? dst; // 갖다 놓을 곳
  bool carrying = false; // 이미 집었는지
  Vehicle? veh; // 도크 적재 일일 때 싣는 차량
  List<Offset> path = []; // 걸어갈 길 (칸 가운데들 + 목적지)
  Offset? pathGoal; // path 를 찾은 목적지
  int pathSig = -1; // path 를 찾을 때의 배치
  Carrier(this.staff, this.pos);
  bool get idle => job == null;
}