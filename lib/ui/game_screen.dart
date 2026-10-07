import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import 'overlay_ui.dart';
import 'theme.dart';

/// 맨 아래는 게임 맵(캔버스), 그 위에 메뉴·패널 위젯을 겹침
class GameScreen extends StatelessWidget {
  final HubGame game;
  const GameScreen(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 위젯이 가리는 높이를 게임에 알려 카메라가 그만큼 비켜 있게 함
    game.insetTop = mq.padding.top + 92;
    game.insetBottom = mq.padding.bottom + 88;
    if (game.camInit) game.clampCam();

    return Material(
      color: C.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => game.handleTap(d.localPosition),
              onPanStart: (d) => game.panStart(d.localPosition),
              onPanUpdate: (d) => game.panUpdate(d.localPosition, d.delta),
              onPanEnd: (_) => game.panEnd(),
              onPanCancel: () => game.panEnd(),
              child: GameWidget(game: game),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: game.tick,
              builder: (context, _, __) => OverlayUi(game),
            ),
          ),
        ],
      ),
    );
  }
}