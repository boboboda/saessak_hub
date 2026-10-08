import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
import '../models/models.dart';
import 'theme.dart';

/// 전체화면 노선 지도: 허브 → 지역센터 → 동네. 차량이 달리는 걸 실시간으로 보고,
/// 노선·차량 배정·업그레이드를 여기서 한다.
class RouteMapScreen extends StatefulWidget {
  final HubGame g;
  const RouteMapScreen(this.g, {super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int sel = 0; // 선택한 지역

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
          Expanded(
            flex: 11,
            child: LayoutBuilder(builder: (context, box) {
              return GestureDetector(
                onTapUp: (d) {
                  final i = _MapPainter.hit(
                      d.localPosition, Size(box.maxWidth, box.maxHeight), g);
                  if (i >= 0) {
                    setState(() => sel = i);
                  }
                },
                child: CustomPaint(
                  painter: _MapPainter(g, _anim, sel),
                  size: Size(box.maxWidth, box.maxHeight),
                ),
              );
            }),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        // 소식
        if (g.notes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: C.card, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in g.notes.take(3))
                  Text(n.text,
                      style: TextStyle(color: Color(n.color), fontSize: 12)),
              ],
            ),
          ),
        for (var i = 0; i < Cfg.regionName.length; i++) ...[
          g.regionOpen[i] ? _routeCard(i) : _lockedCard(i),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _lockedCard(int i) {
    final can = g.canUnlockRegion(i);
    return CardBox(
      child: Row(
        children: [
          const Icon(Icons.lock, color: C.sub, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '${Cfg.regionName[i]} · 명성 ${Cfg.regionFame[i]} 필요 (지금 ${g.fame})',
                style: Tx.body),
          ),
          AppButton('열기',
              small: true, color: C.good, onTap: can ? () => g.unlockRegion(i) : null),
        ],
      ),
    );
  }

  Widget _routeCard(int i) {
    final rt = g.routes[i];
    final color = Color(Cfg.regionColor[i]);
    return GestureDetector(
      onTap: () => setState(() => sel = i),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel == i ? C.accent : Colors.transparent, width: 2),
        ),
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
                  child: Text(
                      '${Cfg.regionName[i]} · 허브 ${g.regionStock(i)}건 · 센터 ${g.centerStock[i]}건',
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
                '대형 트럭 ${g.trunkCount(i)}대 · 배달 차량 ${g.courierCount(i)}대',
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
          ],
        ),
      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        for (final u in g.fleet) ...[
          _unitCard(u),
          const SizedBox(height: 8),
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

  ui.Image? _img(FleetUnit u) {
    switch (u.type) {
      case 0:
        return Sprites.truck;
      case 1:
        return Sprites.van;
      default:
        return Sprites.moto;
    }
  }

  Widget _unitCard(FleetUnit u) {
    final img = _img(u);
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
        Text('${Cfg.regionName[r]} 노선에 배정돼요 (노선 탭이나 지도에서 지역을 고르세요)',
            style: Tx.sub),
        const SizedBox(height: 8),
        for (var t = 0; t < Cfg.vehicles.length; t++) ...[
          CardBox(
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 40,
                  child: RawImage(
                      image: t == 0
                          ? Sprites.truck
                          : (t == 1 ? Sprites.van : Sprites.moto),
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

// =================== 지도 그리기 ===================
class _MapPainter extends CustomPainter {
  final HubGame g;
  final int sel;
  _MapPainter(this.g, Listenable repaint, this.sel) : super(repaint: repaint);

  static const _pts = [
    Offset(0.36, 0.22),
    Offset(0.46, 0.78),
    Offset(0.66, 0.30),
    Offset(0.76, 0.80),
    Offset(0.90, 0.50),
  ];
  static const _hub = Offset(0.09, 0.50);

  static Offset _at(Offset f, Size s) => Offset(f.dx * s.width, f.dy * s.height);

  /// 센터 주변 동네 집 위치 (6채)
  static Offset house(Offset center, int k, Size s) {
    final a = k * pi / 3 + 0.5;
    final r = min(s.width, s.height) * 0.12;
    return center + Offset(cos(a) * r * 1.15, sin(a) * r * 0.85);
  }

  /// 탭한 지점에 가장 가까운 지역센터 번호 (없으면 -1)
  static int hit(Offset p, Size s, HubGame g) {
    var best = -1;
    var bd = 36.0;
    for (var i = 0; i < _pts.length; i++) {
      if (!g.regionOpen[i]) continue;
      final d = (p - _at(_pts[i], s)).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  @override
  void paint(Canvas c, Size s) {
    // 땅
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF5E9E4F));
    final hub = _at(_hub, s);

    // 도로 + 동네 길 + 집
    for (var i = 0; i < _pts.length; i++) {
      final open = g.regionOpen[i];
      final p = _at(_pts[i], s);
      final col = Color(Cfg.regionColor[i]);
      if (!open) {
        c.drawLine(hub, p,
            Paint()..color = const Color(0x44000000)..strokeWidth = 6..strokeCap = StrokeCap.round);
        _text(c, '🔒 ${Cfg.regionName[i]}', p + const Offset(-26, -8), 11, Colors.white70);
        continue;
      }
      final on = g.routes[i].on;
      c.drawLine(hub, p,
          Paint()..color = on ? const Color(0xFF3A3A48) : const Color(0xFF6A6A72)..strokeWidth = 12..strokeCap = StrokeCap.round);
      _dashed(c, hub, p, Paint()..color = const Color(0xFFFFD166)..strokeWidth = 2);
      for (var k = 0; k < 6; k++) {
        final h = house(p, k, s);
        c.drawLine(p, h, Paint()..color = const Color(0xFFB9B5A8)..strokeWidth = 4);
      }
      for (var k = 0; k < 6; k++) {
        final h = house(p, k, s);
        c.drawRect(Rect.fromCenter(center: h, width: 14, height: 12),
            Paint()..color = const Color(0xFFE8D9B5));
        c.drawRect(Rect.fromCenter(center: h.translate(0, -8), width: 16, height: 6),
            Paint()..color = const Color(0xFFB5523B));
      }
      // 센터
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: 30, height: 24), const Radius.circular(5)),
          Paint()..color = col);
      if (sel == i) {
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: p, width: 36, height: 30), const Radius.circular(7)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white);
      }
      _text(c, '${Cfg.regionName[i]} ${g.centerStock[i]}', p + const Offset(-22, 14), 11, Colors.white);
    }

    // 허브
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: hub, width: 38, height: 32), const Radius.circular(6)),
        Paint()..color = C.accent);
    _text(c, '허브', hub + const Offset(-12, -7), 12, Colors.white);

    // 차량
    for (final u in g.fleet) {
      _drawUnit(c, u, hub, s);
    }
  }

  void _drawUnit(Canvas c, FleetUnit u, Offset hub, Size s) {
    final center = _at(_pts[u.region], s);
    Offset a, b;
    double p;
    if (u.isTrunk) {
      switch (u.state) {
        case 1:
          a = hub;
          b = center;
          p = u.t / (u.dur + u.delay);
          break;
        case 2:
          a = center;
          b = hub;
          p = u.t / u.dur;
          break;
        default:
          a = hub;
          b = hub;
          p = 0;
      }
    } else {
      final h = house(center, u.house, s);
      switch (u.state) {
        case 1:
          a = center;
          b = h;
          p = u.t / (u.dur + u.delay);
          break;
        case 2:
          a = h;
          b = center;
          p = u.t / u.dur;
          break;
        default:
          a = center;
          b = center;
          p = 0;
      }
    }
    p = p.clamp(0.0, 1.0).toDouble();
    var pos = Offset.lerp(a, b, p)!;
    if (u.state == 0 || u.state == 3) {
      // 대기 중: 허브/센터 옆에 서 있음
      pos = (u.isTrunk ? hub : center) + Offset(14.0 * ((u.id % 3) - 1), 22);
    }
    final img = u.isTrunk
        ? Sprites.truck
        : (u.type == 1 ? Sprites.van : Sprites.moto);
    final w = u.isTrunk ? 42.0 : (u.type == 1 ? 30.0 : 20.0);
    if (img != null) {
      final h = w * img.height / img.width;
      final dst = Rect.fromCenter(center: pos, width: w, height: h);
      final flip = b.dx < a.dx;
      c.save();
      if (flip) {
        c.translate(pos.dx, 0);
        c.scale(-1, 1);
        c.translate(-pos.dx, 0);
      }
      c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          dst,
          Paint()..filterQuality = FilterQuality.none);
      c.restore();
    } else {
      c.drawCircle(pos, 6, Paint()..color = Colors.white);
    }
    if (u.state == 1 && u.cargo > 0) {
      _text(c, '${u.cargo}', pos + Offset(-6, -w * 0.5 - 12), 10, Colors.white);
    }
    // 이벤트 말풍선
    if (u.evtT > 0 && u.evtText != null) {
      final col = u.evtOk ? const Color(0xFF3FB27F) : const Color(0xFFE5484D);
      final tp = TextPainter(
        text: TextSpan(
            text: u.evtText,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = Rect.fromCenter(
          center: pos.translate(0, -w * 0.5 - 22),
          width: tp.width + 14,
          height: tp.height + 8);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = col);
      tp.paint(c, Offset(r.left + 7, r.top + 4));
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    if (len < 1) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 16) {
      c.drawLine(a + dir * d, a + dir * min(d + 8, len), p);
    }
  }

  void _text(Canvas c, String t, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
