import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
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

  static const _branchColor = [C.accent, C.blue, C.good, Color(0xFF8E5BD0)];
  int? _branch; // 보고 있는 갈래 (없으면 고른 연구의 갈래)
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
    Icons.content_cut, // 테이프 디스펜서
    Icons.print, // 라벨 프린터
    Icons.bubble_chart, // 에어캡 롤러
    Icons.forklift, // 지게차
    Icons.precision_manufacturing, // 포장 로봇팔
    Icons.shopping_cart, // 손수레
    Icons.self_improvement, // 스트레칭 체조
    Icons.stairs, // 높은 선반 사다리
    Icons.view_week, // 롤러 컨베이어
    Icons.confirmation_number_outlined, // 번호표 발권기
    Icons.credit_card, // 카드 단말기
    Icons.flight, // 드론 배송
    Icons.sell, // 스마트 태그
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
    // 위(RP 판·연구 나무)는 스크롤, 아래 고른 연구 설명은 늘 보이게 고정
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            children: [
              _status(),
              const SizedBox(height: 10),
              _tree(pick),
            ],
          ),
        ),
        const SizedBox(height: 6),
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
          ..._teaser(),
        ],
      ),
    );
  }

  /// 다음 회사 등급에서 열리는 연구 미리보기 (장비는 그림으로) — 다음 목표를 보여 줘서 기대감
  List<Widget> _teaser() {
    final next = g.companyGrade + 1;
    if (next >= Cfg.corpName.length) return const [];
    final ids = [
      for (var i = 0; i < Cfg.research.length; i++)
        if (Cfg.research[i].grade == next) i,
    ];
    if (ids.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.line, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock, size: 16, color: C.accent),
            const SizedBox(width: 4),
            Text('${Cfg.corpName[next]}가 되면', style: Tx.sub.copyWith(fontSize: 10, color: C.text)),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  for (final i in ids)
                    Cfg.research[i].equip != null && Sprites.equips[Cfg.research[i].equip] != null
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: RawImage(image: Sprites.equips[Cfg.research[i].equip], fit: BoxFit.contain, filterQuality: FilterQuality.none),
                          )
                        : Tooltip(message: Cfg.research[i].name, child: Icon(_icons[i], size: 20, color: C.sub)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
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

  /// 연구 나무: 위에 갈래 탭(할 수 있는 연구 수 표시), 아래에 그 갈래 단계들을 사다리처럼 (칸 사이 화살표)
  Widget _tree(int pick) {
    final br = _branch ?? Cfg.research[pick].branch;
    final nodes = [
      for (var i = 0; i < Cfg.research.length; i++)
        if (Cfg.research[i].branch == br) i,
    ]..sort((a, b) => Cfg.research[a].tier.compareTo(Cfg.research[b].tier));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var b = 0; b < Cfg.resBranch.length; b++) ...[
              if (b > 0) const SizedBox(width: 5),
              Expanded(child: _tab(b, b == br)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (final (k, i) in nodes.indexed) ...[
          if (k > 0)
            Icon(Icons.keyboard_double_arrow_down, size: 16, color: g.resDone(nodes[k - 1]) ? C.frame : C.line),
          _node(i, pick == i, _branchColor[br]),
        ],
      ],
    );
  }

  /// 갈래 탭: 이름 + 완료/전체 + 지금 시작할 수 있는 연구가 있으면 빨간 점
  Widget _tab(int b, bool on) {
    final ids = [
      for (var i = 0; i < Cfg.research.length; i++)
        if (Cfg.research[i].branch == b) i,
    ];
    final done = ids.where(g.resDone).length;
    final ready = ids.any((i) => g.resProblem(i) == null);
    final col = _branchColor[b];
    return GestureDetector(
      onTap: () => setState(() {
        _branch = b;
        _pick = ids.firstWhere((i) => !g.resDone(i), orElse: () => ids.last);
      }),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: on ? col : const Color(0xFFFFFBEE),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: C.frame, width: 2),
              boxShadow: [BoxShadow(color: on ? shade(col, 0.4) : const Color(0xFFC9A46A), offset: const Offset(0, 3))],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Cfg.resBranch[b], style: Tx.h2.copyWith(fontSize: 13, color: on ? Colors.white : C.text)),
                Text('$done/${ids.length}', style: Tx.sub.copyWith(fontSize: 10, color: on ? Colors.white : C.sub)),
              ],
            ),
          ),
          if (ready) const Positioned(top: -5, right: -4, child: _Badge(Icons.priority_high, C.bad)),
        ],
      ),
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
    final lockGrade = !done && g.companyGrade < d.grade;
    return GestureDetector(
      onTap: () => setState(() => _pick = i),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: picked ? C.accent : C.frame, width: picked ? 3 : 2),
              boxShadow: [BoxShadow(color: picked ? shade(C.accent, 0.3) : const Color(0xFFC9A46A), offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: open || done ? col.withValues(alpha: 0.15) : const Color(0x22000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  // 장비 연구는 잠겨 있어도 장비 그림을 흐리게 미리 보여 줌 (기대감)
                  child: d.equip != null && Sprites.equips[d.equip] != null
                      ? Opacity(
                          opacity: open || done ? 1 : 0.45,
                          child: RawImage(image: Sprites.equips[d.equip], fit: BoxFit.contain, filterQuality: FilterQuality.none),
                        )
                      : Icon(open || done ? _icons[i] : Icons.lock, size: 22, color: done ? C.good : (open ? col : C.sub)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.tier + 1}단계 · ${d.name}${d.equip != null ? '  [장비]' : ''}',
                          style: Tx.h2.copyWith(fontSize: 12, color: open || done ? C.text : C.sub)),
                      Text(
                        lockGrade ? '${Cfg.corpName[d.grade]} 등급부터' : d.effect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tx.sub.copyWith(fontSize: 10, color: lockGrade ? C.bad : C.sub),
                      ),
                      if (running) ...[
                        const SizedBox(height: 3),
                        _bar((1 - g.resLeft / d.time).clamp(0.0, 1.0).toDouble(), C.coin),
                      ],
                    ],
                  ),
                ),
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
              if (d.equip != null && Sprites.equips[d.equip] != null)
                SizedBox(width: 30, height: 30, child: RawImage(image: Sprites.equips[d.equip], fit: BoxFit.contain, filterQuality: FilterQuality.none))
              else
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
