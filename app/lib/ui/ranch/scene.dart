// 牧場場景（設計稿 design/m2/src/js/scene.js 的 ranchScene）：背景是 cow-ui 匯出的 assets/ui/scenes/ranch.svg
// （兩個螢幕寬 780×844，不含牛），照 fit() 等比例放大、置中裁切（cover）；牛畫在 Flame 裡（ranch_game.dart），
// 腳底對準位置，後面的先畫，會走動（A-11）、轉身（A-07）。手指可以左右拖動（不滑行，A-12 的慣性在第 6 步）。
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/models.dart';
import '../kit/cow_art.dart';
import 'herd.dart';
import 'ranch_game.dart';

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

  /// [dx]：往右走出去多遠（場景座標，牛走動時；往左是負的）。
  static CowPlacement? of(SceneCow c, SceneFit fit, {double dx = 0}) {
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
    final feet = fit.map(c.slot.x + dx, c.slot.y);
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

/// 牧場的牛會不會走動、轉身（A-11、A-07）。app 打開時是開的（main.dart）；沒有包這個的時候（測試）關著，牛站在原位，
/// 跟靜態的設計稿一樣。手機設定了「減少動態」也一樣關著。
class HerdMotion extends InheritedWidget {
  const HerdMotion({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<HerdMotion>()?.enabled ?? false) &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  bool updateShouldNotify(HerdMotion oldWidget) => oldWidget.enabled != enabled;
}

/// 牧場場景：背景加上牛。[onPan] 給了就可以左右拖動（拖動時回報新的 pan）。
/// [game] 是畫牛的 Flame 遊戲：牧場頁自己留著，泡泡和小名片才知道停下來的牛在哪裡。
class RanchScene extends StatefulWidget {
  const RanchScene({
    super.key,
    required this.cows,
    required this.pan,
    this.game,
    this.onPan,
    this.onTapCow,
    this.onTapEmpty,
  });

  final List<SceneCow> cows;
  final double pan;
  final RanchGame? game;
  final ValueChanged<double>? onPan;
  final ValueChanged<Cow>? onTapCow;

  /// 點到場景的空地（不是牛）。
  final VoidCallback? onTapEmpty;

  /// 後面（上面）的先畫，同一排從左到右（scene.js：依 depth、y 排序）。
  static List<SceneCow> paintOrder(List<SceneCow> cows) =>
      [...cows]..sort((a, b) => a.slot.y != b.slot.y ? a.slot.y.compareTo(b.slot.y) : a.slot.x.compareTo(b.slot.x));

  @override
  State<RanchScene> createState() => _RanchSceneState();
}

class _RanchSceneState extends State<RanchScene> {
  RanchGame? _own;

  RanchGame get _game => widget.game ?? (_own ??= RanchGame());

  @override
  Widget build(BuildContext context) {
    final animate = HerdMotion.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final fit = SceneFit(c.biggest, widget.pan);
        final game = _game..configure(widget.cows, fit, dpr, animate: animate);
        final scene = ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: fit.ox - widget.pan * fit.k,
                top: fit.oy,
                width: kSceneWidth * fit.k,
                height: kScreenHeight * fit.k,
                child: SvgPicture.asset('assets/ui/scenes/ranch.svg', fit: BoxFit.fill, excludeFromSemantics: true),
              ),
              Positioned.fill(child: GameWidget(game: game)),
            ],
          ),
        );
        final onTapCow = widget.onTapCow, onTapEmpty = widget.onTapEmpty, onPan = widget.onPan;
        if (onPan == null && onTapCow == null && onTapEmpty == null) return scene;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 點到牛（現在的位置，前面的優先）就是點牛，不然是點空地
          onTapUp: onTapCow == null && onTapEmpty == null
              ? null
              : (d) {
                  final cow = game.cowAt(d.localPosition);
                  if (cow != null && onTapCow != null) {
                    onTapCow(cow);
                  } else if (cow == null) {
                    onTapEmpty?.call();
                  }
                },
          onHorizontalDragUpdate: onPan == null
              ? null
              : (d) => onPan((widget.pan - d.delta.dx / fit.k).clamp(0.0, kMaxPan)),
          child: scene,
        );
      },
    );
  }
}
