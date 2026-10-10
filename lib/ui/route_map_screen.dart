import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/region_map.dart';
import '../game/sprites.dart';
import '../models/models.dart';
import 'fleet_widgets.dart';
import 'theme.dart';

/// 전체화면 노선 지도. 한 번에 한 지역만 보여 준다: 허브 → (도로) → 지역센터 → 동네 집들.
/// 차량이 달리는 걸 실시간으로 보고 노선을 고친다. 차량 배정·업그레이드·구입은 차고 화면(garage_screen.dart).
/// 지도는 화면보다 크고(타일 고정 크기), 드래그로 움직이거나 차량을 따라가며 본다.
class RouteMapScreen extends StatefulWidget {
  final HubGame g;
  const RouteMapScreen(this.g, {super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late int sel = g.mapSel; // 보고 있는 지역 (차고와 같이 씀)
  final _Cam cam = _Cam();
  final Stopwatch _sw = Stopwatch()..start();
  double _last = 0;

  HubGame get g => widget.g;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
    // 차고에서 '지도에서 보기'로 들어오면 그 차량을 따라감
    cam.follow = g.mapFollow;
    cam.pick = g.mapFollow;
    g.mapFollow = null;
  }

  /// 매 프레임: 관성 스크롤 / 차량 따라가기 / 지도 경계
  void _tick() {
    final now = _sw.elapsedMicroseconds / 1e6;
    final dt = (now - _last).clamp(0.0, 0.05).toDouble();
    _last = now;
    final v = cam.view;
    if (v.isEmpty) return;
    const T = _MapPainter.T;
    final l = _MapPainter.layout(sel);
    final half = Offset(v.width / 2, v.height / 2);
    if (cam.reset) {
      // 처음 들어올 때·지역을 바꿀 때: 허브와 출발 도로가 보이게
      cam.reset = false;
      cam.vel = Offset.zero;
      cam.pos = Offset((l.hubX + 4) * T, (l.hubFoot - 2.5) * T) - half;
    } else if (cam.follow != null) {
      Offset? target;
      for (final (u, pos) in _MapPainter.units(g, sel)) {
        if (u.id == cam.follow) target = pos * T - half;
      }
      // 따라가는 차량은 가운데보다 조금 아래에 둠 (위쪽 정보 카드와 말풍선이 안 겹치게)
      if (target != null) target = target - Offset(0, v.height * 0.15);
      if (target == null) {
        cam.follow = null;
      } else {
        cam.pos += (target - cam.pos) * min(1.0, dt * 6);
      }
    } else if (cam.vel.distance > 8) {
      cam.pos += cam.vel * dt;
      cam.vel *= pow(0.03, dt).toDouble();
    } else {
      cam.vel = Offset.zero;
    }
    double fit(double p, double world, double view) =>
        world <= view ? (world - view) / 2 : p.clamp(0.0, world - view).toDouble();
    final nx = fit(cam.pos.dx, l.gw * T, v.width), ny = fit(cam.pos.dy, l.gh * T, v.height);
    // 가장자리에 닿으면 그 방향 관성은 멈춤
    cam.vel = Offset(nx == cam.pos.dx ? cam.vel.dx : 0, ny == cam.pos.dy ? cam.vel.dy : 0);
    cam.pos = Offset(nx, ny);
  }

  /// 지도를 탭: 가까운 차량이 있으면 그 차량 정보 카드, 없으면 카드 닫기
  void _tapMap(Offset local) {
    const T = _MapPainter.T;
    final tile = (local + cam.pos) / T;
    int? best;
    var bd = 1.3;
    for (final (u, pos) in _MapPainter.units(g, sel)) {
      // 차량 그림은 발 밑에서 위로 그려지므로 조금 위쪽까지 맞은 걸로 침
      final d = (tile - pos.translate(0, -0.3)).distance;
      if (d < bd) {
        bd = d;
        best = u.id;
      }
    }
    setState(() => cam.pick = best);
  }


  /// 고른 차량 정보: 기사 이름·능력, 차량 레벨·상태·적재, 따라가기
  Widget _unitInfo() {
    FleetUnit? u;
    for (final x in g.fleet) {
      if (x.id == cam.pick && x.region == sel) u = x;
    }
    if (u == null) return const SizedBox();
    final unit = u;
    final img = unitImage(unit.type, full: unit.state == 1 && unit.cargo > 0);
    final following = cam.follow == unit.id;
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xF2FFF6DE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.frame, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 34,
            child: img == null
                ? const SizedBox()
                : RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.none),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${unit.driver} · ${Cfg.skillName[unit.skill]}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                Text('${skillStars(unit.skill)}  ${unit.name} Lv.${unit.level}',
                    style: const TextStyle(color: C.gold, fontSize: 10)),
                Text(unitState(unit), style: const TextStyle(color: C.sub, fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              cam.follow = following ? null : unit.id;
              cam.vel = Offset.zero;
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: following ? C.accent : C.line,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.my_location, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _select(int i) {
    g.mapSel = i;
    setState(() => sel = i);
    cam.reset = true;
    cam.follow = null;
    cam.pick = null;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Material(
      color: C.bg,
      child: Column(
        children: [
          _top(mq),
          _regionBar(),
          Expanded(
            flex: 11,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(builder: (context, box) {
                  cam.view = box.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (_) => cam.vel = Offset.zero,
                    onPanUpdate: (d) {
                      cam.follow = null;
                      cam.pos -= d.delta;
                    },
                    onPanEnd: (d) => cam.vel = -d.velocity.pixelsPerSecond,
                    onTapUp: (d) => _tapMap(d.localPosition),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _MapPainter(g, _anim, sel, cam, mq.devicePixelRatio)),
                        ValueListenableBuilder<int>(
                          valueListenable: g.tick,
                          builder: (context, _, __) => _mapHud(),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: ValueListenableBuilder<int>(
              valueListenable: g.tick,
              builder: (context, _, __) => _panel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _top(MediaQueryData mq) {
    return ValueListenableBuilder<int>(
      valueListenable: g.tick,
      builder: (context, _, __) => Container(
        padding: EdgeInsets.fromLTRB(6, mq.padding.top + 4, 10, 6),
        decoration: const BoxDecoration(
          color: C.panel,
          border: Border(bottom: BorderSide(color: C.frame, width: 3)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: C.frame),
              onPressed: () => g.goScreen(0),
            ),
            const Expanded(child: Align(alignment: Alignment.centerLeft, child: TitlePlate('노선 지도', color: C.blue))),
            Pill(Icons.star, '명성 ${g.fame}', color: C.accent),
            const SizedBox(width: 6),
            Pill(Icons.monetization_on, g.fmt(g.money), color: C.gold),
          ],
        ),
      ),
    );
  }

  /// 지역 고르는 줄
  Widget _regionBar() {
    return ValueListenableBuilder<int>(
      valueListenable: g.tick,
      builder: (context, _, __) => Container(
        height: 44,
        color: C.panel,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < Cfg.regionName.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => _select(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel == i ? Color(Cfg.regionColor[i]) : C.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!g.regionOpen[i])
                          Icon(Icons.lock,
                              size: 12, color: sel == i ? Colors.black : C.sub),
                        if (!g.regionOpen[i]) const SizedBox(width: 2),
                        Text(
                          Cfg.regionName[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: sel == i
                                ? Colors.black
                                : (g.regionOpen[i] ? Colors.white : C.sub),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 지도 위에 얹는 정보 (재고·소식·잠김 안내)
  Widget _mapHud() {
    final open = g.regionOpen[sel];
    return Stack(
      children: [
        if (open)
          Positioned(
            left: 8,
            top: 8,
            child: _hudPill(
                '${Cfg.regionName[sel]} · 허브 ${g.regionStock(sel)}건 → 센터 ${g.centerStock[sel]}건'),
          ),
        if (open)
          Positioned(
            right: 8,
            top: 8,
            left: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final n in g.notes.take(2))
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xF2FFF6DE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.frame, width: 1.5),
                    ),
                    child: Text(n.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: shade(Color(n.color), 0.4), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        // 지도 칸 안의 아래쪽 (화면 맨 아래가 아니라서 시스템 바·화면 탭 여백은 안 씀)
        Positioned(left: 8, bottom: 8, child: _camButtons()),
        if (open && cam.pick != null) Positioned(left: 8, top: 40, child: _unitInfo()),
        Positioned(right: 8, bottom: 8, child: _miniMap()),
        if (!open)
          Positioned.fill(
            child: Container(
              color: const Color(0xCCFFF4D8),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: C.frame, size: 36),
                  const SizedBox(height: 6),
                  Text('${Cfg.regionName[sel]} 지역',
                      style: Tx.title),
                  const SizedBox(height: 4),
                  Text('명성 ${Cfg.regionFame[sel]} 필요 (지금 ${g.fame})',
                      style: Tx.body),
                  const SizedBox(height: 10),
                  AppButton('지역 열기',
                      color: C.good,
                      onTap: g.canUnlockRegion(sel)
                          ? () => g.unlockRegion(sel)
                          : null),
                  if (sel > 0 && !g.regionOpen[sel - 1])
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('앞 지역을 먼저 열어야 해요', style: Tx.sub),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 허브로 돌아가기 + 차량 따라가기 (탭할 때마다 다음 차량, 끝나면 끔)
  Widget _camButtons() {
    final list = [for (final (u, _) in _MapPainter.units(g, sel)) u];
    FleetUnit? cur;
    for (final u in list) {
      if (u.id == cam.follow) cur = u;
    }
    Widget btn(IconData icon, String text, bool on, VoidCallback f) => GestureDetector(
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: on ? C.accent : const Color(0xF2FFF6DE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.frame, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: on ? Colors.white : C.text),
              const SizedBox(width: 4),
              Text(text,
                  style: TextStyle(
                      color: on ? Colors.white : C.text, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.home_work, '허브', false, () {
          cam.follow = null;
          cam.reset = true;
        }),
        const SizedBox(height: 6),
        if (g.regionOpen[sel] && list.isNotEmpty)
          btn(Icons.my_location, cur == null ? '차량 따라가기' : '${cur.driver} (${cur.name}) 따라가는 중',
              cur != null, () {
            // 실제로 달리는 차량부터, 없으면 도크에서 싣는 차량, 그것도 없으면 전부
            final moving = list.where((u) => u.state == 1 || u.state == 2).toList();
            final busy = list.where((u) => u.busy).toList();
            final pick = moving.isNotEmpty ? moving : (busy.isNotEmpty ? busy : list);
            final i = cur == null ? 0 : pick.indexOf(cur) + 1;
            cam.follow = i < pick.length ? pick[i].id : null;
            cam.pick = cam.follow;
            cam.vel = Offset.zero;
            g.ui();
          }),
      ],
    );
  }

  /// 미니맵: 탭하거나 끌어서 그 곳으로 이동
  Widget _miniMap() {
    final l = _MapPainter.layout(sel);
    const w = 112.0;
    final h = w * l.gh / l.gw;
    void jump(Offset p) {
      const T = _MapPainter.T;
      final tile = p / (w / l.gw);
      cam.follow = null;
      cam.vel = Offset.zero;
      cam.pos = tile * T - Offset(cam.view.width / 2, cam.view.height / 2);
    }

    return GestureDetector(
      onTapDown: (d) => jump(d.localPosition),
      onPanUpdate: (d) => jump(d.localPosition),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: C.frame, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(size: Size(w, h), painter: _MiniMap(g, _anim, sel, cam)),
      ),
    );
  }

  Widget _hudPill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xF2FFF6DE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.frame, width: 2),
      ),
      child: Text(t,
          style: const TextStyle(
              color: C.text, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _panel() {
    final n = g.fleet.where((u) => u.region == sel).length;
    return Container(
      color: C.panel,
      child: Column(
        children: [
          // 차량 관리는 차고 화면으로 옮김
          InkWell(
            onTap: () => g.goScreen(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: C.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${Cfg.regionName[sel]} 노선 차량 $n대 · 업그레이드·구입은 차고에서', style: Tx.sub)),
                  const Icon(Icons.chevron_right, color: C.sub),
                ],
              ),
            ),
          ),
          Expanded(child: _routeTab()),
        ],
      ),
    );
  }

  // ---------------- 노선 탭 ----------------
  Widget _routeTab() {
    if (!g.regionOpen[sel]) {
      return Center(
        child: Text('${Cfg.regionName[sel]} 지역은 아직 닫혀 있어요 (명성 ${Cfg.regionFame[sel]})',
            style: Tx.sub),
      );
    }
    final rt = g.routes[sel];
    final color = Color(Cfg.regionColor[sel]);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${Cfg.regionName[sel]} 노선 · 집 ${RegionMap.of(sel).houses.length}채',
                        style: Tx.h2),
                  ),
                  Switch(
                    value: rt.on,
                    activeColor: C.good,
                    onChanged: (v) {
                      rt.on = v;
                      g.ui();
                    },
                  ),
                ],
              ),
              Text(
                  '대형 트럭 ${g.trunkCount(sel)}대 · 배달 차량 ${g.courierCount(sel)}대 · 편도 ${RegionMap.of(sel).tripSec.round()}초',
                  style: Tx.sub),
              const SizedBox(height: 6),
              _row('대기', [
                for (final w in Cfg.waitOptions)
                  _chip('${w.round()}초', rt.wait == w, () {
                    rt.wait = w;
                    g.ui();
                  }),
              ]),
              _row('우선', [
                for (var p = 1; p <= 3; p++)
                  _chip(p == 1 ? '보통' : (p == 2 ? '높음' : '최우선'), rt.prio == p, () {
                    rt.prio = p;
                    g.ui();
                  }),
              ]),
              const SizedBox(height: 6),
              const Text('대기: 더 실을 택배가 없을 때 트럭이 기다리는 시간 · 우선: 여러 노선이 동시에 준비되면 높은 쪽이 먼저',
                  style: Tx.sub),
            ],
          ),
        ),
        if (g.trunkCount(sel) == 0 || g.courierCount(sel) == 0) ...[
          const SizedBox(height: 8),
          CardBox(
            child: Text(
                g.trunkCount(sel) == 0
                    ? '이 노선에는 대형 트럭이 없어요. 차량 구입 탭에서 사거나, 내 차량 탭에서 다른 지역 차량을 옮겨 오세요.'
                    : '이 노선에는 배달 차량이 없어 센터에 택배가 쌓여요. 오토바이나 소형 트럭을 배정하세요.',
                style: const TextStyle(color: C.gold, fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: Tx.sub)),
          Expanded(child: Wrap(spacing: 6, children: chips)),
        ],
      ),
    );
  }

  Widget _chip(String text, bool on, VoidCallback f) {
    return GestureDetector(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? C.accent : C.line,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }

  // ---------------- 내 차량 탭 ----------------
}

// ======================================================================
//                              지도 그리기
// ======================================================================

/// 카메라: 지도 중 화면에 보이는 영역 (dp). 드래그·관성·차량 따라가기를 여기서 처리.
class _Cam {
  Offset pos = Offset.zero; // 보이는 영역 왼쪽 위
  Offset vel = Offset.zero; // 손을 뗀 뒤 관성 속도 (dp/초)
  Size view = Size.zero;
  int? follow; // 따라가는 차량 id (null 이면 자유 드래그)
  int? pick; // 탭해서 정보 카드를 연 차량 id
  bool reset = true; // 다음 프레임에 허브 쪽으로 이동
}

class _MapPainter extends CustomPainter {
  final HubGame g;
  final int sel;
  final _Cam cam;
  final double dpr;
  _MapPainter(this.g, Listenable repaint, this.sel, this.cam, this.dpr) : super(repaint: repaint);

  /// 한 칸 = 32dp. 도트 1px = 1dp 로 그려서 화면에 맞추려고 줄이지 않는다.
  static const double T = 32;
  static const double bigScale = 1.25; // 허브·센터 건물 배율
  static const double stopTime = 1.2; // 교차로·건널목에서 잠깐 서는 시간(초)

  /// 소품 배율 (64 캔버스로 뽑아 원본이 커서 집 크기에 맞게 줄임)
  static const Map<String, double> propScale = {
    'mailbox': 0.55, 'vending': 0.6, 'busstop': 0.85, 'billboard': 0.8, 'haystack': 0.5,
    'fence': 0.6, 'crops': 0.9, 'fountain': 0.9, 'hwsign': 0.75, 'gas': 1.0,
    'container': 0.55, 'crane': 0.75, 'boat': 0.7, 'factory': 0.75, 'tank': 0.5,
  };

  /// 지역 지도 (lib/game/region_map.dart 가 설정값으로 만든다)
  static RegionMap layout(int r) => RegionMap.of(r);

  // ---- 길 따라 위치 구하기 ----
  static double _len(List<Offset> p) {
    var s = 0.0;
    for (var i = 0; i + 1 < p.length; i++) {
      s += (p[i + 1] - p[i]).distance;
    }
    return s;
  }

  static Offset _pointAt(List<Offset> p, double dist) {
    var d = dist;
    for (var i = 0; i + 1 < p.length; i++) {
      final seg = (p[i + 1] - p[i]).distance;
      if (d <= seg || i + 2 == p.length) {
        final f = seg <= 0 ? 0.0 : (d / seg).clamp(0.0, 1.0).toDouble();
        return Offset.lerp(p[i], p[i + 1], f)!;
      }
      d -= seg;
    }
    return p.last;
  }

  /// 진행률 p(0~1) → 길 따라 거리. 정차 지점마다 w 만큼 멈춰 선다.
  static double _distAt(double p, double len, List<double> stops, double w) {
    final m = 1 - stops.length * w;
    final v = len / m;
    var tt = p, prev = 0.0;
    for (final sd in stops) {
      final need = (sd - prev) / v;
      if (tt <= need) return prev + tt * v;
      tt -= need;
      if (tt <= w) return sd;
      tt -= w;
      prev = sd;
    }
    return min(len, prev + tt * v);
  }

  static List<Offset> _path(FleetUnit u, RegionMap l) =>
      u.isTrunk ? l.trunk : l.courier[u.house % l.courier.length];

  static List<double> _stops(FleetUnit u, RegionMap l) =>
      u.isTrunk ? l.trunkStops : l.courierStops[u.house % l.courierStops.length];

  /// 차량의 지도 위 위치(칸 좌표). slot 은 대기 줄 순서.
  static Offset unitPos(FleetUnit u, RegionMap l, int slot) {
    final path = _path(u, l);
    final len = _len(path);
    final stops = _stops(u, l);
    if (u.state == 1 || u.state == 2) {
      final total = u.state == 1 ? u.dur + u.delay : u.dur;
      final p = total <= 0 ? 1.0 : (u.t / total).clamp(0.0, 1.0).toDouble();
      // 한 번 서는 시간이 전체의 몇 %인지 (정차가 많아도 이동이 30% 밑으로는 안 줄게)
      final w = stops.isEmpty ? 0.0 : min(stopTime / max(total, 1), 0.7 / stops.length);
      if (u.state == 1) return _pointAt(path, _distAt(p, len, stops, w));
      final back = [for (final s in stops.reversed) len - s];
      return _pointAt(path, len - _distAt(p, len, back, w));
    }
    // 대형 트럭은 허브 도크 앞, 배달 차량은 센터 앞에서 대기
    return u.isTrunk
        ? Offset(l.hubX + 1.2 + (slot % 3) * 2.7, l.hubFoot + 1.9)
        : l.courierHome.translate((slot % 3) * 1.2, 0);
  }

  /// 지역 sel 의 차량별 위치 (그리기·따라가기·미니맵이 같이 씀)
  static List<(FleetUnit, Offset)> units(HubGame g, int sel) {
    final l = layout(sel);
    var tw = 0, cr = 0;
    return [
      for (final u in g.fleet)
        if (u.region == sel) (u, unitPos(u, l, u.isTrunk ? tw++ : cr++)),
    ];
  }

  static final Map<int, bool> _faceRight = {};

  // ---- 그리기 ----
  final double t = T;
  late RegionMap l;
  late Rect view; // 보이는 영역 (칸 좌표)

  Offset _px(Offset tile) => tile * t;

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF4F8A43));
    final open = g.regionOpen[sel];
    l = layout(sel);
    // 기기 픽셀에 맞춰 이동 (타일 사이 틈 방지)
    final ox = (cam.pos.dx * dpr).roundToDouble() / dpr;
    final oy = (cam.pos.dy * dpr).roundToDouble() / dpr;
    view = Rect.fromLTWH(ox / t, oy / t, s.width / t, s.height / t);
    c.save();
    c.translate(-ox, -oy);

    // 1) 땅: 잔디 + 도로 + 동네 길 + 차선·건널목. 8x8칸 묶음 이미지로 구워 두고 보이는 묶음만 그림
    if (Sprites.wangRoad != null && Sprites.wangWalk != null) {
      _groundChunks(c);
    } else {
      _ground(c);
      _roadMarks(c, l.trunk);
      for (final rd in l.roads) {
        _roadMarks(c, rd);
      }
      _crosswalks(c);
    }

    // 2) 세워진 것들을 아래쪽 순서대로 그림 (앞에 있는 게 위에 오도록). 화면 밖은 건너뜀
    final cull = view.inflate(3);
    final items = <_Item>[];
    for (final d in l.decor) {
      if (cull.contains(Offset(d.x, d.y))) items.add(_Item(d.y, (cv) => _decor(cv, d)));
    }
    for (var k = 0; k < l.houses.length; k++) {
      final h = l.houses[k];
      if (cull.contains(Offset(h.x, h.y))) items.add(_Item(h.y, (cv) => _house(cv, h)));
    }
    if (cull.overlaps(Rect.fromLTRB(l.hubX - 1, l.hubFoot - 6, l.hubX + 7, l.hubFoot + 1))) {
      items.add(_Item(l.hubFoot, (cv) => _hub(cv)));
    }
    if (cull.overlaps(Rect.fromLTRB(l.cx0 - 3, l.cFoot - 6, l.cx0 + 6, l.cFoot + 2))) {
      items.add(_Item(l.cFoot, (cv) => _center(cv, open)));
    }
    if (open) {
      for (final (u, pos) in units(g, sel)) {
        if (cull.contains(pos)) items.add(_Item(pos.dy + 0.4, (cv) => _unit(cv, u, pos)));
      }
    }
    items.sort((a, b) => a.y.compareTo(b.y));
    for (final it in items) {
      it.draw(c);
    }
    if (open) _effects(c);
    c.restore();

    // 3) 화면 효과 (비)
    if (open) _rain(c, s);
  }

  static final Paint _tp = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// 이중 격자: 그리는 칸(i,j)은 지도 칸 (i-1..i, j-1..j) 네 칸의 중심을 꼭짓점으로 써서
  /// Wang 코너 타일을 고른다. 그래서 길이 정확히 칸 폭으로 나오고 가장자리가 자연스럽다.
  // ---- 땅 묶음 이미지 (한 지역만 보관, 지역을 바꾸면 비움) ----
  static const int chunk = 8;
  static final Map<int, ui.Image> _chunks = {};
  static int _chunkRegion = -1;

  void _groundChunks(Canvas c) {
    if (_chunkRegion != sel) {
      for (final im in _chunks.values) {
        im.dispose();
      }
      _chunks.clear();
      _chunkRegion = sel;
    }
    const px = chunk * T;
    final cx0 = max(0, (view.left / chunk).floor()), cx1 = min((l.gw - 1) ~/ chunk, (view.right / chunk).floor());
    final cy0 = max(0, (view.top / chunk).floor()), cy1 = min((l.gh - 1) ~/ chunk, (view.bottom / chunk).floor());
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        final img = _chunks[cy * 1000 + cx] ??= _bakeChunk(cx, cy);
        c.drawImageRect(img, const Rect.fromLTWH(0, 0, px, px),
            Rect.fromLTWH(cx * px, cy * px, px, px), _tp);
      }
    }
  }

  /// 묶음 하나를 도트 1px = 1dp 크기 이미지로 굽기
  ui.Image _bakeChunk(int cx, int cy) {
    const px = chunk * T;
    final rec = ui.PictureRecorder();
    final cc = Canvas(rec);
    cc.clipRect(const Rect.fromLTWH(0, 0, px, px));
    cc.translate(-cx * px, -cy * px);
    final saved = view;
    view = Rect.fromLTWH(cx * chunk.toDouble(), cy * chunk.toDouble(), chunk.toDouble(), chunk.toDouble());
    _ground(cc);
    _roadMarks(cc, l.trunk);
    for (final rd in l.roads) {
      _roadMarks(cc, rd);
    }
    _crosswalks(cc);
    view = saved;
    return rec.endRecording().toImageSync(px.toInt(), px.toInt());
  }

  void _ground(Canvas c) {
    final road = Sprites.wangRoad, walk = Sprites.wangWalk;
    final x0 = max(0, view.left.floor()), x1 = min(l.gw, view.right.ceil() + 1);
    final y0 = max(0, view.top.floor()), y1 = min(l.gh, view.bottom.ceil() + 1);
    for (var j = y0; j <= y1; j++) {
      for (var i = x0; i <= x1; i++) {
        final nw = l.at(i - 1, j - 1), ne = l.at(i, j - 1), sw = l.at(i - 1, j), se = l.at(i, j);
        int mask(int v) =>
            (nw == v ? 8 : 0) | (ne == v ? 4 : 0) | (sw == v ? 2 : 0) | (se == v ? 1 : 0);
        final dst = Rect.fromLTWH((i - 0.5) * t, (j - 0.5) * t, t, t);
        final mr = mask(1), mw = mask(2), ms = mask(3);
        if (road == null || walk == null) {
          // 타일셋이 없으면 단색
          final v = mr != 0 ? 1 : (mw != 0 ? 2 : (ms != 0 ? 3 : 0));
          c.drawRect(
              dst,
              Paint()
                ..color = const [Color(0xFF69A857), Color(0xFF3A3A48), Color(0xFFB9B5A8), Color(0xFF3F78C8)][v]);
          continue;
        }
        if (ms != 0 && mr == 0 && mw == 0) {
          final sea = Sprites.wangWater;
          if (sea != null) {
            _wang(c, sea, ms, dst);
          } else {
            c.drawRect(dst, Paint()..color = ms == 15 ? const Color(0xFF3F78C8) : const Color(0xFF69A857));
          }
          continue;
        }
        if (mr != 0) {
          _wang(c, road, mr, dst);
          final over = Sprites.wangWalkOver;
          if (mw != 0 && over != null) _wang(c, over, mw, dst);
        } else if (mw != 0) {
          _wang(c, walk, mw, dst);
        } else {
          _grass(c, i, j, dst);
        }
      }
    }
  }

  /// 건널목: 골목이 차도를 건너는 칸에 흰 줄무늬 (건너는 방향으로 긴 막대)
  void _crosswalks(Canvas c) {
    final p = Paint()..color = const Color(0xE6F2F2F2);
    final vis = view.inflate(1);
    for (final k in l.cross) {
      final x = k % l.gw, y = k ~/ l.gw;
      if (!vis.contains(Offset(x + 0.5, y + 0.5))) continue;
      bool lane(int xx, int yy) => l.at(xx, yy) == 2 || l.cross.contains(yy * l.gw + xx);
      final vertical = lane(x, y - 1) || lane(x, y + 1);
      for (var i = 0; i < 3; i++) {
        final f = 0.12 + i * 0.3;
        c.drawRect(
            vertical
                ? Rect.fromLTWH((x + f) * t, y * t, t * 0.17, t)
                : Rect.fromLTWH(x * t, (y + f) * t, t, t * 0.17),
            p);
      }
    }
  }

  void _wang(Canvas c, ui.Image sheet, int idx, Rect dst) {
    final w = sheet.width / 16;
    c.drawImageRect(sheet, Rect.fromLTWH(w * idx, 0, w, sheet.height.toDouble()), dst, _tp);
  }

  /// 잔디는 여러 장을 섞어 반복 무늬가 덜 보이게
  void _grass(Canvas c, int i, int j, Rect dst) {
    final h = ((i * 73856093) ^ (j * 19349663) ^ (sel * 83492791)) & 0x7fffffff;
    final v = h % 7;
    if (v < 2) {
      _wang(c, v == 0 ? Sprites.wangRoad! : Sprites.wangWalk!, 0, dst);
      return;
    }
    final img = Sprites.grass;
    if (img == null) {
      _wang(c, Sprites.wangRoad!, 0, dst);
      return;
    }
    final w = img.width / 4;
    c.drawImageRect(img, Rect.fromLTWH(w * ((v - 2) % 4), 0, w, img.height.toDouble()), dst, _tp);
  }

  void _roadMarks(Canvas c, List<Offset> path) {
    final p = Paint()
      ..color = const Color(0xCCFFD166)
      ..strokeWidth = 2;
    final vis = view.inflate(1);
    for (var i = 0; i + 1 < path.length; i++) {
      final a = path[i], b = path[i + 1];
      if (!vis.overlaps(Rect.fromPoints(a, b).inflate(0.1))) continue;
      final pa = _px(a), pb = _px(b);
      final len = (pb - pa).distance;
      if (len < 1) continue;
      final dir = (pb - pa) / len;
      final step = t * 0.7;
      for (var d = t * 0.15; d < len; d += step) {
        c.drawLine(pa + dir * d, pa + dir * min(d + step * 0.4, len), p);
      }
    }
  }

  /// 스프라이트를 발 밑 기준으로 도트 1px = 1dp × scale 로 그림
  Rect _sprite(Canvas c, ui.Image img, double footX, double footY, double scale,
      {Paint? paint, bool leftAlign = false}) {
    final w = img.width * scale * t / 32, h = img.height * scale * t / 32;
    final left = leftAlign ? footX * t : footX * t - w / 2;
    final dst = Rect.fromLTWH(left, footY * t - h, w, h);
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
        paint ?? _tp);
    return dst;
  }

  void _decor(Canvas c, MapDec d) {
    final img = d.key.startsWith('p:') ? Sprites.mapProps[d.key.substring(2)] : Sprites.decor[d.key];
    if (img == null && d.key.startsWith('p:')) return; // 소품 그림이 없으면 생략
    if (img != null && d.key.startsWith('p:')) {
      _sprite(c, img, d.x, d.y, propScale[d.key.substring(2)] ?? 1);
      return;
    }
    if (img == null) {
      c.drawCircle(_px(Offset(d.x, d.y - 0.5)), t * 0.4, Paint()..color = const Color(0xFF2F6B35));
      return;
    }
    _sprite(c, img, d.x, d.y, 1);
  }

  void _house(Canvas c, MapHouse hs) {
    final img = Sprites.mapHouses[hs.key] ?? Sprites.decor[hs.key] ?? Sprites.decor['house1'];
    if (img == null) {
      final r = Rect.fromLTWH((hs.x - 1) * t, (hs.y - 1.6) * t, 2 * t, 1.6 * t);
      c.drawRect(r, Paint()..color = const Color(0xFFE8D9B5));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.35),
          Paint()..color = const Color(0xFFB5523B));
      return;
    }
    // 지도 전용 집은 원본 크기, 가게(128 캔버스)는 집 폭에 맞게 줄임
    final scale = min(1.0, 2.4 * 32 / img.width);
    _sprite(c, img, hs.x, hs.y, scale);
  }

  /// 도트풍 사각형 (검은 테두리)
  void _block(Canvas c, Rect r, Color fill, {Color edge = const Color(0xFF2A2438)}) {
    final rr = Rect.fromLTRB(
        r.left.roundToDouble(), r.top.roundToDouble(), r.right.roundToDouble(), r.bottom.roundToDouble());
    c.drawRect(rr, Paint()..color = edge);
    c.drawRect(rr.deflate(max(1.0, t * 0.06)), Paint()..color = fill);
  }

  /// 건물 위 이름표
  void _tag(Canvas c, Rect building, String name, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(
          text: name, style: TextStyle(color: fg, fontSize: t * 0.44, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tag = Rect.fromCenter(
        center: Offset(building.center.dx, building.top - tp.height * 0.2),
        width: tp.width + t * 0.5,
        height: tp.height + t * 0.12);
    c.drawRRect(RRect.fromRectAndRadius(tag, Radius.circular(t * 0.2)), Paint()..color = bg);
    tp.paint(c, Offset(tag.center.dx - tp.width / 2, tag.center.dy - tp.height / 2));
  }

  void _shadow(Canvas c, Rect dst) {
    c.drawOval(Rect.fromLTWH(dst.left + dst.width * 0.04, dst.bottom - t * 0.22, dst.width * 0.96, t * 0.4),
        Paint()..color = const Color(0x33000000));
  }

  void _hub(Canvas c) {
    final img = Sprites.hub;
    if (img != null) {
      final w = img.width * bigScale * t / 32, h = img.height * bigScale * t / 32;
      final dst = Rect.fromLTWH(l.hubX * t, l.hubFoot * t - h, w, h);
      _shadow(c, dst);
      _sprite(c, img, l.hubX, l.hubFoot, bigScale, leftAlign: true);
      _tag(c, dst, '허브', C.accent, Colors.white);
      return;
    }
    final r = Rect.fromLTRB(l.hubX * t, (l.hubFoot - 3.6) * t, (l.hubX + 3.6) * t, l.hubFoot * t);
    _block(c, r, const Color(0xFFD9CFC0));
    _block(c, Rect.fromLTRB(r.left - t * 0.1, r.top - t * 0.1, r.right + t * 0.1, r.top + t * 0.9),
        C.accent);
    for (var i = 0; i < 2; i++) {
      final x = r.left + t * (0.45 + i * 1.6);
      _block(c, Rect.fromLTWH(x, r.bottom - t * 1.5, t * 1.2, t * 1.5), const Color(0xFF55506E));
    }
    _tag(c, r, '허브', C.accent, Colors.white);
  }

  void _center(Canvas c, bool open) {
    final col = Color(Cfg.regionColor[sel]);
    final name = '${Cfg.regionName[sel]} 센터';
    final tagBg = open ? col : const Color(0xFF8A8799);
    final tagFg = open ? Colors.black : Colors.white70;
    final img = Sprites.centers[sel];
    if (img != null) {
      final w = img.width * bigScale * t / 32, h = img.height * bigScale * t / 32;
      final dst = Rect.fromLTWH(l.cx0 * t, l.cFoot * t - h, w, h);
      _shadow(c, dst);
      final p = Paint()..filterQuality = FilterQuality.none;
      if (!open) {
        p.colorFilter = const ColorFilter.matrix(<double>[
          0.25, 0.45, 0.1, 0, 10, //
          0.25, 0.45, 0.1, 0, 10, //
          0.25, 0.45, 0.1, 0, 14, //
          0, 0, 0, 1, 0,
        ]);
      }
      _sprite(c, img, l.cx0, l.cFoot, bigScale, paint: p, leftAlign: true);
      _tag(c, dst, name, tagBg, tagFg);
    } else {
      final r = Rect.fromLTRB(l.cx0 * t, (l.cFoot - 3.2) * t, (l.cx0 + 4.5) * t, l.cFoot * t);
      _block(c, r, open ? const Color(0xFFE6DDCF) : const Color(0xFFB9B5A8));
      _block(c, Rect.fromLTRB(r.left - t * 0.1, r.top - t * 0.1, r.right + t * 0.1, r.top + t * 0.95),
          tagBg);
      _tag(c, r, name, tagBg, tagFg);
    }
    // 내려둔 택배 더미 (센터 왼쪽 앞, 도로 끝)
    final n = g.centerStock[sel];
    if (n > 0) {
      final base = _px(Offset(l.cx0 + 4.9, l.cFoot - 1.0));
      final img = Sprites.boxS;
      final cnt = min(n, 9);
      final bs = t * 0.4;
      for (var i = 0; i < cnt; i++) {
        final cx = base.dx + (i % 3) * bs * 1.05;
        final cy = base.dy + t * 0.95 - (i ~/ 3) * bs * 0.95 - bs;
        final dst = Rect.fromLTWH(cx, cy, bs, bs);
        if (img != null) {
          c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              dst, _tp);
        } else {
          c.drawRect(dst, Paint()..color = const Color(0xFFC89B5E));
        }
      }
      if (n > 9) _label(c, '$n', base.translate(t * 0.65, t * 0.1), t * 0.4, Colors.white);
    }
  }

  void _label(Canvas c, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _unit(Canvas c, FleetUnit u, Offset tilePos) {
    final loaded = u.state == 1 && u.cargo > 0;
    final img = u.isTrunk
        ? (loaded ? Sprites.truckFull ?? Sprites.truck : Sprites.truck)
        : (u.type == 1
            ? (loaded ? Sprites.vanFull ?? Sprites.van : Sprites.van)
            : (loaded ? Sprites.motoFull ?? Sprites.moto : Sprites.moto));
    final wTiles = u.isTrunk ? 2.5 : (u.type == 1 ? 1.8 : 1.1);
    final w = wTiles * t;
    final bob = (u.state == 1 || u.state == 2) ? sin(g.clock * 14 + u.id) * 0.5 : 0.0;
    final foot = _px(tilePos).translate(0, t * 0.45 + bob);
    // 방향 (움직일 때만 갱신)
    if (u.state == 1 || u.state == 2) {
      final ahead = _heading(u);
      if (ahead.abs() > 0.01) _faceRight[u.id] = ahead > 0;
    }
    final right = _faceRight[u.id] ?? true;
    // 따라가는 차량 표시
    if (cam.follow == u.id) {
      c.drawOval(Rect.fromCenter(center: foot.translate(0, -t * 0.05), width: w * 1.1, height: t * 0.5),
          Paint()
            ..color = const Color(0xCCFFD166)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    // 그림자
    c.drawOval(Rect.fromCenter(center: foot.translate(0, -t * 0.05), width: w * 0.9, height: t * 0.32),
        Paint()..color = const Color(0x44000000));
    if (img == null) {
      c.drawCircle(foot.translate(0, -t * 0.4), t * 0.4, Paint()..color = Colors.white);
    } else {
      final h = w * img.height / img.width;
      final dst = Rect.fromLTWH(foot.dx - w / 2, foot.dy - h, w, h);
      c.save();
      final age = u.evtT > 0 ? Cfg.evtShow - u.evtT : 99.0; // 사건이 난 뒤 지난 시간
      if (age < 0.6) {
        c.translate(sin(age * 60) * t * 0.08 * (1 - age / 0.6), 0); // 덜컹
      }
      if (u.evtT > 0 && !u.evtOk && u.evtKind == 2) {
        // 펑크: 뒷바퀴 쪽으로 주저앉음
        final k = min(1.0, age / 0.3);
        c.translate(foot.dx, foot.dy);
        c.rotate((right ? 1 : -1) * 0.09 * k);
        c.translate(-foot.dx, -foot.dy);
      }
      if (!right) {
        c.translate(foot.dx, 0);
        c.scale(-1, 1);
        c.translate(-foot.dx, 0);
      }
      c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          dst,
          Paint()..filterQuality = FilterQuality.none);
      c.restore();
    }
    final top = foot.dy - (img == null ? t : w * img.height / img.width);
    // 고르거나 따라가는 차량은 기사 이름표
    if (cam.pick == u.id || cam.follow == u.id) {
      final tp = TextPainter(
        text: TextSpan(
            text: '${u.driver} ${'★' * u.skill}',
            style: TextStyle(color: Colors.black, fontSize: t * 0.34, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = Rect.fromCenter(
          center: Offset(foot.dx, foot.dy + t * 0.35), width: tp.width + t * 0.4, height: tp.height + t * 0.1);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(t * 0.15)),
          Paint()..color = Color(Cfg.regionColor[u.region]).withValues(alpha: 0.9));
      tp.paint(c, Offset(r.left + t * 0.2, r.top + t * 0.05));
    }
    // 싣고 있는 택배 수
    if (u.state == 1 && u.cargo > 0) {
      final tag = Rect.fromCenter(center: Offset(foot.dx, top - t * 0.3), width: t * 1.0, height: t * 0.5);
      c.drawRRect(RRect.fromRectAndRadius(tag, Radius.circular(t * 0.15)),
          Paint()..color = const Color(0xCC1E1B2E));
      _label(c, '${u.cargo}', tag.center, t * 0.36, Colors.white);
    }
    if (u.evtT > 0) _evtFx(c, u, foot, top, w, right);
    // 정체·펑크는 라바콘
    if (u.evtT > 0 && !u.evtOk && (u.evtKind == 0 || u.evtKind == 2)) {
      final cone = Sprites.decor['cone'];
      if (cone != null) {
        final cw = t * 0.55, ch = cw * cone.height / cone.width;
        c.drawImageRect(
            cone,
            Rect.fromLTWH(0, 0, cone.width.toDouble(), cone.height.toDouble()),
            Rect.fromLTWH(foot.dx + (right ? w * 0.55 : -w * 0.55 - cw), foot.dy - ch, cw, ch),
            Paint()..filterQuality = FilterQuality.none);
      }
    }
    // 이벤트 말풍선
    if (u.evtT > 0 && u.evtText != null) {
      final col = u.evtOk ? const Color(0xFF2E9E6B) : const Color(0xFFD23A40);
      final tp = TextPainter(
        text: TextSpan(
            text: u.evtText,
            style: TextStyle(color: Colors.white, fontSize: t * 0.42, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      // 처음 0.25초는 커지며 튀어나오고(살짝 넘침), 마지막 0.5초는 위로 떠오르며 사라짐
      final age = Cfg.evtShow - u.evtT;
      final pop = age < 0.25 ? Curves.easeOutBack.transform(age / 0.25) : 1.0;
      final fade = u.evtT < 0.5 ? (u.evtT / 0.5).clamp(0.0, 1.0) : 1.0;
      final lift = (1 - fade) * t * 0.6;
      c.save();
      final anchor = Offset(foot.dx, top - t * 0.5 - lift);
      c.translate(anchor.dx, anchor.dy);
      c.scale(pop, pop);
      c.translate(-anchor.dx, -anchor.dy);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fade));
      final r = Rect.fromCenter(
          center: Offset(foot.dx, top - t * 0.95 - lift),
          width: tp.width + t * 0.6,
          height: tp.height + t * 0.3);
      final bubble = Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(t * 0.25)))
        ..moveTo(foot.dx - t * 0.15, r.bottom)
        ..lineTo(foot.dx, r.bottom + t * 0.22)
        ..lineTo(foot.dx + t * 0.15, r.bottom);
      c.drawPath(bubble, Paint()..color = col);
      tp.paint(c, Offset(r.left + t * 0.3, r.top + t * 0.15));
      c.restore();
      c.restore();
    }
  }

  /// 노선 사건 연출 (evtT: Cfg.evtShow → 0). 성공은 반짝임, 실패는 종류별
  void _evtFx(Canvas c, FleetUnit u, Offset foot, double top, double w, bool right) {
    final age = Cfg.evtShow - u.evtT;
    final back = right ? -1.0 : 1.0; // 차 뒤쪽 방향
    if (u.evtOk) {
      // 성공: 별 8개가 퍼지며 사라짐
      if (age > 1.2) return;
      final k = age / 1.2;
      final p = Paint()..color = Color.fromRGBO(255, 214, 102, 1 - k);
      final ctr = Offset(foot.dx, (foot.dy + top) / 2);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + 0.3;
        final q = ctr + Offset(cos(a), sin(a)) * (w * 0.3 + k * t * 1.2);
        _star(c, q, t * 0.14 * (1 - k * 0.5), p);
      }
      return;
    }
    switch (u.evtKind) {
      case 0: // 정체: 앞에 막힌 차 2대 + 빵! + 브레이크등
        final cars = Sprites.roadCars;
        for (var i = 0; i < 2 && cars.isNotEmpty; i++) {
          final img = cars[(u.id + i) % cars.length];
          final cw = t * 1.1, chh = cw * img.height / img.width;
          final x = foot.dx - back * (w * 0.6 + t * 0.7 + i * t * 1.2);
          c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              Rect.fromLTWH(x - cw / 2, foot.dy - chh, cw, chh),
              Paint()
                ..filterQuality = FilterQuality.none
                ..color = const Color(0xCCFFFFFF));
        }
        if (sin(g.clock * 8) > 0) {
          c.drawCircle(Offset(foot.dx + back * w * 0.5, foot.dy - t * 0.25), t * 0.12, Paint()..color = const Color(0xCCFF3B30));
        }
        final h = (age * 1.5) % 1.0; // 0.7초마다 '빵!'
        if (h < 0.5) {
          _label(c, '빵!', Offset(foot.dx - back * w * 0.9, top - t * 0.2 - h * t * 0.6), t * 0.4,
              Color.fromRGBO(255, 255, 255, 1 - h * 2));
        }
        break;
      case 1: // 폭우: 바퀴 밑 물 튀김
        for (var i = 0; i < 3; i++) {
          final ph = (g.clock * 2.5 + i / 3) % 1.0;
          c.drawOval(
              Rect.fromCenter(
                  center: foot.translate((i - 1) * w * 0.35, -t * 0.02),
                  width: t * (0.3 + ph * 0.6),
                  height: t * (0.1 + ph * 0.2)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = Color.fromRGBO(191, 216, 255, 0.8 * (1 - ph)));
        }
        break;
      case 2: // 펑크: 뒤에서 회색 연기가 피어오름
        for (var i = 0; i < 4; i++) {
          final ph = (g.clock * 0.9 + i / 4) % 1.0;
          final q = Offset(foot.dx + back * w * 0.45 + back * ph * t * 0.4, foot.dy - t * 0.3 - ph * t * 1.2);
          c.drawCircle(q, t * (0.12 + ph * 0.25), Paint()..color = Color.fromRGBO(150, 150, 160, 0.55 * (1 - ph)));
        }
        break;
      case 3: // 분실: 상자 하나가 뒤로 떨어져 튕기다 사라짐
        final box = Sprites.box;
        if (box == null || age > 2.2) break;
        final k = (age / 1.4).clamp(0.0, 1.0);
        final x = foot.dx + back * (w * 0.4 + k * t * 1.6);
        final bounce = sin(k * pi * 3).abs() * t * (1.0 - k) * 1.1;
        final alpha = age < 1.4 ? 1.0 : (1 - (age - 1.4) / 0.8).clamp(0.0, 1.0);
        final bs = t * 0.5;
        c.save();
        c.translate(x, foot.dy - bs / 2 - bounce);
        c.rotate(k * 4 * back);
        c.drawImageRect(box, Rect.fromLTWH(0, 0, box.width.toDouble(), box.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: bs, height: bs),
            Paint()
              ..filterQuality = FilterQuality.none
              ..color = Color.fromRGBO(255, 255, 255, alpha));
        c.restore();
        break;
    }
  }

  /// 작은 네 갈래 별
  void _star(Canvas c, Offset p, double r, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..lineTo(p.dx + r * 0.3, p.dy - r * 0.3)
      ..lineTo(p.dx + r, p.dy)
      ..lineTo(p.dx + r * 0.3, p.dy + r * 0.3)
      ..lineTo(p.dx, p.dy + r)
      ..lineTo(p.dx - r * 0.3, p.dy + r * 0.3)
      ..lineTo(p.dx - r, p.dy)
      ..lineTo(p.dx - r * 0.3, p.dy - r * 0.3)
      ..close();
    c.drawPath(path, paint);
  }

  /// 차량이 지금 가는 방향의 좌우 성분 (오른쪽 +, 왼쪽 -)
  double _heading(FleetUnit u) {
    final path = _path(u, l);
    final len = _len(path);
    final p = (u.t / (u.state == 1 ? (u.dur + u.delay) : u.dur)).clamp(0.0, 1.0).toDouble();
    final f = u.state == 1 ? p : 1 - p;
    final a = _pointAt(path, len * f);
    final b = _pointAt(path, len * (f + (u.state == 1 ? 0.02 : -0.02)).clamp(0.0, 1.0));
    return b.dx - a.dx;
  }

  void _effects(Canvas c) {
    for (final f in g.mapFx) {
      if (f.region != sel) continue;
      final Offset base;
      if (f.atCenter) {
        base = _px(Offset(l.cx0 + 2.4, l.cFoot - 4.2));
      } else {
        final h = l.houses[l.deliver[f.house % l.deliver.length]];
        base = _px(Offset(h.x, h.y - 2.2));
      }
      final p = (f.t / 2.2).clamp(0.0, 1.0).toDouble();
      final pos = base.translate(0, -p * t * 1.6);
      final alpha = (p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
      final tp = TextPainter(
        text: TextSpan(
            text: f.text,
            style: TextStyle(
                color: Color(f.color).withOpacity(alpha),
                fontSize: t * 0.55,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black.withOpacity(alpha * 0.8), blurRadius: 2)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  /// 폭우 이벤트가 진행 중이면 지도에 비가 내림
  void _rain(Canvas c, Size s) {
    var rain = false;
    for (final u in g.fleet) {
      if (u.region == sel && u.evtT > 0 && u.evtKind == 1) rain = true;
    }
    if (!rain) return;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0x331E2A44));
    final p = Paint()
      ..color = const Color(0x88BFD8FF)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 70; i++) {
      final x = (i * 53 + g.clock * 90) % s.width;
      final y = (i * 97 + g.clock * 420) % s.height;
      c.drawLine(Offset(x, y), Offset(x - 4, y + 12), p);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

class _Item {
  final double y;
  final void Function(Canvas) draw;
  _Item(this.y, this.draw);
}

/// 미니맵: 지역 전체를 작게 그리고 지금 보이는 영역을 네모로 표시
class _MiniMap extends CustomPainter {
  final HubGame g;
  final int sel;
  final _Cam cam;
  _MiniMap(this.g, Listenable repaint, this.sel, this.cam) : super(repaint: repaint);

  static final Map<int, ui.Picture> _bg = {};

  @override
  void paint(Canvas c, Size s) {
    final l = _MapPainter.layout(sel);
    final k = s.width / l.gw; // 칸 하나의 미니맵 크기
    final bg = _bg[sel] ??= _drawBg(l, k, s);
    c.drawPicture(bg);
    // 허브·센터
    c.drawRect(Rect.fromLTWH(l.hubX * k, (l.hubFoot - 3.5) * k, 4 * k, 3.5 * k), Paint()..color = C.accent);
    c.drawRect(Rect.fromLTWH(l.cx0 * k, (l.cFoot - 3.5) * k, 4.5 * k, 3.5 * k),
        Paint()..color = Color(Cfg.regionColor[sel]));
    // 차량
    if (g.regionOpen[sel]) {
      for (final (u, pos) in _MapPainter.units(g, sel)) {
        c.drawCircle(pos * k, u.id == cam.follow ? 3 : 2,
            Paint()..color = u.id == cam.follow ? const Color(0xFFFFD166) : Colors.white);
      }
    }
    // 보이는 영역
    const T = _MapPainter.T;
    c.drawRect(
        Rect.fromLTWH(cam.pos.dx / T * k, cam.pos.dy / T * k, cam.view.width / T * k, cam.view.height / T * k)
            .intersect(Offset.zero & s),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  ui.Picture _drawBg(RegionMap l, double k, Size s) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF4F8A43));
    final road = Paint()..color = const Color(0xFF3A3A48);
    final walk = Paint()..color = const Color(0xFFCFC8B4);
    final sea = Paint()..color = const Color(0xFF3F78C8);
    for (var y = 0; y < l.gh; y++) {
      for (var x = 0; x < l.gw; x++) {
        final v = l.at(x, y);
        if (v != 0) {
          c.drawRect(Rect.fromLTWH(x * k, y * k, k + 0.3, k + 0.3), v == 1 ? road : (v == 3 ? sea : walk));
        }
      }
    }
    final house = Paint()..color = const Color(0xFFE8D9B5);
    for (final h in l.houses) {
      c.drawRect(Rect.fromLTWH((h.x - 0.9) * k, (h.y - 1.6) * k, 1.8 * k, 1.6 * k), house);
    }
    return rec.endRecording();
  }

  @override
  bool shouldRepaint(covariant _MiniMap old) => true;
}
