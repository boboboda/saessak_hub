import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';
import 'theme.dart';

/// 노선 지도 + 지역별 노선 설정 (운행·차량·대기 시간·우선순위)
class RoutePanel extends StatelessWidget {
  final HubGame g;
  const RoutePanel(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final open = [
      for (var i = 0; i < g.regionOpen.length; i++)
        if (g.regionOpen[i]) i
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('노선', style: Tx.h2),
        const SizedBox(height: 4),
        const Text('지역마다 차량·출발 방식·우선순위를 정해요. 오래 기다릴수록 꽉 채워 보내 수익 ×1.2를 받기 쉬워요',
            style: Tx.sub),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(painter: _MapPainter(g), size: Size.infinite),
          ),
        ),
        const SizedBox(height: 8),
        for (final i in open) ...[
          _routeCard(i),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _routeCard(int i) {
    final rt = g.routes[i];
    final color = Color(Cfg.regionColor[i]);
    return CardBox(
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
                    '${Cfg.regionName[i]} · 재고 ${g.regionStock(i)}건',
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
          _row('차량', [
            _chip('자동', rt.vehicle == -1, () => _set(() => rt.vehicle = -1)),
            for (var k = Cfg.vehicles.length - 1; k >= 0; k--)
              _chip(Cfg.vehicles[k].name, rt.vehicle == k,
                  () => _set(() => rt.vehicle = k)),
          ]),
          _row('대기', [
            for (final w in Cfg.waitOptions)
              _chip('${w.round()}초', rt.wait == w, () => _set(() => rt.wait = w)),
          ]),
          _row('우선', [
            for (var p = 1; p <= 3; p++)
              _chip(p == 1 ? '보통' : (p == 2 ? '높음' : '최우선'), rt.prio == p,
                  () => _set(() => rt.prio = p)),
          ]),
          if (rt.vehicle >= 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  '${Cfg.vehicles[rt.vehicle].name}은 이 지역 택배가 ${Cfg.vehicles[rt.vehicle].minStock}건 이상 쌓여야 와요',
                  style: Tx.sub),
            ),
        ],
      ),
    );
  }

  void _set(VoidCallback f) {
    f();
    g.ui();
  }

  Widget _row(String label, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label, style: Tx.sub)),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: chips),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? C.accent : C.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? C.accent : C.line),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final HubGame g;
  _MapPainter(this.g);

  static const _pts = [
    Offset(0.36, 0.24),
    Offset(0.44, 0.78),
    Offset(0.64, 0.36),
    Offset(0.74, 0.82),
    Offset(0.90, 0.5),
  ];

  @override
  void paint(Canvas c, Size s) {
    Offset at(Offset f) => Offset(f.dx * s.width, f.dy * s.height);
    final hub = Offset(s.width * 0.1, s.height * 0.5);

    for (var i = 0; i < _pts.length; i++) {
      final p = at(_pts[i]);
      final open = g.regionOpen[i];
      final on = g.routes[i].on;
      final col = Color(Cfg.regionColor[i]);
      c.drawLine(
          hub,
          p,
          Paint()
            ..color = open ? col.withOpacity(on ? 0.9 : 0.3) : C.line
            ..strokeWidth = open ? (g.routes[i].prio + 1.0) : 1.5);
      c.drawCircle(p, 9, Paint()..color = open ? col : C.panel);
      c.drawCircle(
          p,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = open ? Colors.white : C.line);
      _text(c, Cfg.regionName[i], Offset(p.dx - 16, p.dy + 11), 10,
          open ? Colors.white : C.sub);
    }
    // 달리는 차량
    for (final t in g.trips) {
      final p = Offset.lerp(hub, at(_pts[t.region]), (t.t / t.dur).clamp(0.0, 1.0))!;
      c.drawCircle(p, 5, Paint()..color = Colors.white);
      c.drawCircle(p, 3.5, Paint()..color = Color(Cfg.regionColor[t.region]));
    }
    // 허브
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: hub, width: 30, height: 30),
            const Radius.circular(6)),
        Paint()..color = C.accent);
    _text(c, '허브', Offset(hub.dx - 10, hub.dy - 6), 11, Colors.white);
  }

  void _text(Canvas c, String t, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
