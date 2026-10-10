import 'dart:async';

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import '../game/sprites.dart';
import 'garage_screen.dart';
import 'overlay_ui.dart';
import 'route_map_screen.dart';
import 'theme.dart';

/// 화면 3개(허브 · 노선 지도 · 차고)를 맨 아래 탭으로 오간다.
/// 허브는 게임 맵(캔버스) 위에 메뉴·패널 위젯을 겹친 것, 나머지 둘은 허브 위로 밀려 들어오는 전체 화면.
class GameScreen extends StatefulWidget {
  final HubGame game;
  const GameScreen(this.game, {super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double tabH = 52; // 화면 탭 높이
  static const Duration dur = Duration(milliseconds: 320);

  HubGame get game => widget.game;
  int _shown = 0; // 지금 그리는 화면 (전환이 끝나기 전엔 이전 화면도 같이 그림)
  int _from = 0; // 전환 방향 (이전 화면 번호)
  bool _hubHidden = false; // 다른 화면이 다 덮으면 허브 그림을 쉬게 함
  int _wipe = 0; // 트럭 지나가는 연출 번호 (바뀔 때마다 새로)
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    game.tick.addListener(_onTick);
  }

  @override
  void dispose() {
    game.tick.removeListener(_onTick);
    _hide?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (game.screen == _shown) return;
    setState(() {
      _from = _shown;
      _shown = game.screen;
      _wipe++;
      _hide?.cancel();
      if (_shown == 0) {
        _hubHidden = false; // 허브로 돌아갈 땐 바로 다시 그림
      } else {
        _hide = Timer(dur, () {
          if (mounted && game.screen != 0) setState(() => _hubHidden = true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final nav = navInset(context);
    // 화면 탭만큼 아래 여백을 늘려서, 원래 시스템 내비게이션 바를 피하던 메뉴·시트가 탭도 피하게 함
    final inner = mq.copyWith(
      padding: mq.padding.copyWith(bottom: nav + tabH),
      viewPadding: mq.viewPadding.copyWith(bottom: nav + tabH),
    );
    game.insetTop = mq.padding.top + 92;
    game.insetBottom = nav + tabH + 88;
    if (game.camInit) game.clampCam();

    return Material(
      color: C.bg,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => game.lastTouchMs = DateTime.now().millisecondsSinceEpoch,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: inner,
                child: Offstage(offstage: _hubHidden, child: _hub()),
              ),
            ),
            Positioned.fill(
              child: MediaQuery(
                data: inner,
                child: AnimatedSwitcher(
                  duration: dur,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: _slide,
                  layoutBuilder: (cur, prev) => Stack(children: [...prev, if (cur != null) cur]),
                  child: _shown == 1
                      ? KeyedSubtree(key: const ValueKey(1), child: RouteMapScreen(game))
                      : _shown == 2
                          ? KeyedSubtree(key: const ValueKey(2), child: GarageScreen(game))
                          : const SizedBox.shrink(key: ValueKey(0)),
                ),
              ),
            ),
            if (_wipe > 0) Positioned(left: 0, right: 0, bottom: nav + tabH - 6, height: 40, child: _TruckWipe(key: ValueKey(_wipe), toRight: _shown > _from)),
            Positioned(left: 0, right: 0, bottom: 0, child: _ScreenTabs(game, nav, tabH)),
            // 허브가 아닌 화면에서도 알림이 보이게 (허브 알림은 OverlayUi 가 그림)
            Positioned(
              left: 16,
              right: 16,
              bottom: nav + tabH + 16,
              child: ValueListenableBuilder<int>(
                valueListenable: game.tick,
                builder: (context, _, __) => game.screen != 0 && game.toastTime > 0
                    ? IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xEE000000), borderRadius: BorderRadius.circular(20)),
                            child: Text(game.toast, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 새 화면은 옆에서 밀려 들어옴 (오른쪽 탭이면 오른쪽에서), 나가는 화면은 반대로 살짝 밀려 나가며 흐려짐
  Widget _slide(Widget child, Animation<double> a) {
    final k = (child.key as ValueKey?)?.value as int? ?? 0;
    final dir = _shown > _from ? 1.0 : -1.0;
    final incoming = k == _shown;
    final off = Tween<Offset>(
      begin: Offset(incoming ? dir : -dir * 0.3, 0),
      end: Offset.zero,
    ).animate(a);
    // 들어오는 화면은 불투명하게 밀려 들어옴 (반투명이면 허브 메뉴가 먼저 사라져 깨져 보임), 나가는 화면만 흐려짐
    final slid = SlideTransition(position: off, child: child);
    return incoming ? slid : FadeTransition(opacity: a, child: slid);
  }

  Widget _hub() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => game.handleTap(d.localPosition),
            // 한 손가락: 끌기(화면 이동·배치·통로), 두 손가락: 확대/축소 + 이동
            onScaleStart: (d) {
              if (d.pointerCount >= 2) {
                game.panEnd();
                game.pinchStart();
              } else {
                game.panStart(d.localFocalPoint);
              }
            },
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) {
                game.pinchUpdate(d.localFocalPoint, d.scale);
                game.cam -= d.focalPointDelta / game.zoom;
                game.clampCam();
              } else {
                game.panUpdate(d.localFocalPoint, d.focalPointDelta);
              }
            },
            onScaleEnd: (_) => game.panEnd(),
            child: GameWidget(game: game),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: game.tick,
            // 전환이 끝날 때까지는 허브 메뉴도 그대로 둠 (다 덮이면 허브 전체가 Offstage 로 쉼)
            builder: (context, _, __) => OverlayUi(game),
          ),
        ),
      ],
    );
  }
}

/// 맨 아래 화면 탭: 허브 · 노선 지도 · 차고
class _ScreenTabs extends StatelessWidget {
  final HubGame g;
  final double nav, h;
  const _ScreenTabs(this.g, this.nav, this.h);

  static const _icons = [Icons.warehouse, Icons.map, Icons.garage];
  static const _names = ['허브', '노선 지도', '차고'];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: g.tick,
      builder: (context, _, __) {
        // 노선 지도 탭: 지금 사건을 겪는 차량 수
        final evt = g.fleet.where((u) => u.evtT > 0 && !u.evtOk).length;
        return Container(
          height: h + nav,
          padding: EdgeInsets.only(bottom: nav),
          decoration: const BoxDecoration(
            color: Color(0xFF17142A),
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => g.goScreen(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: g.screen == i ? C.accent.withValues(alpha: 0.22) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: g.screen == i ? C.accent : Colors.transparent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_icons[i], size: 18, color: g.screen == i ? C.accent : C.sub),
                          const SizedBox(width: 6),
                          Text(_names[i],
                              style: TextStyle(
                                  color: g.screen == i ? Colors.white : C.sub, fontSize: 13, fontWeight: FontWeight.w800)),
                          if (i == 0 && g.modalOpen && g.screen != 0) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.error, size: 14, color: C.gold), // 허브에서 확인할 카드가 있음
                          ],
                          if (i == 1 && evt > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: C.bad, borderRadius: BorderRadius.circular(8)),
                              child: Text('$evt',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 화면을 바꿀 때 탭 위로 택배 트럭이 한 번 지나감 (바뀌는 방향으로)
class _TruckWipe extends StatefulWidget {
  final bool toRight;
  const _TruckWipe({super.key, required this.toRight});

  @override
  State<_TruckWipe> createState() => _TruckWipeState();
}

class _TruckWipeState extends State<_TruckWipe> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Sprites.vanFull ?? Sprites.van;
    if (img == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          if (_a.isCompleted) return const SizedBox.shrink();
          final w = MediaQuery.of(context).size.width;
          final t = Curves.easeInOut.transform(_a.value);
          final x = widget.toRight ? -60 + (w + 120) * t : w + 60 - (w + 120) * t;
          final bounce = (t * 18).floor().isEven ? 0.0 : -1.5;
          return Stack(
            children: [
              Positioned(
                left: x - 30,
                top: 4 + bounce,
                width: 60,
                height: 34,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(widget.toRight ? 1 : -1, 1, 1),
                  child: RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
