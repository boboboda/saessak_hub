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
      heightFactor: hasSlots
          ? 0.62
          : (t.id == 'shelf' || t.id == 'dock' ? 0.55 : 0.34),
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
                  Text('보관 ${b.stored}/${b.cap}', style: Tx.body),
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
                          ? '대형 트럭 대기 중 · 한 지역 택배가 ${Cfg.hubTruckMin}건 이상 쌓이면 와요'
                          : '${b.vehicle!.type.name} · ${b.vehicle!.loaded}/${b.vehicle!.cap}건 적재',
                      style: Tx.body,
                    ),
                  ),
                ],
              ),
            ),
          if (t.id == 'dock') const SizedBox(height: 8),
          if (t.id == 'shelf' || t.id == 'dock') ..._carrierSection(),
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
          if (b.type.id == 'counter' ||
              b.type.id == 'pack' ||
              b.type.id == 'shelf' ||
              b.type.id == 'dock') ...[
            const SizedBox(height: 8),
            CardBox(
              child: Row(
                children: [
                  const Icon(Icons.upgrade, size: 18, color: C.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lv.${b.level}/${Building.maxLevel} · ${_upgradeText(b)}',
                      style: Tx.body,
                    ),
                  ),
                  if (b.upgradable)
                    AppButton('${g.fmt(b.upgradeCost)}원',
                        small: true,
                        color: C.gold.withOpacity(0.9),
                        onTap: g.money >= b.upgradeCost
                            ? () => g.upgradeBuilding(b)
                            : null),
                ],
              ),
            ),
          ],
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

  /// 직원 고르기 목록 (대기 → 다른 일 순). 누르면 onPick
  List<Widget> _pickRows(void Function(Staff) onPick, bool Function(Staff) ok) {
    final list = g.staff.where(ok).toList()
      ..sort((a, b) => (a.idle ? 0 : 1).compareTo(b.idle ? 0 : 1));
    if (list.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('고를 직원이 없어요. 직원 메뉴에서 고용하세요', style: Tx.sub),
        ),
      ];
    }
    final out = <Widget>[];
    for (final s in list) {
      out.add(Material(
        color: C.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onPick(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                StaffAvatar(s, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${s.name} Lv.${s.level}', style: Tx.h2),
                ),
                RoleChip(g, s),
                const SizedBox(width: 8),
                Text('${(s.energyPct * 100).round()}%', style: Tx.sub),
                const SizedBox(width: 8),
                const Icon(Icons.add_circle, color: C.accent, size: 22),
              ],
            ),
          ),
        ),
      ));
      out.add(const SizedBox(height: 6));
    }
    return out;
  }

  /// 선반·도크: 운반 담당 현황 + 운반 직원 고르기
  List<Widget> _carrierSection() {
    final n = g.staff.where((s) => s.carrier).length;
    return [
      const SizedBox(height: 8),
      Text('운반 담당 $n명 (접수 → 포장 → 선반 → 도크를 나름)', style: Tx.h2),
      const SizedBox(height: 6),
      ..._pickRows((s) => g.setCarrier(s), (s) => !s.carrier),
    ];
  }

  String _upgradeText(Building b) {
    switch (b.type.id) {
      case 'counter':
        return '접수 속도 +${((b.speedMul - 1) * 100).round()}% · 대기 택배 ${b.outCap}건';
      case 'pack':
        return '포장 속도 +${((b.speedMul - 1) * 100).round()}%';
      case 'shelf':
        return '보관 용량 ${b.cap}건';
      default:
        return '싣는 속도 +${((b.loadMul - 1) * 100).round()}%';
    }
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
                      Text(
                          '${s.name} Lv.${s.level}${s.spec > 0 ? ' · ${s.specName}' : ''}',
                          style: Tx.h2),
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

    // 빈 자리가 있으면 직원 목록을 바로 보여 줌: 고르면 배치 (대기 직원이 위)
    if (b.crew.length < t.slots) {
      rows.add(Text('직원 고르기 · 빈 자리 ${t.slots - b.crew.length}', style: Tx.sub));
      rows.add(const SizedBox(height: 6));
      rows.addAll(_pickRows((s) => g.assignTo(s, b), (s) => !b.crew.contains(s)));
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