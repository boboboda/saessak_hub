import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
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
          const Text('명성이 쌓이면 새 지역이 열리고 수익이 더 커져요', style: Tx.sub),
          const SizedBox(height: 8),
          for (var i = 0; i < Cfg.regionName.length; i++) ...[
            _region(i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const Text('목표', style: Tx.h2),
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
                Text('수익 ×${Cfg.regionPay[i]}', style: Tx.sub),
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
            AppButton('+${g.fmt(m.reward)}원',
                small: true,
                color: C.gold.withOpacity(0.9),
                onTap: done ? () => g.claimMission(i) : null),
        ],
      ),
    );
  }
}
