import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import '../models/models.dart';
import 'staff_widgets.dart';
import 'theme.dart';

Widget _shell(String title, List<Widget> rows) {
  return Dialog(
    backgroundColor: C.panel,
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Tx.title),
            ),
          ),
          const Divider(height: 1, color: C.line),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              children: rows,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _row({
  required Widget leading,
  required String title,
  required String sub,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: C.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Tx.h2),
                    const SizedBox(height: 2),
                    Text(sub, style: Tx.sub),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: C.sub),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _icon(IconData i, Color c) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    child: Icon(i, color: Colors.white),
  );
}

/// 직원을 어디에 배치할지 고르기 (운반 / 대기 / 빈 자리가 있는 건물)
Future<void> showAssignPostDialog(
    BuildContext context, HubGame g, Staff s) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final rows = <Widget>[];
      if (!s.carrier) {
        rows.add(_row(
          leading: _icon(Icons.local_shipping, C.blue),
          title: '운반 담당',
          sub: '접수 → 포장 → 보관 택배를 나릅니다',
          onTap: () {
            g.setCarrier(s);
            Navigator.pop(ctx);
          },
        ));
      }
      for (final b in g.openPosts()) {
        if (b == s.post) continue;
        rows.add(_row(
          leading: _icon(
              b.type.id == 'counter' ? Icons.support_agent : Icons.inventory_2,
              b.type.id == 'counter' ? C.accent : C.good),
          title: '${b.type.name} #${g.typeIndex(b)}',
          sub: '근무 ${b.crew.length}/${b.seats}명',
          onTap: () {
            g.assignTo(s, b);
            Navigator.pop(ctx);
          },
        ));
      }
      if (!s.idle) {
        rows.add(_row(
          leading: _icon(Icons.pause_circle_outline, C.line),
          title: '대기',
          sub: '배치를 해제합니다',
          onTap: () {
            g.unassign(s);
            Navigator.pop(ctx);
          },
        ));
      }
      if (rows.isEmpty) {
        rows.add(const Padding(
          padding: EdgeInsets.all(12),
          child: Text('배치할 수 있는 자리가 없어요.\n건설에서 접수 창구나 포장대를 지어 보세요.',
              style: Tx.sub),
        ));
      }
      return _shell('${s.name} 배치', rows);
    },
  );
}

/// 건물에 배치할 직원 고르기
Future<void> showAssignStaffDialog(
    BuildContext context, HubGame g, Building b) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final rows = <Widget>[];
      for (final s in g.staff) {
        if (b.crew.contains(s)) continue;
        rows.add(_row(
          leading: StaffAvatar(s),
          title: s.name,
          sub: '${roleText(g, s)} · 손속도 ${s.speed} 걸음 ${s.walk} 친절 ${s.kind}',
          onTap: () {
            g.assignTo(s, b);
            Navigator.pop(ctx);
          },
        ));
      }
      if (rows.isEmpty) {
        rows.add(const Padding(
          padding: EdgeInsets.all(12),
          child: Text('배치할 직원이 없어요.\n직원 메뉴의 고용 탭에서 뽑아 보세요.', style: Tx.sub),
        ));
      }
      return _shell('${b.type.name} 직원 배치', rows);
    },
  );
}

/// 해고 확인
Future<void> showFireDialog(BuildContext context, HubGame g, Staff s) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.panel,
      title: Text('${s.name} 해고', style: Tx.title),
      content: const Text('해고하면 되돌릴 수 없어요.', style: Tx.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(color: C.sub)),
        ),
        TextButton(
          onPressed: () {
            g.fire(s);
            Navigator.pop(ctx);
          },
          child: const Text('해고', style: TextStyle(color: C.bad)),
        ),
      ],
    ),
  );
}