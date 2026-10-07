/// 목표(미션): 달성하면 보상을 받는다
class Mission {
  final String text;
  final int kind; // 0 배송 건수, 1 건물 수, 2 직원 수, 3 일차, 4 열린 배송 지역 수, 5 창고 단계(0부터)
  final int target;
  final int reward;
  const Mission(this.text, this.kind, this.target, this.reward);
}
