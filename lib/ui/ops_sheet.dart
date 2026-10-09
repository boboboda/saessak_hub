import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/region_map.dart';
import 'theme.dart';

/// 운영 시트: 접수량·달력 / 수익 부스트 / 배송 지역 / 목표
class OpsSheet extends StatelessWidget {
  final HubGame g;
  const OpsSheet(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: '운영',
      heightFactor: 0.74,
      onClose: g.closeAll,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Pill(Icons.paid, g.fmt(g.money), color: C.gold),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          _intake(),
          const SizedBox(height: 10),
          _goals(),
          const SizedBox(height: 10),
          _fever(),
          const SizedBox(height: 16),
          CardBox(
            child: Row(
              children: [
                const Icon(Icons.map, color: C.blue, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('노선 지도', style: Tx.h2),
                      Text('명성 ${g.fame} · 차량 ${g.fleet.length}대', style: Tx.sub),
                    ],
                  ),
                ),
                AppButton('열기', small: true, color: C.blue, onTap: () {
                  g.closeAll();
                  g.showMap = true;
                  g.ui();
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('배송 지역', style: Tx.h2),
          const SizedBox(height: 4),
          const Text('명성이 쌓이면 새 지역이 열려요. 뒤에 여는 지역일수록 지도가 넓고 집이 많아요', style: Tx.sub),
          const SizedBox(height: 8),
          for (var i = 0; i < Cfg.regionName.length; i++) ...[
            _region(i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
                                        _research(),
          const SizedBox(height: 16),
          _setBook(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('업적', style: Tx.h2),
              const Spacer(),
              Pill(Icons.trending_up, '수익 +${g.perkPct}%', color: C.good),
              const SizedBox(width: 6),
              Pill(Icons.description, '전직서 ${g.tickets}', color: C.blue),
            ],
          ),
          const SizedBox(height: 4),
          Text('업적마다 돈, 일부는 전직서·영구 수익 보너스(최대 +${Cfg.perkCap}%)', style: Tx.sub),
          const SizedBox(height: 8),
          for (var i = 0; i < Cfg.missions.length; i++) ...[
            _mission(i),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// 접수량: 명성 구간 × 성수기. 다음 구간과 다음 성수기 안내
  Widget _intake() {
    final tier = Cfg.intakeTier(g.fame);
    final next = tier + 1 < Cfg.intakeFame.length ? tier + 1 : -1;
    final h = g.holiday;
    final (nh, nd) = g.nextHoliday;
    final total = g.onTimeCount + g.lateCount;
    final rate = total == 0 ? 100 : (g.onTimeCount * 100 / total).round();
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.inbox, color: C.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('접수량 분당 ${g.intakeNow.toStringAsFixed(1)}건', style: Tx.h2)),
            Text('${g.year}년차 ${g.dayOfYear}/${Cfg.yearDays}일', style: Tx.sub),
          ]),
          const SizedBox(height: 4),
          Text(
              next < 0
                  ? '명성 구간 최고 단계'
                  : '명성 ${g.fame}/${Cfg.intakeFame[next]} → 분당 ${Cfg.intakePerMin[next]}건',
              style: Tx.sub),
          Text(
              h != null
                  ? '오늘은 ${h.$1}! 접수 ×${h.$4}'
                  : '다음 성수기: ${nh.$1} ($nd일 후, 접수 ×${nh.$4})',
              style: TextStyle(color: h != null ? C.gold : C.sub, fontSize: 12)),
          Text('정시 배송 $rate% · 연속 ${g.streak}건 (최고 ${g.bestStreak})', style: Tx.sub),
        ],
      ),
    );
  }

  Widget _fever() {
    final on = g.fever > 0;
    final cd = g.adCd.ceil();
    return CardBox(
      child: Row(
        children: [
          Icon(Icons.local_fire_department,
              size: 28, color: on ? C.bad : C.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? '수익 부스트 ${g.fever.ceil()}초 남음' : '수익 부스트', style: Tx.h2),
                Text('${Cfg.feverLen.round()}초 동안 배송 수익 ×${Cfg.feverPay} (손님 수는 그대로)',
                    style: Tx.sub),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            on ? '진행 중' : (cd > 0 ? '$cd초' : '광고 보고 시작'),
            small: true,
            color: C.bad,
            onTap: (on || cd > 0) ? null : () => g.adFever(),
          ),
        ],
      ),
    );
  }

  Widget _region(int i) {
    final open = g.regionOpen[i];
    final color = Color(Cfg.regionColor[i]);
    final can = g.canUnlockRegion(i);
    return CardBox(
      child: Row(
        children: [
          Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Cfg.regionName[i], style: Tx.h2),
                Text(
                    '지도 ${Cfg.regionSize[i].$1}×${Cfg.regionSize[i].$2} · 동네 ${Cfg.regionTowns[i]}곳 · 집 ${RegionMap.of(i).houses.length}채',
                    style: Tx.sub),
              ],
            ),
          ),
          if (open)
            const Pill(Icons.check, '운영 중', color: C.good)
          else
            AppButton('명성 ${Cfg.regionFame[i]}',
                small: true,
                color: C.good,
                onTap: can ? () => g.unlockRegion(i) : null),
        ],
      ),
    );
  }

    /// 오늘 만족도 + 올해 목표 3개
  Widget _goals() {
    final gs = g.goals;
    final st = g.todayStars;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${g.year}년차 목표', style: Tx.h2),
              const Spacer(),
              Text(
                st == null
                    ? '오늘 만족도 -'
                    : '오늘 ★${st.toStringAsFixed(1)} · 예상 ${Cfg.gradeName[g.gradeOf(st, g.rt.served + g.rt.lost == 0 ? 0 : g.rt.lost / (g.rt.served + g.rt.lost))]}',
                style: const TextStyle(color: C.gold, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('셋 다 달성하면 명성 +${Cfg.yearAllFame} · 전직서 +${Cfg.yearAllTicket} (해가 바뀌면 새 목표)', style: Tx.sub),
          for (var i = 0; i < gs.length; i++) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  g.rt.yearDone.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: g.rt.yearDone.contains(i) ? C.good : C.sub,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(gs[i].text, style: Tx.body)),
                Text('${g.goalProgress(gs[i]).clamp(0, gs[i].target)}/${gs[i].target}', style: Tx.sub),
                const SizedBox(width: 8),
                Text('+${g.fmt(gs[i].reward)}원', style: const TextStyle(color: C.gold, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

      /// 연구 트리: 3갈래 × 3단계. RP + 돈 + 시간, 한 번에 하나
  Widget _research() {
    final now = g.resNow;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('연구', style: Tx.h2),
              const Spacer(),
              Pill(Icons.science, 'RP ${g.fmt(g.rp)}', color: C.blue),
            ],
          ),
          const SizedBox(height: 2),
          Text('택배 1건 배송 = RP ${Cfg.rpPerParcel}, 연구실 1곳당 하루 +${Cfg.labRpDay} RP', style: Tx.sub),
          if (now != null) ...[
            const SizedBox(height: 8),
            Text('연구 중: ${Cfg.research[now].name} · ${g.resLeft.ceil()}초 남음', style: const TextStyle(color: C.gold, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (1 - g.resLeft / Cfg.research[now].time).clamp(0.0, 1.0).toDouble(),
                minHeight: 5,
                backgroundColor: C.line,
                valueColor: const AlwaysStoppedAnimation<Color>(C.gold),
              ),
            ),
          ],
          for (var b = 0; b < Cfg.resBranch.length; b++) ...[
            const SizedBox(height: 10),
            Text(Cfg.resBranch[b], style: Tx.body),
            for (var i = 0; i < Cfg.research.length; i++)
              if (Cfg.research[i].branch == b) _resRow(i),
          ],
        ],
      ),
    );
  }

  Widget _resRow(int i) {
    final d = Cfg.research[i];
    final done = g.resDone(i);
    final why = g.resProblem(i);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : (g.resOpen(i) ? Icons.science_outlined : Icons.lock_outline),
              size: 18, color: done ? C.good : C.sub),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: Tx.body),
                Text('${d.effect} · RP ${d.rp} · ${g.fmt(d.cost)}원 · ${d.time.round()}초', style: Tx.sub),
              ],
            ),
          ),
          if (!done)
            AppButton(why == null ? '연구' : (g.resNow == i ? '진행 중' : why),
                small: true, color: C.blue, onTap: why == null ? () => g.startResearch(i) : null),
        ],
      ),
    );
  }

  /// 세트 도감: 공개 세트는 조건까지, 숨은 세트는 발견 전엔 ??? + 힌트
  Widget _setBook() {
    final found = g.rt.foundSets;
    String need(Map<String, int> m) => m.entries
        .map((e) => '${Cfg.types.firstWhere((t) => t.id == e.key).name}${e.value > 1 ? '×${e.value}' : ''}')
        .join(' + ');
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('세트 도감', style: Tx.h2),
              const Spacer(),
              Text('${found.length}/${Cfg.sets.length} 발견', style: const TextStyle(color: C.good, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('건물 테두리를 맞대어 놓으면 발동 (맞닿은 묶음 안에 재료가 다 있으면)', style: Tx.sub),
          for (var i = 0; i < Cfg.sets.length; i++) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(found.contains(i) ? Icons.check_circle : (Cfg.sets[i].hidden ? Icons.help_outline : Icons.radio_button_unchecked),
                    size: 18, color: found.contains(i) ? C.good : C.sub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Cfg.sets[i].hidden && !found.contains(i)
                        ? '??? · 힌트: ${Cfg.sets[i].hint}'
                        : '${Cfg.sets[i].name} · ${need(Cfg.sets[i].need)} → ${Cfg.sets[i].effect}',
                    style: Tx.body,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mission(int i) {
    final m = Cfg.missions[i];
    final got = g.claimed.contains(i);
    final prog = g.missionProgress(m);
    final done = prog >= m.target;
    return CardBox(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.text,
                    style: Tx.body.copyWith(
                        color: got ? C.sub : C.text,
                        decoration: got ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (prog / m.target).clamp(0.0, 1.0).toDouble(),
                    minHeight: 4,
                    backgroundColor: C.line,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        done ? C.good : C.accent),
                  ),
                ),
                const SizedBox(height: 2),
                Text('${prog.clamp(0, m.target)}/${m.target}', style: Tx.sub),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (got)
            const Pill(Icons.check, '완료', color: C.good)
          else
                        AppButton('+${g.fmt(m.reward)}원${m.ticket > 0 ? ' · 전직서' : ''}${m.perk > 0 ? ' · +${m.perk}%' : ''}',
                small: true,
                color: C.gold.withOpacity(0.9),
                onTap: done ? () => g.claimMission(i) : null),
        ],
      ),
    );
  }
}
