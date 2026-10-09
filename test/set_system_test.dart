import 'package:flutter_test/flutter_test.dart';
import 'package:saessak_hub/game/config.dart';
import 'package:saessak_hub/game/hub_game.dart';
import 'package:saessak_hub/models/models.dart';

BuildingType _t(String id) => Cfg.types.firstWhere((t) => t.id == id);

/// ids 를 왼쪽부터 빈틈없이(맞닿게) 한 줄로 놓는다. gap 이면 사이를 한 칸씩 띄움
HubGame _row(List<String> ids, {int gap = 0}) {
  final g = HubGame();
  var x = 2;
  for (final id in ids) {
    final t = _t(id);
    g.buildings.add(Building(t, x, 5));
    x += t.w + gap;
  }
  g.updateSets(1);
  return g;
}

void main() {
  // 세트마다: 재료를 맞닿게 놓으면 효과를 받는 건물에 그 세트가 붙는다
  for (var si = 0; si < Cfg.sets.length; si++) {
    final d = Cfg.sets[si];
    final ids = <String>[
      for (final e in d.need.entries) for (var k = 0; k < e.value; k++) e.key,
    ];
    test('세트 ${d.name}: 맞닿으면 발동, 띄우면 안 됨', () {
      final g = _row(ids);
      final targets = g.buildings.where((b) => b.type.id == d.target).toList();
      expect(targets, isNotEmpty);
      for (final b in targets) {
        expect(b.sets, contains(si), reason: '${d.name} → ${b.type.id}');
      }
      expect(g.rt.foundSets, contains(si));
      final b = targets.first;
      if (d.speed != 1) expect(b.setSpeed, closeTo(d.speed, 1e-9));
      if (d.calm != 1) expect(b.setCalm, closeTo(d.calm, 1e-9));
      if (d.rest != 1) expect(b.setRest, closeTo(d.rest, 1e-9));
      if (d.load != 1) expect(b.setLoad, closeTo(d.load, 1e-9));
      if (d.drain != 1) expect(b.setDrain, closeTo(d.drain, 1e-9));
      if (d.cap != 0) expect(b.setCap, d.cap);

      final apart = _row(ids, gap: 1);
      for (final x in apart.buildings) {
        expect(x.sets, isNot(contains(si)), reason: '띄워 놓았는데 발동함');
      }
    });
  }

  test('숨김 세트를 처음 발견하면 명성 +20, 공개 세트는 명성 없음', () {
    final hidden = Cfg.sets.indexWhere((d) => d.hidden);
    final open = Cfg.sets.indexWhere((d) => !d.hidden);
    List<String> ids(SetDef d) =>
        [for (final e in d.need.entries) for (var k = 0; k < e.value; k++) e.key];
    expect(_row(ids(Cfg.sets[hidden])).fame, Cfg.hiddenSetFame);
    expect(_row(ids(Cfg.sets[open])).fame, 0);
  });

  test('배치 미리보기: 놓으면 새로 발동할 세트 이름 (발견 전 숨김은 ???)', () {
    final g = _row(['pack']);
    final (near, names) = g.previewSets(_t('aircon'), 4, 5); // 포장대(2..4) 오른쪽에 맞닿음
    expect(near.length, 1);
    expect(names, ['??? (숨은 조합)']);
    final (far, none) = g.previewSets(_t('aircon'), 6, 5); // 한 칸 띄움
    expect(far, isEmpty);
    expect(none, isEmpty);
  });

  test('화분 반경 2칸: 체력 소모 −5%씩 3개까지, 에어컨 반경 3칸 −10%', () {
    final g = HubGame();
    final pack = Building(_t('pack'), 10, 10);
    g.buildings.add(pack);
    final s = Staff(1, '테스트', 3, 3, 3, 3, 3, 0, 100);
    s.post = pack;
    pack.crew.add(s);
    expect(g.drainAt(s), closeTo(1.0, 1e-9));
    for (var i = 0; i < 4; i++) {
      g.buildings.add(Building(_t('plant'), 12, 10 + i % 2)); // 포장대 바로 옆 (반경 안)
    }
    expect(g.drainAt(s), closeTo(0.95 * 0.95 * 0.95, 1e-9)); // 4개여도 3개까지
    g.buildings.add(Building(_t('aircon'), 9, 10));
    expect(g.drainAt(s), closeTo(0.95 * 0.95 * 0.95 * 0.9, 1e-9)); // 봄(1일차)은 2배 아님
    final far = HubGame();
    final p2 = Building(_t('pack'), 10, 10);
    far.buildings.addAll([p2, Building(_t('plant'), 20, 10)]); // 반경 밖
    final s2 = Staff(2, '멀리', 3, 3, 3, 3, 3, 0, 100)..post = p2;
    expect(far.drainAt(s2), closeTo(1.0, 1e-9));
  });
}
