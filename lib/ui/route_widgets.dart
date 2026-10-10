import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../models/models.dart';
import 'theme.dart';

/// 작은 고르기 칸 (구역·적재 한도)
Widget routeChip(String text, bool on, VoidCallback onTap, {Color color = C.accent}) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: on ? color : const Color(0xFFFFFBEE),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: C.frame, width: 1.5),
        ),
        child: Text(text,
            style: TextStyle(fontFamily: kFont, fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white : C.text)),
      ),
    );

/// 차량의 노선 설정: 맡을 구역(배달 차량만) · 적재 한도 · 기사 개성 · 차량 무리
class UnitRouteControls extends StatelessWidget {
  final HubGame g;
  final FleetUnit u;
  const UnitRouteControls(this.g, this.u, {super.key});

  @override
  Widget build(BuildContext context) {
    final lp = Cfg.loadPct[u.loadIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (u.trait > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('개성: ${Cfg.traitName[u.trait]} · ${Cfg.traitDesc[u.trait]}',
                style: Tx.sub.copyWith(color: const Color(0xFF8E5BD0), fontWeight: FontWeight.w700)),
          ),
        if (!u.isTrunk) ...[
          Text('맡을 구역', style: Tx.sub.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Wrap(spacing: 4, runSpacing: 4, children: [
            routeChip('자동', u.zone < 0, () => g.setZone(u, -1)),
            for (var z = 0; z < 3; z++)
              routeChip('${Cfg.zoneNameR[z]} ×${Cfg.zonePay[z]}', u.zone == z, () => g.setZone(u, z), color: Color(Cfg.zoneColor[z])),
          ]),
          const SizedBox(height: 4),
        ],
        Text('적재 한도 · 이번에 ${u.cap}건 (정량 ${u.baseCap})', style: Tx.sub.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < Cfg.loadPct.length; i++)
            routeChip(Cfg.loadName[i], u.loadIdx == i, () => g.setLoad(u, i), color: i >= 2 ? C.bad : (i == 0 ? C.good : C.accent)),
        ]),
        if (lp > 1)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '과적 위험: 속도 ×${Cfg.loadSpeed[u.loadIdx]} · 단속 ${(Cfg.loadPolice[u.loadIdx] * Cfg.regionPolice[u.region] * 100).round()}% · 파손 ${(Cfg.loadBreak[u.loadIdx] * 100).round()}%/건${u.trait == 4 ? ' (힘장사라 절반)' : ''}',
              style: Tx.sub.copyWith(fontSize: 10, color: C.bad),
            ),
          )
        else if (lp < 1)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('가볍게: 빨리 출발하고 속도 ×${Cfg.loadSpeed[0]} (기한 짧은 지역에 좋아요)',
                style: Tx.sub.copyWith(fontSize: 10, color: C.good)),
          ),
        if (u.wear > 0)
          Text('차량 무리 ${u.wear} · 펑크가 잦아져요 (하루마다 조금씩 회복)', style: Tx.sub.copyWith(fontSize: 10, color: C.accent)),
      ],
    );
  }
}

/// 노선 지도 패널 위쪽: 지역 개성 · 날씨 · 평판 · 의뢰 게시판 · 지도 시설 · 단골 집
class RoutePanelExtras extends StatelessWidget {
  final HubGame g;
  final int r;
  const RoutePanelExtras(this.g, this.r, {super.key});

  static const _wIcon = [Icons.wb_sunny, Icons.umbrella, Icons.ac_unit, Icons.cloud];

  @override
  Widget build(BuildContext context) {
    final col = Color(Cfg.regionColor[r]);
    final lv = g.repLv(r);
    final next = lv + 1 < Cfg.repNeed.length ? Cfg.repNeed[lv + 1] : null;
    final reqs = g.rs.reqs;
    final regulars = [
      for (final k in g.rs.hearts[r].keys)
        if (g.regularLv(r, k) > 0) k,
    ]..sort((a, b) => g.heartsOf(r, b).compareTo(g.heartsOf(r, a)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 지역 개성 + 날씨
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(child: Text('${Cfg.regionName[r]} · ${Cfg.regionCargo[r]}', style: Tx.h2)),
                Icon(_wIcon[g.rs.weather], size: 16, color: C.blue),
                Text(' 오늘 ${Cfg.weatherName[g.rs.weather]}', style: Tx.sub),
                Text(' · 내일 ${Cfg.weatherName[g.rs.tomorrow]}', style: Tx.sub),
              ]),
              const SizedBox(height: 3),
              Text(Cfg.regionTip[r], style: Tx.sub),
              Text(
                '수익 ×${Cfg.regionPayMul[r]} · 기한 ×${Cfg.regionDeadlineMul[r]} · 우대 차량 ${Cfg.vehicles[Cfg.regionFavor[r]].name}(수익 +${((Cfg.favorPay - 1) * 100).round()}%)',
                style: Tx.sub.copyWith(color: C.text, fontWeight: FontWeight.w700),
              ),
              if (g.rs.weather != 0 || g.rs.tomorrow != 0)
                Text('비·눈·안개는 오토바이가 특히 느려지고 사건이 잦아요 (비에 강한 기사는 괜찮아요)', style: Tx.sub.copyWith(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 평판
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('지역 평판 ', style: Tx.h2),
                Text('★' * lv + '☆' * (Cfg.repNeed.length - 1 - lv), style: const TextStyle(color: C.gold, fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(child: Text(Cfg.repName[lv], style: Tx.sub.copyWith(color: C.text))),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: next == null ? 1 : ((g.rs.rep[r] - Cfg.repNeed[lv]) / (next - Cfg.repNeed[lv])).clamp(0.0, 1.0).toDouble(),
                  minHeight: 7,
                  backgroundColor: C.line,
                  valueColor: const AlwaysStoppedAnimation(C.good),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                next == null
                    ? '최고 평판! 수익 +${(Cfg.repPay * lv * 100).round()}%'
                    : '정시 배달 ${g.rs.rep[r]}/$next · 지금 수익 +${(Cfg.repPay * lv * 100).round()}% · 오르면 의뢰가 커져요',
                style: Tx.sub,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 의뢰 게시판
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.assignment, size: 16, color: C.accent),
                const SizedBox(width: 4),
                const Expanded(child: Text('의뢰 게시판', style: Tx.h2)),
                Text('완료 ${g.rs.reqDone}건', style: Tx.sub),
              ]),
              const SizedBox(height: 4),
              if (reqs.isEmpty) const Text('새 의뢰는 내일 들어와요', style: Tx.sub),
              for (final q in reqs) ...[
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: Color(Cfg.regionColor[q.region]), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Expanded(child: Text(q.text, style: Tx.body.copyWith(fontWeight: FontWeight.w700))),
                  Text('${q.got}/${q.need}', style: Tx.sub.copyWith(color: C.text)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 13, bottom: 4),
                  child: Text(
                      '보상 ${g.fmt(q.reward)}원 · 명성 +${q.fame} · ${q.until == g.day ? '오늘까지' : '${q.until - g.day + 1}일 남음'}',
                      style: Tx.sub.copyWith(fontSize: 10, color: C.gold)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 지도 시설
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${Cfg.regionName[r]} 지도 시설', style: Tx.h2),
              const SizedBox(height: 4),
              for (var f = 0; f < Cfg.facName.length; f++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    Icon(g.hasFac(r, f) ? Icons.check_circle : Icons.construction, size: 16, color: g.hasFac(r, f) ? C.good : C.sub),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Cfg.facName[f], style: Tx.body.copyWith(fontWeight: FontWeight.w700)),
                        Text(Cfg.facDesc[f], style: Tx.sub.copyWith(fontSize: 10)),
                      ]),
                    ),
                    g.hasFac(r, f)
                        ? const Text('완료', style: TextStyle(fontFamily: kFont, color: C.good, fontWeight: FontWeight.w700))
                        : AppButton('${g.fmt(g.facCost(r, f))}원',
                            small: true,
                            color: const Color(0xFF8E5BD0),
                            onTap: g.money >= g.facCost(r, f) ? () => g.buyFac(r, f) : null),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 단골 집
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('♥ ', style: TextStyle(color: Color(0xFFFF4F8B), fontSize: 15)),
                Expanded(child: Text('단골 집 ${regulars.length}곳', style: Tx.h2)),
              ]),
              const SizedBox(height: 2),
              Text('같은 집에 배달할수록 하트가 쌓여요. 구역을 정해 주면 같은 동네를 자주 가요', style: Tx.sub.copyWith(fontSize: 10)),
              for (final k in regulars.take(5))
                Text(
                  '${k + 1}번 집 · ${Cfg.regularName[g.regularLv(r, k)]} (하트 ${g.heartsOf(r, k)}) · 팁 ${Cfg.heartTip[g.regularLv(r, k)]}원/건 · ${Cfg.zoneNameR[g.zoneOf(r, k)]}',
                  style: Tx.sub.copyWith(color: C.text),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 사건 대응 고르기 (지도에서 보고 있을 때). 시간이 지나면 기사에게 맡김
class RouteEvtChoice extends StatelessWidget {
  final HubGame g;
  final FleetUnit u;
  const RouteEvtChoice(this.g, this.u, {super.key});

  @override
  Widget build(BuildContext context) {
    final k = u.evtPendKind;
    final p = (u.evtWaitT / Cfg.evtChooseSec).clamp(0.0, 1.0).toDouble();
    final base = Cfg.evtSuccess(u.skill);
    final opts = [
      (0, '맡기기', '성공 ${(base * 100).round()}%', C.blue),
      (1, '우회로', '확실 · 조금 늦음 · 기름값', C.good),
      (2, '서둘러!', '성공 ${((base + 0.25).clamp(0, 1) * 100).round()}% · 실패하면 더 늦음', C.bad),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xF7FFF6DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.frame, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: C.bad, size: 18),
            const SizedBox(width: 4),
            Expanded(child: Text('${u.driver} 기사: ${Cfg.evtName[k]}! 어떻게 할까요?', style: Tx.h2.copyWith(fontSize: 13))),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: p, minHeight: 5, backgroundColor: C.line, valueColor: const AlwaysStoppedAnimation(C.accent)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (final (c, name, sub, col) in opts) ...[
              if (c > 0) const SizedBox(width: 5),
              Expanded(
                child: GestureDetector(
                  onTap: () => g.chooseRouteEvt(u, c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.frame, width: 2)),
                    child: Column(children: [
                      Text(name, style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(sub,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 9)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
