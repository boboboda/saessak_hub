import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';
import 'dialogs.dart';
import 'staff_widgets.dart';
import 'theme.dart';

String _n(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return v < 0 ? '-$b' : b.toString();
}

/// 직원 시트: [내 직원] [고용] 탭
class StaffSheet extends StatelessWidget {
  final HubGame g;
  const StaffSheet(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: '직원',
      heightFactor: 0.82,
      onClose: g.closeAll,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Pill(Icons.paid, '${_n(g.money)}원', color: C.gold),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: _Tab('내 직원 ${g.staff.length}', g.staffTab == 0, () {
                    g.staffTab = 0;
                    g.ui();
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tab('고용 ${g.candidates.length}', g.staffTab == 1, () {
                    g.staffTab = 1;
                    g.ui();
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: g.staffTab == 0 ? _MyStaff(g) : _Hire(g),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Tab(this.label, this.on, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? C.accent : C.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: on ? Colors.white : C.sub,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 내 직원
class _MyStaff extends StatelessWidget {
  final HubGame g;
  const _MyStaff(this.g);

  @override
  Widget build(BuildContext context) {
    final left = (Cfg.dayLength - g.dayTimer).clamp(0, Cfg.dayLength).ceil();

    if (g.staff.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '아직 직원이 없어요.\n[고용] 탭에서 직원을 뽑아 보세요.',
            textAlign: TextAlign.center,
            style: Tx.sub,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      children: [
        CardBox(
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: C.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '일급 합계 ${_n(g.dailyWages)}원 · 정산까지 $left초',
                  style: Tx.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final s in g.staff) ...[
          _StaffCard(g, s),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final HubGame g;
  final Staff s;
  const _StaffCard(this.g, this.s);

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StaffAvatar(s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(s.name, style: Tx.h2),
                        RoleChip(g, s),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StaffStats(s),
                    const SizedBox(height: 6),
                    EnergyBar(s),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '일급 ${_n(s.wage)}원 · 실수 ${s.mistakes}회',
                  style: const TextStyle(
                      color: C.gold, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              AppButton('배치 변경',
                  small: true,
                  color: C.blue,
                  onTap: () => showAssignPostDialog(context, g, s)),
              const SizedBox(width: 8),
              AppButton('해고',
                  small: true,
                  color: C.bad,
                  onTap: () => showFireDialog(context, g, s)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 고용
class _Hire extends StatelessWidget {
  final HubGame g;
  const _Hire(this.g);

  @override
  Widget build(BuildContext context) {
    final left = (Cfg.candidateRefreshSec - g.candTimer)
        .clamp(0, Cfg.candidateRefreshSec)
        .ceil();
    final canRefresh = g.money >= Cfg.refreshCost;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      children: [
        CardBox(
          child: Row(
            children: [
              const Icon(Icons.timer, size: 18, color: C.sub),
              const SizedBox(width: 8),
              Expanded(
                child: Text('새 후보까지 $left초', style: Tx.body),
              ),
              AppButton(
                '새 후보 ${Cfg.refreshCost}원',
                small: true,
                color: C.blue,
                onTap: canRefresh ? () => g.refreshCandidates() : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (g.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('후보가 없어요. 새 후보를 불러오세요.',
                textAlign: TextAlign.center, style: Tx.sub),
          ),
        for (final s in g.candidates) ...[
          _CandCard(g, s),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CandCard extends StatelessWidget {
  final HubGame g;
  final Staff s;
  const _CandCard(this.g, this.s);

  @override
  Widget build(BuildContext context) {
    final can = g.money >= s.hireCost;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StaffAvatar(s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: Tx.h2),
                    const SizedBox(height: 6),
                    StaffStats(s),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '고용비 ${_n(s.hireCost)}원 · 일급 ${_n(s.wage)}원',
                  style: TextStyle(
                    color: can ? C.gold : C.bad,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppButton('고용',
                  small: true,
                  color: C.good,
                  onTap: can ? () => g.hireCandidate(s) : null),
            ],
          ),
        ],
      ),
    );
  }
}