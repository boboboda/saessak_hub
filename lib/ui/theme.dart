import 'dart:async';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/sprites.dart';

/// 색상: 카이로소프트풍 — 크림색 종이 창 + 진한 갈색 테두리 + 또렷한 원색 버튼
class C {
  static const bg = Color(0xFFEAD7AE); // 전체 화면 바탕 (양피지)
  static const panel = Color(0xFFFFF4D8); // 창 바탕 (크림)
  static const card = Color(0xFFF9E6BC); // 창 안 칸
  static const line = Color(0xFFD3AF76); // 칸 테두리·구분선
  static const frame = Color(0xFF5B3A1F); // 창·버튼 굵은 외곽선
  static const wood = Color(0xFF8A5A30); // 나무 판 (아래 탭·바)
  static const accent = Color(0xFFF08A24);
  static const good = Color(0xFF3FA55B);
  static const bad = Color(0xFFE04848);
  static const gold = Color(0xFFD08A00); // 돈·보상 글씨 (크림 위에서 읽히는 진한 금색)
  static const coin = Color(0xFFFFC93C); // 동전·별 채움
  static const blue = Color(0xFF3B7DD8);
  static const text = Color(0xFF4A2F1A); // 진한 갈색 글씨
  static const sub = Color(0xFF8C6A48);
  static const onDark = Color(0xFFFFF4D8); // 진한 바탕 위 글씨
}

/// 글꼴: 한글 도트 폰트 Galmuri
const String kFont = 'Galmuri';

/// 글자 스타일
class Tx {
  static const title = TextStyle(
    fontFamily: kFont,
    color: C.text,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const h2 = TextStyle(
    fontFamily: kFont,
    color: C.text,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(fontFamily: kFont, color: C.text, fontSize: 12);
  static const sub = TextStyle(fontFamily: kFont, color: C.sub, fontSize: 11);
}

/// 색을 어둡게/밝게 (버튼 입체감)
Color shade(Color c, double k) => Color.lerp(c, Colors.black, k)!;
Color tint(Color c, double k) => Color.lerp(c, Colors.white, k)!;

/// 도트 UI 아이콘 (assets/sprites/ui/<name>.png). 없으면 머티리얼 아이콘으로
class UiIcon extends StatelessWidget {
  final String name;
  final IconData fallback;
  final double size;
  final Color color;
  const UiIcon(
    this.name,
    this.fallback, {
    super.key,
    this.size = 32,
    this.color = C.text,
  });

  @override
  Widget build(BuildContext context) {
    final img = Sprites.menuIcons[name];
    if (img == null) return Icon(fallback, size: size * 0.8, color: color);
    return SizedBox(
      width: size,
      height: size,
      child: RawImage(
        image: img,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}

/// 물건 그림 칸 (건설 목록 등): 흰 크림 판 + 갈색 테두리 + 도트 그림, 아래 오른쪽에 작은 꼬리표
class ItemFrame extends StatelessWidget {
  final dynamic image; // ui.Image? (시설 그림)
  final String? icon; // 메뉴 아이콘 이름 (image 대신)
  final Widget fallback;
  final String? tag;
  final Color tagColor;
  final double size;
  const ItemFrame({super.key, this.image, this.icon, required this.fallback, this.tag, this.tagColor = C.accent, this.size = 58});

  @override
  Widget build(BuildContext context) {
    final img = image ?? (icon == null ? null : Sprites.menuIcons[icon]);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEE),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: C.frame, width: 2),
              ),
              alignment: Alignment.center,
              child: img == null ? fallback : RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.none),
            ),
          ),
          if (tag != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: C.frame, width: 1.5),
                ),
                child: Text(tag!, style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 작은 정보 알약 (아이콘 + 글자): 크림 바탕 + 갈색 테두리
class Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const Pill(this.icon, this.text, {super.key, this.color = C.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.frame, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color == C.gold ? C.coin : color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: kFont,
              color: color == C.sub || color == C.gold ? C.text : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공용 버튼 (onTap이 null이면 비활성): 굵은 외곽선 + 위 밝은 띠 + 아래 그림자, 누르면 쑥 들어감
class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final enabled = w.onTap != null;
    // 크림 계열(취소 등)은 갈색 글씨, 원색은 흰 글씨
    final base = enabled
        ? (w.color == C.card ? const Color(0xFFFFFBEE) : w.color)
        : const Color(0xFFD9C7A2);
    final light = base.computeLuminance() > 0.6;
    final fg = !enabled
        ? const Color(0xFFA08A68)
        : (light ? C.text : Colors.white);
    final depth = _down || !enabled ? 1.0 : 3.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w.icon != null) ...[
          Icon(w.icon, size: w.small ? 14 : 18, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            w.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kFont,
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: w.small ? 12 : 14,
              shadows: light || !enabled
                  ? null
                  : [
                      Shadow(
                        color: shade(base, 0.5),
                        offset: const Offset(1, 1),
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: w.onTap,
      child: Padding(
        padding: EdgeInsets.only(top: 3 - depth),
        child: Container(
          decoration: BoxDecoration(
            color: shade(base, 0.35),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: C.frame, width: 2),
          ),
          padding: EdgeInsets.only(bottom: depth),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint(base, 0.25), base, base],
                stops: const [0, 0.35, 1],
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: w.small ? 10 : 14,
              vertical: w.small ? 6 : 10,
            ),
            child: w.expand ? Center(child: content) : content,
          ),
        ),
      ),
    );
  }
}

/// 카이로소프트풍 창 틀: 굵은 갈색 테두리 + 크림 바탕 + 왼쪽 위 제목 판 + 빨간 닫기 단추
class WindowBox extends StatelessWidget {
  final Widget child;
  final String? title;
  final Color titleColor;
  final VoidCallback? onClose;
  final Widget? trailing;
  final EdgeInsets padding;
  const WindowBox({
    super.key,
    required this.child,
    this.title,
    this.titleColor = C.accent,
    this.onClose,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.frame,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: const Color(0xFFFFFDF4),
            width: 2,
          ), // 안쪽 밝은 테
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Row(
                  children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: TitlePlate(title!, color: titleColor))),
                    if (trailing != null) trailing!,
                    if (onClose != null) ...[
                      const SizedBox(width: 6),
                      CloseBtn(onClose!),
                    ],
                  ],
                ),
              ),
            Flexible(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// 창 제목 판 (색 띠 + 흰 글씨 + 갈색 외곽선)
class TitlePlate extends StatelessWidget {
  final String text;
  final Color color;
  const TitlePlate(this.text, {super.key, this.color = C.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.frame, width: 2),
        boxShadow: [
          BoxShadow(color: shade(color, 0.4), offset: const Offset(0, 3)),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: kFont,
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: shade(color, 0.55), offset: const Offset(1, 1)),
          ],
        ),
      ),
    );
  }
}

/// 빨간 동그라미 닫기 단추
class CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const CloseBtn(this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: C.bad,
          shape: BoxShape.circle,
          border: Border.all(color: C.frame, width: 2),
          boxShadow: [
            BoxShadow(color: shade(C.bad, 0.45), offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 아래에서 올라오는 시트 틀 (제목 판 + 닫기 + 내용)
class SheetFrame extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double heightFactor;
  final Widget? trailing;
  final Color titleColor;
  const SheetFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.6,
    this.trailing,
    this.titleColor = C.accent,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final nav = navInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 0, 6, nav + 4),
      child: SizedBox(
        height: mq.size.height * heightFactor - nav,
        child: WindowBox(
          title: title,
          titleColor: titleColor,
          onClose: onClose,
          trailing: trailing,
          child: child,
        ),
      ),
    );
  }
}

/// 알림(토스트): 진한 갈색 말판 + 크림 글씨
final toastBox = BoxDecoration(
  color: const Color(0xF04A2F1A),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: C.coin, width: 2),
);
const toastText = TextStyle(fontFamily: kFont, color: C.onDark, fontSize: 13, fontWeight: FontWeight.w700);

/// 화면 아래 시스템 내비게이션 바(제스처 막대·3버튼)가 가리는 높이
double navInset(BuildContext context) {
  final m = MediaQuery.of(context);
  return m.viewPadding.bottom > m.padding.bottom
      ? m.viewPadding.bottom
      : m.padding.bottom;
}

/// 카드 배경: 창 안의 한 칸 (조금 진한 크림 + 얇은 테두리)
class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.line, width: 1.5),
      ),
      child: child,
    );
  }
}

/// 팝업이 뜬 직후 잠깐(Cfg.popupTapGuard) 탭을 막음: 다른 곳을 누르던 손가락이 팝업 버튼을 잘못 누르지 않게
class TapGuard extends StatefulWidget {
  final Widget child;
  const TapGuard({super.key, required this.child});

  @override
  State<TapGuard> createState() => _TapGuardState();
}

class _TapGuardState extends State<TapGuard> {
  bool ready = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: Cfg.popupTapGuard), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AbsorbPointer(absorbing: !ready, child: widget.child); // 막는 동안 탭이 아래 맵으로도 안 감
}
