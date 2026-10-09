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
  int kind = 0; // 맡기는 택배 종류 (0 일반, 1 급송, 2 파손주의, 3 대형)
  bool vip = false; // VIP: 인내심이 짧지만 접수하면 팁
  final int region;
  int look = 0; // 외형 (Sprites.custLooks 중 하나)
  int story = -1; // 사연 택배 (Cfg.storyDefs 번호, 사연 손님만)
  double storyT = 0; // 문 앞에서 기다린 시간
  int guest = -1; // 숨은 손님 (Cfg.guestName 번호)
  bool pre = false; // 사연을 들어 줌 (별점 +0.5)
  Rect? bubble; // 마지막으로 그린 말풍선 (월드 픽셀, 탭 판정용)
  Customer(this.pos, this.region);
}