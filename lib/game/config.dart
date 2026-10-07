import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/mission.dart';
import '../models/vehicle.dart';

class Cfg {
  static const double tile = 40; // 한 칸 픽셀
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
  static const Rect yard = Rect.fromLTRB(22, 7, 32, 29);
  static const Rect road = Rect.fromLTRB(32, 0, 35, 36);

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
    BuildingType('counter', '접수 창구', 2, 1, 1500, 0xFFF0963A, '손님 접수 · 직원 2명까지', 0, 2),
    BuildingType('pack', '포장대', 2, 2, 2000, 0xFF5BA88A, '택배 포장 · 직원 2명까지', 1, 2),
    BuildingType('shelf', '선반', 2, 3, 1500, 0xFF8B5E3C, '택배 20건 보관', 2, 0),
    BuildingType('vending', '자판기', 1, 1, 4000, 0xFF3B82D6, '인내심 감소 완화', -1, 0),
    BuildingType('lounge', '휴게실', 3, 3, 8000, 0xFFB06AB3, '지친 직원이 와서 쉼 (회복 3배)', -1, 0),
    BuildingType('dock', '도크', 4, 3, 3000, 0xFF3D4466, '벽에 붙여 설치 · 차량이 서는 칸', 3, 0),
  ];

  // ---- 흐름 수치 ----
  static const double serveTime = 5; // 접수 시간(초, 직원 1명 기준 ×1.0)
  static const double packTime = 5; // 포장 시간(초)
  static const double customerSpeed = 2.2; // 칸/초
  static const double carrierSpeed = 3.0; // 칸/초 (걸음 능력치로 배수)
  static const double patience = 45; // 손님 인내심(초)
  static const int shelfCap = 20; // 선반 1개 용량
  static const int outboxCap = 4; // 접수 창구 대기 택배 한도
  static const int parcelPay = 60; // 배송 완료 택배 1건 기본 수익
  static const double fullBonus = 1.2; // 차량을 가득 채워 보내면 수익 배수
  static const double vehicleMove = 1.5; // 차량이 들어오고 나가는 시간(초)
  static const double vehicleWait = 5; // 더 실을 게 없을 때 기다리는 시간(초)
  // 택배가 쌓인 양에 맞춰 알아서 오는 차량 (큰 것부터 검사)
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

  // ---- 배송 지역 (택배 색과 같은 순서) ----
  static const List<String> regionName = ['동네', '시내', '근교', '타도시', '전국'];
  static const List<int> regionUnlock = [0, 8000, 25000, 60000, 150000];
  static const List<double> regionPay = [1.0, 1.3, 1.7, 2.2, 3.0]; // 수익 배수

  static const List<double> regionTrip = [15, 30, 50, 80, 120]; // 노선 지도에서 달리는 시간(초)
  static const List<double> waitOptions = [5, 15, 30];

  // ---- 피버 타임 (손님이 몰리고 수익이 오름) ----
  static const double feverFirst = 180; // 첫 피버까지(게임 초)
  static const double feverMin = 300;
  static const double feverMax = 420;
  static const double feverLen = 60;
  static const double feverSpawn = 0.5; // 손님 도착 간격 배수
  static const double feverPay = 1.5; // 수익 배수
  static const double adCooldown = 300; // 광고로 피버를 켜는 재사용 대기(초)

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