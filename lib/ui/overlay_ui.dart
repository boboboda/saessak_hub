import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'alert_bar.dart';
import 'award_card.dart';
import 'bottom_bar.dart';
import 'build_sheet.dart';
import 'book_sheet.dart';
import 'building_sheet.dart';
import 'menu_sheet.dart';
import 'ops_sheet.dart';
import 'event_card.dart';
import 'report_card.dart';
import 'staff_sheet.dart';
import 'story_card.dart';
import 'theme.dart';
import 'top_bar.dart';

/// 게임 위에 겹치는 모든 위젯 (상단 바, 하단 바, 시트, 안내 메시지)
class OverlayUi extends StatelessWidget {
  final HubGame game;
  const OverlayUi(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final mq = MediaQuery.of(context);

    Widget? sheet;
    if (g.sheet == 'build') {
      sheet = BuildSheet(g);
        } else if (g.sheet == 'book') {
      sheet = BookSheet(g);
    } else if (g.sheet == 'menu') {
      sheet = MenuSheet(g);
    } else if (const ['goals', 'research', 'stats', 'region', 'ops'].contains(g.sheet)) {
      sheet = OpsSheet(g, g.sheet!);
    } else if (g.sheet == 'staff') {
      sheet = StaffSheet(g);
    } else if (g.mode == 0 && g.selected != null) {
      sheet = BuildingSheet(g, g.selected!);
    }

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, child: TopBar(g)),
        if (g.mode == 0 && sheet == null && g.alerts.isEmpty && g.hint != null)
          Positioned(
            top: mq.padding.top + Cfg.topUiH,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF2FFF6DE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.accent, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, size: 16, color: C.accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(g.hint!, style: Tx.h2.copyWith(fontSize: 12))),
                ],
              ),
            ),
          ),
        if (g.mode == 0 && sheet == null && g.alerts.isNotEmpty)
          Positioned(
            top: mq.padding.top + Cfg.topUiH,
            left: 8,
            right: 8,
            child: AlertBar(g),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: g.mode == 0 ? BottomBar(g) : ActionBar(g),
        ),
        if (sheet != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: g.closeAll,
              child: Container(color: Colors.black38),
            ),
          ),
        if (sheet != null)
          Positioned(left: 0, right: 0, bottom: 0, child: sheet),
        // 선택형 사건 (정산 카드보다 아래, 둘이 겹치면 정산 먼저)
                // 연말 시상식 · 승급 (정산 카드를 닫은 뒤)
        if (g.report == null && g.award != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: TapGuard(key: const ValueKey('award'), child: Center(child: SingleChildScrollView(child: AwardCard(g))))),
        ] else if (g.report == null && g.gradeUp != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: TapGuard(key: ValueKey('grade${g.gradeUp}'), child: Center(child: GradeUpCard(g)))),
        ],
        if (g.evtNow != null && g.report == null && g.award == null && g.gradeUp == null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(
            child: TapGuard(
              key: ValueKey('evt${g.evtNow!.kind}${g.evtLastAt}'),
              child: Center(child: SingleChildScrollView(child: EventCard(g))),
            ),
          ),
        ],
        // 사연 택배: 접수 선택 카드 → (포장) → 결과 엽서
        if (g.storyAsk != null && g.report == null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(
            child: TapGuard(
              key: ValueKey('story${g.storyAsk.hashCode}'),
              child: Center(child: SingleChildScrollView(child: StoryCard(g))),
            ),
          ),
        ] else if (g.postcardShown && g.report == null && g.evtNow == null) ...[
          Positioned.fill(child: Container(color: Colors.black54)),
          Positioned.fill(
            child: TapGuard(
              key: ValueKey('post${g.postcard.hashCode}'),
              child: Center(child: SingleChildScrollView(child: PostcardCard(g))),
            ),
          ),
        ],
        // 하루 정산 카드 (맨 위)
        if (g.report != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: TapGuard(key: ValueKey('report${g.day}'), child: Center(child: ReportCard(g)))),
        ],
          // 알림은 맨 위에 (카드가 떠 있을 때 막힌 이유도 보이게). 시트 위에 (시트보다 앞에 끼우면 시트가 다시 만들어져 스크롤이 처음으로 돌아감)
        if (g.toastTime > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: navInset(context) + (g.mode == 0 ? 96 : 160),
            child: Center(child: _Toast(g.toast)),
          ),
    ],
    );
  }
}

class _Toast extends StatelessWidget {
  final String text;
  const _Toast(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: toastBox,
      child: Text(text, textAlign: TextAlign.center, style: toastText),
    );
  }
}
