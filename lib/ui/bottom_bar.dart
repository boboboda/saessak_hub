import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

/// 하단 메뉴: 건설 / 직원 / 창고 확장
class BottomBar extends StatelessWidget {
  final HubGame g;
  const BottomBar(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final idle = g.staff.where((s) => s.idle).length;
    final expandSub = g.canExpand ? '${g.nextAreaCost}원' : '최대 크기';

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + navInset(context)),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavBtn(
              icon: Icons.construction,
              label: '건설',
              onTap: () {
                g.selected = null;
                g.sheet = 'build';
                g.ui();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NavBtn(
              icon: Icons.groups,
              label: '직원',
              sub: idle > 0 ? '대기 $idle' : null,
              badge: idle > 0,
              onTap: () {
                g.selected = null;
                g.sheet = 'staff';
                g.ui();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NavBtn(
              icon: Icons.flag,
              label: '운영',
              sub: g.claimableCount > 0 ? '보상 ${g.claimableCount}' : null,
              badge: g.claimableCount > 0,
              onTap: () {
                g.selected = null;
                g.sheet = 'ops';
                g.ui();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NavBtn(
              icon: Icons.open_in_full,
              label: '창고 확장',
              sub: expandSub,
              enabled: g.canExpand,
              onTap: () {
                if (!g.canExpand) return;
                g.selected = null;
                g.mode = 3;
                g.ui();
              },
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
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: infoColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: infoColor.withOpacity(0.6)),
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
      ('화면 이동', Icons.pan_tool),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + nav),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.line)),
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool badge;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.badge = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? C.text : C.sub.withOpacity(0.5);
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: fg),
                  const SizedBox(height: 2),
                  Text(
                    sub == null ? label : '$label · $sub',
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge)
                Positioned(
                  top: -2,
                  right: 14,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: C.bad,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
