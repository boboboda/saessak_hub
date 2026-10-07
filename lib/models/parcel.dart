/// 택배 한 건
class Parcel {
  final int region; // 지역(색)
  int stage = 0; // 0 접수창구 대기, 2 포장 중, 3 포장 완료
  bool reserved = false; // 운반 직원이 예약함
  Parcel(this.region);
}