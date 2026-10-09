// S17 的田地場景（設計稿 s17.js 的 fieldScene）：天空、太陽、山坡、草地，最多 4 塊水田。有牛的田是水藍色，稻子依長滿的
// 比例長高、長滿變金黃（穗往下垂），牛站在田前面（側面、朝右，牛的圖跟牧場場景一樣用 cow-ui 匯出的 SVG）；空田是土色加三條犁溝。
// 每塊田上面一個白底的田號。高 150，寬度是卡片裡面的寬（設計稿 w − 6）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';

/// 場景的高。
const kFieldSceneHeight = 150.0;

/// 場景裡的一塊田：田號、在這裡工作的耕牛（空田 null）、稻米 ÷ 上限。
class FieldPlot {
  const FieldPlot({required this.number, this.cow, this.ratio = 0});

  final int number;
  final Cow? cow;
  final double ratio;
}

/// 一塊田在場景裡的位置（設計稿：左右各留 8、田之間 8；不到 3 塊也照 3 等分排）。
class _PlotBox {
  _PlotBox(double w, int i, int n) {
    final pw = (w - 16) / math.max(n, 3);
    x0 = 8 + pw * i + 4;
    x1 = x0 + pw - 8;
  }

  late final double x0;
  late final double x1;
  static const yt = 80.0;
  static const yb = kFieldSceneHeight - 10;

  double get cx => (x0 + x1) / 2;

  /// 牛的腳底：田寬的 3 成處、田的下緣往下 4。
  Offset get feet => Offset(x0 + (x1 - x0) * 0.3, yb + 4);
}

/// 一頭在田裡的牛畫在場景上的位置：圖（朝右；沒有自己畫的朝右圖就把朝左的翻過來）和影子。
class _CowSpot {
  _CowSpot(this.name, this.mirror, this.image, this.shadow);

  final String name;
  final bool mirror;
  final Rect image;
  final Rect shadow;

  /// 設計稿 drawCow 的 scale 0.4（匯出的 SVG 一單位 = 場景一點 × 0.4）。
  static const scale = 0.4;

  static _CowSpot? of(Cow cow, _PlotBox box) {
    final art = CowArt.instance;
    if (art == null) return null;
    final (name, mirror) = art.pick(
      breed: cow.look,
      bull: cow.bull,
      calf: cow.stage == CowStage.calf,
      front: false,
      right: true,
      variant: cow.number,
    );
    final m = art.meta(name);
    if (m == null) return null;
    const s = scale;
    final feet = box.feet;
    // 圖的原點在腳底；左右翻的時候以腳底為軸
    final left = mirror ? feet.dx - (m.x0 + m.w) * s : feet.dx + m.x0 * s;
    final image = Rect.fromLTWH(left, feet.dy + m.y0 * s, m.w * s, m.h * s);
    final (cx, rx, ry) = m.shadow;
    // 影子在田的下緣往上 1（設計稿 cy = yb − 1），不是腳底
    final shadow = Rect.fromCenter(
      center: Offset(feet.dx + (mirror ? -cx : cx) * s, _PlotBox.yb - 1),
      width: rx * 2 * s,
      height: ry * 2 * s,
    );
    return _CowSpot(name, mirror, image, shadow);
  }
}

/// 田地場景：背景、田、稻子、影子用 CustomPainter 畫；牛疊在上面；田號最後畫（蓋在牛上面）。
class FieldScene extends StatelessWidget {
  const FieldScene({super.key, required this.plots});

  /// 全部的田；場景只畫前 4 塊。
  final List<FieldPlot> plots;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final shown = plots.take(4).toList();
      final boxes = [for (var i = 0; i < shown.length; i++) _PlotBox(w, i, shown.length)];
      final spots = [
        for (var i = 0; i < shown.length; i++) shown[i].cow == null ? null : _CowSpot.of(shown[i].cow!, boxes[i]),
      ];
      return SizedBox(
        width: w,
        height: kFieldSceneHeight,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _ScenePainter(shown, boxes, spots))),
              for (final spot in spots)
                if (spot != null)
                  Positioned.fromRect(
                    rect: spot.image,
                    child: Transform.flip(
                      flipX: spot.mirror,
                      child: SvgPicture.asset('assets/cows/svg/${spot.name}.svg', fit: BoxFit.fill),
                    ),
                  ),
              Positioned.fill(child: CustomPaint(painter: _TagPainter(shown, boxes))),
            ],
          ),
        ),
      );
    },
  );
}

const _line = AppColors.ink;

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt, StrokeJoin join = StrokeJoin.miter}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = join;

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.plots, this.boxes, this.spots);

  final List<FieldPlot> plots;
  final List<_PlotBox> boxes;
  final List<_CowSpot?> spots;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const h = kFieldSceneHeight;
    // 天空（上 #94D3FF → 下 #E4F6FF）、太陽
    final sky = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF94D3FF), Color(0xFFE4F6FF)],
        ).createShader(sky),
    );
    canvas.drawCircle(Offset(w - 34, 26), 12, _fill(const Color(0xFFFFE58A)));
    canvas.drawCircle(Offset(w - 34, 26), 12, _stroke(_line, 2.2));
    // 遠山
    final hills = Path()
      ..moveTo(-10, 64)
      ..cubicTo(w * 0.2, 44, w * 0.45, 48, w * 0.6, 60)
      ..cubicTo(w * 0.75, 46, w * 0.9, 44, w + 10, 58)
      ..lineTo(w + 10, 90)
      ..lineTo(-10, 90)
      ..close();
    canvas.drawPath(hills, _fill(const Color(0xFFC6ECAB)));
    canvas.drawPath(hills, _stroke(const Color(0xFF8CC77E), 2.2));
    // 草地（下緣超出場景）
    final ground = Rect.fromLTWH(-4, 70, w + 8, h);
    canvas.drawRect(ground, _fill(const Color(0xFFAEE594)));
    canvas.drawRect(ground, _stroke(_line, 2.6));

    for (var i = 0; i < plots.length; i++) {
      final p = plots[i], b = boxes[i];
      final x0 = b.x0, x1 = b.x1;
      const yt = _PlotBox.yt, yb = _PlotBox.yb;
      final plot = Path()
        ..moveTo(x0 + 6, yt)
        ..lineTo(x1 - 6, yt)
        ..lineTo(x1, yb)
        ..lineTo(x0, yb)
        ..close();
      canvas.drawPath(plot, _fill(p.cow != null ? const Color(0xFF9CC9E8) : const Color(0xFFC99A6B)));
      canvas.drawPath(plot, _stroke(_line, 2.4, join: StrokeJoin.round));
      if (p.cow != null) {
        // 水面的反光
        canvas.drawLine(
          Offset(x0 + 12, yt + 8),
          Offset(x0 + 12 + (x1 - x0) * 0.3, yt + 8),
          _stroke(Colors.white.withValues(alpha: 0.8), 2, cap: StrokeCap.round),
        );
        _rice(canvas, b, p.ratio);
        final spot = spots[i];
        if (spot != null) {
          canvas.drawOval(spot.shadow, _fill(const Color(0xFF6FA7C9).withValues(alpha: 0.6)));
        }
      } else {
        // 犁溝
        for (var r = 0; r < 3; r++) {
          canvas.drawLine(
            Offset(x0 + 8 + r * 2, yt + 18 + r * 18),
            Offset(x1 - 8 - r * 2, yt + 18 + r * 18),
            _stroke(const Color(0xFFB0804F), 2.4, cap: StrokeCap.round),
          );
        }
      }
    }
  }

  /// 稻子：4 排 × 7 叢，一叢三片葉；越前面的排越大。依長滿的比例長高（7 → 24），長滿變金黃、中間那片往右垂、加一顆穗。
  void _rice(Canvas canvas, _PlotBox b, double ratio) {
    final ripe = ratio >= 1;
    final hh = 7 + 17 * math.min(1.0, math.max(0.0, ratio));
    final col = ripe ? const Color(0xFFE0AE3C) : const Color(0xFF6DBB55);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 7; c++) {
        final t = (c + 0.5 + (r % 2) * 0.5) / 7.5;
        final y = _PlotBox.yt + 14 + r * 14;
        final xl = b.x0 + 4 + r * 1.5, xr = b.x1 - 4 - r * 1.5;
        final x = xl + (xr - xl) * t;
        final k = 0.75 + r * 0.1;
        final leaves = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x - 3 * k, y - hh * 0.5 * k, x - 5 * k, y - hh * 0.8 * k)
          ..moveTo(x, y)
          ..quadraticBezierTo(x, y - hh * 0.6 * k, x + (ripe ? 2 : 0), y - hh * k)
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 3 * k, y - hh * 0.5 * k, x + 5 * k, y - hh * 0.8 * k);
        canvas.drawPath(leaves, _stroke(col, 1.8 * k, cap: StrokeCap.round));
        if (ripe) {
          final center = Offset(x + 3 * k, y - hh * k + 3);
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(35 * math.pi / 180);
          final grain = Rect.fromCenter(center: Offset.zero, width: 4.8 * k, height: 3 * k);
          canvas.drawOval(grain, _fill(const Color(0xFFFFD35C)));
          canvas.drawOval(grain, _stroke(_line, 0.8));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}

/// 田號：白底圓角方塊（24 × 18）、粗體 12px 的數字，基線在田的上緣往下 1。
class _TagPainter extends CustomPainter {
  _TagPainter(this.plots, this.boxes);

  final List<FieldPlot> plots;
  final List<_PlotBox> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < plots.length; i++) {
      final cx = boxes[i].cx;
      const yt = _PlotBox.yt;
      final tag = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 12, yt - 13, 24, 18), const Radius.circular(6));
      canvas.drawRRect(tag, _fill(Colors.white));
      canvas.drawRRect(tag, _stroke(_line, 2));
      final text = TextPainter(
        text: TextSpan(
          text: '${plots[i].number}',
          style: AppText.style(12, weight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final baseline = text.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      text.paint(canvas, Offset(cx - text.width / 2, yt + 1 - baseline));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_TagPainter old) => true;
}
