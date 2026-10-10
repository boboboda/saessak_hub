import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 도트 스프라이트 모음. 로딩에 실패하면 null → 화면은 기존 도형으로 그려짐.
class Sprites {
  static ui.Image? staffWalk;

  /// 직원 외형 변형 시트 (assets/sprites/staff/staff_walk_1..5.png). 있는 것만 모아 둠. 0번은 staffWalk.
  static final List<ui.Image> staffLooks = [];

  /// 손님 걷기 시트 (assets/sprites/customer/cust_0..5.png, 직원 시트와 같은 배치). 없으면 null.
    static const int custLooks = 11; // 0~5 일반 손님, 6~10 숨은 손님
  static final List<ui.Image?> custWalk = List.filled(custLooks, null);
  static ui.Image? box;
  static ui.Image? floor;
  // 사연 택배: 물건 아이콘(story_<item>) · 포장 효과(fx_<ice|wrap|tape>) · 도장(st_<done|broken|late>) · 말풍선·느낌표
  static final Map<String, ui.Image> storyItems = {}, fxIcons = {}, stamps = {};
  static ui.Image? storyBubble, storyAlert;
  static ui.Image? wallBack, wallItems, floorVar; // 절차 생성 (tools/hubgen): 뒷벽 4종 · 벽걸이 4종 · 바닥 변형 4종
  static ui.Image? counter, pack, shelf, van, truck, moto;
  static final ui.Paint _np = ui.Paint()..filterQuality = ui.FilterQuality.none;
  static ui.Image? vanFull, truckFull, motoFull; // 상자 가득 찬 모습 (없으면 null)
  static ui.Image? grass, asphalt, sidewalk, yard;
  static ui.Image? boxS, boxOpen, packEmpty;

  /// 허브 개편 그림: 모두 같은 시점(내려다보기 3/4)·같은 배율(도트 1px = 1칸의 1/32)
  static ui.Image? hubCounter, hubPack, hubShelf, hubLounge, hubDock;
  static ui.Image? wangFloor; // 창고 바닥(콘크리트) / 노란 통로
  /// 허브 도로 배경 차량 (위에서 본 모습, 아래로 달리는 방향. 위로 갈 땐 상하 반전)
  static final List<ui.Image> roadCars = [];

  /// 허브 도크 대형 트럭 (위에서 본 3/4, 왼쪽 짐칸·오른쪽 운전석). 빈 차 / 짐 가득 (같은 모양)
  static ui.Image? dockTruck, dockTruckFull;

  /// 도크 트럭 짐칸 (그림 픽셀): 실은 만큼 운전석 쪽부터 짐 실은 그림으로 채움
  static const ui.Rect dockTruckBed = ui.Rect.fromLTRB(3, 7, 71, 36);

  /// 노선 지도 지역센터 건물 (assets/sprites/map/center_<지역>.png). 없으면 null → 도형으로 그림.
  static final List<ui.Image?> centers = List.filled(5, null);
  static ui.Image? hub; // 노선 지도 허브 외관
  /// 노선 지도 Wang 타일 시트 (가로 16칸, 칸 번호 = NW*8+NE*4+SW*2+SE). 잔디/도로, 잔디/동네 길
  static ui.Image? wangRoad, wangWalk;
  static ui.Image? wangWalkOver; // 동네 길 시트에서 잔디만 투명하게 뺀 것 (차도 위에 겹쳐 그림)
  static ui.Image? wangWater; // 잔디/바다 (항구)

  /// 노선 지도 지역 소품 (assets/sprites/map/prop_<이름>.png). 없는 건 빠짐
    static final Map<String, ui.Image> mapProps = {};
  static final Map<String, ui.Image> setProps = {}; // 세트 소품 (prop_*.png)
  static const List<String> mapPropNames = [
    'mailbox',
    'vending',
    'busstop',
    'billboard',
    'haystack',
    'fence',
    'crops',
    'fountain',
    'gas',
    'hwsign',
    'container',
    'crane',
    'boat',
    'factory',
    'tank',
  ];

  /// 노선 지도 배달지 집 (assets/sprites/map/house_<이름>.png). d0~d11 단독주택, v0~v2 빌라
  static final Map<String, ui.Image> mapHouses = {};
  static const List<String> mapHouseNames = [
    'd0',
    'd1',
    'd2',
    'd3',
    'd4',
    'd5',
    'd6',
    'd7',
    'd8',
    'd9',
    'd10',
    'd11',
    'v0',
    'v1',
    'v2',
    'apt',
  ];

  /// 배경 장식 도트 (assets/sprites/decor/<이름>.png). 없는 건 null.
  static final Map<String, ui.Image> decor = {};
  static const List<String> decorNames = [
    'tree',
    'tree2',
    'bush',
    'lamp',
    'light',
    'bench',
    'cone',
    'sign',
    'house1',
    'house2',
    'house3',
    // 길가 건물 후보 (높이 다양화: 가게 86~102 · 주택 96~104 · 아파트 114~119 px)
    'shop1', 'shop2', 'shop3', 'home0', 'home1', 'home3', 'bake1', 'bake2', 'bake3',
    'apt0', 'apt1', 'apt2', 'apt3',
    // 배경 소품 (창고 밖 휴식 자리 옆 · 입구 안쪽)
    'vend', 'locker', 'extinguisher',
    'pallet',
    'flower',
  ];

  /// 시트: 가로 7프레임, 세로 4방향 (0 남, 1 서, 2 동, 3 북). 프레임 56x56.
  static const int frames = 7;
  static const double cell = 56;

  static Future<void> load() async {
    staffWalk = await _img('assets/sprites/staff/staff_walk.png');
    staffLooks.clear();
    if (staffWalk != null) staffLooks.add(staffWalk!);
    for (var i = 1; i <= 5; i++) {
      final im = await _img('assets/sprites/staff/staff_walk_$i.png');
      if (im != null) staffLooks.add(im);
    }
    for (var i = 0; i < custLooks; i++) {
      custWalk[i] = await _img('assets/sprites/customer/cust_$i.png');
    }
    box = await _img('assets/sprites/props/box.png');
    floor = await _img('assets/sprites/tiles/floor.png');
    counter = await _img('assets/sprites/props/counter.png');
    pack = await _img('assets/sprites/props/pack.png');
    shelf = await _img('assets/sprites/props/shelf.png');
    van = await _img('assets/sprites/props/van.png');
    truck = await _img('assets/sprites/props/truck.png');
    moto = await _img('assets/sprites/props/moto.png');
    vanFull = await _img('assets/sprites/props/van_full.png');
    truckFull = await _img('assets/sprites/props/truck_full.png');
    motoFull = await _img('assets/sprites/props/moto_full.png');
    boxS = await _img('assets/sprites/props/box_s.png');
    boxOpen = await _img('assets/sprites/props/box_open.png');
    packEmpty = await _img(
      'assets/sprites/props/pack_empty.png',
    ); // 있으면 포장 상자가 동적으로 생김
    hubCounter = await _img('assets/sprites/props/hub_counter.png');
    hubPack = await _img('assets/sprites/props/hub_pack.png');
    hubShelf = await _img('assets/sprites/props/hub_shelf.png');
    hubLounge = await _img('assets/sprites/props/hub_lounge.png');
        hubDock = await _img('assets/sprites/props/hub_dock.png');
        final lab = await _img('assets/sprites/props/hub_lab.png');
    if (lab != null) setProps['lab'] = lab;
    final cls = await _img('assets/sprites/props/hub_class.png');
    if (cls != null) setProps['classroom'] = cls;
    for (final n in const ['bin', 'chair', 'plant', 'board', 'aircon', 'conveyor']) {
      final im = await _img('assets/sprites/props/prop_$n.png');
      if (im != null) setProps[n] = im;
    }
    wangFloor = await _img('assets/sprites/tiles/wang_floor.png');
    dockTruck = await _img('assets/sprites/props/dock_truck.png');
    dockTruckFull = await _img('assets/sprites/props/dock_truck_full.png');
    roadCars.clear();
    for (final n in const ['car', 'van', 'moto']) {
      final im = await _img('assets/sprites/props/road_$n.png');
      if (im != null) roadCars.add(im);
    }
    grass = await _img('assets/sprites/tiles/grass.png');
    for (final n in const ['letter', 'teddy', 'kimchi', 'cake', 'vase', 'fish', 'docs', 'flower', 'guitar', 'medicine']) {
      final im = await _img('assets/sprites/props/story_$n.png');
      if (im != null) storyItems[n] = im;
    }
    for (final n in const ['ice', 'wrap', 'tape']) {
      final im = await _img('assets/sprites/props/fx_$n.png');
      if (im != null) fxIcons[n] = im;
    }
    for (final n in const ['done', 'broken', 'late']) {
      final im = await _img('assets/sprites/props/st_$n.png');
      if (im != null) stamps[n] = im;
    }
    storyBubble = await _img('assets/sprites/props/ui_bubble.png');
    storyAlert = await _img('assets/sprites/props/ui_alert.png');
    wallBack = await _img('assets/sprites/tiles/wall_back.png');
    wallItems = await _img('assets/sprites/tiles/wall_items.png');
    floorVar = await _img('assets/sprites/tiles/floor_var.png');
    asphalt = await _img('assets/sprites/tiles/asphalt.png');
    sidewalk = await _img('assets/sprites/tiles/sidewalk.png');
    yard = await _img('assets/sprites/tiles/yard.png');
    hub = await _img('assets/sprites/map/hub.png');
    wangRoad = await _img('assets/sprites/map/wang_road.png');
    wangWalk = await _img('assets/sprites/map/wang_walk.png');
    wangWalkOver = await _img('assets/sprites/map/wang_walk_over.png');
    wangWater = await _img('assets/sprites/map/wang_water.png');
    for (final n in mapPropNames) {
      final im = await _img('assets/sprites/map/prop_$n.png');
      if (im != null) mapProps[n] = im;
    }
    for (final n in mapHouseNames) {
      final im = await _img('assets/sprites/map/house_$n.png');
      if (im != null) mapHouses[n] = im;
    }
    for (var i = 0; i < centers.length; i++) {
      centers[i] = await _img('assets/sprites/map/center_$i.png');
    }
    for (final n in decorNames) {
      final im = await _img('assets/sprites/decor/$n.png');
      if (im != null) decor[n] = im;
    }
  }

  static Future<ui.Image?> _img(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// 직원 한 명을 그린다. (x,y)는 발 위치. dir 0남 1서 2동 3북, moving이면 걷기 모션.
  static void drawStaff(
    ui.Canvas c,
    double x,
    double y,
    int dir,
    bool moving,
    double clock, {
    int look = 0,
    double alpha = 1,
    bool work = false,
    double workHz = 7,
  }) {
    if (staffLooks.isEmpty) return;
    final img = staffLooks[look % staffLooks.length];
    final cw = img.width / frames, ch = img.height / 4;
    final f = moving ? 1 + (clock * 7).floor() % (frames - 1) : 0;
    final src = ui.Rect.fromLTWH(f * cw, dir * ch, cw, ch);
    final dst = ui.Rect.fromLTWH(x - cw / 2, y - ch * 0.86, cw, ch);
    final p = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..color = ui.Color.fromARGB((alpha * 255).round(), 255, 255, 255);
    if (work) {
      // 작업 중 모션: 발을 기준으로 몸이 리듬 있게 숙였다 올라오고 살짝 흔들림
      final ph = clock * workHz;
      final dip = (math.sin(ph) * 0.5 + 0.5); // 0~1
      c.save();
      c.translate(x, y);
      c.rotate(math.sin(ph * 0.5) * 0.05);
      c.scale(1 + dip * 0.03, 1 - dip * 0.05);
      c.translate(-x, -y);
      c.drawImageRect(img, src, dst.translate(0, dip * 1.5), p);
      c.restore();
      return;
    }
    c.drawImageRect(img, src, dst, p);
  }

  /// 손님/행인 한 명. 전용 시트가 있으면 그것을, 없으면 직원 시트를 색만 바꿔 그림.
  static void drawPerson(
    ui.Canvas c,
    double x,
    double y,
    int dir,
    bool moving,
    double clock,
    int look,
  ) {
    final own = custWalk[look % custLooks];
    final img = own ?? staffWalk;
    if (img == null) return;
    // 시트마다 한 칸 크기가 다를 수 있어 가로 7칸 기준으로 계산 (1:1 크기로 그림)
    final cw = img.width / frames, ch = img.height / 4;
    final f = moving ? 1 + (clock * 9 + look * 3).floor() % (frames - 1) : 0;
    final src = ui.Rect.fromLTWH(f * cw, dir * ch, cw, ch);
    final dst = ui.Rect.fromLTWH(x - cw / 2, y - ch * 0.86, cw, ch);
    final p = ui.Paint()..filterQuality = ui.FilterQuality.none;
    if (own == null) {
      const hues = [70.0, 140.0, 200.0, 260.0, 310.0, 30.0];
      final a = hues[look % hues.length] * math.pi / 180;
      final co = math.cos(a), si = math.sin(a);
      p.colorFilter = ui.ColorFilter.matrix(<double>[
        0.213 + co * 0.787 - si * 0.213,
        0.715 - co * 0.715 - si * 0.715,
        0.072 - co * 0.072 + si * 0.928,
        0,
        0,
        0.213 - co * 0.213 + si * 0.143,
        0.715 + co * 0.285 + si * 0.140,
        0.072 - co * 0.072 - si * 0.283,
        0,
        0,
        0.213 - co * 0.213 - si * 0.787,
        0.715 - co * 0.715 + si * 0.715,
        0.072 + co * 0.928 + si * 0.072,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    c.drawImageRect(img, src, dst, p);
  }

  /// 택배 상자. 칸 안에 맞춰 그리고 구역 색 스티커를 붙인다. 이미지가 없으면 false.
  static bool drawBox(ui.Canvas c, ui.Rect r, int stickerColor) {
    final img = box;
    if (img == null) return false;
    c.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      r,
      _np,
    );
    final s = r.width * 0.3;
    c.drawRect(
      ui.Rect.fromLTWH(r.center.dx - s / 2, r.center.dy - s * 0.1, s, s * 0.8),
      ui.Paint()..color = ui.Color(stickerColor),
    );
    return true;
  }

  /// 창고 바닥 한 칸.
  static bool drawFloor(ui.Canvas c, double x, double y, double t) {
    final img = floor;
    if (img == null) return false;
    c.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(x, y, t, t),
      _np,
    );
    return true;
  }

  static ui.Image? forBuilding(String id) {
    switch (id) {
      case 'counter':
        return hubCounter ?? counter;
      case 'pack':
        return hubPack ?? packEmpty ?? pack;
      case 'shelf':
        return hubShelf ?? shelf;
      case 'lounge':
        return hubLounge;
      case 'dock':
        return hubDock;
            case 'vending':
        return mapProps['vending'];
    }
    return setProps[id];
  }

  /// 칸(r) 안에 비율 유지로 넣고 아래에 붙임 (칸 밖으로 넘치지 않음). 1:1 보다 크게는 안 키움.
  static ui.Rect fitBottom(ui.Image img, ui.Rect r, {bool left = false}) {
    var k = (r.width / img.width) < (r.height / img.height)
        ? r.width / img.width
        : r.height / img.height;
    if (k > 1) k = 1;
    final w = img.width * k, h = img.height * k;
    final x = left ? r.left : r.center.dx - w / 2;
    return ui.Rect.fromLTWH(
      x.roundToDouble(),
      (r.bottom - h).roundToDouble(),
      w,
      h,
    );
  }

  static ui.Rect drawFitBottom(
    ui.Canvas c,
    ui.Image img,
    ui.Rect r, {
    bool left = false,
  }) {
    final dst = fitBottom(img, r, left: left);
    _blit(c, img, dst);
    return dst;
  }

  /// 칸 너비에 맞춰(비율 유지) 아래쪽 기준으로 그린다. 위로 넘쳐도 됨.
  static void drawFitWidth(ui.Canvas c, ui.Image img, ui.Rect r) {
    final h = r.width * img.height / img.width;
    _blit(c, img, ui.Rect.fromLTWH(r.left, r.bottom - h, r.width, h));
  }

  /// 칸 안에 비율을 유지하며 가운데에 맞춘다.
  /// 차량 종류 이름 → 그림 (없으면 null)
  static ui.Image? vehicleImg(String typeName) {
    switch (typeName) {
      case '대형 트럭':
        return truck;
      case '소형 트럭':
        return van;
      case '오토바이':
        return moto;
    }
    return null;
  }

  /// 상자 가득 찬 차량 그림 (없으면 null)
  static ui.Image? vehicleFullImg(String typeName) {
    switch (typeName) {
      case '대형 트럭':
        return truckFull;
      case '소형 트럭':
        return vanFull;
      case '오토바이':
        return motoFull;
    }
    return null;
  }

  /// 짐칸 위치 (그림 픽셀 기준): [왼, 위, 오른, 아래, 상자 한 변, 가로 칸 수, 세로 칸 수]
  static const Map<String, List<double>> cargoSpec = {
    '대형 트럭': [6, 4, 72, 66, 11, 6, 5],
    '소형 트럭': [10, 26, 60, 44, 12, 4, 2],
    '오토바이': [3, 3, 25, 16, 10, 2, 1],
  };

  /// drawContain 이 실제로 그리는 영역
  static ui.Rect containRect(ui.Image img, ui.Rect r) {
    final k = (r.width / img.width) < (r.height / img.height)
        ? r.width / img.width
        : r.height / img.height;
    final w = img.width * k, h = img.height * k;
    return ui.Rect.fromLTWH(r.center.dx - w / 2, r.center.dy - h / 2, w, h);
  }

  /// 차량 짐칸에 실린 만큼 상자를 쌓아 그림 (아래 칸부터)
  static void drawCargo(
    ui.Canvas c,
    String typeName,
    ui.Image img,
    ui.Rect drawn,
    int loaded,
    int cap,
  ) {
    final sp = cargoSpec[typeName];
    final bx = boxS;
    if (sp == null || bx == null || loaded <= 0) return;
    final k = drawn.width / img.width;
    final cols = sp[5].toInt(), rows = sp[6].toInt();
    final slots = (loaded / cap * cols * rows).ceil().clamp(1, cols * rows);
    final side = sp[4] * k;
    for (var i = 0; i < slots; i++) {
      final row = i ~/ cols, col = i % cols;
      final dst = ui.Rect.fromLTWH(
        drawn.left + sp[0] * k + col * side,
        drawn.top + sp[3] * k - (row + 1) * side,
        side,
        side,
      );
      c.drawImageRect(
        bx,
        ui.Rect.fromLTWH(0, 0, bx.width.toDouble(), bx.height.toDouble()),
        dst,
        _np,
      );
    }
  }

  static void drawContain(ui.Canvas c, ui.Image img, ui.Rect r) {
    final k = (r.width / img.width) < (r.height / img.height)
        ? r.width / img.width
        : r.height / img.height;
    final w = img.width * k, h = img.height * k;
    _blit(
      c,
      img,
      ui.Rect.fromLTWH(r.center.dx - w / 2, r.center.dy - h / 2, w, h),
    );
  }

  static void _blit(ui.Canvas c, ui.Image img, ui.Rect dst) {
    c.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _np,
    );
  }

  /// 32x32 바닥 한 칸. variants>1이면 가로로 이어진 시트에서 v번째를 그림.
  static bool drawTile(
    ui.Canvas c,
    ui.Image? img,
    double x,
    double y,
    double t, [
    int variants = 1,
    int v = 0,
  ]) {
    if (img == null) return false;
    final w = img.width / variants;
    c.drawImageRect(
      img,
      ui.Rect.fromLTWH(w * v, 0, w, img.height.toDouble()),
      ui.Rect.fromLTWH(x, y, t, t),
      _np,
    );
    return true;
  }

  /// 작은 상자(선반 칸용). 이미지 없으면 false.
  static bool drawSmallBox(ui.Canvas c, double x, double y, {double? w, double? h}) {
    final img = boxS;
    if (img == null) return false;
    c.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(x, y, w ?? img.width.toDouble(), h ?? img.height.toDouble()),
      _np,
    );
    return true;
  }
}
