import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 연말 '택배 대상' 시상식: 순위표(경쟁사 5곳 + 나), 보상
class AwardCard extends StatelessWidget {
  final HubGame g;
  const AwardCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final a = g.award!;
    const medal = [Color(0xFFFFD166), Color(0xFFD7DCE3), Color(0xFFD9915A)];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.frame, width: 3),
        boxShadow: [BoxShadow(color: C.gold, offset: const Offset(0, 5)), const BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 48, color: a.rank <= 3 ? medal[a.rank - 1] : C.sub),
          const SizedBox(height: 4),
          Text('${a.year}년차 택배 대상', style: Tx.title),
          const SizedBox(height: 2),
          const Text('올해 접수 + 평균 별 × 60 + 명성 × 0.5', style: Tx.sub),
          const SizedBox(height: 12),
          for (var i = 0; i < a.rows.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: a.rows[i].$3 ? C.good.withValues(alpha: 0.2) : C.card,
                borderRadius: BorderRadius.circular(8),
                border: a.rows[i].$3 ? Border.all(color: C.good) : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}위',
                        style: TextStyle(color: i < 3 ? medal[i] : C.sub, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.rows[i].$1, style: Tx.body)),
                  Text(g.fmt(a.rows[i].$2), style: const TextStyle(color: C.text, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          for (final r in a.rewards)
            Text(r, textAlign: TextAlign.center, style: const TextStyle(color: C.gold, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          AppButton('확인', color: C.good, expand: true, onTap: () {
            g.award = null;
            g.ui();
          }),
        ],
      ),
    );
  }
}

/// 회사 등급 승급 카드 (마지막 등급이면 엔딩 + 무한 모드 안내)
class GradeUpCard extends StatelessWidget {
  final HubGame g;
  const GradeUpCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final k = g.gradeUp!;
    final last = k == Cfg.corpName.length - 1;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.frame, width: 3),
        boxShadow: [BoxShadow(color: C.good, offset: const Offset(0, 5)), const BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(last ? Icons.public : Icons.trending_up, size: 48, color: C.good),
          const SizedBox(height: 6),
          Text(last ? '전국 네트워크 달성!' : '승급! ${Cfg.corpName[k]}', style: Tx.title),
          const SizedBox(height: 8),
          Text(
            last
                ? '작은 동네 영업소에서 시작한 새싹 택배가 전국을 잇는 회사가 됐어요.\n'
                    '이제부터는 무한 모드: 경쟁사가 더 빨리 커져요.'
                : '새로 열림: ${Cfg.gradeUnlockText[k]}',
            textAlign: TextAlign.center,
            style: Tx.body,
          ),
          const SizedBox(height: 14),
          AppButton(last ? '계속하기' : '확인', color: C.good, expand: true, onTap: () {
            g.gradeUp = null;
            g.ui();
          }),
        ],
      ),
    );
  }
}
