import 'package:flutter/material.dart';

void box(Canvas c, double x, double y, double bw, double bh, int color) {
  c.drawRect(Rect.fromLTWH(x, y, bw, bh), Paint()..color = Color(color));
}

void strokeBox(Canvas c, Rect r, int color, double width) {
  c.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = Color(color));
}

void label(Canvas c, String text, double x, double y,
    {double size = 12, Color color = Colors.white}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, Offset(x, y));
}

/// 사각형 안 가운데에 글자
void labelIn(Canvas c, String text, Rect r,
    {double size = 12, Color color = Colors.white}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
  )..layout(maxWidth: r.width);
  tp.paint(c,
      Offset(r.left + (r.width - tp.width) / 2, r.top + (r.height - tp.height) / 2));
}

void btn(Canvas c, Rect r, String text, int color,
    {double size = 14, Color textColor = Colors.white}) {
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
      Paint()..color = Color(color));
  labelIn(c, text, r, size: size, color: textColor);
}