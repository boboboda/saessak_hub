import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 도감: 손님 · 직업 · 세트 3권 + 완성 보너스 (25% 수익 +3%, 50% 연구 +10%, 100% 전설 직원)
class BookSheet extends StatelessWidget {
  final HubGame g;
  const BookSheet(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final rt = g.rt;
    final pct = g.bookPct;
    return SheetFrame(
      title: '도감',
      heightFactor: 0.8,
      onClose: g.closeAll,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Pill(Icons.menu_book, '${g.bookFound}/${g.bookTotal}', color: C.good),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('완성도 ${(pct * 100).floor()}%', style: Tx.h2),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: C.line,
                    valueColor: const AlwaysStoppedAnimation<Color>(C.good),
                  ),
                ),
                const SizedBox(height: 6),
                _bonus(pct >= 0.25, '25% · 수익 +3% (영구)'),
                _bonus(pct >= 0.5, '50% · 연구 속도 +10%'),
                _bonus(pct >= 1.0, '100% · 전설 직원 후보'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('손님 도감 ${rt.foundGuests.length}/${Cfg.guestName.length}', style: Tx.h2),
          const SizedBox(height: 6),
          for (var k = 0; k < Cfg.guestName.length; k++)
            _row(
              rt.foundGuests.contains(k),
              rt.foundGuests.contains(k) ? Cfg.guestName[k] : '???',
              rt.foundGuests.contains(k) ? Cfg.guestEffect[k] : '힌트: ${Cfg.guestHint[k]}',
              Icons.person,
            ),
          const SizedBox(height: 14),
          Text(
              '직업 도감 ${rt.seenJobs.length + rt.seenPromo.length}/${Cfg.jobName.length + Cfg.baseJobs}',
              style: Tx.h2),
          const SizedBox(height: 6),
          for (var j = 0; j < Cfg.baseJobs; j++) ...[
            _row(rt.seenJobs.contains(j), Cfg.jobName[j], Cfg.jobWhere[j], Icons.badge),
            _row(rt.seenPromo.contains(j), rt.seenPromo.contains(j) ? '★${Cfg.jobPromo[j]}' : '??? (상위 직업)',
                rt.seenPromo.contains(j) ? Cfg.jobSkills[j][3] : '${Cfg.jobName[j]} Lv5 + 전직서', Icons.star),
          ],
          for (var h = Cfg.baseJobs; h < Cfg.jobName.length; h++)
            _row(
              rt.seenJobs.contains(h),
              rt.seenJobs.contains(h) ? Cfg.jobName[h] : '??? (숨은 직업)',
              rt.seenJobs.contains(h)
                  ? Cfg.jobSkills[h][0]
                  : '힌트: ${Cfg.jobName[Cfg.hiddenJobNeed[h - Cfg.baseJobs].$1]}과(와) '
                      '${Cfg.jobName[Cfg.hiddenJobNeed[h - Cfg.baseJobs].$2]}을(를) 한 사람이 Lv5까지',
              Icons.auto_awesome,
            ),
          const SizedBox(height: 14),
          Text('세트 도감 ${rt.foundSets.length}/${Cfg.sets.length}', style: Tx.h2),
          const SizedBox(height: 6),
          for (var i = 0; i < Cfg.sets.length; i++)
            _row(
              rt.foundSets.contains(i),
              Cfg.sets[i].hidden && !rt.foundSets.contains(i) ? '???' : Cfg.sets[i].name,
              Cfg.sets[i].hidden && !rt.foundSets.contains(i)
                  ? '힌트: ${Cfg.sets[i].hint}'
                  : '${_need(Cfg.sets[i].need)} → ${Cfg.sets[i].effect}',
              Icons.link,
            ),
        ],
      ),
    );
  }

  static String _need(Map<String, int> m) => m.entries
      .map((e) => '${Cfg.types.firstWhere((t) => t.id == e.key).name}${e.value > 1 ? '×${e.value}' : ''}')
      .join(' + ');

  Widget _bonus(bool on, String t) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(on ? Icons.check_circle : Icons.lock_outline, size: 16, color: on ? C.good : C.sub),
            const SizedBox(width: 6),
            Text(t, style: TextStyle(color: on ? C.text : C.sub, fontSize: 12)),
          ],
        ),
      );

  Widget _row(bool got, String name, String sub, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: CardBox(
          child: Row(
            children: [
              Icon(got ? icon : Icons.help_outline, size: 20, color: got ? C.gold : C.sub),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Tx.body.copyWith(color: got ? C.text : C.sub)),
                    Text(sub, style: Tx.sub),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
