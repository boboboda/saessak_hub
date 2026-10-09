import 'package:flutter/material.dart';

/// 색상
class C {
  static const bg = Color(0xFF1E1B2E);
  static const panel = Color(0xFF2A2640);
  static const card = Color(0xFF363152);
  static const line = Color(0xFF4A4468);
  static const accent = Color(0xFFF0963A);
  static const good = Color(0xFF3FB27F);
  static const bad = Color(0xFFE5484D);
  static const gold = Color(0xFFFFD166);
  static const blue = Color(0xFF3B82D6);
  static const text = Colors.white;
  static const sub = Color(0xFFB6B1CC);
}

/// 글자 스타일
class Tx {
  static const title =
  TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w800);
  static const h2 =
  TextStyle(color: C.text, fontSize: 15, fontWeight: FontWeight.w700);
  static const body = TextStyle(color: C.text, fontSize: 13);
  static const sub = TextStyle(color: C.sub, fontSize: 12);
}

/// 작은 정보 알약 (아이콘 + 글자)
class Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const Pill(this.icon, this.text, {super.key, this.color = C.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color == C.sub ? C.text : color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공용 버튼 (onTap이 null이면 비활성)
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool small;
  final bool expand;
  final IconData? icon;
  const AppButton(
      this.label, {
        super.key,
        this.onTap,
        this.color = C.accent,
        this.small = false,
        this.expand = false,
        this.icon,
      });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 14 : 18, color: enabled ? Colors.white : C.sub),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : C.sub,
            fontWeight: FontWeight.w700,
            fontSize: small ? 12 : 14,
          ),
        ),
      ],
    );
    return Material(
      color: enabled ? color : C.line,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 12 : 16, vertical: small ? 8 : 12),
          child: expand ? Center(child: content) : content,
        ),
      ),
    );
  }
}

/// 아래에서 올라오는 시트 틀 (제목 + 닫기 + 내용)
class SheetFrame extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;
  final Widget? trailing;
  const SheetFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.6,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * heightFactor,
      decoration: const BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: C.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 2),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Tx.title)),
                if (trailing != null) trailing!,
                IconButton(
                  icon: const Icon(Icons.close, color: C.sub),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: C.line),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: navInset(context)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 아래 시스템 내비게이션 바(제스처 막대·3버튼)가 가리는 높이
double navInset(BuildContext context) {
  final m = MediaQuery.of(context);
  return m.viewPadding.bottom > m.padding.bottom
      ? m.viewPadding.bottom
      : m.padding.bottom;
}

/// 카드 배경
class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}