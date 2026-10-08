import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
import '../models/models.dart';
import 'theme.dart';

/// 전체화면 노선 지도. 한 번에 한 지역만 보여 준다: 허브 → (도로) → 지역센터 → 동네 집들.
/// 차량이 달리는 걸 실시간으로 보고, 노선·차량 배정·업그레이드·구입을 여기서 한다.
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

  HubGame get g => widget.g;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _MapPainter(g, _anim, sel)),
                    ValueListenableBuilder<int>(
                      valueListenable: g.tick,
                      builder: (context, _, __) => _mapHud(),
                    ),
                  ],
                ),
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
                  onTap: () => setState(() => sel = i),
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

  ui.Image? _img(int type) {
    switch (type) {
      case 0:
        return Sprites.truck;
      case 1:
        return Sprites.van;
      default:
        return Sprites.moto;
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

/// 지역마다 한 번 만들어 두는 지도 정보 (길 칸, 장식)
class _Layout {
  final List<Offset> trunk; // 허브 → 센터 도로 (칸 중심 좌표)
  final Set<int> roadCells = {};
  final Set<int> walkCells = {};
  final List<_Dec> decor = [];
  _Layout(this.trunk);
}

class _Dec {
  final String key;
  final double x, y; // 발 밑(아래 가운데) 칸 좌표
  final double w; // 칸 단위 너비
  _Dec(this.key, this.x, this.y, this.w);
}

class _MapPainter extends CustomPainter {
  final HubGame g;
  final int sel;
  _MapPainter(this.g, Listenable repaint, this.sel) : super(repaint: repaint);

  static const int gw = 18, gh = 14; // 지도 칸 수

  // 허브 / 센터 / 거리
  static const Rect hubR = Rect.fromLTRB(0.3, 8.6, 3.0, 12.4);
  static const Rect centerR = Rect.fromLTRB(10.0, 9.0, 15.6, 12.2);
  static const double door = 12.5; // 센터 위쪽 문 x
  static const double s1 = 4.5, s2 = 7.5; // 동네 거리 y
  // 집: 발 밑 좌표. 0~2 윗줄(거리 s1 앞), 3~5 아랫줄(거리 s2 앞)
  static const List<Offset> houseFoot = [
    Offset(10.5, 4.0),
    Offset(12.5, 4.0),
    Offset(14.5, 4.0),
    Offset(10.5, 7.0),
    Offset(14.5, 7.0),
    Offset(16.5, 7.0),
  ];
  static const double houseW = 2.0;
  static const double houseMaxH = 2.3;

  static Offset _n(double x, double y) =>
      Offset(x.floorToDouble() + 0.5, y.floorToDouble() + 0.5);

  static List<Offset> _trunkPath(int r) {
    // 지역마다 멀수록 길이 꼬불꼬불 길어진다
    final List<List<double>> w;
    switch (r) {
      case 0:
        w = [[3.6, 10.5], [9.8, 10.5]];
        break;
      case 1:
        w = [[3.6, 10.5], [6, 10.5], [6, 6.5], [8.4, 6.5], [8.4, 10.5], [9.8, 10.5]];
        break;
      case 2:
        w = [[3.6, 10.5], [5.2, 10.5], [5.2, 2.5], [8.4, 2.5], [8.4, 10.5], [9.8, 10.5]];
        break;
      case 3:
        w = [[3.6, 10.5], [5, 10.5], [5, 2.5], [6.7, 2.5], [6.7, 12.9], [8.4, 12.9], [8.4, 10.5], [9.8, 10.5]];
        break;
      default:
        w = [[3.6, 10.5], [4.4, 10.5], [4.4, 2.5], [6, 2.5], [6, 12.9], [7.6, 12.9], [7.6, 2.5], [8.8, 2.5], [8.8, 10.5], [9.8, 10.5]];
    }
    return [for (final p in w) _n(p[0], p[1])];
  }

  /// 센터 문 → 집 앞 (동네 길)
  static List<Offset> courierPath(int k) {
    final hf = houseFoot[k];
    final dx = door.floorToDouble() + 0.5;
    if (k < 3) {
      return [
        Offset(dx, 8.5),
        Offset(dx, s1),
        Offset(_n(hf.dx, 0).dx, s1),
        Offset(_n(hf.dx, 0).dx, 4.15),
      ];
    }
    return [
      Offset(dx, 8.5),
      Offset(dx, s2),
      Offset(_n(hf.dx, 0).dx, s2),
      Offset(_n(hf.dx, 0).dx, 7.15),
    ];
  }

  static final Map<int, _Layout> _cache = {};

  static _Layout layout(int r) {
    final cached = _cache[r];
    if (cached != null) return cached;
    final l = _Layout(_trunkPath(r));
    void mark(Set<int> set, List<Offset> path) {
      for (var i = 0; i + 1 < path.length; i++) {
        final a = path[i], b = path[i + 1];
        if (a.dx == b.dx) {
          final x = a.dx.floor();
          final y0 = min(a.dy, b.dy).floor(), y1 = max(a.dy, b.dy).floor();
          for (var y = y0; y <= y1; y++) {
            set.add(y * 100 + x);
          }
        } else {
          final y = a.dy.floor();
          final x0 = min(a.dx, b.dx).floor(), x1 = max(a.dx, b.dx).floor();
          for (var x = x0; x <= x1; x++) {
            set.add(y * 100 + x);
          }
        }
      }
    }

    mark(l.roadCells, l.trunk);
    for (var k = 0; k < houseFoot.length; k++) {
      mark(l.walkCells, courierPath(k));
    }
    // 장식: 길·건물이 없는 빈 곳에 나무·덤불·꽃·가로등을 흩뿌림 (지역마다 다른 모양)
    final rnd = Random(r * 977 + 13);
    final blocked = <Rect>[
      // 허브: 지붕 위와, 앞에서 대형 트럭이 기다리는 자리까지 비움
      Rect.fromLTRB(hubR.left - 0.3, hubR.top - 0.8, hubR.right + 3.0, hubR.bottom + 1.4),
      // 센터 건물: 위로 넘치는 지붕·이름표와, 앞(아래)에 선 나무가 건물을 가리는 자리까지 비움
      Rect.fromLTRB(centerR.left - 0.6, centerR.top - 1.4, centerR.right + 0.4, centerR.bottom + 1.6),
      for (final h in houseFoot)
        Rect.fromLTRB(h.dx - houseW / 2 - 0.3, h.dy - houseW - 0.3, h.dx + houseW / 2 + 0.3, h.dy + 0.5),
    ];
    bool free(double x, double y) {
      final cx = x.floor(), cy = y.floor();
      for (var dy = -1; dy <= 0; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final key = (cy + dy) * 100 + (cx + dx);
          if (l.roadCells.contains(key) || l.walkCells.contains(key)) return false;
        }
      }
      for (final b in blocked) {
        if (b.contains(Offset(x, y)) || b.contains(Offset(x, y - 1))) return false;
      }
      for (final d in l.decor) {
        if ((d.x - x).abs() < 1.1 && (d.y - y).abs() < 0.9) return false;
      }
      return true;
    }

    const kinds = ['tree', 'tree2', 'bush', 'flower', 'tree', 'bush'];
    const widths = {'tree': 1.5, 'tree2': 1.5, 'bush': 0.9, 'flower': 0.9};
    var tries = 0;
    while (l.decor.length < 26 && tries < 500) {
      tries++;
      final x = 0.6 + rnd.nextDouble() * (gw - 1.2);
      final y = 1.2 + rnd.nextDouble() * (gh - 1.4);
      if (!free(x, y)) continue;
      final k = kinds[rnd.nextInt(kinds.length)];
      l.decor.add(_Dec(k, x, y, widths[k]!));
    }
    _cache[r] = l;
    return l;
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

  static final Map<int, bool> _faceRight = {};

  // ---- 그리기 ----
  late double t; // 한 칸 픽셀 크기
  late Offset org; // 지도 왼쪽 위

  Offset _px(Offset tile) => Offset(org.dx + tile.dx * t, org.dy + tile.dy * t);
  Rect _pr(Rect r) => Rect.fromLTRB(
      org.dx + r.left * t, org.dy + r.top * t, org.dx + r.right * t, org.dy + r.bottom * t);

  @override
  void paint(Canvas c, Size s) {
    t = min(s.width / gw, s.height / gh).floorToDouble();
    if (t < 8) t = 8;
    org = Offset(((s.width - gw * t) / 2).floorToDouble(),
        ((s.height - gh * t) / 2).floorToDouble());
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF4F8A43));
    final open = g.regionOpen[sel];
    final l = layout(sel);

    // 1) 땅: 잔디
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        final v = (x * 7 + y * 13 + sel) % 4;
        _tile(c, Sprites.grass, x, y, 4, v, const Color(0xFF69A857));
      }
    }
    // 2) 길: 허브 앞 마당 + 인도 + 도로
    _yard(c, Rect.fromLTRB(3.0, 9.0, 4.0, 12.0));
    for (final key in l.walkCells) {
      _tile(c, Sprites.sidewalk, key % 100, key ~/ 100, 1, 0, const Color(0xFFB9B5A8));
    }
    for (final key in l.roadCells) {
      _tile(c, Sprites.asphalt, key % 100, key ~/ 100, 1, 0, const Color(0xFF3A3A48));
    }
    _roadMarks(c, l.trunk);

    // 3) 세워진 것들을 아래쪽 순서대로 그림 (앞에 있는 게 위에 오도록)
    final items = <_Item>[];
    for (final d in l.decor) {
      items.add(_Item(d.y, (cv) => _decor(cv, d)));
    }
    for (var k = 0; k < houseFoot.length; k++) {
      final kk = k;
      items.add(_Item(houseFoot[k].dy, (cv) => _house(cv, kk)));
    }
    items.add(_Item(hubR.bottom, (cv) => _hub(cv)));
    items.add(_Item(centerR.bottom, (cv) => _center(cv, open)));
    if (open) {
      var tw = 0, cr = 0;
      for (final u in g.fleet) {
        if (u.region != sel) continue;
        final slot = u.isTrunk ? tw++ : cr++;
        final pos = _unitPos(u, l, slot);
        items.add(_Item(pos.dy + 0.4, (cv) => _unit(cv, u, pos)));
      }
    }
    items.sort((a, b) => a.y.compareTo(b.y));
    for (final it in items) {
      it.draw(c);
    }

    // 4) 효과 (떠오르는 글자, 비)
    if (open) {
      _effects(c);
      _rain(c, s);
    }
  }

  void _tile(Canvas c, ui.Image? img, int x, int y, int variants, int v, Color fallback) {
    final dst = Rect.fromLTWH(org.dx + x * t, org.dy + y * t, t, t);
    if (img == null) {
      c.drawRect(dst, Paint()..color = fallback);
      return;
    }
    final w = img.width / variants;
    c.drawImageRect(img, Rect.fromLTWH(w * v, 0, w, img.height.toDouble()), dst,
        Paint()..filterQuality = FilterQuality.none);
  }

  void _roadMarks(Canvas c, List<Offset> path) {
    final p = Paint()
      ..color = const Color(0xCCFFD166)
      ..strokeWidth = max(2.0, t * 0.1);
    for (var i = 0; i + 1 < path.length; i++) {
      final a = _px(path[i]), b = _px(path[i + 1]);
      final len = (b - a).distance;
      if (len < 1) continue;
      final dir = (b - a) / len;
      final step = t * 0.7;
      for (var d = t * 0.15; d < len; d += step) {
        c.drawLine(a + dir * d, a + dir * min(d + step * 0.4, len), p);
      }
    }
  }

  void _yard(Canvas c, Rect r) {
    for (var y = r.top.floor(); y < r.bottom.floor(); y++) {
      for (var x = r.left.floor(); x < r.right.floor(); x++) {
        _tile(c, Sprites.yard, x, y, 1, 0, const Color(0xFF8E8A7C));
      }
    }
  }

  void _decor(Canvas c, _Dec d) {
    final img = Sprites.decor[d.key];
    final foot = _px(Offset(d.x, d.y));
    if (img == null) {
      c.drawCircle(foot.translate(0, -t * 0.5), t * 0.4, Paint()..color = const Color(0xFF2F6B35));
      return;
    }
    final w = d.w * t;
    final h = w * img.height / img.width;
    c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(foot.dx - w / 2, foot.dy - h, w, h),
        Paint()..filterQuality = FilterQuality.low);
  }

  /// 지역마다 배달지 집 모양 (집 칸 0~5 순서). 'house1~3'은 가게(장식 폴더), 나머지는 지도 전용 집
  static const List<List<String>> housePool = [
    ['d0', 'd1', 'd2', 'd3', 'd4', 'd7'], // 동네: 알록달록 단독주택
    ['v0', 'house1', 'v1', 'v2', 'house3', 'house2'], // 시내: 빌라·가게
    ['d8', 'd9', 'd10', 'd11', 'd6', 'd5'], // 근교: 나무·돌집
    ['v1', 'd5', 'v2', 'd3', 'v0', 'house3'], // 타도시
    ['d6', 'v2', 'd4', 'house1', 'd9', 'v0'], // 전국
  ];

  void _house(Canvas c, int k) {
    final foot = _px(houseFoot[k]);
    final key = housePool[sel % housePool.length][k % 6];
    final img = Sprites.mapHouses[key] ??
        Sprites.decor[key.startsWith('house') ? key : ['house1', 'house2', 'house3'][(k + sel) % 3]];
    var w = houseW * t;
    if (img != null && w * img.height / img.width > houseMaxH * t) {
      // 키 큰 빌라는 높이에 맞춰 폭을 줄임 (윗줄 집이 아랫길을 덮지 않게)
      w = houseMaxH * t * img.width / img.height;
    }
    if (img == null) {
      final r = Rect.fromLTWH(foot.dx - w / 2, foot.dy - w * 0.8, w, w * 0.8);
      c.drawRect(r, Paint()..color = const Color(0xFFE8D9B5));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.35),
          Paint()..color = const Color(0xFFB5523B));
    } else {
      final h = w * img.height / img.width;
      c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(foot.dx - w / 2, foot.dy - h, w, h),
          Paint()..filterQuality = FilterQuality.none);
    }
  }

  /// 도트풍 사각형 (검은 테두리)
  void _block(Canvas c, Rect r, Color fill, {Color edge = const Color(0xFF2A2438)}) {
    final rr = Rect.fromLTRB(
        r.left.roundToDouble(), r.top.roundToDouble(), r.right.roundToDouble(), r.bottom.roundToDouble());
    c.drawRect(rr, Paint()..color = edge);
    c.drawRect(rr.deflate(max(1.0, t * 0.06)), Paint()..color = fill);
  }

  void _hub(Canvas c) {
    final img = Sprites.hub;
    if (img != null) {
      // 허브는 칸보다 조금 크게, 바닥은 앞(y 13)에서 기다리는 대형 트럭 지붕선 위에 맞춰 도크 문이 보이게
      _buildingSprite(c, img, Rect.fromLTRB(0.1, 7.6, 3.5, 11.9),
          '허브', C.accent, Colors.white,
          center: true);
      return;
    }
    final r = _pr(hubR);
    // 그림자
    c.drawRect(r.shift(Offset(t * 0.15, t * 0.15)), Paint()..color = const Color(0x33000000));
    _block(c, r, const Color(0xFFD9CFC0));
    // 지붕
    _block(c, Rect.fromLTRB(r.left - t * 0.1, r.top - t * 0.1, r.right + t * 0.1, r.top + t * 0.9),
        C.accent);
    // 도크 문 두 개
    for (var i = 0; i < 2; i++) {
      final x = r.left + t * (0.45 + i * 1.2);
      _block(c, Rect.fromLTWH(x, r.bottom - t * 1.5, t * 0.95, t * 1.5), const Color(0xFF55506E));
      c.drawRect(Rect.fromLTWH(x + t * 0.1, r.bottom - t * 1.35, t * 0.75, t * 0.12),
          Paint()..color = const Color(0xFF7C779A));
    }
    _label(c, '허브', Offset(r.center.dx, r.top + t * 0.45), t * 0.62, Colors.white);
  }

  void _center(Canvas c, bool open) {
    final r = _pr(centerR);
    final col = Color(Cfg.regionColor[sel]);
    final img = Sprites.centers[sel];
    if (img != null) {
      _buildingSprite(
          c,
          img,
          Rect.fromLTRB(centerR.left, centerR.top - 0.8, centerR.right, centerR.bottom),
          '${Cfg.regionName[sel]} 센터',
          open ? col : const Color(0xFF8A8799),
          open ? Colors.black : Colors.white70,
          grey: !open);
    } else {
      _centerShape(c, r, open, col);
    }
    // 내려둔 택배 더미
    final n = g.centerStock[sel];
    if (n > 0) {
      final base = _px(const Offset(9.0, 11.0));
      final img = Sprites.boxS;
      final cnt = min(n, 9);
      final bs = t * 0.32;
      for (var i = 0; i < cnt; i++) {
        final cx = base.dx + (i % 3) * bs * 1.05 + t * 0.1;
        final cy = base.dy + t * 0.95 - (i ~/ 3) * bs * 0.95 - bs;
        final dst = Rect.fromLTWH(cx, cy, bs, bs);
        if (img != null) {
          c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              dst, Paint()..filterQuality = FilterQuality.none);
        } else {
          c.drawRect(dst, Paint()..color = const Color(0xFFC89B5E));
        }
      }
      if (n > 9) _label(c, '$n', base.translate(t * 0.55, t * 0.2), t * 0.4, Colors.white);
    }
  }

  /// 도트 건물: 칸(타일 좌표) 안에 비율 유지로 맞추고 아래에 붙임. 기본은 왼쪽 정렬(센터는 도로가 왼쪽에서 닿음)
  void _buildingSprite(Canvas c, ui.Image img, Rect tiles, String name, Color tagColor,
      Color textColor,
      {bool grey = false, bool center = false}) {
    final box = _pr(tiles);
    final k = min(box.width / img.width, box.height / img.height);
    final w = img.width * k, h = img.height * k;
    final left = center ? box.center.dx - w / 2 : box.left;
    final dst = Rect.fromLTWH(left, box.bottom - h, w, h);
    c.drawOval(Rect.fromLTWH(dst.left + w * 0.04, dst.bottom - t * 0.22, w * 0.96, t * 0.4),
        Paint()..color = const Color(0x33000000));
    final p = Paint()..filterQuality = FilterQuality.none;
    if (grey) {
      p.colorFilter = const ColorFilter.matrix(<double>[
        0.25, 0.45, 0.1, 0, 10, //
        0.25, 0.45, 0.1, 0, 10, //
        0.25, 0.45, 0.1, 0, 14, //
        0, 0, 0, 1, 0,
      ]);
    }
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, p);
    // 이름표 (지붕 위)
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: TextStyle(
              color: textColor,
              fontSize: max(9.0, t * 0.48),
              fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tag = Rect.fromCenter(
        center: Offset(dst.center.dx, dst.top - tp.height * 0.2),
        width: tp.width + t * 0.5,
        height: tp.height + t * 0.12);
    c.drawRRect(RRect.fromRectAndRadius(tag, Radius.circular(t * 0.2)),
        Paint()..color = tagColor);
    tp.paint(c, Offset(tag.center.dx - tp.width / 2, tag.center.dy - tp.height / 2));
  }

  void _centerShape(Canvas c, Rect r, bool open, Color col) {
    c.drawRect(r.shift(Offset(t * 0.15, t * 0.15)), Paint()..color = const Color(0x33000000));
    _block(c, r, open ? const Color(0xFFE6DDCF) : const Color(0xFFB9B5A8));
    _block(c, Rect.fromLTRB(r.left - t * 0.1, r.top - t * 0.1, r.right + t * 0.1, r.top + t * 0.95),
        open ? col : const Color(0xFF8A8799));
    // 왼쪽 하역구 (도로가 들어오는 곳)
    _block(c, Rect.fromLTWH(r.left - t * 0.05, r.top + t * 1.15, t * 0.9, t * 1.5),
        const Color(0xFF55506E));
    // 위쪽 문 (배달 차량이 나가는 곳)
    final dx = _px(Offset(door.floorToDouble() + 0.5, 0)).dx;
    _block(c, Rect.fromLTWH(dx - t * 0.55, r.top + t * 1.0, t * 1.1, t * 0.95),
        const Color(0xFF55506E));
    // 창문
    for (var i = 0; i < 2; i++) {
      _block(c, Rect.fromLTWH(r.left + t * (1.5 + i * 3.2), r.top + t * 1.15, t * 0.9, t * 0.7),
          const Color(0xFF9CC8E8));
    }
    _label(c, '${Cfg.regionName[sel]} 센터', Offset(r.center.dx, r.top + t * 0.48), t * 0.58,
        open ? Colors.black : Colors.white70);
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

  /// 차량의 지도 위 위치(칸 좌표)
  Offset _unitPos(FleetUnit u, _Layout l, int slot) {
    if (u.isTrunk) {
      final len = _len(l.trunk);
      switch (u.state) {
        case 1:
          final p = (u.t / (u.dur + u.delay)).clamp(0.0, 1.0).toDouble();
          return _pointAt(l.trunk, len * p);
        case 2:
          final p = (u.t / u.dur).clamp(0.0, 1.0).toDouble();
          return _pointAt(l.trunk, len * (1 - p));
        default:
          // 허브 앞에서 대기 (도크에서 싣는 중이면 도크 문 앞)
          return Offset(1.4 + (slot % 3) * 1.5, 13.0);
      }
    }
    final path = courierPath(u.house);
    final len = _len(path);
    switch (u.state) {
      case 1:
        final p = (u.t / (u.dur + u.delay)).clamp(0.0, 1.0).toDouble();
        return _pointAt(path, len * p);
      case 2:
        final p = (u.t / u.dur).clamp(0.0, 1.0).toDouble();
        return _pointAt(path, len * (1 - p));
      default:
        return Offset(16.6, 9.7 + (slot % 3) * 0.9);
    }
  }

  void _unit(Canvas c, FleetUnit u, Offset tilePos) {
    final img = u.isTrunk ? Sprites.truck : (u.type == 1 ? Sprites.van : Sprites.moto);
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
            style: TextStyle(
                color: Colors.white, fontSize: max(10.0, t * 0.46), fontWeight: FontWeight.w800)),
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
    final l = layout(sel);
    final path = u.isTrunk ? l.trunk : courierPath(u.house);
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
        base = _px(Offset(door.floorToDouble() + 0.5, 8.3));
      } else {
        final hf = houseFoot[f.house % houseFoot.length];
        base = _px(Offset(hf.dx, hf.dy - houseW * 0.9));
      }
      final p = (f.t / 2.2).clamp(0.0, 1.0).toDouble();
      final pos = base.translate(0, -p * t * 1.6);
      final alpha = (p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
      final tp = TextPainter(
        text: TextSpan(
            text: f.text,
            style: TextStyle(
                color: Color(f.color).withOpacity(alpha),
                fontSize: max(11.0, t * 0.55),
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
