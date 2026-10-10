import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 연구 창 내용: 위 RP 판 + 진행 중 연구, 가운데 3갈래 연구 나무(단계마다 칸, 화살표로 이어짐), 아래 고른 연구 설명·시작 단추
class ResearchPanel extends StatefulWidget {
  final HubGame g;
  const ResearchPanel(this.g, {super.key});

  @override
  State<ResearchPanel> createState() => _ResearchPanelState();
}

class _ResearchPanelState extends State<ResearchPanel> {
  int? _pick; // 고른 연구 (없으면 진행 중 → 시작할 수 있는 첫 연구)

  HubGame get g => widget.g;

  static const _branchColor = [C.accent, C.blue, C.good];
  static const _icons = [
    Icons.qr_code_scanner, // 바코드 접수
    Icons.auto_fix_high, // 자동 테이프
    Icons.precision_manufacturing, // 포장 라인 2세대
    Icons.conveyor_belt, // 컨베이어 해금
    Icons.sort, // 분류 자동화
    Icons.nightlight_round, // 야간 출고
    Icons.confirmation_number, // 번호표
    Icons.card_membership, // 단골 카드
    Icons.workspace_premium, // 프리미엄 배송
  ];

  int _defaultPick() {
    if (g.resNow != null) return g.resNow!;
    for (var i = 0; i < Cfg.research.length; i++) {
      if (g.resProblem(i) == null) return i;
    }
    for (var i = 0; i < Cfg.research.length; i++) {
      if (!g.resDone(i) && g.resOpen(i)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final pick = _pick ?? _defaultPick();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _status(),
        const SizedBox(height: 10),
        _tree(pick),
        const SizedBox(height: 10),
        _detail(pick),
      ],
    );
  }

  /// RP 판: 지금 RP · 얻는 법 · 진행 중 연구 막대
  Widget _status() {
    final now = g.resNow;
    final labs = g.ofType('lab').length;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UiIcon('research', Icons.science, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('연구 포인트 ${g.fmt(g.rp)} RP', style: Tx.h2.copyWith(fontSize: 16, color: C.blue)),
                    Text(
                      '배송 1건 = ${Cfg.rpPerParcel} RP · 연구실 ${labs}곳 × 하루 ${Cfg.labRpDay} RP',
                      style: Tx.sub,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (now != null) ...[
            Row(
              children: [
                Icon(_icons[now], size: 16, color: C.gold),
                const SizedBox(width: 4),
                Expanded(child: Text('연구 중: ${Cfg.research[now].name}', style: Tx.h2.copyWith(fontSize: 13))),
                Text('${g.resLeft.ceil()}초 남음', style: Tx.sub),
              ],
            ),
            const SizedBox(height: 4),
            _bar((1 - g.resLeft / Cfg.research[now].time).clamp(0.0, 1.0).toDouble(), C.coin),
          ] else
            Text(labs == 0 ? '연구실을 지으면 매일 RP가 더 쌓여요 · 칸을 눌러 고르세요' : '칸을 눌러 고르고 시작하세요 (한 번에 하나)', style: Tx.sub),
        ],
      ),
    );
  }

  /// 진행 막대 (갈색 테두리 + 채움)
  Widget _bar(double v, Color c) => Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE9D3A6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C.frame, width: 1.5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5))),
        ),
      );

  /// 3갈래 연구 나무: 갈래마다 한 줄 (제목 판 + 1·2·3단계 칸, 칸 사이 화살표)
  Widget _tree(int pick) {
    return Column(
      children: [
        for (var b = 0; b < Cfg.resBranch.length; b++) ...[
          if (b > 0) const SizedBox(height: 8),
          Row(
            children: [
              // 갈래 이름 (세로 판)
              Container(
                width: 34,
                height: 76,
                decoration: BoxDecoration(
                  color: _branchColor[b],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.frame, width: 2),
                  boxShadow: [BoxShadow(color: shade(_branchColor[b], 0.4), offset: const Offset(0, 3))],
                ),
                alignment: Alignment.center,
                child: Text(
                  Cfg.resBranch[b].split('').join('\n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.15),
                ),
              ),
              const SizedBox(width: 6),
              for (final (k, i) in [
                for (var i = 0; i < Cfg.research.length; i++)
                  if (Cfg.research[i].branch == b) i,
              ].indexed) ...[
                if (k > 0)
                  Icon(Icons.play_arrow, size: 14, color: g.resDone(i) || g.resOpen(i) ? C.frame : C.line),
                Expanded(child: _node(i, pick == i, _branchColor[b])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// 연구 칸 하나: 완료(초록 체크) · 할 수 있음(밝게) · 진행 중(금색 테두리 + 막대) · 잠김(흐리게 + 자물쇠)
  Widget _node(int i, bool picked, Color col) {
    final d = Cfg.research[i];
    final done = g.resDone(i);
    final running = g.resNow == i;
    final open = g.resOpen(i);
    final ready = g.resProblem(i) == null;
    final bg = done
        ? const Color(0xFFDDF0D6)
        : running
            ? const Color(0xFFFFF0B8)
            : open
                ? const Color(0xFFFFFBEE)
                : const Color(0xFFE6D6B6);
    return GestureDetector(
      onTap: () => setState(() => _pick = i),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 76,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: picked ? C.accent : C.frame, width: picked ? 3 : 2),
              boxShadow: [BoxShadow(color: picked ? shade(C.accent, 0.3) : const Color(0xFFC9A46A), offset: const Offset(0, 3))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(open || done ? _icons[i] : Icons.lock, size: 24, color: done ? C.good : (open ? col : C.sub)),
                const SizedBox(height: 3),
                Text(
                  d.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Tx.h2.copyWith(fontSize: 11, height: 1.1, color: open || done ? C.text : C.sub),
                ),
                if (running) ...[
                  const SizedBox(height: 3),
                  _bar((1 - g.resLeft / d.time).clamp(0.0, 1.0).toDouble(), C.coin),
                ],
              ],
            ),
          ),
          if (done)
            const Positioned(top: -5, right: -5, child: _Badge(Icons.check, C.good))
          else if (ready)
            const Positioned(top: -5, right: -5, child: _Badge(Icons.priority_high, C.bad)), // 지금 시작할 수 있음
        ],
      ),
    );
  }

  /// 고른 연구 설명 + 비용 + 시작 단추
  Widget _detail(int i) {
    final d = Cfg.research[i];
    final why = g.resProblem(i);
    final done = g.resDone(i);
    final running = g.resNow == i;
    Widget cost(IconData ic, String t, bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEE),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: ok ? C.line : C.bad, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 13, color: ok ? C.sub : C.bad),
            const SizedBox(width: 3),
            Text(t, style: Tx.body.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ok ? C.text : C.bad)),
          ]),
        );
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icons[i], size: 22, color: _branchColor[d.branch]),
              const SizedBox(width: 6),
              Expanded(child: Text('${Cfg.resBranch[d.branch]} ${d.tier + 1}단계 · ${d.name}', style: Tx.h2)),
            ],
          ),
          const SizedBox(height: 4),
          Text('효과: ${d.effect}', style: Tx.body.copyWith(fontWeight: FontWeight.w700, color: C.good)),
          const SizedBox(height: 8),
          if (!done)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                cost(Icons.science, '${g.fmt(d.rp)} RP', g.rp >= d.rp || running),
                cost(Icons.paid, '${g.fmt(d.cost)}원', g.money >= d.cost || running),
                cost(Icons.schedule, '${d.time.round()}초', true),
              ],
            ),
          if (!done) const SizedBox(height: 10),
          AppButton(
            done ? '연구 완료' : (running ? '연구 중 · ${g.resLeft.ceil()}초' : (why ?? '연구 시작')),
            color: done ? C.good : C.blue,
            expand: true,
            icon: done ? Icons.check : (running ? Icons.hourglass_top : Icons.science),
            onTap: why == null
                ? () {
                    g.startResearch(i);
                    setState(() => _pick = i);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// 칸 모서리 작은 동그라미 표시 (완료 체크 · 시작 가능 느낌표)
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Badge(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}
