import 'package:flutter/material.dart';

import '../game/config.dart';
import 'parcel.dart';
import 'staff.dart';
import 'vehicle.dart';

/// 건설 가능한 건물 종류
class BuildingType {
  final String id;
  final String name;
  final int w; // 칸 수
  final int h;
  final int cost;
  final int color;
  final String desc;
  final int zone; // 0 접수, 1 포장, 2 보관·출고, 3 도크(벽 밖), -1 창고 어디든
  final int slots; // 근무 직원 자리 수 (0이면 직원 없음)
  const BuildingType(this.id, this.name, this.w, this.h, this.cost, this.color,
      this.desc, this.zone, this.slots);
}

/// 설치된 건물 (타일 좌표)
class Building {
  final BuildingType type;
  int tx;
  int ty;
  Building(this.type, this.tx, this.ty);

  // ---- 런타임 상태 ----
  final List<Parcel> outbox = []; // 접수 창구: 포장 대기 택배
  Parcel? slot; // 포장대: 올려진 택배
  double progress = 0; // 포장대: 포장 진행(초)
  bool reservedIn = false; // 포장대: 운반 예약됨
  int stored = 0; // 선반: 보관 수
  int incoming = 0; // 선반: 운반 중 예약 수
  final List<int> regions = List<int>.filled(5, 0); // 선반: 지역별 보관 수
  Vehicle? vehicle; // 도크: 서 있는 차량
  final List<Staff> crew = []; // 배치된 직원 (쉬러 간 직원 포함)
  double flash = 0; // 포장 실수 표시 남은 시간(초)
  bool mine = false; // 접수 창구: 내가 직접 앉는 자리 (손님을 탭해서 접수)

  // ---- 업그레이드 ----
  int level = 1;
  static const int maxLevel = 3;
  bool get upgradable =>
      const ['counter', 'pack', 'shelf', 'dock'].contains(type.id) &&
      level < maxLevel;
  int get upgradeCost => (type.cost * (level == 1 ? 1.5 : 3)).round();

  /// 접수·포장 속도 배수
  double get speedMul =>
      (type.id == 'counter' || type.id == 'pack') ? 1 + 0.25 * (level - 1) : 1.0;

  /// 선반 용량
  int get cap => Cfg.shelfCap + 10 * (level - 1);

  /// 접수 창구 대기 택배 한도
  int get outCap => Cfg.outboxCap + 2 * (level - 1);

  /// 도크 싣는 속도 배수
  double get loadMul => type.id == 'dock' ? 1 + 0.5 * (level - 1) : 1.0;

  /// 지금 실제로 자리에 있는 직원 (쉬러 간 직원은 빠짐)
  List<Staff> get active => crew.where((s) => !s.away).toList();

  Rect get rect => Rect.fromLTWH(
      tx.toDouble(), ty.toDouble(), type.w.toDouble(), type.h.toDouble());
}