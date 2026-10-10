import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import 'theme.dart';

/// 메뉴 창: 자주 안 쓰는 기능을 아이콘 칸으로 모아 둠 (카이로소프트풍 3열 격자)
class MenuSheet extends StatelessWidget {
  final HubGame g;
  const MenuSheet(this.g, {super.key});

  void _open(String sheet) {
    g.selected = null;
    g.sheet = sheet;
    g.ui();
  }

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, String, String?, VoidCallback?)>[
      (
        'stats',
        Icons.insights,
        '경영 현황',
        '접수량 ${g.intakeNow.toStringAsFixed(1)}/분',
        () => _open('stats'),
      ),
      (
        'goal',
        Icons.emoji_events,
        '목표·업적',
        g.claimableCount > 0 ? '보상 ${g.claimableCount}' : null,
        () => _open('goals'),
      ),
      (
        'research',
        Icons.science,
        '연구',
        'RP ${g.fmt(g.rp)}',
        () => _open('research'),
      ),
      ('region', Icons.map, '배송 지역', '명성 ${g.fame}', () => _open('region')),
      (
        'book',
        Icons.menu_book,
        '도감',
        '${(g.bookPct * 100).floor()}%',
        () => _open('book'),
      ),
      (
        'aisle',
        Icons.format_paint,
        '통로 깔기',
        '직원 동선',
        () {
          g.sheet = null;
          g.startAisle();
        },
      ),
      (
        'expand',
        Icons.open_in_full,
        '창고 확장',
        g.canExpand ? '${g.fmt(g.nextAreaCost)}원' : '최대 크기',
        g.canExpand
            ? () {
                g.sheet = null;
                g.selected = null;
                g.mode = 3;
                g.ui();
              }
            : null,
      ),
      ('map', Icons.map, '노선 지도', '차량 ${g.fleet.length}대', () {
        g.closeAll();
        g.goScreen(1);
      }),
      ('truck', Icons.garage, '차고', '차량 관리', () {
        g.closeAll();
        g.goScreen(2);
      }),
    ];
    return SheetFrame(
      title: '메뉴',
      titleColor: C.wood,
      heightFactor: 0.7,
      onClose: g.closeAll,
      child: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (final (icon, fb, label, sub, onTap) in items)
            MenuTile(
              icon: icon,
              fallback: fb,
              label: label,
              sub: sub,
              onTap: onTap,
              badge: icon == 'goal' && g.claimableCount > 0,
            ),
        ],
      ),
    );
  }
}

/// 아이콘 칸 한 개: 크림 판 + 도트 아이콘 + 이름 (+ 빨간 알림 점)
class MenuTile extends StatelessWidget {
  final String icon;
  final IconData fallback;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final bool badge;
  const MenuTile({
    super.key,
    required this.icon,
    required this.fallback,
    required this.label,
    this.sub,
    this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.frame, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFC9A46A), offset: Offset(0, 3)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UiIcon(icon, fallback, size: 44),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Tx.h2.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: Tx.sub.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (badge) const Positioned(top: -4, right: -4, child: RedDot()),
          ],
        ),
      ),
    );
  }
}

/// 빨간 알림 점 (숫자 있으면 숫자)
class RedDot extends StatelessWidget {
  final int? n;
  const RedDot({super.key, this.n});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: C.bad,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: n == null
          ? null
          : Text(
              '$n',
              style: const TextStyle(
                fontFamily: kFont,
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
