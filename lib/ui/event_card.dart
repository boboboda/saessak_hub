import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 선택형 사건 팝업: 아이콘 · 제목 · 설명 · 선택지 2개(예상 결과). 고르는 동안 게임은 멈춤
class EventCard extends StatelessWidget {
  final HubGame g;
  const EventCard(this.g, {super.key});

  static const _icons = [
    Icons.videocam,
    Icons.celebration,
    Icons.mood_bad,
    Icons.inventory,
    Icons.wb_sunny,
    Icons.person_add,
  ];
  static const _colors = [
    Color(0xFF8EC5FF),
    Color(0xFFFFD166),
    Color(0xFFE5484D),
    Color(0xFFF0963A),
    Color(0xFFFF8A50),
    Color(0xFF7BD389),
  ];

  @override
  Widget build(BuildContext context) {
    final e = g.evtNow!;
    final col = _colors[e.kind];
    final ch = g.evtChoices(e);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.frame, width: 3),
        boxShadow: [BoxShadow(color: col, offset: const Offset(0, 5)), const BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: col, width: 2),
            ),
            child: Icon(_icons[e.kind], color: col, size: 34),
          ),
          const SizedBox(height: 10),
          Text(Cfg.hubEvtName[e.kind], style: Tx.title),
          const SizedBox(height: 6),
          Text(Cfg.hubEvtDesc[e.kind], style: Tx.body, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          for (var i = 0; i < ch.length; i++) ...[
            Material(
              color: i == 0 ? col.withValues(alpha: 0.18) : C.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => g.chooseEvent(i),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == 0 ? col : C.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch[i].$1, style: Tx.h2),
                      const SizedBox(height: 2),
                      Text(ch[i].$2, style: Tx.sub),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Text('고르는 동안 게임은 잠시 멈춰요', style: Tx.sub),
        ],
      ),
    );
  }
}
