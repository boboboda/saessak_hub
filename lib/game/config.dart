import 'dart:math';
import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/mission.dart';
import '../models/vehicle.dart';
import '../systems/research_system.dart';
import '../systems/set_system.dart';
import '../systems/story_system.dart';
import 'region_map.dart';

class Cfg {
  static const double tile = 32; // 한 칸 픽셀 (도트 에셋과 1:1)
  static const int cols = 36; // 월드 가로 칸
  static const int rows = 36; // 월드 세로 칸

  // ---- 허브 화면 확대 ----
  static const double zoomFitTiles = 10; // 기본 확대: 화면 가로에 이만큼 칸이 보이게
  static const double zoomMin = 0.6; // 가장 멀리 (월드보다 넓게 보이면 그만큼 더 제한)
  static const double zoomMax = 2.4; // 가장 가까이

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
    BuildingType('shelf', '선반', 2, 2, 1500, 0xFF8B5E3C, '택배 20건 보관', 2, 0),
    BuildingType('vending', '자판기', 1, 1, 4000, 0xFF3B82D6, '인내심 감소 완화', -1, 0),
    BuildingType('lounge', '휴게실', 3, 3, 8000, 0xFFB06AB3, '지친 직원이 와서 쉼 (회복 3배)', -1, 0),
        BuildingType('dock', '도크', 4, 3, 3000, 0xFF3D4466, '벽에 붙여 설치 · 차량이 서는 칸', 3, 0),
    // ---- 세트 소품 (맞닿게 놓으면 세트, 화분·에어컨은 반경 효과도) ----
    BuildingType('bin', '자재함', 1, 1, 600, 0xFFC8955E, '포장 자재. 포장대·선반 세트 재료', -1, 0),
    BuildingType('chair', '대기 의자', 1, 1, 400, 0xFF3B82D6, '손님 대기 의자. 접수 창구 세트 재료', -1, 0),
    BuildingType('plant', '화분', 1, 1, 300, 0xFF3FA34D, '반경 2칸 직원 체력 소모 −5% (3개까지)', -1, 0),
    BuildingType('board', '게시판', 1, 1, 500, 0xFFB98A5E, '공지 게시판. 접수 창구 세트 재료', -1, 0),
    BuildingType('aircon', '에어컨', 1, 1, 2500, 0xFFDDE6EE, '반경 3칸 체력 소모 −10% (여름 2배)', -1, 0),
        BuildingType('conveyor', '컨베이어', 2, 1, 1500, 0xFF7A8FA6, '선반·포장대·도크를 잇는 세트 재료 (연구 필요)', -1, 0),
    // ---- 연구·훈련 시설 ----
    BuildingType('lab', '연구실', 3, 3, 10000, 0xFF6C8EBF, '하루 +30 RP (연구 포인트)', -1, 0),
    BuildingType('classroom', '교육실', 3, 3, 6000, 0xFFB98AC8, '직원을 하루 훈련해 능력치 +1 (2명까지)', -1, 0),
  ];

  // ---- 허브 배치 규칙 ----
  // 창고 가운데 줄 양쪽 벽에 문(왼쪽 손님 입구, 오른쪽 도크 마당으로 나가는 문). 문 바로 안쪽 칸은 비워 둔다.
  static const double doorH = 2; // 문 폭(칸)

  // ---- 직원 통로 (유저가 직접 깜) ----
  // 통로 위에서는 빠르게, 밖에서는 느리게 걷는다. 직원 길찾기는 걸리는 시간이 가장 짧은 길(= 통로 우선)을 고른다.
  static const double aisleFast = 1.5; // 통로 위 걸음 배수
  // 통로 밖 걸음 배수. 0.7이면 통로 없는 시작 구성이 분당 1.5건에서 5%쯤 놓쳐 0.8로 (시뮬레이션: 놓침 1% 미만)
  static const double aisleSlow = 0.8;
  static const int aisleCost = 30; // 통로 1칸 비용(원)
  static const double aisleRefund = 0.5; // 철거하면 돌려받는 비율
  static const double trafficHalfLife = 60; // 동선 기록이 절반으로 옅어지는 시간(게임 초)
  // 건물 바로 아래 한 줄은 '앞줄'(손님 줄·직원 서는 자리). 다른 건물이 막을 수 없다.

  // ---- 허브 도로 배경 차량 (보기용, 게임 로직과 무관) ----
  // 시간만으로 위치가 정해지는 순환 경로라 따로 상태를 저장하지 않는다. 화면 밖 차량은 그리지 않음
  static const int trafficPerLane = 2; // 차선마다 차량 수 (전체 4대)
  static const List<double> trafficSpeed = [3.0, 2.4]; // 칸/초: 아래로 가는 차선, 위로 가는 차선
  static const double trafficLoop = 54; // 한 바퀴 길이(칸, 월드 밖 구간 포함 → 차가 뜸하게 지나감)

  // ---- 흐름 수치 ----
  // 접수 시간(초, 직원 1명 기준 ×1.0). 직원 1명 창구는 분당 6건쯤 받아서 시작엔 병목이 아니지만,
  // 손님이 창구 앞에 서 있는 시간이 길어 줄이 보이고 명성이 오르면(분당 4건~) 창구 직원을 늘려야 한다.
  // 사연 말풍선을 탭하면 그 손님은 2배 빨리 접수됨
  static const double serveTime = 12;
  static const double packTime = 5; // 포장 시간(초)
  static const double customerSpeed = 2.2; // 칸/초
  static const double carrierSpeed = 1.3; // 칸/초 (걸음 능력치로 배수)
  static const double patience = 60; // 손님 인내심(초)
  static const int shelfCap = 20; // 선반 1개 용량
  static const int outboxCap = 6; // 접수 창구 대기 택배 한도 (레벨마다 +2, 최대 8 = 적재대 2x4)
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
  // 휴게실(3×3) 안 쉬는 자리 (건물 왼쪽 위 기준, 칸 단위). hub_lounge 그림에 맞춤:
  // 앞의 둘은 소파 방석 위(소파 앞면이 다리를 가림), 뒤의 둘은 탁자 양옆 바닥 (탁자·정수기 위에 서지 않게)
  static const List<Offset> loungeSeats = [
    Offset(1.13, 1.28),
    Offset(1.87, 1.28),
    Offset(0.41, 2.34),
    Offset(2.56, 2.34),
  ];
  // 휴게실이 없을 때 창고 밖 벤치 옆에 서서 쉬는 자리 (breakSpot 기준, 칸 단위). 벤치 앞 줄은 대기 직원 자리
  static const List<Offset> benchRestSlots = [
    Offset(-1.2, 0.05),
    Offset(1.2, 0.05),
    Offset(-2.0, 0.05),
    Offset(2.0, 0.05),
    Offset(-1.2, -0.8),
    Offset(1.2, -0.8),
  ];
  static const double backWallH = 64; // 창고 뒷벽 높이(px, 2칸)
  static const double faceIdle = 0.6; // 이만큼(초) 멈춰 있어야 정면을 봄
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
  static const double evtShow = 4; // 노선 사건 말풍선·연출 시간(초)
  /// 이벤트 확률: 간선이 길수록 조금 높음
  static double evtChance(bool trunk, int region) =>
      trunk ? 0.2 + RegionMap.of(region).trunkLen / 400 : 0.2;
  static double evtSuccess(int skill) => 0.3 + 0.12 * skill;

  static const List<double> waitOptions = [5, 15, 30];

  // ---- 접수량: 오직 ① 명성 구간 ② 달력 성수기 배수로만 늘어난다 ----
  // 시뮬레이션(tools/sim/econ_sim.py, 접수 12초·인내심 60초·1~2명씩 도착) 기준: 시작 구성(창구1·포장1·운반1·트럭1)은
  // 통로 없이(걸음 0.8배)도 분당 1.5건을 거의 놓침 없이 처리하고(선반은 쌓이지 않음), 통로를 깔면 분당 2.2건까지.
  // 그 위(명성 120~, 분당 2.7건)는 통로만으로 부족해 운반 직원·창구를 늘려야 놓침이 없어진다. 직원·선반·트럭을 늘린 구성은 분당 8건 안팎까지.
  static const List<int> intakeFame = [0, 25, 60, 120, 200, 320, 480, 700, 1000, 1400, 2000, 2800];
  static const List<double> intakePerMin = [1.5, 1.8, 2.2, 2.7, 3.2, 3.8, 4.6, 5.6, 6.8, 8.2, 10, 12];
  static const double intakeJitter = 0.4; // 손님 도착 간격 ±40%
  static const int groupMax = 2; // 손님이 한 번에 함께 오는 최대 인원 (줄이 보이게, 평균 접수량은 같음)

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
  // 업적 30개. 앞 17개는 예전 '목표'와 같은 순서 (저장된 받은 목록을 그대로 씀)
  static const List<Mission> missions = [
    Mission('건물을 3개 설치하세요', 1, 3, 1000),
    Mission('택배 20건 배송', 0, 20, 1500),
    Mission('직원 4명 모으기', 2, 4, 1500),
    Mission('택배 100건 배송', 0, 100, 4000, perk: 1),
    Mission('3일차 도달', 3, 3, 2000),
    Mission('배송 지역 2곳 열기', 4, 2, 3000, perk: 1),
    Mission('중형 창고로 확장', 5, 1, 5000, perk: 1),
    Mission('택배 500건 배송', 0, 500, 12000, perk: 1),
    Mission('배송 지역 4곳 열기', 4, 4, 15000, perk: 1),
    Mission('대형 창고로 확장', 5, 2, 20000, perk: 1),
    Mission('택배 2,000건 배송', 0, 2000, 50000, perk: 1),
    Mission('모든 배송 지역 열기', 4, 5, 60000, ticket: 1, perk: 1),
    Mission('직원 레벨 3 달성', 6, 3, 3000),
    Mission('건물 업그레이드 3번', 7, 3, 5000),
    Mission('급송 택배 5건 성공', 8, 5, 4000),
    Mission('직원 레벨 6 달성', 6, 6, 30000, ticket: 1),
    Mission('급송 택배 30건 성공', 8, 30, 25000, ticket: 1),
    // ---- 새 업적 ----
    Mission('처음으로 S등급 받기', 9, 1, 3000, ticket: 1),
    Mission('S등급 10번', 9, 10, 20000, ticket: 1, perk: 1),
    Mission('포장 실수 없는 날 3일 연속', 10, 3, 4000),
    Mission('포장 실수 없는 날 7일 연속', 10, 7, 12000, perk: 1),
    Mission('별 5점 손님 50명', 11, 50, 5000),
    Mission('별 5점 손님 500명', 11, 500, 30000, perk: 1),
    Mission('올해 목표를 모두 달성', 12, 1, 10000, perk: 1),
    Mission('3년 연속 목표 모두 달성', 12, 3, 40000, ticket: 1, perk: 1),
    Mission('첫 전직', 13, 1, 5000),
    Mission('전직 5번', 13, 5, 25000, perk: 1),
    Mission('세트 3개 발견', 14, 3, 6000),
    Mission('세트 10개 모두 발견', 14, 10, 50000, ticket: 1, perk: 1),
    Mission('누적 접수 10,000건', 15, 10000, 80000, perk: 1),
  ];
  static const int perkCap = 15; // 업적 영구 수익 보너스 상한(%)

  // ---- 하루 평가 (하루가 끝나면 등급) ----
  // 손님마다 별 1~5점: 남은 인내심 비율로 정함. 놓친 손님·포장 실수는 1점으로 셈.
  static const List<double> starCut = [0.8, 0.6, 0.4, 0.2]; // 이 비율 이상이면 5·4·3·2점
  static const List<String> gradeName = ['S', 'A', 'B', 'C', 'D'];
  static const List<double> gradeStar = [4.5, 4.0, 3.3, 2.5]; // 평균 별 기준 (S·A·B·C)
  static const List<double> gradeMiss = [0.05, 0.12, 1, 1]; // 놓친 비율 상한 (S·A)
  // 등급별 명성. 제안서 예시(+30/−10)는 접수량 구간(25·60·120…)에 비해 커서 줄임
  static const List<int> gradeFame = [8, 4, 1, 0, -4];
  static const List<int> gradeColor = [0xFFFFD166, 0xFF7BD389, 0xFF8EC5FF, 0xFFF0963A, 0xFFE5484D];

  // ---- 직업 (8개) ----
  // 맞는 곳에서 일할 때만 직업 효과가 나고 직업 경험치가 쌓인다. Lv2·Lv4에 스킬, Lv5 + 전직서 1장으로 전직.
    // 8~10 은 숨은 직업 (두 직업을 Lv5까지 키운 직원만, 전직 없음)
  static const List<String> jobName = ['접수원', '포장사', '운반원', '분류사', '상담원', '검수원', '정비사', '현장 반장', '원스톱 사원', '자동화 설계사', '고객 감동 매니저'];
    static const List<String> jobPromo = ['창구 매니저', '포장 장인', '물류 달인', '출고 반장', '고객만족 팀장', '품질 관리자', '정비 반장', '현장 소장', '원스톱 사원', '자동화 설계사', '고객 감동 매니저'];
    static const List<String> jobWhere = ['접수 창구', '포장대', '운반', '선반(보조 자리)', '접수 창구', '포장대', '도크(보조 자리)', '창구·포장대·운반', '접수 창구·포장대', '운반', '접수 창구'];
    static const List<int> jobColor = [0xFFF0963A, 0xFF5BA88A, 0xFF8EC5FF, 0xFFB98A5E, 0xFFE58FB0, 0xFF9AA7C7, 0xFF7A8FA6, 0xFFFFD166, 0xFFFF7EB6, 0xFF6FE3D2, 0xFFC59BFF];
  static const int baseJobs = 8;
  // 숨은 직업 조건: 이 두 직업을 Lv5까지 (접수원+포장사, 운반원+분류사, 상담원+접수원)
  static const List<(int, int)> hiddenJobNeed = [(0, 1), (2, 3), (4, 0)];
  // 직업별 [기본, Lv2, Lv4, 전직] 효과 설명
  static const List<List<String>> jobSkills = [
    ['접수 창구에서 손님 접수', '빠른 손: 접수 +10%', '미소 응대: 창구 손님 인내심 감소 −15%', '창구 매니저: 접수 +40%'],
    ['포장대에서 포장', '테이프 달인: 포장 +10%', '완충 마스터: 포장 실수 −50%', '포장 장인: 포장 +40%, 실수 −90%'],
    ['접수 → 포장 → 선반 → 도크 운반', '가벼운 발: 걸음 +10%', '지름길: 걸음 +25%', '물류 달인: 걸음 +45%'],
    ['선반 용량 +3', '색깔 분류: 선반 용량 +5', '테트리스: 선반 용량 +8', '출고 반장: 선반 용량 +12'],
    ['창구 손님 인내심 감소 −20% (접수는 느림)', '달래기: 인내심 감소 −30%', 'VIP 전담: VIP 팁 2배', '고객만족 팀장: 인내심 감소 −45%'],
    ['포장 실수 −50% (포장은 느림)', '꼼꼼 검사: 실수 −70%', '이중 확인: 실수 −90%', '품질 관리자: 실수 없음, 포장 덜 느림'],
    ['도크 싣기 +20%', '정비 요령: 싣기 +30%', '지게차 달인: 싣기 +45%', '정비 반장: 싣기 +70%'],
        ['모든 직원 체력 소모 −8% (본인 일은 느림)', '격려: 체력 소모 −12%', '팀워크: 체력 소모 −18%', '현장 소장: 체력 소모 −25%'],
    ['창구·포장대 어디서든 일 +30%', '일 +35%', '일 +40%', '-'],
    ['운반 걸음 +35%, 컨베이어 세트 도크 싣기 +20%', '걸음 +40%', '걸음 +45%', '-'],
    ['접수 +10%, 창구 손님 인내심 감소 −40%', '인내심 감소 −45%', '인내심 감소 −50%', '-'],
  ];
  static const List<double> jobXpNeed = [100, 250, 500, 900]; // 직업 Lv1→2, →3, →4, →5 (게임 초)
  static const int jobMaxLv = 5;

    // ---- 세트 (맞닿은 묶음 안에 아래 종류가 모두 있으면 발동, 효과는 target 건물에) ----
  static const List<SetDef> sets = [
    SetDef('포장 라인', {'pack': 2, 'bin': 1}, 'pack', '포장 +15%', speed: 1.15),
    SetDef('대기 공간', {'counter': 1, 'chair': 2}, 'counter', '손님 인내심 감소 −20%', calm: 0.8),
    SetDef('물류 랙', {'shelf': 3}, 'shelf', '선반 용량 +5', cap: 5),
    SetDef('공지 게시판', {'counter': 1, 'board': 1}, 'counter', '접수 +10%', speed: 1.1),
    SetDef('자재 보급', {'shelf': 1, 'bin': 1}, 'shelf', '선반 용량 +3', cap: 3),
    SetDef('직원 카페', {'lounge': 1, 'vending': 1, 'plant': 1}, 'lounge', '휴게실 회복 ×1.3',
        hidden: true, hint: '휴게실 옆에 마실 것과 초록 식물', rest: 1.3),
    SetDef('빠른 출고', {'shelf': 1, 'conveyor': 1, 'dock': 1}, 'dock', '도크 싣기 +30%',
        hidden: true, hint: '선반에서 도크까지 굴러가는 길', load: 1.3),
    SetDef('시원한 작업장', {'pack': 1, 'aircon': 1}, 'pack', '포장 직원 체력 소모 −20%',
        hidden: true, hint: '더운 포장대에 바람을', drain: 0.8),
    SetDef('초록 쉼터', {'counter': 1, 'chair': 1, 'plant': 1}, 'counter', '손님 인내심 감소 −15%',
        hidden: true, hint: '기다리는 자리에 식물 하나', calm: 0.85),
    SetDef('컨베이어 라인', {'pack': 1, 'conveyor': 1, 'shelf': 1}, 'pack', '포장 +10%',
        hidden: true, hint: '포장대와 선반 사이를 잇는 벨트', speed: 1.1),
  ];
    static const int hiddenSetFame = 20; // 숨은 세트 처음 발견 명성
    static const Set<String> propIds = {'bin', 'chair', 'plant', 'board', 'aircon', 'conveyor', 'vending', 'lab', 'classroom'};
  static const double plantRadius = 2, plantDrain = 0.05; // 화분: 반경 2칸, 소모 −5%
  static const int plantMax = 3;
  static const double airconRadius = 3, airconDrain = 0.10; // 에어컨: 반경 3칸, 소모 −10%

    // ---- 선택형 사건 (허브 안, 하루 1~2번, 같은 사건은 일주일에 한 번 이하) ----
  static const List<String> hubEvtName = ['TV 취재 요청', '명절 특수', '직원 다툼', '대량 주문 제안', '폭염', '신입 지원자'];
  static const List<String> hubEvtDesc = [
    '방송국에서 허브를 취재하고 싶대요. 손님이 몰리겠지만 잘 해내면 유명해져요.',
    '명절을 앞두고 택배가 쏟아질 조짐이에요. 특근을 할까요?',
    '두 직원이 말다툼을 했어요. 분위기가 험악해요.',
    '쇼핑몰에서 대량 주문을 맡기고 싶대요. 기한 안에 다 보내야 해요.',
    '오늘은 찜통더위예요. 직원들이 금방 지칠 것 같아요.',
    '경력 많은 지원자가 찾아왔어요. 월급은 두 배를 원해요.',
  ];
  static const List<int> evtPerDay = [0, 1]; // 하루 사건 수 (최소, 최대)
  static const int evtQuietDays = 2; // 처음 이틀은 사건 없음 (가게를 차리는 동안)
  static const double evtMinGap = 360; // 사건 사이 최소 간격 (게임 초, 하루 = 300)
  static const int evtTouchGrace = 1000; // 마지막 터치 뒤 이만큼(ms) 지나야 팝업
  static const int popupTapGuard = 300; // 팝업이 뜬 직후 이만큼(ms)은 탭 무시
  static const List<double> evtWindow = [40, 260]; // 하루(300초) 중 사건이 뜨는 구간(초)
  static const int evtCooldownDays = 7;
  static const double evtTvBase = 0.25, evtTvIntake = 1.5;
  static const int evtTvFame = 50, evtTvFail = 10;
  static const int evtRushDays = 3, evtRushFame = 10;
  static const double evtRushIntake = 1.5, evtRushWage = 1.3;
  static const int evtFightCost = 500, evtFightDays = 3;
  static const double evtFightSlow = 0.85;
  // 대량 주문: 제안서의 '급송 40건'은 시작 접수량으로 불가능해서, 지금 접수량 × 5분 × 0.8 건(최소 8)을 내일 끝까지 배송
  static const double evtBulkIntake = 1.3;
  static const int evtBulkPay = 250, evtBulkFail = 30;
  static const int evtHeatCost = 2000;
  static const double evtHeatDrain = 1.3;
  static const double evtRookieWage = 2.0;

    // ---- 연구 (RP: 배송 1건 = 1, 연구실 1개당 하루 +30). 한 번에 하나, 같은 갈래는 앞 단계부터 ----
  static const List<String> resBranch = ['작업', '물류', '서비스'];
  static const List<ResearchDef> research = [
    ResearchDef('바코드 접수', 0, 0, 200, 1000, 120, '접수 +10%'),
    ResearchDef('자동 테이프', 0, 1, 500, 3000, 240, '포장 +15%'),
    ResearchDef('포장 라인 2세대', 0, 2, 1200, 8000, 400, '세트 효과 ×1.5'),
    ResearchDef('컨베이어 해금', 1, 0, 400, 2000, 180, '컨베이어를 지을 수 있음'),
    ResearchDef('분류 자동화', 1, 1, 900, 5000, 300, '분류사 선반 용량 효과 ×1.5'),
    ResearchDef('야간 출고', 1, 2, 2000, 10000, 480, '하루 끝에 선반 택배 10건을 지역센터로 자동 출고'),
    ResearchDef('번호표', 2, 0, 300, 1500, 150, '손님 인내심 감소 −10%'),
    // 단골 카드: 제안서 '재방문 +'을 손님 수 +8%로 정함
    ResearchDef('단골 카드', 2, 1, 700, 4000, 270, '단골이 다시 와서 손님 +8%'),
    ResearchDef('프리미엄 배송', 2, 2, 1500, 9000, 420, '급송 보너스 ×2'),
  ];
  static const int rpPerParcel = 1, labRpDay = 30, nightShip = 10;
  // ---- 훈련 (교육실에서 하루, 능력치 하나 +1, 비용 1,000 × 지금 능력치) ----
  static const List<String> statName = ['손속도', '걸음', '친절', '체력', '꼼꼼'];
  static const int trainBase = 1000, classSeats = 2;

    // ---- 연말 '택배 대상' 시상식: 올해 점수 = 올해 접수 + 평균 별 × 60 + 명성 × 0.5 ----
  static const List<String> rivalName = ['번개택배', '한빛로지스', '다람쥐배송', '큰곰물류', '하늘특송'];
  static const List<int> rivalBase = [350, 550, 800, 1100, 1500]; // 1년차 점수
  static const double rivalGrowth = 1.45; // 해마다 ×1.45
  static const double endlessBoost = 1.3; // 무한 모드(전국 네트워크 뒤) 경쟁사 강화
  static const double awardStarW = 60, awardFameW = 0.5;
  static const int awardFirstFame = 300, awardTop3Fame = 100;

  // ---- 회사 등급 (창고 확장과 따로, 내려가지 않음) ----
  static const List<String> corpName = ['동네 영업소', '지점', '거점 허브', '광역 물류센터', '전국 네트워크'];
  static const List<String> gradeUnlockText = [
    '기본 시설',
    '연구실 · 대기 의자 · 화분',
    '교육실 · 컨베이어 · 상위 직업(전직)',
    '야간 출고 연구',
    '엔딩 + 무한 모드(경쟁사 강화)',
  ];
  // 지점 조건 '하루 처리 40건'은 명성 100 근처 접수량(하루 약 13건)으로 어려워 20건으로 낮춤
  static const int grade1Day = 20;
  static const Map<String, int> gradeUnlock = {
    'lab': 1, 'chair': 1, 'plant': 1, 'classroom': 2, 'conveyor': 2,
  };
  static const int promoGrade = 2, nightShipGrade = 3;

    // ---- 숨은 손님 (조건을 채우면 하루 한 번까지 확률로 옴, 처음 오면 손님 도감) ----
  static const List<String> guestName = ['단골 할머니', '유튜버', '이삿짐 센터 사장', '꼬마 손님', '해외 바이어'];
  static const List<String> guestHint = [
    '대기 의자가 있는 창구에 친절한 직원이 있으면…',
    '유명해진 뒤 수익 부스트가 켜져 있을 때…',
    '대형 택배를 아주 많이 받으면…',
    '창고에 화분이 많으면…',
    '먼 지역까지 고급 배송을 하면…',
  ];
  static const List<String> guestEffect = [
    '김치 택배 + 팁 500원',
    '다음 날 손님 ×1.3',
    '대형 택배 3건 + 2,000원',
    '그림 편지, 명성 +10',
    '해외 배송 +1,500원 · RP +100',
  ];
  static const double guestChance = 0.15, guestStreamIntake = 1.3;
  static const int guestFoundFame = 15, guestLook0 = 6; // 숨은 손님 외형 = cust_6..10

  // ---- 계절 (1년 28일 = 7일씩) ----
  static const List<String> seasonName = ['봄', '여름', '가을', '겨울'];

  /// y년차 목표 3개
  static List<YearGoal> yearGoals(int y) => [
    YearGoal('하루 접수 ${15 + 8 * (y - 1)}건', 0, 15 + 8 * (y - 1), 2000 * y),
    YearGoal('B등급 이상인 날 ${6 + 2 * (y - 1)}일', 1, 6 + 2 * (y - 1), 2000 * y),
    YearGoal('배송 지역 ${min(5, y + 1)}곳 열기', 2, min(5, y + 1), 2000 * y),
  ];
  static const int yearAllFame = 50; // 올해 목표 3개 모두 달성: 명성
  static const int yearAllTicket = 1; // + 전직서


  // ---- 편의 시설 ----
  static const double vendingCalm = 0.15; // 자판기 1대당 손님 짜증 속도 감소 (2대까지)
  static const int vendingMax = 2;

  // ---- 저장 ----
  static const double autosaveSec = 10;

  // ---- 사연 택배 (사연 손님만 말풍선, 문 앞에서 기다림) ----
  static const int storyFromDay = 2; // 이 날부터 사연 손님이 옴
  static const double storyChance = 0.12; // 새 손님이 사연 손님일 확률 (한 번에 한 명)
  static const double storyWait = 35; // 문 앞에서 기다리는 시간(게임 초). 지나면 돌아감
  static const double storyTouchDp = 48; // 사연 손님 터치 영역 최소 크기(dp)
  static const double storyPackTime = 4.0; // 포장 연출 시간(게임 초)
  static const double storyNormalOk = 0.45, storyTempOk = 0.75; // 조건 미달 때 성공 확률
  static const int storyTempCost = 300; // 임시 포장 재료비
  static const int storySkillBonus = 500; // 숙련 포장 보너스
  // 초기 5개 (재미를 보고 늘림). 1단계는 포장대 레벨만 요구
  static const List<StoryDef> storyDefs = [
    StoryDef('letter', '군대 간 아들에게', '엄마', '손편지랑 양말 몇 켤레예요. 구겨지지 않게만 부탁해요.',
        'pack', 1, ['tape'], 600, 3, '아들이 편지를 받고 전화했대요. "엄마 글씨 그대로네!"', '봉투가 조금 젖었지만, 아들은 편지를 다 읽었대요.'),
    StoryDef('teddy', '아이 곰인형이요', '꼬마 지우', '할머니 댁에 두고 온 곰인형을 보내 주세요. 매일 밤 안고 자요.',
        'pack', 1, ['wrap', 'tape'], 700, 4, '곰인형이 무사히 도착! 지우가 오늘 밤 푹 잤대요.', '귀가 조금 눌렸지만, 지우는 곰인형을 꼭 안아 줬대요.'),
    StoryDef('kimchi', '할머니 김장 김치', '할머니', '손주들 먹으라고 담근 김장 김치예요. 국물이 새면 큰일이에요.',
        'pack', 2, ['ice', 'wrap', 'tape'], 900, 5, '김치 국물 한 방울 안 샜대요. 손주가 밥 두 공기 먹었대요.', '국물이 조금 샜지만, 손주들은 "할머니 맛"이라며 다 먹었대요.'),
    StoryDef('cake', '생일 케이크요', '단골 빵집', '딸 생일 케이크를 시골 부모님께요. 크림이 녹으면 안 돼요.',
        'pack', 2, ['ice', 'wrap'], 1000, 5, '촛불까지 멀쩡! 부모님이 영상 통화로 노래를 불러 줬대요.', '크림이 조금 녹았지만, 부모님은 "세상에서 제일 맛있다"고 했대요.'),
    StoryDef('vase', '결혼 기념 도자기', '노부부', '50년 전 결혼 선물로 받은 도자기예요. 딸에게 물려주려고요.',
        'pack', 3, ['wrap', 'wrap', 'tape'], 1500, 8, '금 하나 없이 도착. 딸이 거실 한가운데에 두었대요.', '이가 조금 나갔지만, 딸은 "50년 이야기가 하나 더 생겼다"고 했대요.'),
  ];
  static const List<String> storyStamp = ['배송 완료', '파손', '지연'];
  static const String storyLateText = '하루 늦게 도착했지만, 기다린 만큼 더 반가웠대요.'; // 지연 엽서 글

  // ---- 직접 개입 ----
  static const int tapBonus = 10; // 내 자리에서 손님을 직접 탭해 접수하면 받는 보너스(원)
  static const double alertAngry = 0.3; // 인내심이 이 비율 아래면 '화난 손님'
  static const double alertTired = 0.25; // 체력이 이 비율 아래면 '지친 직원' (자동 휴식은 0.15)
  static const double sootheTo = 0.7; // 달래면 인내심이 이 비율까지 회복
  static const double sootheCooldown = 20; // 달래기 재사용 대기(게임 초)
  static const int snackCost = 200; // 간식 비용(원)
  static const double snackRestore = 0.4; // 간식으로 회복하는 체력 비율
}