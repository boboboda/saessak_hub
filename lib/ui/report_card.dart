import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 하루 정산 카드: 등급(S~D) · 별점 · 접수/놓침/실수 · 명성 · 수익/월급 (해가 바뀌면 올해 목표 결과)
class ReportCard extends StatelessWidget {
  final HubGame g;
  const ReportCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = g.report!;
    final has = r.grade >= 0;
    final col = has ? Color(Cfg.gradeColor[r.grade]) : C.sub;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
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
          Text('${r.day}일차 정산', style: Tx.title),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: col, width: 3),
                ),
                child: Text(
                  has ? Cfg.gradeName[r.grade] : '-',
                  style: TextStyle(color: col, fontSize: 40, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stars(r.stars),
                  const SizedBox(height: 4),
                  Text(has ? '만족도 ${r.stars.toStringAsFixed(1)}점' : '손님이 없었어요', style: Tx.sub),
                  const SizedBox(height: 4),
                  Text(
                    r.fameD == 0 ? '명성 변화 없음' : '명성 ${r.fameD > 0 ? '+' : ''}${r.fameD}',
                    style: TextStyle(
                      color: r.fameD >= 0 ? C.good : C.bad,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _cell('접수', '${r.served}건', C.text),
              _cell('놓친 손님', '${r.lost}명', r.lost > 0 ? C.bad : C.text),
              _cell('포장 실수', '${r.mistakes}번', r.mistakes > 0 ? C.accent : C.text),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cell('수익', '+${g.fmt(r.earned)}원', C.gold),
              _cell('월급', '-${g.fmt(r.wages)}원', r.paidAll ? C.text : C.bad),
            ],
          ),
          if (!r.paidAll) ...[
            const SizedBox(height: 6),
            const Text('월급을 다 못 줬어요 (파산은 없어요)', style: TextStyle(color: C.bad, fontSize: 12)),
          ],
                    for (final n in r.notes) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.campaign, size: 16, color: C.accent),
                const SizedBox(width: 6),
                Expanded(child: Text(n, style: Tx.body)),
              ],
            ),
          ],
          if (g.rs.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.line, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.local_shipping, size: 16, color: C.blue),
                    SizedBox(width: 4),
                    Text('노선 결산', style: Tx.h2),
                  ]),
                  const SizedBox(height: 3),
                  for (final line in g.rs.summary)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(line, style: Tx.body.copyWith(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
          if (r.yearText != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('새해! ${r.yearText}', style: const TextStyle(color: C.gold, fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 12),
          AppButton('확인', color: C.good, expand: true, onTap: () {
            g.report = null;
            g.ui();
          }),
        ],
      ),
    );
  }

  Widget _stars(double v) => Row(
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          v >= i - 0.25 ? Icons.star : (v >= i - 0.75 ? Icons.star_half : Icons.star_border),
          color: C.gold,
          size: 20,
        ),
    ],
  );

  Widget _cell(String k, String v, Color c) => Expanded(
    child: Column(
      children: [
        Text(k, style: Tx.sub),
        const SizedBox(height: 2),
        Text(v, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
