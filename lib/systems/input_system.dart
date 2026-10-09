import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/hub_game.dart';

/// 맵(게임 화면) 터치만 담당. 메뉴·패널은 Flutter 위젯이 처리.
extension InputSystem on HubGame {
  Offset toWorld(Offset p) => p + cam;

  void handleTap(Offset p) {
    if (size.x == 0) return;
    final w = toWorld(p);

    // 배치 중: 맵을 탭하면 목업이 그 칸으로 이동
    if (mode == 2 && placing != null) {
      this.moveGhost(w);
      return;
    }
    if (mode == 3) return;
    if (mode == 4) {
      if (aisleTool != 2) this.aisleAt(w);
      aisleLast = null;
      return;
    }

    // 내 자리 손님을 눌렀으면 접수
    if (this.tapCustomer(w)) return;

    final tx = (w.dx / Cfg.tile).floor();
    final ty = (w.dy / Cfg.tile).floor();
    sheet = null;
    selected = this.buildingAt(tx, ty);
    ui();
  }

  void panStart(Offset p) {
    draggingGhost = false;
    if (size.x == 0) return;
    if (mode == 4 && aisleTool != 2) {
      aisleLast = null;
      this.aisleAt(toWorld(p));
      return;
    }
    if (mode == 2 && placing != null) {
      final r = this.ghostRect;
      final px = Rect.fromLTWH(
        r.left * Cfg.tile,
        r.top * Cfg.tile,
        r.width * Cfg.tile,
        r.height * Cfg.tile,
      );
      if (px.inflate(14).contains(toWorld(p))) draggingGhost = true;
    }
  }

  void panUpdate(Offset p, Offset delta) {
    if (size.x == 0) return;
    if (mode == 4 && aisleTool != 2) {
      this.aisleAt(toWorld(p), drag: true);
    } else if (draggingGhost && placing != null) {
      this.moveGhost(toWorld(p));
    } else {
      cam = cam - delta;
      clampCam();
    }
  }

  void panEnd() {
    draggingGhost = false;
    aisleLast = null;
  }
}
