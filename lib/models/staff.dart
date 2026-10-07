import 'dart:ui';

import 'building.dart';

/// 직원 한 명 (이름·능력치·체력 상태가 있는 캐릭터)
class Staff {
  final int id;
  final String name;
  final int speed; // 손속도 1~5: 접수·포장 속도
  final int walk; // 걸음 1~5: 운반 속도
  final int kind; // 친절 1~5: 손님이 짜증 내는 속도 감소
  final int stamina; // 체력 1~5: 오래 일할 수 있는 정도
  final int care; // 꼼꼼 1~5: 포장 실수 확률 감소
  final int hireCost; // 고용비
  int wage; // 일급(하루 월급). 레벨이 오르면 올라감

  Building? post; // 배치된 건물 (접수 창구·포장대)
  bool carrier = false; // 운반 담당

  // ---- 성장 ----
  static const int maxLevel = 6;
  static const List<String> specNames = ['', '접수 베테랑', '포장 장인', '쾌속 운반'];
  int level = 1;
  double xp = 0; // 일한 시간(게임 초)이 쌓임
  int spec = 0; // 특기: 1 접수 베테랑, 2 포장 장인, 3 쾌속 운반
  double get xpNeed => 120.0 * level;
  String get specName => specNames[spec];

  double energy; // 현재 체력 (일하면 줄고, 쉬면 참)
  bool working = false; // 이번 프레임에 일했는지 (체력 계산용)
  int mistakes = 0; // 포장 실수 누적

  // ---- 휴식 ----
  int rest = 0; // 0 근무, 1 쉬러 가는 중, 2 쉬는 중, 3 돌아오는 중
  Offset pos = Offset.zero; // 자리를 비웠을 때 위치 (타일 좌표)
  Building? lounge; // 쉬고 있는 휴게실 (null이면 창고 밖 휴식 자리)
  int seat = 0; // 휴게실 안 자리 번호

  Staff(this.id, this.name, this.speed, this.walk, this.kind, this.stamina,
      this.care, this.hireCost, this.wage)
      : energy = 60.0 + 20.0 * stamina;

  bool get idle => post == null && !carrier;

  /// 자리를 비운 상태 (쉬러 가는 중·쉬는 중·돌아오는 중)
  bool get away => rest != 0;

  /// 체력 최대치 (체력 1 → 80, 3 → 120, 5 → 160)
  double get maxEnergy => (60.0 + 20.0 * stamina) * (1 + 0.04 * (level - 1));

  /// 체력 비율 0~1
  double get energyPct => (energy / maxEnergy).clamp(0.0, 1.0);

  /// 지쳤는지 (30% 미만)
  bool get tired => energyPct < 0.3;

  /// 피로 배수: 30% 이상이면 1.0, 0이면 0.5까지 떨어짐
  double get fatigueMul =>
      energyPct >= 0.3 ? 1.0 : 0.5 + 0.5 * (energyPct / 0.3);

  /// 일하는 속도 배수 (손속도 1 → 0.8, 3 → 1.2, 5 → 1.6) × 피로
  double get workRate =>
      (0.6 + 0.2 * speed) * fatigueMul * (1 + 0.06 * (level - 1));

  /// 걷는 속도 배수 (걸음 1 → 0.85, 3 → 1.15, 5 → 1.45) × 피로
  double get walkMul =>
      (0.7 + 0.15 * walk) *
      fatigueMul *
      (1 + 0.06 * (level - 1)) *
      (spec == 3 ? 1.25 : 1.0);

  String get initial => name.isEmpty ? '?' : name.substring(0, 1);
}