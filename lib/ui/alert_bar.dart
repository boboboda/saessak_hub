import 'package:flutter/material.dart';

import '../game/hub_game.dart';
import '../models/models.dart';
import 'theme.dart';

/// 화면 위쪽에 뜨는 위기 알림 칩. 누르면 바로 조치한다.
class AlertBar extends StatelessWidget {
  final HubGame g;
  const AlertBar(this.g, {super.key});

  Color _color(Alert a) {
    switch (a.kind) {
      case Alert.angry:
        return C.bad;
      case Alert.tired:
        return C.accent;
      default:
        return C.blue;
    }
  }

  IconData _icon(Alert a) {
    switch (a.kind) {
      case Alert.angry:
        return Icons.sentiment_very_dissatisfied;
      case Alert.tired:
        return Icons.bedtime;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = List<Alert>.from(g.alerts);
    if (list.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in list)
          Material(
            color: _color(a).withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => g.runAlert(a),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon(a), size: 16, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(a.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(a.action,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
