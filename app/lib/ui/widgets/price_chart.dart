import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../format.dart';
import '../palette.dart';

/// 折線圖（CustomPainter）。線的顏色：這段期間漲是紅、跌是綠。
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, this.height = 160});
  final List<PricePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(height: height, child: const Center(child: Text(S.noChart)));
    }
    final lo = points.map((p) => p.price).reduce(min);
    final hi = points.map((p) => p.price).reduce(max);
    final color = Palette.change(points.last.price - points.first.price);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [Text(fmtNum(hi, 2), style: const TextStyle(fontSize: 11)), Text(fmtNum(lo, 2), style: const TextStyle(fontSize: 11))],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: CustomPaint(painter: PriceChartPainter(points, lo, hi, color)),
          ),
        ],
      ),
    );
  }
}

class PriceChartPainter extends CustomPainter {
  PriceChartPainter(this.points, this.lo, this.hi, this.color);
  final List<PricePoint> points;
  final double lo;
  final double hi;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Palette.card;
    canvas.drawRect(Offset.zero & size, bg);
    final t0 = points.first.t, t1 = points.last.t;
    final spanT = (t1 - t0).abs() < 1e-9 ? 1.0 : t1 - t0;
    final spanP = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.t - t0) / spanT * size.width;
      final y = size.height - (p.price - lo) / spanP * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(PriceChartPainter old) =>
      old.points != points || old.lo != lo || old.hi != hi || old.color != color;
}
