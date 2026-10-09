import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';
import 'theme.dart';

Color roleColor(Staff s) {
  if (s.carrier) return C.blue;
  final p = s.post;
  if (p == null) return C.line;
  return p.type.id == 'counter' ? C.accent : C.good;
}

String roleText(HubGame g, Staff s) {
  final String base;
  final p = s.post;
  if (s.carrier) {
    base = '운반 담당';
  } else if (p == null) {
    return '대기 중';
  } else {
    base = '${p.type.name} #${g.typeIndex(p)}';
  }
  if (s.rest == 1) return '$base · 휴식하러 이동';
  if (s.rest == 2) return '$base · 휴식 중';
  if (s.rest == 3) return '$base · 복귀 중';
  return base;
}

/// 직업 칩: '접수원 Lv3' (전직하면 상위 직업 이름 + 별). fit = 지금 자리에서 직업 효과가 나는지
class JobChip extends StatelessWidget {
  final Staff s;
  final bool? fit;
  const JobChip(this.s, {super.key, this.fit});

  @override
  Widget build(BuildContext context) {
    final col = Color(Cfg.jobColor[s.job]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.22),
        border: Border.all(color: col),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${s.promoted ? '★' : ''}${s.jobTitle} Lv${s.jobLv}${fit == null ? '' : (fit! ? ' ✓' : ' ✗')}',
        style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 이름 첫 글자가 들어간 동그란 아바타 (색 = 맡은 일)
class StaffAvatar extends StatelessWidget {
  final Staff s;
  final double size;
  const StaffAvatar(this.s, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: roleColor(s), shape: BoxShape.circle),
      child: Text(
        s.initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 능력치 막대 (1~5칸)
class StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const StatBar(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 42, child: Text(label, style: Tx.sub)),
        for (var i = 0; i < 5; i++)
          Container(
            width: 10,
            height: 6,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < value ? color : C.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// 능력치 5개 묶음
class StaffStats extends StatelessWidget {
  final Staff s;
  const StaffStats(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        StatBar('손속도', s.speed, C.accent),
        StatBar('걸음', s.walk, C.blue),
        StatBar('친절', s.kind, C.good),
        StatBar('체력', s.stamina, C.gold),
        StatBar('꼼꼼', s.care, const Color(0xFFB06AB3)),
      ],
    );
  }
}

/// 현재 컨디션(체력) 막대
class EnergyBar extends StatelessWidget {
  final Staff s;
  const EnergyBar(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final pct = s.energyPct;
    final col = pct >= 0.6 ? C.good : (pct >= 0.3 ? C.accent : C.bad);
    return Row(
      children: [
        const SizedBox(width: 42, child: Text('컨디션', style: Tx.sub)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: C.line,
              valueColor: AlwaysStoppedAnimation<Color>(col),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s.tired ? '지침' : '${(pct * 100).round()}%',
          style: TextStyle(
              color: col, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// 맡은 일 표시 칩
class RoleChip extends StatelessWidget {
  final HubGame g;
  final Staff s;
  const RoleChip(this.g, this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final col = roleColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: col.withOpacity(0.28),
        border: Border.all(color: col),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        roleText(g, s),
        style: TextStyle(
          color: s.idle ? C.sub : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}