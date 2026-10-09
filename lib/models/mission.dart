/// 업적: 달성하면 보상을 받는다 (돈 + 일부는 전직서·영구 수익 보너스)
class Mission {
  final String text;
  // 0 배송 건수, 1 건물 수, 2 직원 수, 3 일차, 4 열린 배송 지역 수, 5 창고 단계(0부터),
  // 6 직원 최고 레벨, 7 업그레이드 횟수, 8 급송 성공, 9 S등급 날 수, 10 실수 0인 날 연속(최고),
  // 11 별 5점 손님 수, 12 연차 목표 전부 달성한 해 수, 13 전직 횟수, 14 발견한 세트 수, 15 누적 접수
  final int kind;
  final int target;
  final int reward;
  final int ticket; // 전직서 보상 장수
  final int perk; // 영구 수익 보너스 (%)
  const Mission(this.text, this.kind, this.target, this.reward,
      {this.ticket = 0, this.perk = 0});
}

/// 올해 목표 한 개 (해마다 새로 정해짐)
class YearGoal {
  final String text;
  final int kind; // 0 하루 최고 접수, 1 B등급 이상인 날 수, 2 열린 지역 수
  final int target;
  final int reward;
  const YearGoal(this.text, this.kind, this.target, this.reward);
}
