import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
import 'theme.dart';

/// 사연 물건 아이콘 (도트 그대로 확대)
class StoryIcon extends StatelessWidget {
  final ui.Image? img;
  final double size;
  const StoryIcon(this.img, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: img == null ? const Icon(Icons.inventory_2, color: C.gold) : RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.none),
      );
}

/// 사연 손님 접수 카드: 사연 · 요구 시설 · 선택지(C안). 고르는 동안 게임은 멈춤
class StoryCard extends StatelessWidget {
  final HubGame g;
  const StoryCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final cu = g.storyAsk!;
    final k = cu.story;
    final d = Cfg.storyDefs[k];
    final met = g.storyNeedMet(k);
    final need = g.storyNeedText(k);
    final again = g.rt.storyLocked.contains(k);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.gold, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              shape: BoxShape.circle,
              border: Border.all(color: C.gold, width: 2),
            ),
            padding: const EdgeInsets.all(10),
            child: StoryIcon(Sprites.storyItems[d.item]),
          ),
          const SizedBox(height: 8),
          if (again) const Text('다시 찾아온 손님', style: TextStyle(color: C.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(d.bubble, style: Tx.title),
          const SizedBox(height: 2),
          Text(d.who, style: Tx.sub),
          const SizedBox(height: 8),
          Text('"${d.text}"', style: Tx.body, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (met ? C.good : C.accent).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(met ? Icons.check_circle : Icons.info_outline, size: 16, color: met ? C.good : C.accent),
                const SizedBox(width: 6),
                Text(
                  met ? '$need 있음 · 숙련 포장 가능' : '숙련 포장에는 $need 필요',
                  style: TextStyle(color: met ? C.good : C.accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (mode, label, sub, ok) in g.storyChoices(k)) ...[
            SizedBox(
              width: double.infinity,
              child: Material(
                color: !ok ? C.line : (mode == 0 ? C.good : (mode == 3 ? C.card : C.accent)),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ok ? () => g.chooseStory(mode) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// 결과 엽서: 성공(배송 완료 도장)·실패(파손/지연 도장). 파손 엽서는 금·얼룩·찢긴 귀퉁이를 코드로 그림. 실패도 따뜻한 글
class PostcardCard extends StatelessWidget {
  final HubGame g;
  const PostcardCard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = g.postcard!;
    final d = Cfg.storyDefs[r.story];
    final broken = !r.ok && r.stamp == 1;
    final stampKey = const ['done', 'broken', 'late'][r.stamp];
    final paper = r.ok ? const Color(0xFFFFF6E3) : const Color(0xFFF6E7CF);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: broken ? -0.03 : 0.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: CustomPaint(
              foregroundPainter: broken ? _Damage(r.story) : null,
              painter: _PostcardFrame(r.ok),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFD9C7A3), width: 3),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: StoryIcon(Sprites.storyItems[d.item]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.ok ? (r.skilled ? '숙련 포장! 배송 완료' : '배송 완료') : (r.stamp == 2 ? '조금 늦었어요' : '조금 다쳤어요'),
                                  style: const TextStyle(color: Color(0xFF6B4A2B), fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(d.bubble, style: const TextStyle(color: Color(0xFF2A2438), fontSize: 17, fontWeight: FontWeight.w900)),
                              Text('보낸 사람 · ${d.who}', style: const TextStyle(color: Color(0xFF8A7458), fontSize: 11)),
                            ],
                          ),
                        ),
                        _Stamp(stampKey, Cfg.storyStamp[r.stamp], r.stamp),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.ok ? d.thanks : (r.stamp == 2 ? Cfg.storyLateText : d.sorry),
                      style: const TextStyle(color: Color(0xFF3D3020), fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.ok ? '+${g.fmt(r.pay)}원 · 명성 +${r.fame}' : '고마운 마음은 그대로 전해졌어요',
                      style: TextStyle(color: r.ok ? const Color(0xFF2E8B57) : const Color(0xFFB0703A), fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppButton('엽서 보관하기', color: C.good, onTap: g.closePostcard),
      ],
    );
  }
}

/// 도장: 도트 그림 + 글자(코드), 살짝 기울임
class _Stamp extends StatelessWidget {
  final String keyName, text;
  final int kind;
  const _Stamp(this.keyName, this.text, this.kind);

  @override
  Widget build(BuildContext context) {
    final col = const [Color(0xFFD9483B), Color(0xFF9E2B2B), Color(0xFF3B6FD9)][kind];
    return Transform.rotate(
      angle: kind == 0 ? -0.22 : 0.18,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0.85, child: StoryIcon(Sprites.stamps[keyName], size: 60)),
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: col, width: 1.5), borderRadius: BorderRadius.circular(3), color: const Color(0xCCFFF6E3)),
                child: Text(text, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 엽서 테두리: 항공 우편 줄무늬 (성공) / 갈색 점선 (실패)
class _PostcardFrame extends CustomPainter {
  final bool ok;
  _PostcardFrame(this.ok);

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    const w = 6.0;
    if (ok) {
      final cols = [const Color(0xFFD9483B), const Color(0xFFFFF6E3), const Color(0xFF3B6FD9), const Color(0xFFFFF6E3)];
      c.save();
      c.clipPath(Path()
        ..addRect(r)
        ..addRect(r.deflate(w))
        ..fillType = PathFillType.evenOdd);
      for (var i = -s.height; i < s.width + s.height; i += 10) {
        c.drawLine(Offset(i, 0), Offset(i + s.height, s.height), Paint()
          ..color = cols[(i / 10).floor() % 4]
          ..strokeWidth = 5);
      }
      c.restore();
    } else {
      final p = Paint()
        ..color = const Color(0xFFC9A876)
        ..strokeWidth = 2;
      final q = r.deflate(5);
      for (var x = q.left; x < q.right; x += 8) {
        c.drawLine(Offset(x, q.top), Offset(min(x + 4, q.right), q.top), p);
        c.drawLine(Offset(x, q.bottom), Offset(min(x + 4, q.right), q.bottom), p);
      }
      for (var y = q.top; y < q.bottom; y += 8) {
        c.drawLine(Offset(q.left, y), Offset(q.left, min(y + 4, q.bottom)), p);
        c.drawLine(Offset(q.right, y), Offset(q.right, min(y + 4, q.bottom)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PostcardFrame o) => o.ok != ok;
}

/// 파손 엽서: 접힌 금 · 물 얼룩 · 찢긴 귀퉁이 (사연마다 같은 모양)
class _Damage extends CustomPainter {
  final int seed;
  _Damage(this.seed);

  @override
  void paint(Canvas c, Size s) {
    final rnd = Random(seed * 31 + 7);
    // 물 얼룩
    for (var i = 0; i < 2; i++) {
      final ctr = Offset(s.width * (0.25 + rnd.nextDouble() * 0.5), s.height * (0.3 + rnd.nextDouble() * 0.5));
      final rad = 18.0 + rnd.nextDouble() * 16;
      c.drawCircle(ctr, rad, Paint()..color = const Color(0x1A8A5A2B));
      c.drawCircle(ctr, rad, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x338A5A2B));
    }
    // 접힌 금 (지그재그)
    final crack = Paint()
      ..color = const Color(0x667A5A3A)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(s.width * 0.62, 0);
    var x = s.width * 0.62;
    for (var y = 0.0; y < s.height; y += 14) {
      x += (rnd.nextDouble() - 0.5) * 14;
      path.lineTo(x, y + 14);
    }
    c.drawPath(path, crack);
    c.drawPath(path.shift(const Offset(1.5, 0)), Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke);
    // 찢긴 오른쪽 위 귀퉁이 (배경색으로 덮고 들쭉날쭉한 가장자리)
    final tear = Path()
      ..moveTo(s.width - 34, 0)
      ..lineTo(s.width - 26, 6)
      ..lineTo(s.width - 22, 3)
      ..lineTo(s.width - 15, 14)
      ..lineTo(s.width - 9, 13)
      ..lineTo(s.width - 3, 26)
      ..lineTo(s.width, 30)
      ..lineTo(s.width, 0)
      ..close();
    c.drawPath(tear, Paint()..color = C.bg.withValues(alpha: 0.92));
    c.drawPath(tear, Paint()
      ..color = const Color(0x667A5A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_Damage o) => o.seed != seed;
}
