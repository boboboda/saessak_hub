import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 건설 메뉴: 건물 목록. '건설'을 누르면 시트가 닫히고 지도에서 목업(고스트)을 옮겨 놓는다.
class BuildSheet extends StatelessWidget {
  final HubGame g;
  const BuildSheet(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: '건설',
      heightFactor: 0.62,
      onClose: g.closeAll,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Pill(Icons.paid, '${g.money}원', color: C.gold),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        itemCount: Cfg.types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TypeCard(g, Cfg.types[i]),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final HubGame g;
  final dynamic t; // BuildingType
  const _TypeCard(this.g, this.t);

  @override
  Widget build(BuildContext context) {
    final can = g.money >= t.cost;
    final zone = t.zone >= 0 ? Cfg.zoneName[t.zone as int] : '창고 어디든';
    final swatch = Color(t.color as int);

    return CardBox(
      child: Row(
        children: [
          // 크기 견본
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: swatch.withOpacity(0.22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: swatch, width: 2),
            ),
            child: Text(
              '${t.w}×${t.h}',
              style: TextStyle(
                color: swatch,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name as String, style: Tx.h2),
                const SizedBox(height: 2),
                Text(t.desc as String, style: Tx.sub),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 12, color: C.sub),
                    const SizedBox(width: 3),
                    Text(zone, style: Tx.sub),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.cost}원',
                style: TextStyle(
                  color: can ? C.gold : C.bad,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              AppButton(
                '건설',
                small: true,
                onTap: can ? () => g.startPlacing(t) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}