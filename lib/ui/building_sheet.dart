import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';
import 'dialogs.dart';
import 'staff_widgets.dart';
import 'theme.dart';

/// 지도에서 건물을 눌렀을 때 뜨는 시트
class BuildingSheet extends StatelessWidget {
  final HubGame g;
  final Building b;
  const BuildingSheet(this.g, this.b, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = b.type;
    final hasSlots = t.slots > 0;
    final refund = t.cost ~/ 2;

    return SheetFrame(
      title: '${t.name} #${g.typeIndex(b)}',
      heightFactor: hasSlots ? 0.62 : 0.34,
      onClose: g.closeAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          Text(t.desc, style: Tx.sub),
          const SizedBox(height: 10),
          if (t.id == 'counter')
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 18, color: C.good),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.mine
                          ? '내 자리예요. 손님을 탭하면 바로 접수돼요 (+${Cfg.tapBonus}원)'
                          : '직원 창구예요. 내 자리로 바꾸면 손님을 직접 탭해서 접수해요',
                      style: Tx.body,
                    ),
                  ),
                  if (!b.mine)
                    AppButton('내 자리로',
                        small: true, color: C.good, onTap: () => g.setMine(b)),
                ],
              ),
            ),
          if (t.id == 'counter') const SizedBox(height: 8),
          if (hasSlots) ..._crewSection(context),
          if (t.id == 'shelf')
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 18, color: C.sub),
                  const SizedBox(width: 8),
                  Text('보관 ${b.stored}/${Cfg.shelfCap}', style: Tx.body),
                ],
              ),
            ),
          if (t.id == 'dock')
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, size: 18, color: C.sub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.vehicle == null
                          ? '차량 대기 중 · 한 지역 택배가 ${Cfg.vehicles.last.minStock}건 이상 쌓이면 와요'
                          : '${b.vehicle!.type.name} · ${b.vehicle!.loaded}/${b.vehicle!.type.cap}건 적재',
                      style: Tx.body,
                    ),
                  ),
                ],
              ),
            ),
          if (t.id == 'dock') const SizedBox(height: 8),
          if (t.id == 'vending')
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.local_drink, size: 18, color: C.sub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '손님 짜증 -${(Cfg.vendingCalm * 100).round()}% (최대 ${Cfg.vendingMax}대까지 겹쳐요)',
                      style: Tx.body,
                    ),
                  ),
                ],
              ),
            ),
          if (t.id == 'lounge')
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.weekend, size: 18, color: C.sub),
                  const SizedBox(width: 8),
                  Text(
                    '쉬는 직원 ${g.staff.where((s) => s.rest == 2 && s.lounge == b).length}/${Cfg.loungeSeats.length}',
                    style: Tx.body,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          AppButton(
            '철거 (+$refund원)',
            color: C.bad,
            expand: true,
            onTap: () => g.demolish(),
          ),
        ],
      ),
    );
  }

  List<Widget> _crewSection(BuildContext context) {
    final t = b.type;
    final rate = b.active.fold<double>(0, (a, s) => a + s.workRate);
    final rows = <Widget>[
      Row(
        children: [
          Text('근무 직원 ${b.crew.length}/${t.slots}', style: Tx.h2),
          const Spacer(),
          if (b.active.isNotEmpty)
            Pill(Icons.speed, '×${rate.toStringAsFixed(1)}', color: C.accent),
        ],
      ),
      const SizedBox(height: 8),
    ];

    for (final s in b.crew) {
      rows.add(CardBox(
        child: Row(
          children: [
            StaffAvatar(s, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(s.name, style: Tx.h2),
                      if (s.away) RoleChip(g, s),
                    ],
                  ),
                  const SizedBox(height: 4),
                  StaffStats(s),
                  const SizedBox(height: 4),
                  EnergyBar(s),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppButton('해제',
                small: true, color: C.card, onTap: () => g.unassign(s)),
          ],
        ),
      ));
      rows.add(const SizedBox(height: 8));
    }

    for (var i = b.crew.length; i < t.slots; i++) {
      rows.add(Material(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showAssignStaffDialog(context, g, b),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.line),
            ),
            child: const Text(
              '+ 직원 배치',
              style: TextStyle(
                  color: C.accent, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ));
      rows.add(const SizedBox(height: 8));
    }

    if (b.crew.isEmpty) {
      rows.add(Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.bad.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.bad.withOpacity(0.6)),
        ),
        child: const Text(
          '직원이 없으면 작동하지 않아요',
          style: TextStyle(
              color: C.bad, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ));
    } else if (b.active.isEmpty) {
      rows.add(Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.accent.withOpacity(0.6)),
        ),
        child: const Text(
          '모두 쉬러 가서 지금은 멈춰 있어요. 직원을 더 배치하면 덜 멈춰요',
          style: TextStyle(
              color: C.accent, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ));
    }
    return rows;
  }
}