import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import 'theme.dart';

class TopBar extends StatelessWidget {
  final HubGame g;
  const TopBar(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final progress = (g.dayTimer / Cfg.dayLength).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.fromLTRB(14, mq.padding.top + 6, 6, 8),
      decoration: const BoxDecoration(
        color: Color(0xEE1E1B2E),
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('새싹 택배 허브', style: Tx.title),
                    Text(
                      '${Cfg.corpName[g.companyGrade]} · ${Cfg.areaName[g.areaLevel]} · ${g.year}년차 ${Cfg.seasonName[(g.dayOfYear - 1) ~/ 7]} ${(g.dayOfYear - 1) % 7 + 1}일',
                      style: Tx.sub,
                    ),
                  ],
                ),
              ),
              Pill(Icons.monetization_on, g.fmt(g.money), color: C.gold),
              const SizedBox(width: 6),
              _SmallBtn('x${g.speedMul}', () {
                g.speedIdx = (g.speedIdx + 1) % Cfg.speeds.length;
                g.ui();
              }),
              PopupMenuButton<int>(
                icon: const Icon(Icons.bug_report, color: C.sub),
                color: C.panel,
                onSelected: (v) {
                  switch (v) {
                    case 0:
                      g.money += 10000;
                      break;
                    case 1:
                      g.genCandidates();
                      g.candTimer = 0;
                      break;
                    case 2:
                      g.dayTimer = Cfg.dayLength; // 곧바로 월급 정산
                      break;
                    case 3:
                      for (var i = 0; i < 3; i++) {
                        g.spawnCustomer();
                      }
                      break;
                    case 4:
                      g.resetSave();
                      break;
                    case 5:
                      g.fame += 500;
                      break;
                    case 6:
                      g.debugStarterLayout();
                      break;
                    case 7:
                      g.debugRestCheck();
                      break;
                    case 8:
                      // 직원 모두 직업 Lv5 + 전직서 1장 (전직 확인용)
                      for (final s in g.staff) {
                        s.jobLv = Cfg.jobMaxLv;
                      }
                      g.tickets++;
                      break;
                                        case 9:
                      g.debugProps();
                      break;
                                        case 11:
                      g.rp += 1000;
                      break;
                                                            case 17:
                      if (!g.debugRouteEvent(g.debugStory++)) g.showToast('달리는 차량이 없어요');
                      break;
                    case 16:
                      // 실패 엽서 미리보기 (파손 → 지연 차례로)
                      g.postcard = StoryResult(g.debugStory % Cfg.storyDefs.length, false, 1 + g.debugStory++ % 2, false, 0, 0);
                      break;
                    case 15:
                      // 사연 손님 부르기 (차례로, 확률·날짜 무시)
                      if (g.storyBusy) {
                        g.showToast('진행 중인 사연이 있어요');
                        break;
                      }
                      g.spawnCustomer();
                      final sc = g.customers.last;
                      sc.guest = -1;
                      sc.story = g.debugStory++ % Cfg.storyDefs.length;
                      break;
                    case 14:
                      // 숨은 손님 차례로 부르기 (조건 무시)
                      g.spawnCustomer();
                      final cu = g.customers.last;
                      final k = g.debugGuest++ % Cfg.guestName.length;
                      cu.guest = k;
                      cu.look = Cfg.guestLook0 + k;
                      cu.story = -1;
                      if (g.rt.foundGuests.add(k)) g.showToast('새 손님 발견! ${Cfg.guestName[k]}');
                      break;
                    case 12:
                      g.runAward(g.year); // 지금 기록으로 시상식 보기
                      break;
                    case 13:
                      if (g.companyGrade < Cfg.corpName.length - 1) {
                        g.companyGrade++;
                        g.gradeUp = g.companyGrade;
                        if (g.companyGrade == Cfg.corpName.length - 1) g.endless = true;
                      }
                      break;
                    case 10:
                      // 사건 차례로 일으키기 (확인용)
                      g.openEvent(g.debugEvt++ % Cfg.hubEvtName.length);
                      break;
                  }
                  g.ui();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 0,
                    child: Text('돈 +10,000', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Text('후보 새로고침 (무료)', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 2,
                    child: Text('하루 넘기기 (월급)', style: Tx.body),
                  ),
                  PopupMenuItem(value: 3, child: Text('손님 +3', style: Tx.body)),
                  PopupMenuItem(
                    value: 5,
                    child: Text('명성 +500', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 6,
                    child: Text('시작 구성 자동 배치', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 7,
                    child: Text('휴게실 놓고 직원 지치게', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 8,
                    child: Text('직업 Lv5 + 전직서 1장', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 9,
                    child: Text('세트 소품 6종 놓기', style: Tx.body),
                  ),
                                    PopupMenuItem(
                    value: 10,
                    child: Text('사건 일으키기 (차례로)', style: Tx.body),
                  ),
                                    PopupMenuItem(
                    value: 11,
                    child: Text('RP +1000', style: Tx.body),
                  ),
                                    PopupMenuItem(
                    value: 12,
                    child: Text('연말 시상식 보기', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 13,
                    child: Text('회사 등급 +1', style: Tx.body),
                  ),
                                    PopupMenuItem(
                    value: 17,
                    child: Text('노선 사건 일으키기 (차례로)', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 16,
                    child: Text('실패 엽서 보기 (파손·지연)', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 15,
                    child: Text('사연 손님 부르기 (차례로)', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 14,
                    child: Text('숨은 손님 부르기 (차례로)', style: Tx.body),
                  ),
                  PopupMenuItem(
                    value: 4,
                    child: Text('저장 지우기 (다시 켜면 새로 시작)', style: Tx.body),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 상태 알약은 한 줄 가로 스크롤 (줄이 늘어 아래 경고와 겹치지 않게)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 6,
              children: [
                                for (final l in g.evtLabels) Pill(Icons.campaign, l, color: C.accent),
                Pill(Icons.inbox, '접수 ${g.done}'),
                Pill(Icons.inventory_2, '보관 ${g.totalStored}'),
                Pill(Icons.local_shipping, '배송 ${g.delivered}'),
                Pill(
                  Icons.sentiment_dissatisfied,
                  '놓침 ${g.lost}',
                  color: g.lost > 0 ? C.bad : C.sub,
                ),
                Pill(Icons.groups, '직원 ${g.staff.length}'),
                if (g.holiday != null)
                  Pill(
                    Icons.celebration,
                    '${g.holiday!.$1} ×${g.holiday!.$4}',
                    color: C.gold,
                  ),
                if (g.streak >= 5)
                  Pill(Icons.bolt, '연속 정시 ${g.streak}', color: C.good),
                if (g.fever > 0)
                  Pill(
                    Icons.local_fire_department,
                    '부스트 ${g.fever.ceil()}초',
                    color: C.bad,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: C.line,
                valueColor: const AlwaysStoppedAnimation<Color>(C.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: C.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
