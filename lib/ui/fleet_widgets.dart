import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';
import '../game/sprites.dart';
import '../models/models.dart';
import 'route_widgets.dart';
import 'theme.dart';

/// 노선 지도·차고에서 같이 쓰는 차량 표시

String skillStars(int s) => '★' * s + '☆' * (5 - s);

String unitState(FleetUnit u) {
  switch (u.state) {
    case 1:
      return u.isTrunk ? '센터로 가는 중 (${u.cargo}건)' : '배달 중 (${u.cargo}건)';
    case 2:
      return '돌아오는 중';
    case 3:
      return '허브 도크에서 싣는 중';
    default:
      return '대기';
  }
}

ui.Image? unitImage(int type, {bool full = false}) {
  switch (type) {
    case 0:
      return full ? (Sprites.truckFull ?? Sprites.truck) : Sprites.truck;
    case 1:
      return full ? (Sprites.vanFull ?? Sprites.van) : Sprites.van;
    default:
      return full ? (Sprites.motoFull ?? Sprites.moto) : Sprites.moto;
  }
}

/// 차량 카드: 그림·레벨·기사·상태, 노선 바꾸기, 업그레이드·기사 훈련, 지도에서 보기
class UnitCard extends StatelessWidget {
  final HubGame g;
  final FleetUnit u;
  const UnitCard(this.g, this.u, {super.key});

  @override
  Widget build(BuildContext context) {
    final img = unitImage(u.type, full: u.state == 1 && u.cargo > 0);
    final color = Color(Cfg.regionColor[u.region]);
    final upCost = Cfg.upgradeCost(u.type, u.level);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 40,
                child: img == null ? const SizedBox() : RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.none),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u.name} Lv.${u.level} · 적재 ${u.cap}', style: Tx.h2),
                    Text('기사 ${u.driver} · ${Cfg.skillName[u.skill]}(${'★' * u.skill}) · ${unitState(u)}', style: Tx.sub),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => g.cycleRegion(u),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                  child: Text('${Cfg.regionName[u.region]} ▸',
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          UnitRouteControls(g, u),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              AppButton(u.level >= Cfg.maxLevel ? '최고 레벨' : '업그레이드 ${g.fmt(upCost)}원',
                  small: true,
                  color: C.blue,
                  onTap: (u.level >= Cfg.maxLevel || g.money < upCost) ? null : () => g.upgradeUnit(u)),
              AppButton(u.skill >= 5 ? '기사 달인' : '기사 훈련 ${g.fmt(g.trainCostOf(u))}원',
                  small: true,
                  color: C.good,
                  onTap: (u.skill >= 5 || g.money < g.trainCostOf(u)) ? null : () => g.trainDriver(u)),
              AppButton('지도에서 보기', small: true, color: C.line, icon: Icons.my_location, onTap: () {
                g.mapSel = u.region;
                g.mapFollow = u.id;
                g.goScreen(1);
              }),
            ],
          ),
        ],
      ),
    );
  }
}
