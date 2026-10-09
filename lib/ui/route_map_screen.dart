import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
import '../models/models.dart';
import 'theme.dart';

/// 전체화면 노선 지도. 한 번에 한 지역만 보여 준다: 허브 → (도로) → 지역센터 → 동네 집들.
/// 차량이 달리는 걸 실시간으로 보고, 노선·차량 배정·업그레이드·구입을 여기서 한다.
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
  int sel = 0; // 보고 있는 지역
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

  String _skillStars(int s) => '★' * s + '☆' * (5 - s);

  /// 고른 차량 정보: 기사 이름·능력, 차량 레벨·상태·적재, 따라가기
  Widget _unitInfo() {
    FleetUnit? u;
    for (final x in g.fleet) {
      if (x.id == cam.pick && x.region == sel) u = x;
    }
    if (u == null) return const SizedBox();
    final unit = u;
    final img = _img(unit.type, full: unit.state == 1 && unit.cargo > 0);
    final following = cam.follow == unit.id;
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xEE1E1B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(Cfg.regionColor[unit.region]).withValues(alpha: 0.8)),
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
                Text('${_skillStars(unit.skill)}  ${unit.name} Lv.${unit.level}',
                    style: const TextStyle(color: C.gold, fontSize: 10)),
                Text(_state(unit), style: const TextStyle(color: C.sub, fontSize: 10)),
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
          color: Color(0xEE1E1B2E),
          border: Border(bottom: BorderSide(color: C.line)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                g.showMap = false;
                g.ui();
              },
            ),
            const Expanded(child: Text('노선 지도', style: Tx.title)),
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
                      color: const Color(0xCC1E1B2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(n.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(n.color), fontSize: 11)),
                  ),
              ],
            ),
          ),
        Positioned(left: 8, bottom: 8, child: _camButtons()),
        if (open && cam.pick != null) Positioned(left: 8, top: 40, child: _unitInfo()),
        Positioned(right: 8, bottom: 8, child: _miniMap()),
        if (!open)
          Positioned.fill(
            child: Container(
              color: const Color(0xAA1E1B2E),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 36),
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
              color: on ? C.accent : const Color(0xCC1E1B2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
          border: Border.all(color: const Color(0xCC1E1B2E), width: 2),
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
        color: const Color(0xCC1E1B2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(t,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _panel() {
    return DefaultTabController(
      length: 3,
      child: Container(
        color: C.panel,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: C.sub,
              indicatorColor: C.accent,
              tabs: [Tab(text: '노선'), Tab(text: '내 차량'), Tab(text: '차량 구입')],
            ),
            Expanded(
              child: TabBarView(
                children: [_routeTab(), _fleetTab(), _buyTab()],
              ),
            ),
          ],
        ),
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
                    child: Text('${Cfg.regionName[sel]} 노선 · 수익 ×${Cfg.regionPay[sel]}',
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
                  '대형 트럭 ${g.trunkCount(sel)}대 · 배달 차량 ${g.courierCount(sel)}대 · 편도 ${Cfg.regionTrip[sel].round()}초',
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
  Widget _fleetTab() {
    if (g.fleet.isEmpty) {
      return const Center(child: Text('차량이 없어요. 차량 구입 탭에서 사세요', style: Tx.sub));
    }
    final mine = g.fleet.where((u) => u.region == sel).toList();
    final others = g.fleet.where((u) => u.region != sel).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Text('${Cfg.regionName[sel]} 노선 차량 ${mine.length}대', style: Tx.h2),
        const SizedBox(height: 6),
        if (mine.isEmpty) const Text('배정된 차량이 없어요', style: Tx.sub),
        for (final u in mine) ...[
          _unitCard(u),
          const SizedBox(height: 8),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('다른 노선 차량', style: Tx.h2),
          const SizedBox(height: 6),
          for (final u in others) ...[
            _unitCard(u),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  String _state(FleetUnit u) {
    switch (u.state) {
      case 1:
        return u.isTrunk ? '센터로 가는 중 (${u.cargo}건)' : '배달 중 (${u.cargo}건)';
      case 2:
        return '돌아오는 중';
      case 3:
        return '허브 도크에서 싣는 중';
      default:
        return '대기';
    }
  }

  ui.Image? _img(int type, {bool full = false}) {
    switch (type) {
      case 0:
        return full ? (Sprites.truckFull ?? Sprites.truck) : Sprites.truck;
      case 1:
        return full ? (Sprites.vanFull ?? Sprites.van) : Sprites.van;
      default:
        return full ? (Sprites.motoFull ?? Sprites.moto) : Sprites.moto;
    }
  }

  Widget _unitCard(FleetUnit u) {
    final img = _img(u.type);
    final color = Color(Cfg.regionColor[u.region]);
    final upCost = Cfg.upgradeCost(u.type, u.level);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 40,
                child: img == null
                    ? const SizedBox()
                    : RawImage(
                        image: img,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u.name} Lv.${u.level} · 적재 ${u.cap}', style: Tx.h2),
                    Text(
                        '기사 ${u.driver} · ${Cfg.skillName[u.skill]}(${'★' * u.skill}) · ${_state(u)}',
                        style: Tx.sub),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => g.cycleRegion(u),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${Cfg.regionName[u.region]} ▸',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AppButton(
                  u.level >= Cfg.maxLevel ? '최고 레벨' : '업그레이드 ${g.fmt(upCost)}원',
                  small: true,
                  color: C.blue,
                  onTap: (u.level >= Cfg.maxLevel || g.money < upCost)
                      ? null
                      : () => g.upgradeUnit(u)),
              const SizedBox(width: 8),
              AppButton(
                  u.skill >= 5 ? '기사 달인' : '기사 훈련 ${g.fmt(Cfg.trainCost(u.skill))}원',
                  small: true,
                  color: C.good,
                  onTap: (u.skill >= 5 || g.money < Cfg.trainCost(u.skill))
                      ? null
                      : () => g.trainDriver(u)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 구입 탭 ----------------
  Widget _buyTab() {
    final r = g.regionOpen[sel] ? sel : 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        Text('${Cfg.regionName[r]} 노선에 배정돼요 (위에서 지역을 고르세요)', style: Tx.sub),
        const SizedBox(height: 8),
        for (var t = 0; t < Cfg.vehicles.length; t++) ...[
          CardBox(
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 40,
                  child: RawImage(
                      image: _img(t),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Cfg.vehicles[t].name, style: Tx.h2),
                      Text(
                          t == 0
                              ? '허브→지역센터 간선 · 적재 ${Cfg.vehicles[t].cap}'
                              : '센터→동네 배달 · 적재 ${Cfg.vehicles[t].cap}',
                          style: Tx.sub),
                    ],
                  ),
                ),
                AppButton('${g.fmt(Cfg.unitCost[t])}원',
                    small: true,
                    color: C.accent,
                    onTap: g.money >= Cfg.unitCost[t] ? () => g.buyUnit(t, r) : null),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
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

/// 지역 하나의 지도 설계. 도로 좌표는 칸 경계(중심선, 2칸 폭), 골목 좌표는 칸 번호(1칸 폭).
class _Spec {
  final int gw, gh;
  final Offset hub; // 허브 건물 왼쪽 x, 바닥 y
  final Offset center; // 센터 건물 왼쪽 x, 바닥 y (간선 끝이 센터 왼쪽에 닿음)
  final List<Offset> trunk; // 허브 → 센터 간선
  final List<List<Offset>> roads; // 간선과 엇갈리는 다른 차도 (교차로·갈림길)
  final List<List<Offset>> lanes; // 동네 골목 (첫 골목의 첫 칸이 센터 출구)
  const _Spec(this.gw, this.gh, this.hub, this.center, this.trunk, this.roads, this.lanes);
}

/// 지역마다 한 번 만들어 두는 지도 정보. 좌표는 칸 단위.
class _Layout {
  final _Spec sp;
  final Uint8List cell; // 0 잔디, 1 도로(아스팔트), 2 동네 길(보도블록)
  final Set<int> cross = {}; // 골목이 차도를 건너는 칸 (건널목)
  final List<_House> houses = [];
  final List<int> deliver = []; // 배달 번호(0~5) → houses 번호
  final List<List<Offset>> courier = []; // 배달 번호별 센터 → 집 앞 길
  final List<List<double>> courierStops = []; // 배달 길의 건널목 위치(길 따라 거리)
  final List<double> trunkStops = []; // 간선의 교차로·건널목 위치(길 따라 거리)
  final List<Offset> lights = []; // 신호등을 세울 교차로 중심
  final List<_Dec> decor = [];
  _Layout(this.sp) : cell = Uint8List(sp.gw * sp.gh);

  int get gw => sp.gw;
  int get gh => sp.gh;
  double get hubX => sp.hub.dx;
  double get hubFoot => sp.hub.dy;
  double get cx0 => sp.center.dx;
  double get cFoot => sp.center.dy;
  List<Offset> get trunk => sp.trunk;

  int at(int x, int y) => (x < 0 || y < 0 || x >= gw || y >= gh) ? 0 : cell[y * gw + x];
  void set(int x, int y, int v) {
    if (x >= 0 && y >= 0 && x < gw && y < gh) cell[y * gw + x] = v;
  }

  bool nearPath(double x, double y) {
    final cx = x.floor(), cy = y.floor();
    for (var dy = -1; dy <= 0; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (at(cx + dx, cy + dy) != 0) return true;
      }
    }
    return false;
  }
}

class _House {
  final double x, y; // 발 밑(아래 가운데)
  final String key;
  _House(this.x, this.y, this.key);
}

class _Dec {
  final String key;
  final double x, y; // 발 밑(아래 가운데) 칸 좌표
  _Dec(this.key, this.x, this.y);
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

  /// 지역별 지도. 정사각형에 가까운 영역 안에서 굽은 길·교차로·블록으로 거리를 만든다.
  /// 지역마다 틀이 다르다: 주택가 / 상가 격자 / 산동네 굽잇길 / 순환로 도심 / 물류 인터체인지
  static const List<_Spec> specs = [
    // 동네 (주택가): ㄱ자 간선 + 가로지르는 큰길, 골목 격자에 단독주택
    _Spec(30, 26, Offset(1.4, 23), Offset(17, 10), [
      Offset(5, 22), Offset(11, 22), Offset(11, 9), Offset(17, 9),
    ], [
      [Offset(0, 16), Offset(30, 16)],
    ], [
      [Offset(22, 9), Offset(23, 9)], [Offset(23, 3), Offset(23, 23)], [Offset(2, 3), Offset(28, 3)],
      [Offset(23, 13), Offset(28, 13)], [Offset(14, 22), Offset(28, 22)], [Offset(2, 3), Offset(2, 13)],
      [Offset(2, 13), Offset(8, 13)],
    ]),
    // 시내 (상가): 큰길 격자를 ㄹ자로 지나감, 교차로가 많음
    _Spec(34, 30, Offset(1.4, 27), Offset(21, 15), [
      Offset(5, 26), Offset(10, 26), Offset(10, 8), Offset(16, 8), Offset(16, 14), Offset(21, 14),
    ], [
      [Offset(10, 0), Offset(10, 30)], [Offset(0, 19), Offset(34, 19)], [Offset(10, 8), Offset(34, 8)],
    ], [
      [Offset(26, 14), Offset(27, 14)], [Offset(27, 2), Offset(27, 28)], [Offset(1, 5), Offset(33, 5)],
      [Offset(12, 17), Offset(33, 17)], [Offset(12, 28), Offset(33, 28)], [Offset(1, 5), Offset(1, 13)],
      [Offset(1, 13), Offset(8, 13)],
    ]),
    // 근교 (산동네): 계단처럼 오르내리는 굽잇길 + 농장 갈림길, 비탈에 층층이 집
    _Spec(38, 32, Offset(1.4, 29), Offset(26, 9), [
      Offset(5, 28), Offset(12, 28), Offset(12, 25), Offset(18, 25), Offset(18, 28), Offset(26, 28),
      Offset(26, 23), Offset(33, 23), Offset(33, 17), Offset(28, 17), Offset(28, 12), Offset(22, 12),
      Offset(22, 8), Offset(26, 8),
    ], [
      [Offset(18, 25), Offset(18, 16), Offset(8, 16)],
    ], [
      [Offset(31, 8), Offset(35, 8)], [Offset(35, 3), Offset(35, 14)], [Offset(3, 3), Offset(37, 3)],
      [Offset(30, 14), Offset(37, 14)], [Offset(4, 3), Offset(4, 12)], [Offset(4, 12), Offset(16, 12)],
      [Offset(4, 7), Offset(18, 7)],
    ]),
    // 타도시 (도심): 순환로를 반 바퀴 넘게 돌아 안쪽 센터로, 광장 분수와 바깥 블록
    _Spec(42, 36, Offset(1.4, 33), Offset(19, 18), [
      Offset(5, 32), Offset(12, 32), Offset(12, 26), Offset(30, 26), Offset(30, 8), Offset(12, 8),
      Offset(12, 17), Offset(19, 17),
    ], [
      [Offset(12, 17), Offset(12, 26)], [Offset(21, 0), Offset(21, 8)], [Offset(30, 13), Offset(42, 13)],
      [Offset(0, 20), Offset(11, 20)],
    ], [
      [Offset(24, 17), Offset(26, 17)], [Offset(26, 11), Offset(26, 23)], [Offset(14, 11), Offset(28, 11)],
      [Offset(14, 23), Offset(28, 23)], [Offset(26, 20), Offset(35, 20)], [Offset(35, 3), Offset(35, 33)],
      [Offset(32, 6), Offset(41, 6)], [Offset(32, 17), Offset(41, 17)], [Offset(32, 30), Offset(41, 30)],
      [Offset(2, 3), Offset(41, 3)], [Offset(4, 3), Offset(4, 24)], [Offset(4, 14), Offset(10, 14)],
      [Offset(4, 24), Offset(10, 24)],
    ]),
    // 전국 (물류 인터체인지): 촘촘한 ㄹ자 램프가 이어지는 긴 간선, 주유소·표지판
    _Spec(46, 40, Offset(1.4, 37), Offset(36, 25), [
      Offset(5, 36), Offset(10, 36), Offset(10, 24), Offset(5, 24), Offset(5, 14), Offset(12, 14),
      Offset(12, 4), Offset(20, 4), Offset(20, 20), Offset(16, 20), Offset(16, 30), Offset(26, 30),
      Offset(26, 10), Offset(32, 10), Offset(32, 24), Offset(36, 24),
    ], [
      [Offset(26, 27), Offset(46, 27)], [Offset(0, 18), Offset(5, 18)],
    ], [
      [Offset(41, 24), Offset(43, 24)], [Offset(43, 3), Offset(43, 38)], [Offset(28, 6), Offset(45, 6)],
      [Offset(34, 15), Offset(45, 15)], [Offset(18, 34), Offset(45, 34)],
    ]),
  ];

  /// 지역 특색 큰 소품: (이름, x, 발 y, 폭, 높이)
  static const List<List<(String, double, double, double, double)>> specials = [
    [],
    [],
    [],
    [('p:fountain', 16, 21, 2.0, 1.6)], // 순환로 안 광장
    [('p:gas', 16, 12, 3.4, 3.2)], // 램프 사이 휴게소
  ];

  /// 지역마다 배달지 집 모양. 'house1~3'은 가게(장식 폴더), 나머지는 지도 전용 집
  static const List<List<String>> housePool = [
    ['d0', 'd1', 'd2', 'd3', 'd4', 'd7'], // 동네: 알록달록 단독주택
    ['v0', 'house1', 'v1', 'v2', 'house3', 'house2'], // 시내: 빌라·가게
    ['d8', 'd9', 'd10', 'd11', 'd6', 'd5'], // 근교: 나무·돌집
    ['v1', 'd5', 'v2', 'd3', 'v0', 'house3'], // 타도시
    ['d6', 'v2', 'd4', 'house1', 'd9', 'v0'], // 전국
  ];

  /// 지역별 소품 ('p:이름'은 assets/sprites/map/prop_<이름>.png, 나머지는 장식 폴더)
  static const List<List<String>> roadside = [
    ['lamp', 'p:mailbox', 'lamp', 'bench'], // 동네
    ['lamp', 'p:busstop', 'light', 'p:billboard'], // 시내
    ['p:fence', 'lamp', 'p:haystack', 'p:fence'], // 근교
    ['lamp', 'p:billboard', 'light', 'sign'], // 타도시
    ['p:hwsign', 'lamp', 'lamp', 'p:billboard'], // 전국
  ];
  static const List<List<String>> townProps = [
    ['p:mailbox', 'p:vending', 'bench', 'flower'],
    ['p:vending', 'bench', 'lamp', 'p:busstop'],
    ['p:crops', 'p:haystack', 'p:crops', 'p:fence'],
    ['bench', 'lamp', 'p:vending', 'flower'],
    ['p:vending', 'lamp', 'bench', 'p:mailbox'],
  ];
  static const List<List<String>> decorKinds = [
    ['tree', 'tree2', 'bush', 'flower', 'tree', 'bush', 'tree'],
    ['tree2', 'bush', 'bush', 'flower', 'tree', 'lamp'],
    ['tree', 'tree', 'tree2', 'bush', 'flower', 'tree'],
    ['tree2', 'bush', 'flower', 'tree', 'bush'],
    ['tree', 'tree2', 'bush', 'tree', 'flower', 'bush'],
  ];

  /// 소품 배율 (64 캔버스로 뽑아 원본이 커서 집 크기에 맞게 줄임)
  static const Map<String, double> propScale = {
    'mailbox': 0.55, 'vending': 0.6, 'busstop': 0.85, 'billboard': 0.8, 'haystack': 0.5,
    'fence': 0.6, 'crops': 0.9, 'fountain': 0.9, 'hwsign': 0.75, 'gas': 1.0,
  };

  static final Map<int, _Layout> _cache = {};

  static _Layout layout(int r) {
    final cached = _cache[r];
    if (cached != null) return cached;
    final sp = specs[r % specs.length];
    final l = _Layout(sp);
    final gw = sp.gw, gh = sp.gh;
    final side = Uint8List(gw * gh); // 간선이 아닌 차도 (교차로 찾기용)

    // 중심선 양옆 한 칸씩 = 2칸 폭 차도
    void road(List<Offset> pts, {bool isSide = false}) {
      void mark(int x, int y) {
        l.set(x, y, 1);
        if (isSide && x >= 0 && y >= 0 && x < gw && y < gh) side[y * gw + x] = 1;
      }

      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        if (a.dy == b.dy) {
          final y = a.dy.toInt();
          for (var x = min(a.dx, b.dx).toInt() - 1; x <= max(a.dx, b.dx).toInt(); x++) {
            mark(x, y - 1);
            mark(x, y);
          }
        } else {
          final x = a.dx.toInt();
          for (var y = min(a.dy, b.dy).toInt() - 1; y <= max(a.dy, b.dy).toInt(); y++) {
            mark(x - 1, y);
            mark(x, y);
          }
        }
      }
    }

    // 허브 앞마당 (트럭 도크)
    for (var y = l.hubFoot.toInt() - 3; y < l.hubFoot.toInt(); y++) {
      l.set(5, y, 1);
      l.set(6, y, 1);
    }
    road(sp.trunk);
    for (final rd in sp.roads) {
      road(rd, isSide: true);
    }
    // 골목: 차도와 만나는 칸은 건널목
    for (final ln in sp.lanes) {
      for (var i = 0; i + 1 < ln.length; i++) {
        final a = ln[i], b = ln[i + 1];
        for (var y = min(a.dy, b.dy).toInt(); y <= max(a.dy, b.dy).toInt(); y++) {
          for (var x = min(a.dx, b.dx).toInt(); x <= max(a.dx, b.dx).toInt(); x++) {
            if (x < 0 || y < 0 || x >= gw || y >= gh) continue;
            if (l.at(x, y) == 1) {
              l.cross.add(y * gw + x);
            } else {
              l.set(x, y, 2);
            }
          }
        }
      }
    }

    // 집: 가로 골목 위쪽 빈 땅에 자동 배치 (허브·센터 자리는 피함)
    final blocked = <Rect>[
      Rect.fromLTRB(l.hubX - 0.6, l.hubFoot - 5.4, l.hubX + 7.1, l.hubFoot + 3.2), // 허브 + 대기 트럭
      Rect.fromLTRB(l.cx0 - 2.5, l.cFoot - 5.4, l.cx0 + 5.5, l.cFoot + 2.6), // 센터 + 택배 더미 + 대기 차
    ];
    final rnd = Random(r * 977 + 13);
    final pool = housePool[r % housePool.length];
    var hi = rnd.nextInt(6);
    for (final ln in sp.lanes) {
      for (var i = 0; i + 1 < ln.length; i++) {
        final a = ln[i], b = ln[i + 1];
        if (a.dy != b.dy || (b.dx - a.dx).abs() < 3) continue;
        final y = a.dy.toInt();
        var x = min(a.dx, b.dx) + 1.5;
        while (x < max(a.dx, b.dx) + 0.5) {
          var ok = true;
          for (var yy = y - 3; yy < y && ok; yy++) {
            for (var xx = (x - 1).floor(); xx <= (x + 0.99).floor(); xx++) {
              if (yy < 0 || xx < 0 || xx >= gw || l.at(xx, yy) != 0) ok = false;
            }
          }
          final rect = Rect.fromLTRB(x - 1.2, y - 2.6, x + 1.2, y.toDouble());
          if (ok && blocked.any((b) => b.overlaps(rect))) ok = false;
          if (ok && l.houses.any((h) => h.y == y && (h.x - x).abs() < 2.4)) ok = false;
          if (ok) {
            l.houses.add(_House(x, y.toDouble(), pool[hi++ % pool.length]));
            x += 2.6;
          } else {
            x += 0.5;
          }
        }
      }
    }
    for (final h in l.houses) {
      blocked.add(Rect.fromLTRB(h.x - 1.4, h.y - 3.0, h.x + 1.4, h.y + 0.2));
    }

    // 배달지 6채를 고르게 고르고, 센터 출구에서 골목·건널목을 따라 길을 찾음
    final n = l.houses.length;
    final start = sp.lanes.first.first;
    for (var k = 0; k < 6 && n > 0; k++) {
      final hk = ((k + 0.5) * n / 6).floor().clamp(0, n - 1);
      final h = l.houses[hk];
      final cells = _bfs(l, start.dx.toInt(), start.dy.toInt(), h.x.floor(), h.y.toInt());
      final path = <Offset>[];
      final stops = <double>[];
      var dist = 0.0;
      var inCross = false;
      for (final c in cells) {
        final p = Offset(c.dx + 0.5, c.dy + 0.5);
        if (path.isNotEmpty) dist += (p - path.last).distance;
        final isCross = l.cross.contains(c.dy.toInt() * gw + c.dx.toInt());
        if (isCross && !inCross) stops.add(max(0.0, dist - 0.6));
        inCross = isCross;
        // 같은 방향으로 이어지는 칸은 합쳐서 꺾이는 곳만 남김
        if (path.length >= 2) {
          final a = path[path.length - 2], b = path.last;
          if ((a.dx == b.dx && b.dx == p.dx) || (a.dy == b.dy && b.dy == p.dy)) path.removeLast();
        }
        path.add(p);
      }
      if (path.isEmpty) path.add(Offset(start.dx + 0.5, start.dy + 0.5));
      path.add(Offset(h.x, h.y + 0.5));
      l.deliver.add(hk);
      l.courier.add(path);
      l.courierStops.add(stops);
    }
    if (l.courier.isEmpty) {
      l.courier.add([Offset(start.dx + 0.5, start.dy + 0.5), Offset(start.dx + 1.5, start.dy + 0.5)]);
      l.courierStops.add([]);
    }

    // 간선의 교차로(옆에서 다른 차도가 붙는 곳)·건널목: 정차 지점과 신호등
    final tl = _len(sp.trunk);
    bool sideAt(int x, int y) => x >= 0 && y >= 0 && x < gw && y < gh && side[y * gw + x] == 1;
    var run = false;
    for (var d = 0.5; d < tl; d += 0.5) {
      final p = _pointAt(sp.trunk, d);
      final q = _pointAt(sp.trunk, min(tl, d + 0.01));
      final horiz = (q.dy - p.dy).abs() < (q.dx - p.dx).abs();
      final x = p.dx.floor(), y = p.dy.floor();
      final hit = horiz
          ? (sideAt(x, y - 2) || sideAt(x, y + 1))
          : (sideAt(x - 2, y) || sideAt(x + 1, y));
      final cw = l.cross.contains(y * gw + x) ||
          l.cross.contains(y * gw + x - 1) ||
          l.cross.contains((y - 1) * gw + x) ||
          l.cross.contains((y - 1) * gw + x - 1);
      final on = hit || cw;
      if (on && !run && d > 2) {
        l.trunkStops.add(max(0.0, d - 1.4));
        if (hit) l.lights.add(p);
      }
      run = on;
    }

    // 장식·소품
    bool free(double x, double y) {
      if (l.nearPath(x, y)) return false;
      for (final b in blocked) {
        if (b.contains(Offset(x, y)) || b.contains(Offset(x, y - 1))) return false;
      }
      for (final d in l.decor) {
        if ((d.x - x).abs() < 1.2 && (d.y - y).abs() < 0.9) return false;
      }
      return true;
    }

    // 크기가 있는 소품: 차지하는 칸에 길·건물·다른 장식이 없을 때만 놓음
    bool place(String key, double x, double y, {double w = 1.0, double h = 1.0, int pad = 1}) {
      for (var cy = (y - h).floor(); cy <= y.floor(); cy++) {
        for (var cx = (x - w / 2).floor() - pad; cx <= (x + w / 2).floor() + pad; cx++) {
          if (l.at(cx, cy) != 0 || cy < 1 || cy >= gh) return false;
        }
      }
      final area = Rect.fromLTRB(x - w / 2, y - h, x + w / 2, y);
      for (final b in blocked) {
        if (b.overlaps(area)) return false;
      }
      for (final d in l.decor) {
        if ((d.x - x).abs() < (w + 1) / 2 && (d.y - y).abs() < 0.9) return false;
      }
      l.decor.add(_Dec(key, x, y));
      return true;
    }

    for (final (key, x, y, w, h) in specials[r % specials.length]) {
      place(key, x, y, w: w, h: h, pad: 0);
    }
    // 교차로 모서리에 신호등 (네 모서리 중 빈 곳 하나)
    for (final p in l.lights) {
      for (final o in const [Offset(1.9, -1.3), Offset(-1.9, -1.3), Offset(1.9, 2.4), Offset(-1.9, 2.4)]) {
        if (place('light', p.dx + o.dx, p.dy + o.dy, pad: 0)) break;
      }
    }
    // 차도변: 6칸마다 가로등·지역 소품 (가로 구간은 길 위쪽, 세로 구간은 길 오른쪽, 안 되면 반대쪽)
    final roadKeys = roadside[r % roadside.length];
    var ri = 0;
    for (final pts in [sp.trunk, ...sp.roads]) {
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        final len = (b - a).distance;
        for (var d = 3.0; d < len - 1; d += 6) {
          final q = Offset.lerp(a, b, d / len)!;
          final key = roadKeys[ri % roadKeys.length];
          final ok = a.dy == b.dy
              ? (place(key, q.dx, q.dy - 1.15) || place(key, q.dx, q.dy + 2.2))
              : (place(key, q.dx + 2.8, q.dy + 0.5) || place(key, q.dx - 2.8, q.dy + 0.5));
          if (ok) ri++;
        }
      }
    }
    // 동네: 가로 골목 아래쪽(집 건너편) 4칸마다 생활 소품
    final town = townProps[r % townProps.length];
    var ti = 0;
    for (final ln in sp.lanes) {
      for (var i = 0; i + 1 < ln.length; i++) {
        final a = ln[i], b = ln[i + 1];
        if (a.dy != b.dy) continue;
        for (var x = min(a.dx, b.dx) + 3.0; x < max(a.dx, b.dx) - 0.5; x += 4) {
          if (place(town[ti % town.length], x, a.dy + 2.2)) ti++;
        }
      }
    }
    // 근교: 빈 들판의 밭·건초
    if (r == 2) {
      for (var k = 0; k < 60; k++) {
        place(rnd.nextBool() ? 'p:crops' : 'p:haystack', 2 + rnd.nextDouble() * (gw - 4),
            3 + rnd.nextDouble() * (gh - 4),
            w: 1.8);
      }
    }

    final kinds = decorKinds[r % decorKinds.length];
    final want = gw * gh ~/ 9;
    var tries = 0;
    while (l.decor.length < want && tries < want * 25) {
      tries++;
      final x = 0.6 + rnd.nextDouble() * (gw - 1.2);
      final y = 1.6 + rnd.nextDouble() * (gh - 1.8);
      if (!free(x, y)) continue;
      l.decor.add(_Dec(kinds[rnd.nextInt(kinds.length)], x, y));
    }
    // 아래쪽 순서로 그릴 때 매번 정렬하지 않아도 되게 미리 정렬
    l.decor.sort((a, b) => a.y.compareTo(b.y));
    _cache[r] = l;
    return l;
  }

  /// 골목·건널목 칸만 지나는 최단 길 (칸 좌표 목록). 못 찾으면 출발 칸만.
  static List<Offset> _bfs(_Layout l, int sx, int sy, int gx, int gy) {
    final gw = l.gw, gh = l.gh;
    bool ok(int x, int y) =>
        x >= 0 && y >= 0 && x < gw && y < gh && (l.at(x, y) == 2 || l.cross.contains(y * gw + x));
    final prev = Int32List(gw * gh)..fillRange(0, gw * gh, -1);
    final s = sy * gw + sx, goal = gy * gw + gx;
    prev[s] = s;
    final q = <int>[s];
    for (var qi = 0; qi < q.length; qi++) {
      final c = q[qi];
      if (c == goal) break;
      final x = c % gw, y = c ~/ gw;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (!ok(nx, ny)) continue;
        final ni = ny * gw + nx;
        if (prev[ni] != -1) continue;
        prev[ni] = c;
        q.add(ni);
      }
    }
    if (prev[goal] == -1) return [Offset(sx.toDouble(), sy.toDouble())];
    final out = <Offset>[];
    for (var c = goal; ; c = prev[c]) {
      out.add(Offset((c % gw).toDouble(), (c ~/ gw).toDouble()));
      if (c == s) break;
    }
    return out.reversed.toList();
  }

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

  static List<Offset> _path(FleetUnit u, _Layout l) =>
      u.isTrunk ? l.trunk : l.courier[u.house % l.courier.length];

  static List<double> _stops(FleetUnit u, _Layout l) =>
      u.isTrunk ? l.trunkStops : l.courierStops[u.house % l.courierStops.length];

  /// 차량의 지도 위 위치(칸 좌표). slot 은 대기 줄 순서.
  static Offset unitPos(FleetUnit u, _Layout l, int slot) {
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
        : Offset(l.cx0 + 1.2 + (slot % 3) * 1.4, l.cFoot + 1.4);
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
  late _Layout l;
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

    // 1) 땅: 잔디 + 도로 + 동네 길 (보이는 칸만)
    _ground(c);
    _roadMarks(c, l.trunk);
    for (final rd in l.sp.roads) {
      _roadMarks(c, rd);
    }
    _crosswalks(c);

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
        final mr = mask(1), mw = mask(2);
        if (road == null || walk == null) {
          // 타일셋이 없으면 단색
          final v = mr != 0 ? 1 : (mw != 0 ? 2 : 0);
          c.drawRect(dst, Paint()..color = const [Color(0xFF69A857), Color(0xFF3A3A48), Color(0xFFB9B5A8)][v]);
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

  void _decor(Canvas c, _Dec d) {
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

  void _house(Canvas c, _House hs) {
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
      final base = _px(Offset(l.cx0 - 1.6, l.cFoot + 0.2));
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
      final r = Rect.fromCenter(
          center: Offset(foot.dx, top - t * 0.95),
          width: tp.width + t * 0.6,
          height: tp.height + t * 0.3);
      final bubble = Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(t * 0.25)))
        ..moveTo(foot.dx - t * 0.15, r.bottom)
        ..lineTo(foot.dx, r.bottom + t * 0.22)
        ..lineTo(foot.dx + t * 0.15, r.bottom);
      c.drawPath(bubble, Paint()..color = col);
      tp.paint(c, Offset(r.left + t * 0.3, r.top + t * 0.15));
    }
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

  ui.Picture _drawBg(_Layout l, double k, Size s) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF4F8A43));
    final road = Paint()..color = const Color(0xFF3A3A48);
    final walk = Paint()..color = const Color(0xFFCFC8B4);
    for (var y = 0; y < l.gh; y++) {
      for (var x = 0; x < l.gw; x++) {
        final v = l.at(x, y);
        if (v != 0) c.drawRect(Rect.fromLTWH(x * k, y * k, k + 0.3, k + 0.3), v == 1 ? road : walk);
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
