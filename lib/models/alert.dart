import 'building.dart';
import 'staff.dart';

/// 화면 위쪽에 뜨는 위기 알림 (누르면 바로 조치)
class Alert {
  static const int angry = 0; // 화난 손님
  static const int tired = 1; // 지친 직원
  static const int jam = 2; // 접수 택배가 가득 참

  final int kind;
  final String text;
  final String action; // 버튼에 보일 짧은 글
  final Staff? staff;
  final Building? building;
  const Alert(this.kind, this.text, this.action, {this.staff, this.building});
}
