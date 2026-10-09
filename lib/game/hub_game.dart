import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../systems/build_system.dart';
import '../systems/dock_system.dart';
import '../systems/fleet_system.dart';
import '../systems/flow_system.dart';
import '../systems/input_system.dart';
import '../systems/interact_system.dart';
import '../systems/ops_system.dart';
import '../systems/save_system.dart';
import '../systems/guide_system.dart';
import '../systems/staff_system.dart';
import '../systems/worker_system.dart';
import '../ui/world_view.dart';
import 'config.dart';
import 'sprites.dart';

export '../systems/build_system.dart';
export '../systems/dock_system.dart';
export '../systems/flow_system.dart';
export '../systems/input_system.dart';
export '../systems/interact_system.dart';
export '../systems/ops_system.dart';
export '../systems/save_system.dart';
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
  final List<DeliveryRoute> routes = List.generate(5, (_) => DeliveryRoute()); // 지역별 노선 설정
  final List<FleetUnit> fleet = []; // 내 차량들
  final List<int> centerStock = List.filled(5, 0); // 지역센터에 내려진 택배
  final List<MapNote> notes = []; // 노선 지도 소식
  final List<MapFx> mapFx = []; // 지도 위 떠오르는 효과
  int fame = 0; // 명성 (지역을 여는 조건)
  int nextUnitId = 1;
  bool showMap = false; // 전체화면 노선 지도
  final Set<int> claimed = {}; // 보상을 받은 목표
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
  double get intakeNow => Cfg.intakeBase(fame) * (holiday?.$4 ?? 1.0);
  double dayTimer = 0;
  double candTimer = 0;
  int lastPayroll = 0;

  // 카메라 (월드 픽셀 기준 화면 왼쪽 위)
  Offset cam = Offset.zero;
  bool camInit = false;

  // 위젯 UI가 가리는 위·아래 높이 (GameScreen이 채워 줌)
  double insetTop = 100;
  double insetBottom = 90;

  // 모드: 0 기본, 2 배치 중, 3 확장 미리보기
  int mode = 0;
  BuildingType? placing;
  int ghostX = 0;
  int ghostY = 0;
  bool draggingGhost = false;
  Building? selected;

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
  Offset frontOf(Building b) =>
      Offset(b.tx + b.type.w / 2, b.ty + b.type.h + 0.6);

  /// 창고 가운데 통로 (입구 → 도크, 건물 금지)
  Rect get aisle {
    final a = area;
    final top = (a.center.dy - Cfg.aisleH / 2).floorToDouble();
    return Rect.fromLTRB(a.left, top, a.right, top + Cfg.aisleH);
  }

  /// 건물 앞줄 (손님 줄·직원 서는 자리)
  Rect frontRow(Rect r) => Rect.fromLTWH(r.left, r.bottom, r.width, 1);

  /// 손님이 들어오고 나가는 입구 바깥 지점
  Offset get exitPoint => Offset(area.left - 3, area.center.dy);

  /// 운반 직원이 처음 나타나는 자리
  Offset get staffSpawn => Offset(area.left + 1.5, area.center.dy);

  @override
  Color backgroundColor() => const Color(0xFF2A2438);

  String fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

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
  void clampCam() {
    final worldW = Cfg.cols * Cfg.tile;
    final worldH = Cfg.rows * Cfg.tile;
    double x = cam.dx;
    double y = cam.dy;
    if (worldW <= size.x) {
      x = (worldW - size.x) / 2;
    } else {
      x = x.clamp(0.0, worldW - size.x).toDouble();
    }
    final minY = -insetTop;
    final maxY = worldH - size.y + insetBottom;
    y = maxY < minY ? (minY + maxY) / 2 : y.clamp(minY, maxY).toDouble();
    cam = Offset(x, y);
  }

  /// 창고 오른쪽(보관·도크 쪽)이 보이도록 처음 위치를 잡음
  void centerCamOnArea() {
    final a = area;
    final visibleH = size.y - insetTop - insetBottom;
    cam = Offset((a.right - 3) * Cfg.tile - size.x / 2,
        a.center.dy * Cfg.tile - (insetTop + visibleH / 2));
    clampCam();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Sprites.load();
    if (!await this.loadGame()) {
      this.addStarters();
    }
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
    final d = dt * speedMul;

    // 달력: 하루가 끝나면 월급 정산
    dayTimer += d;
    if (dayTimer >= Cfg.dayLength) {
      dayTimer = 0;
      day++;
      this.payroll();
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