// 牧場場景（設計稿 design/m2/src/js/scene.js 的 ranchScene）：背景是 cow-ui 匯出的 assets/ui/scenes/ranch.svg
// （兩個螢幕寬 780×844，不含牛），照 fit() 等比例放大、置中裁切（cover）；牛一頭一頭疊上去，腳底對準位置，後面的先畫。
// 這一版是靜態場景：手指可以左右拖動（不滑行，A-12 的慣性在第 6 步），牛不會走動（A-11 在第 5 步換成 Flame）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import 'herd.dart';

/// 場景的寬度：兩個螢幕寬（scene.js 的 WIDE）。一個螢幕 390×844。
const kSceneWidth = 780.0;
const kScreenWidth = 390.0;
const kScreenHeight = 844.0;

/// 最多往右捲多少（場景座標）。
const kMaxPan = kSceneWidth - kScreenWidth;

/// 設計稿畫牛時的整體放大（scene.js 的 SCENE_SCALE）。
const _sceneScale = 1.04;

/// 場景座標 → 螢幕座標（scene.js 的 fit）：k = max(w/390, h/844)，置中裁切；[pan] 是往右捲了多少（場景座標）。
class SceneFit {
  SceneFit(Size size, this.pan) : k = math.max(size.width / kScreenWidth, size.height / kScreenHeight) {
    ox = (size.width - kScreenWidth * k) / 2;
    oy = (size.height - kScreenHeight * k) / 2;
  }

  final double pan;
  final double k;
  late final double ox;
  late final double oy;

  Offset map(double x, double y) => Offset((x - pan) * k + ox, y * k + oy);
}

/// 場景裡的一頭牛。[front]：轉正面（奶桶滿了的產奶牛、被點到的牛；D11）。
class SceneCow {
  const SceneCow(this.cow, this.slot, {this.front = false});
  final Cow cow;
  final HerdSlot slot;
  final bool front;
}

/// 一頭牛畫在螢幕上的位置：圖、影子、頭頂（泡泡和小名片對齊這裡）。
class CowPlacement {
  CowPlacement._(this.name, this.mirror, this.image, this.shadow, this.head, this.foot, this.unit);

  final String name;
  final bool mirror;
  final Rect image;
  final Rect shadow;
  final Offset head;

  /// 腳底（設計稿 scene.js 的 anchors.foot）：名片放到牛的下面時從這裡往下量（D30）。
  final Offset foot;

  /// 圖上的 1 單位是螢幕上的幾點。
  final double unit;

  static CowPlacement? of(SceneCow c, SceneFit fit) {
    final art = CowArt.instance;
    if (art == null) return null;
    final cow = c.cow;
    final id = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    final (name, mirror) = art.pick(
      breed: cow.breed,
      bull: cow.bull,
      calf: cow.stage == CowStage.calf,
      front: c.front,
      right: c.slot.right,
      variant: id,
    );
    final m = art.meta(name);
    if (m == null) return null;
    final s = c.slot.scale * _sceneScale * fit.k;
    final feet = fit.map(c.slot.x, c.slot.y);
    // 圖的原點在腳底；左右翻的時候以腳底為軸
    final left = mirror ? feet.dx - (m.x0 + m.w) * s : feet.dx + m.x0 * s;
    final image = Rect.fromLTWH(left, feet.dy + m.y0 * s, m.w * s, m.h * s);
    final (cx, rx, ry) = m.shadow;
    final shadowCenter = Offset(feet.dx + (mirror ? -cx : cx) * s, feet.dy + 1 * fit.k);
    final shadow = Rect.fromCenter(center: shadowCenter, width: rx * 2 * s, height: ry * 2 * s);
    final head = Offset(feet.dx + (mirror ? -m.headTop.dx : m.headTop.dx) * s, feet.dy + m.headTop.dy * s);
    return CowPlacement._(name, mirror, image, shadow, head, feet, s);
  }
}

/// 牧場場景：背景加上牛。[onPan] 給了就可以左右拖動（拖動時回報新的 pan）。
class RanchScene extends StatelessWidget {
  const RanchScene({super.key, required this.cows, required this.pan, this.onPan, this.onTapCow, this.onTapEmpty});

  final List<SceneCow> cows;
  final double pan;
  final ValueChanged<double>? onPan;
  final ValueChanged<Cow>? onTapCow;

  /// 點到場景的空地（不是牛）。
  final VoidCallback? onTapEmpty;

  /// 後面（上面）的先畫，同一排從左到右（scene.js：依 depth、y 排序）。
  static List<SceneCow> paintOrder(List<SceneCow> cows) =>
      [...cows]..sort((a, b) => a.slot.y != b.slot.y ? a.slot.y.compareTo(b.slot.y) : a.slot.x.compareTo(b.slot.x));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final fit = SceneFit(c.biggest, pan);
        final scene = ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: fit.ox - pan * fit.k,
                top: fit.oy,
                width: kSceneWidth * fit.k,
                height: kScreenHeight * fit.k,
                child: SvgPicture.asset('assets/ui/scenes/ranch.svg', fit: BoxFit.fill, excludeFromSemantics: true),
              ),
              for (final cow in paintOrder(cows)) ..._cowLayers(cow, fit),
            ],
          ),
        );
        if (onPan == null && onTapEmpty == null) return scene;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapEmpty,
          onHorizontalDragUpdate: onPan == null ? null : (d) => onPan!((pan - d.delta.dx / fit.k).clamp(0.0, kMaxPan)),
          child: scene,
        );
      },
    );
  }

  List<Widget> _cowLayers(SceneCow c, SceneFit fit) {
    final p = CowPlacement.of(c, fit);
    if (p == null) return const [];
    Widget pic = SvgPicture.asset(
      'assets/cows/svg/${p.name}.svg',
      width: p.image.width,
      height: p.image.height,
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
    if (p.mirror) pic = Transform.flip(flipX: true, child: pic);
    final legend = breedInfo(c.cow.breed)?.tier == 3;
    return [
      Positioned.fromRect(
        rect: p.shadow,
        child: const DecoratedBox(
          decoration: ShapeDecoration(color: Color(0xFF86CC70), shape: OvalBorder()),
        ),
      ),
      Positioned.fromRect(
        rect: p.image,
        child: onTapCow == null
            ? pic
            : GestureDetector(key: Key('scene-cow-${c.cow.id}'), onTap: () => onTapCow!(c.cow), child: pic),
      ),
      if (legend)
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _Sparkles(p.head, p.unit / fit.k, fit.k))),
        ),
    ];
  }
}

/// 傳說品種頭上的兩顆星星（scene.js 的 sparkle）：右上大的、左上小的。
class _Sparkles extends CustomPainter {
  _Sparkles(this.head, this.s, this.k);

  final Offset head;
  final double s; // 設計稿的 SCALE × 1.04
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    void star(Offset c, double r) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFE27A));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * k
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.ink,
      );
    }

    // sparkle(hx + 24s, hy + 8, 5.5s)、sparkle(hx − 22s, hy + 16, 3.6s)：位移 8、16 是場景座標，不跟著牛縮放
    star(head + Offset(24 * s * k, 8 * k), 5.5 * s * k);
    star(head + Offset(-22 * s * k, 16 * k), 3.6 * s * k);
  }

  @override
  bool shouldRepaint(_Sparkles old) => old.head != head || old.s != s || old.k != k;
}
