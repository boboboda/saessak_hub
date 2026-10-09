import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/mission.dart';
import '../models/vehicle.dart';
import 'region_map.dart';

class Cfg {
  static const double tile = 32; // 한 칸 픽셀 (도트 에셋과 1:1)
  static const int cols = 36; // 월드 가로 칸
  static const int rows = 36; // 월드 세로 칸

  // 창고 영역 (타일 좌표). 오른쪽 벽(wallX)은 고정, 왼쪽·위·아래로 커짐.
  static const double wallX = 22; // 창고 오른쪽 벽 = 도크가 붙는 벽
  static const List<Rect> areas = [
    Rect.fromLTWH(8, 13, 14, 10),
    Rect.fromLTWH(6, 11, 16, 14),
    Rect.fromLTWH(4, 9, 18, 18),
    Rect.fromLTWH(2, 7, 20, 22),
  ];
  static const List<int> areaCost = [0, 5000, 15000, 40000];
  static const List<String> areaName = ['작은 창고', '중형 창고', '대형 창고', '물류센터'];

  // 도크 마당 (창고 오른쪽 벽 바깥)과 도로
  // 도크 마당은 도크 4칸 + 차가 드나드는 2칸만 (빈 마당이 넓지 않게), 그 오른쪽이 도로
  static const Rect yard = Rect.fromLTRB(22, 7, 28, 29);
  static const Rect road = Rect.fromLTRB(28, 0, 31, 36);

  // ---- 구역: 창고 안 접수 | 포장 | 보관·출고, 그리고 벽 밖 도크 ----
  static const double zoneX1 = 14; // 접수 | 포장 경계
  static const double zoneX2 = 18; // 포장 | 보관·출고 경계
  static const List<String> zoneName = [
    '접수 구역',
    '포장 구역',
    '보관·출고 구역',
    '도크 구역',
  ];
  static const List<int> zoneTint = [0x33F0963A, 0x335BA88A, 0x333B82D6, 0x00000000];
  static const List<int> zoneHot = [0x77F0963A, 0x775BA88A, 0x773B82D6, 0x55FFD166];

  // 건물 종류 (zone: 0 접수/1 포장/2 보관·출고/3 도크, -1 창고 어디든 / slots: 근무 직원 자리 수)
  static const List<BuildingType> types = [
    BuildingType('counter', '접수 창구', 3, 2, 1500, 0xFFF0963A, '손님 접수 · 직원 2명까지 · 오른쪽 칸은 상자 적재대', 0, 2),
    BuildingType('pack', '포장대', 2, 2, 2000, 0xFF5BA88A, '택배 포장 · 직원 2명까지', 1, 2),
    BuildingType('shelf', '선반', 2, 3, 1500, 0xFF8B5E3C, '택배 20건 보관', 2, 0),
    BuildingType('vending', '자판기', 1, 1, 4000, 0xFF3B82D6, '인내심 감소 완화', -1, 0),
    BuildingType('lounge', '휴게실', 3, 3, 8000, 0xFFB06AB3, '지친 직원이 와서 쉼 (회복 3배)', -1, 0),
    BuildingType('dock', '도크', 4, 3, 3000, 0xFF3D4466, '벽에 붙여 설치 · 차량이 서는 칸', 3, 0),
  ];

  // ---- 허브 배치 규칙 ----
  // 창고 가운데 줄은 입구(왼쪽 벽) → 도크(오른쪽 벽)로 이어지는 통로. 건물을 못 놓는다.
  static const double aisleH = 2; // 통로 폭(칸)
  // 건물 바로 아래 한 줄은 '앞줄'(손님 줄·직원 서는 자리). 다른 건물이 막을 수 없다.

  // ---- 흐름 수치 ----
  static const double serveTime = 5; // 접수 시간(초, 직원 1명 기준 ×1.0)
  static const double packTime = 5; // 포장 시간(초)
  static const double customerSpeed = 2.2; // 칸/초
  static const double carrierSpeed = 1.3; // 칸/초 (걸음 능력치로 배수)
  static const double patience = 45; // 손님 인내심(초)
  static const int shelfCap = 20; // 선반 1개 용량
  static const int outboxCap = 4; // 접수 창구 대기 택배 한도 (레벨마다 +2, 최대 8)
  // 접수 창구 오른쪽 칸 적재대: 상자를 가로 stackCols 개씩 아래 층부터 쌓는다 (최대 stackLayers 층)
  static const int stackCols = 2;
  static const int stackLayers = 4;
  static const double stackStep = 9; // 한 층 높이(px, 작은 상자 앞면)
  static const double stackAnim = 6; // 상자가 올라가고 내려가는 연출 속도(개/초)
  static const int parcelPay = 100; // 배송 완료 택배 1건 기본 수익
  static const double fullBonus = 1.2; // 차량을 가득 채워 보내면 수익 배수
  static const double vehicleMove = 1.5; // 차량이 들어오고 나가는 시간(초)
  static const double vehicleWait = 5; // 더 실을 게 없을 때 기다리는 시간(초)
  static const int hubTruckMin = 3; // 한 지역 택배가 이만큼 쌓이면 허브 도크에 대형 트럭이 옴
  // 차량 종류 (허브 도크는 [0] 대형 트럭만 사용, 나머지는 지역→동네 배송용으로 예정)
  static const List<VehicleType> vehicles = [
    VehicleType('대형 트럭', 40, 30, 3.0, 1.5, 1.0, 0.85),
    VehicleType('소형 트럭', 16, 12, 2.0, 1.2, 0.7, 0.65),
    VehicleType('오토바이', 6, 4, 1.0, 1.0, 0.35, 0.4),
  ];

  // ---- 체력·휴식·실수 ----
  static const double drainPerSec = 1.5; // 일하는 동안 초당 체력 소모
  static const double idleRestPerSec = 0.3; // 자리에서 손이 비었을 때 초당 회복 (서서 쉬기)
  static const double restPerSec = 1.5; // 대기 중이거나 휴식 자리에서 쉴 때 초당 회복
  static const int loungeMax = 2; // 효과가 겹치는 휴게실 최대 개수
  static const double loungeDrain = 0.2; // 휴게실 1개당 소모 감소 (2개까지)
  static const double loungeRestMul = 3.0; // 휴게실 안에서 쉴 때 회복 배수
  static const double restBelow = 0.15; // 이 비율 이하가 되면 쉬러 감
  static const double restUntil = 0.85; // 이 비율까지 차면 돌아옴
  // 휴게실(3×3) 안 앉는 자리 (건물 왼쪽 위 기준, 칸 단위)
  static const List<Offset> loungeSeats = [
    Offset(0.8, 0.8),
    Offset(2.2, 0.8),
    Offset(0.8, 2.2),
    Offset(2.2, 2.2),
  ];
  static const double overnightRest = 0.5; // 하루가 지나면 최대 체력의 이만큼 회복
  static const double slipBase = 0.30; // 포장 실수 기본 확률
  static const double slipPerCare = 0.05; // 꼼꼼 1당 감소
  static const double slipTired = 0.10; // 지쳤을 때 추가 확률

  // ---- 달력·직원 ----
  static const double dayLength = 300; // 하루(초). 하루가 끝나면 월급 정산
  static const int candidateCount = 4; // 고용 후보 수
  static const double candidateRefreshSec = 120; // 후보 자동 갱신 주기
  static const int refreshCost = 300; // 후보 수동 갱신 비용
  static const List<String> surnames = [
    '김', '이', '박', '최', '정', '강', '조', '윤', '장', '임',
  ];
  static const List<String> givens = [
    '민준', '서연', '도윤', '하은', '지호', '수빈', '예준', '지우', '현우', '서윤', '태양', '나래',
  ];

  // 지역 색 (택배 색)
  static const List<int> regionColor = [
    0xFFF2C94C,
    0xFF56CCF2,
    0xFF6FCF97,
    0xFFEB5757,
    0xFFBB6BD9,
  ];

  static const List<int> speeds = [1, 3, 10];

  // ---- 특수 택배 ----
  static const List<String> kindName = ['', '급송', '파손', '대형'];
  static const double urgentLimit = 90; // 급송: 접수 후 이 시간(게임 초) 안에 선반에 넣어야 보너스
  static const int urgentBonus = 300;
  static const int fragileBonus = 60; // 파손주의: 실수 없이 포장하면 보너스
  static const int breakPenalty = 120; // 파손주의: 포장 실수하면 배상
  static const int bulkyBonus = 150; // 대형: 선반까지 옮기면 보너스
  static const double bulkySlow = 0.6; // 대형을 들면 걸음이 느려짐
  static const int vipTip = 200;
  static const double vipPatience = 0.55; // VIP 인내심 배수

  // ---- 배송 지역: 같은 급의 서로 다른 지역 (이름·분위기만 다름). 명성으로 열고, 뒤에 열수록 지도가 크다 ----
  // 지역 수를 바꾸려면 아래 목록들과 regionColor·regionFame 의 길이를 같이 맞춘다.
  static const List<String> regionName = ['주택가', '상가', '항구', '산업단지', '신도시'];
  static const List<String> regionStyle = ['residential', 'commercial', 'harbor', 'industrial', 'newtown'];
  static const List<double> regionPay = [1.0, 1.0, 1.0, 1.0, 1.0]; // 같은 급이라 수익 배수 같음
  // 지도 규격 (칸). 첫 지역 대비 마지막 지역 면적 약 3.4배
  static const List<(int, int)> regionSize = [(28, 22), (34, 26), (42, 32), (47, 36), (52, 40)];
  static const List<int> regionTowns = [3, 6, 10, 13, 16]; // 집이 들어서는 동네 블록 수
  static const List<(int, int)> regionGrid = [(10, 7), (11, 7), (11, 7), (10, 7), (10, 8)]; // 큰길 간격
  static const List<double> regionRoadCut = [0.10, 0.0, 0.15, 0.12, 0.0]; // 큰길을 빼는 확률 (모양 차이)
  static const List<int> regionSea = [0, 0, 5, 0, 0]; // 위쪽 바다 폭 (항구)
  static const List<int> regionTrunkTarget = [24, 40, 56, 72, 96]; // 간선 목표 길이(칸)
  static const List<int> regionSeed = [11, 23, 37, 41, 53]; // 지도 모양 고정용
  static const double trunkSecPerTile = 0.6; // 간선 1칸 달리는 시간(초)
  static const double courierSecPerTile = 0.45; // 배달 길 1칸 달리는 시간(초)

  static const List<int> regionFame = [0, 60, 250, 800, 2000]; // 지역을 여는 데 필요한 명성

  // ---- 차량(플릿) ----
  static const List<int> unitCost = [12000, 8000, 3000]; // Cfg.vehicles 순서
  static const List<String> skillName = ['', '초보', '보통', '숙련', '베테랑', '달인'];
  static const List<String> driverFirst = ['김', '이', '박', '최', '정', '강', '조', '윤', '한', '오'];
  static const List<String> driverLast = ['기사', '대리', '반장', '씨', '팀장', '사원'];
  static const int maxLevel = 5;
  static int upgradeCost(int type, int level) =>
      ((unitCost[type] * 0.6) * level * (1 + level * 0.4)).round();
  static int trainCost(int skill) => 1200 * skill * skill;
  // 이벤트: 이름, 실패 시 지연(초)
  static const List<String> evtName = ['교통 정체', '폭우', '타이어 펑크', '분실 위험'];
  static const List<double> evtDelay = [6, 5, 8, 2];
  /// 이벤트 확률: 간선이 길수록 조금 높음
  static double evtChance(bool trunk, int region) =>
      trunk ? 0.2 + RegionMap.of(region).trunkLen / 400 : 0.2;
  static double evtSuccess(int skill) => 0.3 + 0.12 * skill;

  static const List<double> waitOptions = [5, 15, 30];

  // ---- 접수량: 오직 ① 명성 구간 ② 달력 성수기 배수로만 늘어난다 ----
  // 시뮬레이션(tools/sim/econ_sim.py) 기준: 시작 구성(창구1·포장1·운반1·트럭1)은 분당 2건까지 여유,
  // 직원·선반·트럭을 늘린 구성은 분당 8건 안팎까지. 그 위로는 지각·놓침이 생겨 투자가 필요하다.
  static const List<int> intakeFame = [0, 25, 60, 120, 200, 320, 480, 700, 1000, 1400, 2000, 2800];
  static const List<double> intakePerMin = [1.0, 1.4, 1.8, 2.4, 3.0, 3.8, 4.6, 5.6, 6.8, 8.2, 10, 12];
  static const double intakeJitter = 0.4; // 손님 도착 간격 ±40%

  /// 명성 구간 번호 (0부터)
  static int intakeTier(int fame) {
    var t = 0;
    for (var i = 0; i < intakeFame.length; i++) {
      if (fame >= intakeFame[i]) t = i;
    }
    return t;
  }

  static double intakeBase(int fame) => intakePerMin[intakeTier(fame)];

  // ---- 게임 달력: 1년 = 28일. 성수기(피버)에는 그날 하루 접수량 배수 ----
  static const int yearDays = 28;
  // (이름, 시작일(연중 1~28), 일수, 접수 배수)
  static const List<(String, int, int, double)> holidays = [
    ('설 연휴', 5, 2, 1.8),
    ('가정의 달', 10, 1, 1.4),
    ('추석', 16, 2, 2.0),
    ('블랙프라이데이', 22, 1, 2.5),
    ('연말 성수기', 26, 3, 1.6),
  ];

  // ---- 배송 기한: 접수부터 배달 완료까지. 지역이 멀수록(운행 시간이 길수록) 길다 ----
  static const double deadlineBase = 240; // 게임 초
  static const double deadlinePerTrip = 2.5; // 노선 왕복 시간 1초당 추가
  static double deadline(int region) {
    final m = RegionMap.of(region);
    return deadlineBase + deadlinePerTrip * (m.tripSec + m.avgDeliverSec);
  }
  static const int onTimeFame = 1; // 정시 1건당 명성
  static const int lateFame = 1; // 지각 1건당 명성 감소
  static const double latePay = 0.5; // 지각이면 수익 배수
  static const double streakStep = 0.004; // 연속 정시 1건당 수익 +0.4%
  static const int streakCap = 50; // 수익 보너스는 50연속(+20%)까지
  static const int streakEvery = 25; // 25연속마다 명성 보너스
  static const int streakFame = 5;

  // ---- 수익 부스트 (광고): 접수량은 늘리지 않고 수익만 오름 ----
  static const double feverLen = 60;
  static const double feverPay = 1.5; // 수익 배수
  static const double adCooldown = 300; // 광고 재사용 대기(초)

  // ---- 목표 ----
  static const List<Mission> missions = [
    Mission('건물을 3개 설치하세요', 1, 3, 1000),
    Mission('택배 20건 배송', 0, 20, 1500),
    Mission('직원 4명 모으기', 2, 4, 1500),
    Mission('택배 100건 배송', 0, 100, 4000),
    Mission('3일차 도달', 3, 3, 2000),
    Mission('배송 지역 2곳 열기', 4, 2, 3000),
    Mission('중형 창고로 확장', 5, 1, 5000),
    Mission('택배 500건 배송', 0, 500, 12000),
    Mission('배송 지역 4곳 열기', 4, 4, 15000),
    Mission('대형 창고로 확장', 5, 2, 20000),
    Mission('택배 2,000건 배송', 0, 2000, 50000),
    Mission('모든 배송 지역 열기', 4, 5, 60000),
    Mission('직원 레벨 3 달성', 6, 3, 3000),
    Mission('건물 업그레이드 3번', 7, 3, 5000),
    Mission('급송 택배 5건 성공', 8, 5, 4000),
    Mission('직원 레벨 6 달성', 6, 6, 30000),
    Mission('급송 택배 30건 성공', 8, 30, 25000),
  ];

  // ---- 편의 시설 ----
  static const double vendingCalm = 0.15; // 자판기 1대당 손님 짜증 속도 감소 (2대까지)
  static const int vendingMax = 2;

  // ---- 저장 ----
  static const double autosaveSec = 10;

  // ---- 직접 개입 ----
  static const int tapBonus = 10; // 내 자리에서 손님을 직접 탭해 접수하면 받는 보너스(원)
  static const double alertAngry = 0.3; // 인내심이 이 비율 아래면 '화난 손님'
  static const double alertTired = 0.25; // 체력이 이 비율 아래면 '지친 직원' (자동 휴식은 0.15)
  static const double sootheTo = 0.7; // 달래면 인내심이 이 비율까지 회복
  static const double sootheCooldown = 20; // 달래기 재사용 대기(게임 초)
  static const int snackCost = 200; // 간식 비용(원)
  static const double snackRestore = 0.4; // 간식으로 회복하는 체력 비율
}