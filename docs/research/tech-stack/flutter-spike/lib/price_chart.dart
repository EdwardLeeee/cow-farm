// 疊在牧場上面的 Flutter 折線圖（CustomPainter），模擬正式版的牛奶收購價走勢。
// 資料是隨機漫步的假價格，每 100 ms 加一點（每秒更新 10 次）。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 隨機漫步的價格序列，保留最近 [capacity] 點。
class PriceSeries extends ChangeNotifier {
  PriceSeries({this.capacity = 120, int seed = 7}) : _random = math.Random(seed);

  final int capacity;
  final math.Random _random;
  final List<double> _values = <double>[100];

  List<double> get values => _values;
  double get last => _values.last;

  /// 走一步：小幅隨機變動，並慢慢拉回 100（像行情會回到基本價）。
  void step() {
    final double drift = (100 - last) * 0.03;
    final double shock = (_random.nextDouble() - 0.5) * 2.6;
    _values.add((last + drift + shock).clamp(40.0, 160.0));
    if (_values.length > capacity) _values.removeAt(0);
    notifyListeners();
  }

  void reset() {
    _values
      ..clear()
      ..add(100);
    notifyListeners();
  }
}

class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.series});

  final PriceSeries series;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: PriceChartPainter(series),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class PriceChartPainter extends CustomPainter {
  PriceChartPainter(this.series) : super(repaint: series);

  final PriceSeries series;

  static final Paint _card = Paint()..color = const Color(0xE6FFFFFF);
  static final Paint _grid = Paint()
    ..color = const Color(0x22000000)
    ..strokeWidth = 1;
  static final Paint _line = Paint()
    ..color = const Color(0xFFE67E22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round;
  static final Paint _dot = Paint()..color = const Color(0xFFE67E22);

  @override
  void paint(Canvas canvas, Size size) {
    final RRect card = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(card, _card);

    final List<double> values = series.values;
    final double last = values.last;
    final double change = values.length > 1 ? last - values[values.length - 2] : 0;

    final TextPainter title = TextPainter(
      text: const TextSpan(
        text: '牛奶收購價（測試用假資料）',
        style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    title.paint(canvas, const Offset(12, 8));
    final TextPainter price = TextPainter(
      text: TextSpan(
        text: '${last.toStringAsFixed(1)}  ${change >= 0 ? '▲' : '▼'}${change.abs().toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: change >= 0 ? const Color(0xFFC0392B) : const Color(0xFF1E8449),
          fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    price.paint(canvas, Offset(size.width - price.width - 12, 7));
    title.dispose();
    price.dispose();

    final Rect plot = Rect.fromLTRB(12, 32, size.width - 12, size.height - 10);
    for (int i = 0; i <= 3; i++) {
      final double y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), _grid);
    }
    if (values.length < 2) return;

    double lo = values.first;
    double hi = values.first;
    for (final double v in values) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final double span = math.max(hi - lo, 1);
    final double dx = plot.width / (series.capacity - 1);
    final double startX = plot.right - dx * (values.length - 1);
    Offset point(int i) =>
        Offset(startX + dx * i, plot.bottom - (values[i] - lo) / span * plot.height);

    final Path line = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < values.length; i++) {
      final Offset p = point(i);
      line.lineTo(p.dx, p.dy);
    }
    final Path fill = Path.from(line)
      ..lineTo(point(values.length - 1).dx, plot.bottom)
      ..lineTo(startX, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          plot.topCenter,
          plot.bottomCenter,
          const <Color>[Color(0x55E67E22), Color(0x00E67E22)],
        ),
    );
    canvas.drawPath(line, _line);
    canvas.drawCircle(point(values.length - 1), 3.5, _dot);
  }

  @override
  bool shouldRepaint(PriceChartPainter oldDelegate) => oldDelegate.series != series;
}
