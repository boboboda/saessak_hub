import '../game/config.dart';

/// 내 차량 한 대 (간선 대형 트럭 / 지역 배달 소형 트럭·오토바이)
class FleetUnit {
  final int id;
  final int type; // Cfg.vehicles 번호 (0 대형 트럭, 1 소형 트럭, 2 오토바이)
  String driver;
  int skill; // 기사 능력 1~5 (이벤트 대응 성공률)
  int level = 1; // 차량 레벨 (속도·적재량)
  int region; // 배정된 지역(노선)

  // 운행 상태: 0 대기, 1 가는 중, 2 돌아오는 중, 3 허브 도크에서 싣는 중
  int state = 0;
  double t = 0; // 현재 구간 경과(차량 속도 반영)
  double dur = 0; // 현재 구간 길이
  int cargo = 0; // 싣고 있는 택배
  bool full = false; // 가득 싣고 출발했는지 (수익 보너스)
  int house = 0; // 이번에 배달 가는 집 번호 (지도 표시용)

  // 이벤트
  bool willEvt = false; // 이번 운행에 이벤트가 생길지
  bool evtDone = false;
  double evtAt = 0.5; // 구간 몇 % 지점에서 생길지
  double delay = 0; // 이벤트로 늘어난 시간
  int evtKind = 0; // 0 정체, 1 폭우, 2 펑크, 3 분실
  String? evtText; // 지도에 띄우는 말풍선
  bool evtOk = true;
  double evtT = 0; // 말풍선 남은 시간

  FleetUnit(this.id, this.type, this.driver, this.skill, this.region);

  bool get isTrunk => type == 0;
  String get name => Cfg.vehicles[type].name;
  int get cap => (Cfg.vehicles[type].cap * (1 + 0.15 * (level - 1))).round();
  double get speed => 1 + 0.12 * (level - 1);
  bool get busy => state != 0;
}

/// 지도 위에 잠깐 뜨는 소식 (이벤트 결과, 배달 완료 등)
class MapNote {
  final String text;
  final int color;
  double t = 6;
  MapNote(this.text, this.color);
}

/// 지도 위에 떠오르는 효과 글자 (배달 완료 금액, 센터 도착 등)
class MapFx {
  final int region;
  final bool atCenter; // true 센터 위, false 동네 집 위
  final int house;
  final String text;
  final int color;
  double t = 0;
  MapFx(this.region, this.atCenter, this.house, this.text, this.color);
}
