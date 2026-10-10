import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'menu_sheet.dart';
import 'theme.dart';

/// 하단 메뉴 (카이로소프트풍 아이콘 단추 줄): 건설 / 직원 / 목표 / 연구 / 메뉴
class BottomBar extends StatelessWidget {
  final HubGame g;
  const BottomBar(this.g, {super.key});

  void _open(String s) {
    g.selected = null;
    g.sheet = s;
    g.ui();
  }

  @override
  Widget build(BuildContext context) {
    final idle = g.staff.where((s) => s.idle).length;
    final reward = g.claimableCount;
    final btns = [
      ('build', Icons.construction, '건설', null, () => _open('build')),
      (
        'staff',
        Icons.groups,
        '직원',
        idle > 0 ? idle : null,
        () => _open('staff'),
      ),
      (
        'goal',
        Icons.emoji_events,
        '목표',
        reward > 0 ? reward : null,
        () => _open('goals'),
      ),
      (
        'research',
        Icons.science,
        '연구',
        g.resNow == null && g.rp > 0 && g.ofType('lab').isNotEmpty ? 0 : null,
        () => _open('research'),
      ),
      ('menu', Icons.apps, '메뉴', null, () => _open('menu')),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + navInset(context)),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.frame, width: 3)),
      ),
      child: Row(
        children: [
          for (final (icon, fb, label, badge, onTap) in btns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _NavBtn(
                  icon: icon,
                  fallback: fb,
                  label: label,
                  badge: badge,
                  onTap: onTap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 배치 모드(2) / 확장 모드(3)일 때 하단에 뜨는 확인 바
class ActionBar extends StatelessWidget {
  final HubGame g;
  const ActionBar(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final nav = navInset(context);
    if (g.mode == 4) return _aisleBar(nav);
    String info;
    Color infoColor;
    String okLabel;
    bool okEnabled;
    VoidCallback onOk;
    VoidCallback onCancel;

    if (g.mode == 2 && g.placing != null) {
      final t = g.placing!;
      final problem = g.ghostProblem;
      okEnabled = problem == null;
      infoColor = okEnabled ? C.good : C.bad;
      final (near, sets) = g.previewSets(t, g.ghostX, g.ghostY);
      info =
          '${t.name} ${t.w}×${t.h}칸 · ${t.cost}원 — '
          '${okEnabled ? '놓을 수 있어요' : problem}'
          '${near.isEmpty ? '' : '\n맞닿음 ${near.length}곳'}'
          '${sets.isEmpty ? '' : ' · 세트 발동: ${sets.join(', ')}'}';
      okLabel = '확정';
      onOk = () => g.confirmPlace();
      onCancel = () => g.cancelPlacing();
    } else {
      final next =
          Cfg.areaName[(g.areaLevel + 1).clamp(0, Cfg.areaName.length - 1)];
      final r = Cfg.areas[(g.areaLevel + 1).clamp(0, Cfg.areas.length - 1)];
      okEnabled = g.canExpand && g.money >= g.nextAreaCost;
      infoColor = okEnabled ? C.blue : C.bad;
      info =
          '$next ${r.width.toInt()}×${r.height.toInt()}칸 · '
          '${g.nextAreaCost}원 (건물은 그대로)'
          '${g.money >= g.nextAreaCost ? '' : ' — 돈이 모자라요'}';
      okLabel = '확장 확정';
      onOk = () => g.confirmExpand();
      onCancel = () {
        g.mode = 0;
        g.ui();
      };
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + nav),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.frame, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: infoColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: infoColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              info,
              style: TextStyle(
                color: infoColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  '취소',
                  color: C.card,
                  expand: true,
                  onTap: () => onCancel(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AppButton(
                  okLabel,
                  color: C.good,
                  expand: true,
                  onTap: okEnabled ? () => onOk() : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on ActionBar {
  /// 통로 모드 하단 바: 도구(깔기·철거·화면 이동) + 동선 효율 + 완료
  Widget _aisleBar(double nav) {
    final pct = g.walkAll < 1
        ? null
        : (g.walkOnAisle / g.walkAll * 100).round();
    final tools = [
      ('깔기', Icons.edit),
      ('철거', Icons.delete_outline),
      ('이동', Icons.pan_tool),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + nav),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.frame, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: C.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              '드래그해서 깔아요 · 칸당 ${Cfg.aisleCost}원 (철거 시 절반 환불) · ${g.money}원\n'
              '주황 칸 = 직원이 자주 다닌 길 · 최근 걸음 중 통로 위 ${pct == null ? '-' : '$pct%'}',
              style: const TextStyle(
                color: C.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                Expanded(
                  child: AppButton(
                    tools[i].$1,
                    small: true,
                    icon: tools[i].$2,
                    color: g.aisleTool == i ? C.accent : C.card,
                    expand: true,
                    onTap: () {
                      g.aisleTool = i;
                      g.ui();
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: AppButton(
                  '완료',
                  small: true,
                  color: C.good,
                  expand: true,
                  onTap: () => g.endAisle(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 아래 메뉴 단추: 크림 판 + 굵은 외곽선 + 도트 아이콘 + 이름. badge: null 없음 · 0 점 · 숫자
class _NavBtn extends StatelessWidget {
  final String icon;
  final IconData fallback;
  final String label;
  final int? badge;
  final VoidCallback onTap;
  const _NavBtn({
    required this.icon,
    required this.fallback,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 62,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.frame, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xFFC9A46A), offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UiIcon(icon, fallback, size: 34),
                Text(label, style: Tx.h2.copyWith(fontSize: 12), maxLines: 1),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -6,
              right: -4,
              child: RedDot(n: badge == 0 ? null : badge),
            ),
        ],
      ),
    );
  }
}
