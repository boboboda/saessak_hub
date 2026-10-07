import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../systems/build_system.dart';
import '../systems/dock_system.dart';
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

export '../systems/build_system.dart';
export '../systems/dock_system.dart';
export '../systems/flow_system.dart';
export '../systems/input_system.dart';
export '../systems/interact_system.dart';
export '../systems/ops_system.dart';
export '../systems/save_system.dart';
export '../systems/guide_system.dart';
export '../systems/staff_system.dart';
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
  int dayEarn = 0; // 오늘 번 돈 (하루 결산용)
  double saveTimer = 0;
  final List<bool> regionOpen = [true, false, false, false, false]; // 열린 배송 지역
  final Set<int> claimed = {}; // 보상을 받은 목표
  double fever = 0; // 피버 남은 시간(초)
  double feverCd = Cfg.feverFirst; // 다음 피버까지
  double adCd = 0; // 광고 피버 재사용 대기
  bool noSave = false; // 저장 지우기 후 덮어쓰기 방지
  int speedIdx = 0;
  int get speedMul => Cfg.speeds[speedIdx];

  // 달력·월급
  int day = 1;
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
    y = y.clamp(minY, maxY).toDouble();
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
    }
    // 고용 후보 자동 갱신
    candTimer += d;
    if (candTimer >= Cfg.candidateRefreshSec) {
      candTimer = 0;
      this.genCandidates();
    }

    this.updateFever(d);
    if (sootheCd > 0) sootheCd = max(0.0, sootheCd - d);

    this.updateFlow(d);
    this.updateWorkers(d);
    this.updateDocks(d);

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