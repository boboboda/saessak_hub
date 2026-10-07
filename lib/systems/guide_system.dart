import '../game/hub_game.dart';

extension GuideSystem on HubGame {
  /// 지금 해야 할 일을 한 줄로 안내 (없으면 null)
  String? get hint {
    if (ofType('counter').isEmpty) return '① 아래 건설 메뉴에서 접수 창구를 설치하세요';
    if (ofType('pack').isEmpty) return '② 포장대를 설치하세요 (가운데 구역)';
    if (ofType('shelf').isEmpty) return '③ 선반을 설치하세요 (오른쪽 구역)';
    if (ofType('dock').isEmpty) return '④ 창고 오른쪽 벽에 도크를 설치하면 택배가 배송돼요';
    if (!staff.any((s) => s.carrier)) {
      return '운반 담당이 없어요. 직원 메뉴에서 운반을 지정하세요';
    }
    for (final b in buildings) {
      if (b.type.slots > 0 && b.crew.isEmpty && !b.mine) {
        return '${b.type.name}에 직원이 없어요. 건물을 눌러 배치하세요';
      }
    }
    return null;
  }
}
