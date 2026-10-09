import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../systems/award_system.dart';
import '../systems/book_system.dart';
import '../systems/build_system.dart';
import '../systems/dock_system.dart';
import '../systems/event_system.dart';
import '../systems/fleet_system.dart';
import '../systems/flow_system.dart';
import '../systems/input_system.dart';
import '../systems/job_system.dart';
import '../systems/interact_system.dart';
import '../systems/ops_system.dart';
import '../systems/path_system.dart';
import '../systems/rating_system.dart';
import '../systems/research_system.dart';
import '../systems/save_system.dart';
import '../systems/set_system.dart';
import '../systems/guide_system.dart';
import '../systems/staff_system.dart';
import '../systems/worker_system.dart';
import '../ui/world_view.dart';
import 'config.dart';
import 'sprites.dart';

export '../systems/award_system.dart';
export '../systems/book_system.dart';
export '../systems/build_system.dart';
export '../systems/dock_system.dart';
export '../systems/event_system.dart';
export '../systems/flow_system.dart';
export '../systems/input_system.dart';
export '../systems/job_system.dart';
export '../systems/interact_system.dart';
export '../systems/ops_system.dart';
export '../systems/path_system.dart';
export '../systems/rating_system.dart';
export '../systems/research_system.dart';
export '../systems/save_system.dart';
export '../systems/set_system.dart';
export '../systems/guide_system.dart';
export '../systems/staff_system.dart';
export '../systems/fleet_system.dart';
export '../systems/worker_system.dart';
export '../ui/world_view.dart';

class HubGame extends FlameGame {
  int money = 20000;
  int areaLevel = 0;
  final List<Building> buildings = [];
  final List<Customer> customers = [];
  final List<Staff> staff = []; // 내 직원
  final List<Staff> candidates = []; // 고용 후보
  final List<Carrier> carriers = []; // 운반 담당 직원의 몸
  final List<Alert> alerts = []; // 위기 알림
  double sootheCd = 0; // 손님 달래기 재사용 대기(초)
  int nextStaffId = 1;
  final rnd = Random();
  double spawnTimer = 2;
  double clock = 0; // 애니메이션용 실제 시간
  int done = 0;
  int lost = 0;
  int delivered = 0; // 배송 나간 택배 수
  int upgrades = 0; // 건물 업그레이드 횟수
  int urgentOk = 0; // 급송 성공 건수
  double gt = 0; // 게임 시간(속도 배수 반영)
  int dayEarn = 0; // 오늘 번 돈 (하루 결산용)
  double saveTimer = 0;
  final List<bool> regionOpen = [true, false, false, false, false]; // 열린 배송 지역
  final List<DeliveryRoute> routes = List.generate(
    5,
    (_) => DeliveryRoute(),
  ); // 지역별 노선 설정
  final List<FleetUnit> fleet = []; // 내 차량들
  final List<int> centerStock = List.filled(5, 0); // 지역센터에 내려진 택배
  final List<MapNote> notes = []; // 노선 지도 소식
  final List<MapFx> mapFx = []; // 지도 위 떠오르는 효과
  final List<(Offset, String, int, double)> hubFx = []; // 허브 위 떠오르는 글 (월드 픽셀, 글, 색, 생긴 시각)
  int fame = 0; // 명성 (지역을 여는 조건)
  int nextUnitId = 1;
  bool showMap = false; // 전체화면 노선 지도
    final Set<int> claimed = {}; // 보상을 받은 업적
  final RateState rt = RateState(); // 하루 평가·올해 목표·업적 기록
  int tickets = 0; // 전직서 (직업 Lv5 직원을 상위 직업으로 전직할 때 1장)
  (int, int, int, int, int, double, int)? pendingReport; // 월급 정산 전 하루 평가
    DayReport? report; // 하루 정산 카드 (null 이면 안 보임)
    double setTimer = 0; // 세트 다시 계산까지
  // 선택형 사건
  final List<double> evtTimes = []; // 오늘 사건이 뜰 시각(하루 초)
  final Map<int, int> evtLast = {}; // 사건별 마지막으로 뜬 날
  HubEvent? evtNow; // 고르는 중인 사건 (게임 멈춤)
  final List<ActiveEvt> evts = []; // 진행 중인 사건
    final List<String> evtNotes = []; // 오늘 끝난 사건 결과 (정산 카드에 표시)
    int debugEvt = 0; // (디버그) 다음에 일으킬 사건
  // 연구
  int rp = 0; // 연구 포인트
  final Set<int> researched = {};
  int? resNow; // 진행 중 연구
    double resLeft = 0; // 남은 시간(게임 초)
  // 회사 등급·시상식
  int companyGrade = 0;
  int bestRank = 0; // 연말 시상식 최고 순위 (0 = 아직 없음)
  int awardWins = 0; // 대상(1위) 횟수
  bool endless = false; // 전국 네트워크 뒤 무한 모드
  AwardResult? award; // 시상식 카드
    int? gradeUp; // 승급 카드 (오른 등급)
    final Map<int, int> guestLast = {}; // 숨은 손님이 마지막으로 온 날
  int debugGuest = 0;
  double fever = 0; // 수익 부스트(광고) 남은 시간(초)

  // 배송 기한: 택배마다 접수 시각을 단계마다 넘겨준다 (먼저 들어온 것부터 나감)
  final List<List<double>> hubBorn = List.generate(5, (_) => []); // 허브 선반
  final List<List<double>> centerBorn = List.generate(5, (_) => []); // 지역센터
  int streak = 0; // 연속 정시 배송
  int bestStreak = 0;
  int onTimeCount = 0;
  int lateCount = 0;
  double adCd = 0; // 광고 피버 재사용 대기
  bool noSave = false; // 저장 지우기 후 덮어쓰기 방지
  int speedIdx = 0;
  int get speedMul => Cfg.speeds[speedIdx];

  // 달력·월급
  int day = 1;

  /// 연중 며칠째 (1~yearDays), 몇 년차
  int get dayOfYear => (day - 1) % Cfg.yearDays + 1;
  int get year => (day - 1) ~/ Cfg.yearDays + 1;

  /// 오늘이 성수기면 그 정보, 아니면 null
  (String, int, int, double)? get holiday {
    final d = dayOfYear;
    for (final h in Cfg.holidays) {
      if (d >= h.$2 && d < h.$2 + h.$3) return h;
    }
    return null;
  }

  /// 다음 성수기와 남은 날 수
  ((String, int, int, double), int) get nextHoliday {
    final d = dayOfYear;
    for (final h in Cfg.holidays) {
      if (h.$2 > d) return (h, h.$2 - d);
    }
    final h = Cfg.holidays.first;
    return (h, Cfg.yearDays - d + h.$2);
  }

  /// 지금 접수량 (분당 택배 수) = 명성 구간 × 성수기 배수
    double get intakeNow => Cfg.intakeBase(fame) * (holiday?.$4 ?? 1.0) * this.evtIntake * this.resIntake; // 사건(TV 취재·특근·대량 주문)·연구(단골 카드)
  double dayTimer = 0;
  double candTimer = 0;
  int lastPayroll = 0;

  // 카메라 (월드 픽셀 기준 화면 왼쪽 위)
  Offset cam = Offset.zero;
  bool camInit = false;
  double zoom = 1; // 화면 픽셀 / 월드 픽셀
  double _pinchZoom = 1; // 두 손가락을 댔을 때의 확대율

  // 위젯 UI가 가리는 위·아래 높이 (GameScreen이 채워 줌)
  double insetTop = 100;
  double insetBottom = 90;

  // 모드: 0 기본, 2 배치 중, 3 확장 미리보기
  int mode = 0;
  BuildingType? placing;
  int ghostX = 0;
  int ghostY = 0;
  bool draggingGhost = false;

  // 직원 통로 (칸 번호 = y * Cfg.cols + x). 모드 4에서 깔고 철거
  final Set<int> aisles = {};
  int aisleVer = 0; // 통로가 바뀔 때마다 증가 (길 다시 찾기)
  int aisleTool = 0; // 0 깔기, 1 철거, 2 화면 이동
  (int, int)? aisleLast; // 드래그 중 마지막으로 칠한 칸
  List<bool> walkGrid = []; // 걸을 수 있는 칸 (배치가 바뀌면 다시 만듦)
  int walkSig = -1;
  final List<double> traffic = List<double>.filled(Cfg.cols * Cfg.rows, 0); // 칸별 최근 동선
  double trafficTimer = 0;
  double walkAll = 0, walkOnAisle = 0; // 최근 걸은 거리 (통로 위 비율 표시용)
  Building? selected;
  Staff? picking; // 먼저 탭한 직원 (다음에 탭한 시설에 배치)

  // 시트: null / 'build' / 'staff'
  String? sheet;
  int staffTab = 0; // 0 내 직원, 1 고용

  String toast = '';
  double toastTime = 0;

  // UI 갱신 신호 (위젯이 이 값을 구독)
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  double _tickAcc = 0;
  void ui() {
    tick.value++;
  }

  bool get canExpand => areaLevel < Cfg.areas.length - 1;
  int get nextAreaCost => canExpand ? Cfg.areaCost[areaLevel + 1] : 0;

  /// 창고 영역
  Rect get area => Cfg.areas[areaLevel];

  // ---- 건물 조회 ----
  Iterable<Building> ofType(String id) =>
      buildings.where((b) => b.type.id == id);
  int get totalStored => buildings.fold(0, (a, b) => a + b.stored);

  /// 건물 앞(아래쪽) 서는 자리 (타일 좌표)
  Offset frontOf(Building b) => b.type.id == 'counter'
      ? Offset(b.tx + 1.0, b.ty + b.type.h + 0.6) // 창구: 책상(왼쪽 2칸) 앞
      : Offset(b.tx + b.type.w / 2, b.ty + b.type.h + 0.6);

  /// 운반 직원이 택배를 집거나 내려놓는 자리. 접수 창구는 오른쪽 칸 적재대 앞,
  /// 도크는 창고 안쪽 도크 문 앞 (벽 너머 트럭에 문으로 싣는다)
  Offset pickOf(Building b) {
    switch (b.type.id) {
      case 'counter':
        return Offset(b.tx + b.type.w - 0.5, b.ty + b.type.h + 0.6);
      case 'dock':
        return Offset(b.tx - 0.6, b.ty + b.type.h / 2);
    }
    return frontOf(b);
  }

  /// 건물 앞줄 (손님 줄·직원 서는 자리)
  Rect frontRow(Rect r) => Rect.fromLTWH(r.left, r.bottom, r.width, 1);

  /// 손님이 들어오고 나가는 입구 바깥 지점
  Offset get exitPoint => Offset(area.left - 3, area.center.dy);

  /// 운반 직원이 처음 나타나는 자리
  Offset get staffSpawn => Offset(area.left + 1.5, area.center.dy);

  @override
  Color backgroundColor() => const Color(0xFF2A2438);

  String fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );

  void showToast(String s) {
    toast = s;
    toastTime = 2.2;
    ui();
  }

  void closeAll() {
    sheet = null;
    selected = null;
    ui();
  }

  // ---- 카메라 ----
  /// 화면에 보이는 월드 크기 (월드 픽셀)
  double get viewW => size.x / zoom;
  double get viewH => size.y / zoom;

  /// 가장 멀리 볼 수 있는 확대율: 월드(허브 경계)보다 넓게 보이지 않게
  double get zoomLo {
    final visH = size.y - insetTop - insetBottom;
    return max(
      Cfg.zoomMin,
      max(size.x / (Cfg.cols * Cfg.tile), visH / (Cfg.rows * Cfg.tile)),
    );
  }

  double get zoomHi => max(Cfg.zoomMax, zoomLo);

  /// 기본 확대율: 화면 가로에 Cfg.zoomFitTiles 칸
  double get zoomDefault =>
      (size.x / (Cfg.zoomFitTiles * Cfg.tile)).clamp(zoomLo, zoomHi).toDouble();

  void clampCam() {
    zoom = zoom.clamp(zoomLo, zoomHi).toDouble();
    final worldW = Cfg.cols * Cfg.tile;
    final worldH = Cfg.rows * Cfg.tile;
    final vw = viewW, vh = viewH;
    double x = cam.dx;
    double y = cam.dy;
    if (worldW <= vw) {
      x = (worldW - vw) / 2;
    } else {
      x = x.clamp(0.0, worldW - vw).toDouble();
    }
    // 위·아래는 메뉴가 가리는 만큼 더 밀 수 있음 (월드 끝이 메뉴 바로 옆까지만)
    final minY = -insetTop / zoom;
    final maxY = worldH - vh + insetBottom / zoom;
    y = maxY < minY ? (minY + maxY) / 2 : y.clamp(minY, maxY).toDouble();
    cam = Offset(x, y);
  }

  /// 화면 점 focal 아래의 월드 위치를 그대로 두고 확대율을 바꿈
  void zoomAt(Offset focal, double z) {
    final w = focal / zoom + cam;
    zoom = z.clamp(zoomLo, zoomHi).toDouble();
    cam = w - focal / zoom;
    clampCam();
  }

  void pinchStart() => _pinchZoom = zoom;
  void pinchUpdate(Offset focal, double scale) =>
      zoomAt(focal, _pinchZoom * scale);

  /// 처음 카메라 위치
  void centerCamOnArea() {
    final a = area;
    zoom = zoomDefault;
    final visibleH = size.y - insetTop - insetBottom;
    cam = Offset(
      // 새 게임(건물 없음)은 휴식 벤치와 접수 구역이 보이게, 아니면 접수~보관 쪽
      (buildings.isEmpty ? a.left + 1.5 : a.right - 4.5) * Cfg.tile - viewW / 2,
      a.center.dy * Cfg.tile - (insetTop + visibleH / 2) / zoom,
    );
    clampCam();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Sprites.load();
    if (!await this.loadGame()) {
            this.addStarters();
    }
          this.planEvents();
      this.finishTraining();
    this.genCandidates();
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    if (!camInit && s.x > 0 && s.y > 0) {
      camInit = true;
      centerCamOnArea();
    } else if (camInit) {
      clampCam();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock += dt;
    if (toastTime > 0) toastTime -= dt;
        final d = evtNow != null ? 0.0 : dt * speedMul; // 사건을 고르는 동안 멈춤

    // 달력: 하루가 끝나면 월급 정산
    dayTimer += d;
        if (dayTimer >= Cfg.dayLength) {
      dayTimer = 0;
                  evtNotes
        ..clear()
        ..addAll(this.resolveEvents(day))
        ..addAll(this.researchDayEnd());
      this.endOfDay(day);
      day++;
      this.payroll();
      this.planEvents();
      final h = holiday;
      if (h != null && dayOfYear == h.$2) {
        showToast('${h.$1} 시작! 오늘부터 ${h.$3}일간 접수량 ×${h.$4}');
      } else if (dayOfYear == 1) {
        showToast('$year년차가 시작됐어요');
      }
    }
    // 고용 후보 자동 갱신
    candTimer += d;
    if (candTimer >= Cfg.candidateRefreshSec) {
      candTimer = 0;
      this.genCandidates();
    }

    gt += d;
        this.updateFever(d);
        this.updateEvents(d);
    this.updateResearch(d);
    if (sootheCd > 0) sootheCd = max(0.0, sootheCd - d);

    this.updateFlow(d);
    this.updateWorkers(d);
    this.updateDocks(d);
    this.updateFleet(d);

    saveTimer += dt;
    if (saveTimer >= Cfg.autosaveSec) {
      saveTimer = 0;
      this.saveGame();
    }

    // 위젯 UI는 초당 5번 갱신
    _tickAcc += dt;
    if (_tickAcc >= 0.2) {
      _tickAcc = 0;
            this.refreshAlerts();
            this.checkGoals();
            this.checkGrade();
      this.updateBook();
      ui();
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      this.saveGame();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    this.renderWorld(canvas);
  }
}
