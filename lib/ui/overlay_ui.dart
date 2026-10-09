import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import 'alert_bar.dart';
import 'award_card.dart';
import 'bottom_bar.dart';
import 'build_sheet.dart';
import 'book_sheet.dart';
import 'building_sheet.dart';
import 'ops_sheet.dart';
import 'event_card.dart';
import 'report_card.dart';
import 'staff_sheet.dart';
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
    } else if (g.sheet == 'ops') {
      sheet = OpsSheet(g);
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
            top: mq.padding.top + 98,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xDD2A2640),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0963A)),
              ),
              child: Text(
                g.hint!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (g.mode == 0 && sheet == null && g.alerts.isNotEmpty)
          Positioned(
            top: mq.padding.top + 98,
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
        // 알림은 시트 위에 (시트보다 앞에 끼우면 시트가 다시 만들어져 스크롤이 처음으로 돌아감)
        if (g.toastTime > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: navInset(context) + (g.mode == 0 ? 96 : 160),
            child: Center(child: _Toast(g.toast)),
          ),
        // 선택형 사건 (정산 카드보다 아래, 둘이 겹치면 정산 먼저)
                // 연말 시상식 · 승급 (정산 카드를 닫은 뒤)
        if (g.report == null && g.award != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: Center(child: SingleChildScrollView(child: AwardCard(g)))),
        ] else if (g.report == null && g.gradeUp != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: Center(child: GradeUpCard(g))),
        ],
        if (g.evtNow != null && g.report == null && g.award == null && g.gradeUp == null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(
            child: Center(child: SingleChildScrollView(child: EventCard(g))),
          ),
        ],
        // 하루 정산 카드 (맨 위)
        if (g.report != null) ...[
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned.fill(child: Center(child: ReportCard(g))),
        ],
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
      decoration: BoxDecoration(
        color: const Color(0xEE000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
