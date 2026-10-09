import '../game/hub_game.dart';

extension GuideSystem on HubGame {
  /// 지금 해야 할 일을 한 줄로 안내 (없으면 null)
  String? get hint {
    if (picking != null) return '${picking!.name}: 배치할 시설을 탭하세요 (선반·도크 = 운반 담당, 빈 곳 = 취소)';
    bool noCrew(String id) => ofType(id).any((b) => b.crew.isEmpty);
    if (ofType('counter').isEmpty) return '① 아래 건설 메뉴에서 접수 창구를 설치하세요';
    if (noCrew('counter')) return '① 접수 창구에 직원을 배치하세요 (창구를 탭 → 직원 선택)';
    if (ofType('pack').isEmpty) return '② 포장대를 설치하세요 (가운데 구역)';
    if (noCrew('pack')) return '② 포장대에 직원을 배치하세요 (포장대를 탭 → 직원 선택)';
    if (ofType('shelf').isEmpty) return '③ 선반을 설치하세요 (오른쪽 구역)';
    if (ofType('dock').isEmpty) return '④ 창고 오른쪽 벽에 도크를 설치하면 택배가 배송돼요';
    if (!staff.any((s) => s.carrier)) {
      return '⑤ 운반 담당이 없어요. 선반이나 도크를 탭해서 운반 직원을 고르세요';
    }
    for (final b in buildings) {
      if (b.type.slots > 0 && b.crew.isEmpty) {
        return '${b.type.name}에 직원이 없어요. 시설을 탭해서 배치하세요';
      }
    }
    return null;
  }
}
