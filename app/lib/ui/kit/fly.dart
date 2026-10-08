// 飛的圖示（設計稿 anims.js 的 arc／place）：A-02 金幣飛進頂列、A-08 稻穗飛進倉庫。
// 每個圖示晚一點起飛，沿拋物線從起點飛到終點；位置、大小、角度都只看動畫的時間 t（秒），可以停在任何一格截圖。
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 設計稿的小工具：t 在 a–b 之間走了幾成（0–1）、outCubic、inOut、outBack（超過一點再彈回來）。
double animSeg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double animOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
double animInOut(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
double animOutBack(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
}

/// 一組飛的圖示。第 i 個在 [start] + i × [stagger] 起飛、飛 [dur] 秒；位置照 outCubic 沿拋物線（高 [lift]）從
/// [from](i) 飛到 [to]，[scale]、[angle]（度）看飛了幾成 k。飛之前、飛完都看不見。
class FlyIcons extends StatelessWidget {
  const FlyIcons({
    super.key,
    required this.t,
    required this.count,
    required this.from,
    required this.to,
    required this.icon,
    required this.size,
    required this.start,
    required this.dur,
    required this.stagger,
    required this.lift,
    this.scale,
    this.angle,
    this.keyPrefix = 'fly',
  });

  final double t;
  final int count;
  final Offset Function(int i) from;
  final Offset to;
  final Widget icon;

  /// 圖示的大小（定位用：圖示的中心在拋物線上）。
  final double size;
  final double start;
  final double dur;
  final double stagger;
  final double lift;
  final double Function(double k)? scale;
  final double Function(double k)? angle;

  /// 每個圖示的 key：`'$keyPrefix-$i'`（測試找得到）。
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (var i = 0; i < count; i++)
        if (animSeg(t, start + i * stagger, start + i * stagger + dur) case final k when k > 0 && k < 1)
          Builder(
            key: Key('$keyPrefix-$i'),
            builder: (context) {
              final a = from(i), e = animOutCubic(k);
              final x = a.dx + (to.dx - a.dx) * e, y = a.dy + (to.dy - a.dy) * e - math.sin(math.pi * e) * lift;
              return Positioned(
                left: x - size / 2,
                top: y - size / 2,
                child: Transform.rotate(
                  angle: (angle?.call(k) ?? 0) * math.pi / 180,
                  child: Transform.scale(scale: scale?.call(k) ?? 1, child: icon),
                ),
              );
            },
          ),
    ],
  );
}

/// [box] 的某一點在 [layer] 裡的位置（兩個都要已經排好版面）。
Offset? flyPoint(RenderBox? layer, RenderBox? box, Offset Function(Size size) at) {
  if (layer == null || box == null || !layer.hasSize || !box.hasSize) return null;
  return layer.globalToLocal(box.localToGlobal(at(box.size)));
}
