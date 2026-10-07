/// 배송 노선 설정 (지역마다 하나)
class DeliveryRoute {
  bool on = true; // 운행 여부 (끄면 그 지역 택배는 쌓이기만 함)
  int vehicle = -1; // -1 자동, 그 외 Cfg.vehicles 번호로 고정
  double wait = 5; // 더 실을 게 없을 때 기다리는 시간(초). 길수록 꽉 채워 보내기 쉬움
  int prio = 1; // 우선순위 1~3 (여러 노선이 동시에 준비되면 높은 쪽이 먼저)
}

/// 출발해서 달리는 중인 차량 (지도 표시용)
class Trip {
  final int region;
  final int count;
  final double dur;
  double t = 0;
  Trip(this.region, this.count, this.dur);
}
