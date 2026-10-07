import 'package:flutter/material.dart';

import '../game/config.dart';
import 'building.dart';

class Customer {
  Offset pos; // 타일 좌표(소수)
  Building? counter; // 배정된 접수 창구
  int state = 0; // 0 입장·대기·접수, 2 퇴장
  double patience = Cfg.patience;
  double serveT = 0;
  bool ready = false; // 내 자리 맨 앞에 서서 접수를 기다리는 중
  bool tapped = false; // 내가 탭해서 접수 요청함
  final int region;
  Customer(this.pos, this.region);
}