/// 택배 한 건
class Parcel {
  final int region; // 지역(색)
  int stage = 0; // 0 접수창구 대기, 2 포장 중, 3 포장 완료
  bool reserved = false; // 운반 직원이 예약함
  int kind = 0; // 0 일반, 1 급송, 2 파손주의, 3 대형
  double born = 0; // 접수된 시각(게임 초)
  Parcel(this.region);
}