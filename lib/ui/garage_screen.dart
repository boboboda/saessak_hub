import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'fleet_widgets.dart';
import 'theme.dart';

/// 차고: 내 차량 전체(노선별) 관리와 차량 구입. 노선 지도에서 분리한 화면
class GarageScreen extends StatelessWidget {
  final HubGame g;
  const GarageScreen(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Material(
      color: C.bg,
      child: ValueListenableBuilder<int>(
        valueListenable: g.tick,
        builder: (context, _, __) => Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, mq.padding.top + 12, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xEE1E1B2E),
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.garage, color: C.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('차고 · 차량 ${g.fleet.length}대', style: Tx.title)),
                  Pill(Icons.monetization_on, g.fmt(g.money), color: C.gold),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 16 + navInset(context)),
                children: [
                  for (var r = 0; r < Cfg.regionName.length; r++) ..._region(r),
                  const SizedBox(height: 8),
                  _buy(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _region(int r) {
    final list = g.fleet.where((u) => u.region == r).toList();
    if (list.isEmpty) return const [];
    return [
      Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(Cfg.regionColor[r]), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('${Cfg.regionName[r]} 노선 ${list.length}대', style: Tx.h2),
        ],
      ),
      const SizedBox(height: 6),
      for (final u in list) ...[UnitCard(g, u), const SizedBox(height: 8)],
      const SizedBox(height: 6),
    ];
  }

  /// 차량 구입: 배정할 지역 고르기 + 차종 3개
  Widget _buy() {
    final r = g.regionOpen[g.mapSel] ? g.mapSel : 0;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('차량 구입', style: Tx.h2),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < Cfg.regionName.length; i++)
                if (g.regionOpen[i])
                  ChoiceChip(
                    label: Text(Cfg.regionName[i]),
                    selected: r == i,
                    selectedColor: Color(Cfg.regionColor[i]),
                    onSelected: (_) {
                      g.mapSel = i;
                      g.ui();
                    },
                  ),
            ],
          ),
          const SizedBox(height: 8),
          for (var t = 0; t < Cfg.vehicles.length; t++) ...[
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 40,
                  child: RawImage(image: unitImage(t), fit: BoxFit.contain, filterQuality: FilterQuality.none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Cfg.vehicles[t].name, style: Tx.h2),
                      Text(t == 0 ? '허브→지역센터 간선 · 적재 ${Cfg.vehicles[t].cap}' : '센터→동네 배달 · 적재 ${Cfg.vehicles[t].cap}',
                          style: Tx.sub),
                    ],
                  ),
                ),
                AppButton('${g.fmt(Cfg.unitCost[t])}원',
                    small: true, color: C.accent, onTap: g.money >= Cfg.unitCost[t] ? () => g.buyUnit(t, r) : null),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text('${Cfg.regionName[r]} 노선에 배정돼요', style: Tx.sub),
        ],
      ),
    );
  }
}
