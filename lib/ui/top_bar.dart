import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

class TopBar extends StatelessWidget {
  final HubGame g;
  const TopBar(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final progress = (g.dayTimer / Cfg.dayLength).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.fromLTRB(14, mq.padding.top + 6, 6, 8),
      decoration: const BoxDecoration(
        color: Color(0xEE1E1B2E),
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('새싹 택배 허브', style: Tx.title),
                    Text('${Cfg.areaName[g.areaLevel]} · ${g.day}일차',
                        style: Tx.sub),
                  ],
                ),
              ),
              Pill(Icons.monetization_on, g.fmt(g.money), color: C.gold),
              const SizedBox(width: 6),
              _SmallBtn(
                'x${g.speedMul}',
                    () {
                  g.speedIdx = (g.speedIdx + 1) % Cfg.speeds.length;
                  g.ui();
                },
              ),
              PopupMenuButton<int>(
                icon: const Icon(Icons.bug_report, color: C.sub),
                color: C.panel,
                onSelected: (v) {
                  switch (v) {
                    case 0:
                      g.money += 10000;
                      break;
                    case 1:
                      g.genCandidates();
                      g.candTimer = 0;
                      break;
                    case 2:
                      g.dayTimer = Cfg.dayLength; // 곧바로 월급 정산
                      break;
                    case 3:
                      for (var i = 0; i < 3; i++) {
                        g.spawnCustomer();
                      }
                      break;
                    case 4:
                      g.resetSave();
                      break;
                  }
                  g.ui();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('돈 +10,000', style: Tx.body)),
                  PopupMenuItem(value: 1, child: Text('후보 새로고침 (무료)', style: Tx.body)),
                  PopupMenuItem(value: 2, child: Text('하루 넘기기 (월급)', style: Tx.body)),
                  PopupMenuItem(value: 3, child: Text('손님 +3', style: Tx.body)),
                  PopupMenuItem(value: 4, child: Text('저장 지우기 (다시 켜면 새로 시작)', style: Tx.body)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Pill(Icons.inbox, '접수 ${g.done}'),
                Pill(Icons.inventory_2, '보관 ${g.totalStored}'),
                Pill(Icons.local_shipping, '배송 ${g.delivered}'),
                Pill(Icons.sentiment_dissatisfied, '놓침 ${g.lost}',
                    color: g.lost > 0 ? C.bad : C.sub),
                Pill(Icons.groups, '직원 ${g.staff.length}'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: C.line,
                valueColor: const AlwaysStoppedAnimation<Color>(C.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(label,
              style: const TextStyle(
                  color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }
}