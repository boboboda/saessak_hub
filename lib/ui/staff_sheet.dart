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
      color: on ? C.accent : const Color(0xFFFFFBEE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: C.frame, width: 2),
      ),
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

  /// 직업 레벨 막대 · 배운 스킬 · 직업 바꾸기 · 전직
  Widget _jobBox(BuildContext context) {
    final sk = Cfg.jobSkills[s.job];
    final learned = [
      sk[0],
      if (s.jobLv >= 2) sk[1],
      if (s.jobLv >= 4) sk[2],
      if (s.promoted) sk[3],
    ];
    final pct = s.jobLv >= Cfg.jobMaxLv ? 1.0 : (s.jobXp / s.jobXpNeed).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color(Cfg.jobColor[s.job]).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${s.jobTitle} · ${Cfg.jobWhere[s.job]}', style: Tx.body),
              const Spacer(),
              Text(s.jobLv >= Cfg.jobMaxLv ? '직업 최고 레벨' : '직업 경험 ${(pct * 100).floor()}%', style: Tx.sub),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 4,
              backgroundColor: C.line,
              valueColor: AlwaysStoppedAnimation<Color>(Color(Cfg.jobColor[s.job])),
            ),
          ),
          const SizedBox(height: 4),
          for (final t in learned) Text('· $t', style: const TextStyle(color: C.text, fontSize: 12)),
          if (!g.jobFits(s) && !s.idle)
            const Text('지금 자리는 직업과 맞지 않아 직업 효과·경험치가 없어요', style: TextStyle(color: C.accent, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
                            AppButton('직업 바꾸기', small: true, color: C.card, onTap: () => _pickJob(context)),
              const SizedBox(width: 8),
              AppButton(s.training != null ? '훈련 중' : '훈련',
                  small: true, color: C.card, onTap: s.training != null ? null : () => _pickTrain(context)),
              const SizedBox(width: 8),
                            if (s.canPromote)
                AppButton(
                    g.companyGrade < Cfg.promoGrade ? '전직: ${Cfg.corpName[Cfg.promoGrade]} 필요' : '전직 (전직서 ${g.tickets}장)',
                    small: true,
                    color: C.gold,
                    onTap: g.tickets > 0 && g.companyGrade >= Cfg.promoGrade ? () => g.promote(s) : null),
            ],
          ),
        ],
      ),
    );
  }

    void _pickTrain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('${s.name} 훈련', style: Tx.title),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('교육실에서 하루 동안 일을 쉬고 능력치 하나 +1 (최대 5)', style: Tx.sub),
              const SizedBox(height: 8),
              for (var k = 0; k < Cfg.statName.length; k++)
                ListTile(
                  dense: true,
                  enabled: g.trainProblem(s, k) == null,
                  title: Text(g.statOf(s, k) >= 5 ? '${Cfg.statName[k]} 5 (최대)' : '${Cfg.statName[k]} ${g.statOf(s, k)} → ${g.statOf(s, k) + 1}', style: Tx.body),
                  subtitle: Text(g.trainProblem(s, k) ?? '${g.fmt(g.trainCost(s, k))}원', style: Tx.sub),
                  onTap: () {
                    Navigator.pop(ctx);
                    g.startTraining(s, k);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickJob(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('${s.name} 직업 바꾸기', style: Tx.title),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('새 직업은 Lv1부터 시작해요 (예전 직업 레벨은 기록에 남아요)', style: Tx.sub),
              const SizedBox(height: 8),
              for (var j = 0; j < Cfg.jobName.length; j++)
                                if (j < Cfg.baseJobs || g.rt.seenJobs.contains(j))
                ListTile(
                  dense: true,
                  enabled: j != s.job && (j < Cfg.baseJobs || g.hiddenJobOk(s, j)),
                  leading: CircleAvatar(radius: 8, backgroundColor: Color(Cfg.jobColor[j])),
                  title: Text('${j >= Cfg.baseJobs ? '✦' : ''}${Cfg.jobName[j]}${s.jobHist[j] != null ? ' (예전 Lv${s.jobHist[j]})' : ''}', style: Tx.body),
                  subtitle: Text(
                      j >= Cfg.baseJobs && !g.hiddenJobOk(s, j)
                          ? '숨은 직업 · 이 직원은 아직 자격이 없어요'
                          : '${Cfg.jobWhere[j]} · ${Cfg.jobSkills[j][0]}',
                      style: Tx.sub),
                  onTap: () {
                    Navigator.pop(ctx);
                    g.changeJob(s, j);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }


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
                                                Text('${s.name} Lv.${s.level}', style: Tx.h2),
                        JobChip(s, fit: s.idle || s.training != null ? null : g.jobFits(s)),
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
                    const SizedBox(height: 8),
          _jobBox(context),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '일급 ${_n(s.wage)}원 · 실수 ${s.mistakes}회 · ${s.level >= Staff.maxLevel ? '최고 레벨' : '경험 ${(s.xp / s.xpNeed * 100).floor()}%'}',
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
                    Row(
                      children: [
                        Text(s.name, style: Tx.h2),
                        const SizedBox(width: 8),
                        JobChip(s),
                      ],
                    ),
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