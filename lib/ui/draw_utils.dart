import 'package:flutter/material.dart';

final Paint _fill = Paint();
final Paint _stroke = Paint()..style = PaintingStyle.stroke;

void box(Canvas c, double x, double y, double bw, double bh, int color) {
  _fill.color = Color(color);
  c.drawRect(Rect.fromLTWH(x, y, bw, bh), _fill);
}

void strokeBox(Canvas c, Rect r, int color, double width) {
  _stroke
    ..strokeWidth = width
    ..color = Color(color);
  c.drawRect(r, _stroke);
}

// 글자 레이아웃은 비싸서 같은 글자는 한 번만 계산해 재사용한다.
final Map<String, TextPainter> _tpCache = {};

TextPainter _painter(String text, double size, Color color, double maxWidth,
    bool center) {
  final key = '$text|$size|${color.value}|$maxWidth|$center';
  var tp = _tpCache[key];
  if (tp == null) {
    if (_tpCache.length > 600) _tpCache.clear();
    tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: 'Galmuri', color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      textAlign: center ? TextAlign.center : TextAlign.start,
      maxLines: center ? 2 : null,
    );
    if (center) {
      tp.layout(maxWidth: maxWidth);
    } else {
      tp.layout();
    }
    _tpCache[key] = tp;
  }
  return tp;
}

/// 글자 폭 (한 줄)
double textWidth(String text, double size) => _painter(text, size, Colors.white, 0, false).width;

void label(Canvas c, String text, double x, double y,
    {double size = 12, Color color = Colors.white}) {
  _painter(text, size, color, 0, false).paint(c, Offset(x, y));
}

/// 사각형 안 가운데에 글자
void labelIn(Canvas c, String text, Rect r,
    {double size = 12, Color color = Colors.white}) {
  final tp = _painter(text, size, color, r.width, true);
  tp.paint(c,
      Offset(r.left + (r.width - tp.width) / 2, r.top + (r.height - tp.height) / 2));
}

void btn(Canvas c, Rect r, String text, int color,
    {double size = 14, Color textColor = Colors.white}) {
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
      Paint()..color = Color(color));
  labelIn(c, text, r, size: size, color: textColor);
}