import 'fleet.dart';

/// 차량 종류 (택배가 쌓인 양에 맞춰 알아서 온다)
class VehicleType {
  final String name;
  final int cap; // 한 번에 싣는 최대 택배 수
  final int minStock; // 한 지역 택배가 이만큼 쌓이면 이 차량이 옴
  final double loadPerSec; // 초당 싣는 수
  final double payMul; // 택배당 수익 배수
  final double len; // 도크 칸 안에서 차지하는 길이 비율
  final double wid; // 도크 칸 안에서 차지하는 폭 비율
  const VehicleType(this.name, this.cap, this.minStock, this.loadPerSec,
      this.payMul, this.len, this.wid);
}

/// 도크에 서 있는 차량 한 대
class Vehicle {
  final VehicleType type;
  final FleetUnit? unit; // 이 도크 차량이 되는 내 대형 트럭
  final int cap; // 이 트럭의 적재 한도 (레벨 반영)
  final int region; // 이 차량이 가는 지역(택배 색)
  int state = 0; // 0 들어오는 중, 1 싣는 중, 2 떠나는 중
  double t = 0; // 현재 상태 경과 시간(초)
  double acc = 0; // 싣기 진행 누적
  double idle = 0; // 더 실을 게 없어 기다린 시간
  int loaded = 0;
  final List<double> borns = []; // 실린 택배의 접수 시각 (배송 기한 계산용)
  int incoming = 0; // 운반 직원이 싣고 오는 중인 수 (예약)
  final double wait; // 더 실을 게 없을 때 기다리는 시간(노선 설정)
  Vehicle(this.type, this.region, this.cap, [this.wait = 5, this.unit]);
}
