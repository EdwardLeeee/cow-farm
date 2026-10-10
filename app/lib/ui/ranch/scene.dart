// 牧場場景（設計稿 design/m2/src/js/scene.js 的 ranchScene）：背景是 cow-ui 匯出的 assets/ui/scenes/ranch.svg
// （兩個螢幕寬 780×844，不含牛），照 fit() 等比例放大、置中裁切（cover）；牛畫在 Flame 裡（ranch_game.dart），
// 腳底對準位置，後面的先畫，會走動（A-11）、轉身（A-07）。手指可以左右拖動（不滑行，A-12 的慣性在第 6 步）。
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../kit/cow_art.dart';
import '../kit/motion.dart';
import 'herd.dart';
import 'poop.dart';
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

/// 場景裡的一頭牛。[front]：轉正面（奶桶滿了的產奶牛、被點到的牛；D11；病牛一律正面，v0.3 第 5 節）。
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
      breed: cow.look,
      bull: cow.bull,
      calf: cow.stage == CowStage.calf,
      front: c.front,
      right: c.slot.right,
      variant: id,
      sick: cow.sick,
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

/// 牧場場景：背景加上牛。[onPan] 給了就可以左右拖動（拖動時回報新的 pan）。
/// [game] 是畫牛的 Flame 遊戲：牧場頁自己留著，泡泡和小名片才知道停下來的牛在哪裡。
class RanchScene extends StatefulWidget {
  const RanchScene({
    super.key,
    required this.cows,
    required this.pan,
    this.game,
    this.onPan,
    this.onPanStart,
    this.onPanEnd,
    this.onTapCow,
    this.onTapEmpty,
    this.poops = const [],
    this.onTapPoop,
    this.onSwipePoop,
    this.onSwipeEnd,
    this.poopFx = const [],
    this.onPoopFxCount,
    this.onPoopFxDone,
  });

  final List<SceneCow> cows;
  final double pan;
  final RanchGame? game;
  final ValueChanged<double>? onPan;

  /// 手指按下開始拖（A-12：停掉還在滑的場景）。
  final VoidCallback? onPanStart;

  /// 手指放開：場景座標每秒往右捲多少（A-12 照這個速度再滑一小段）。
  final ValueChanged<double>? onPanEnd;
  final ValueChanged<Cow>? onTapCow;

  /// 點到場景的空地（不是牛）。
  final VoidCallback? onTapEmpty;

  /// 場景裡的大便（v0.3 第 5 節）：畫在牛的上面（設計稿把大便放在牛後面才畫）。
  final List<ScenePoop> poops;

  /// 點到一坨大便（A-14）。比點牛優先。
  final ValueChanged<ScenePoop>? onTapPoop;

  /// 手指從一坨大便上開始劃（A-15）：劃過的每一坨各叫一次；手指放開叫 [onSwipeEnd]。從別的地方開始劃是拖動場景。
  final ValueChanged<ScenePoop>? onSwipePoop;
  final VoidCallback? onSwipeEnd;

  /// 點一下清掉、還在播 A-14 的那幾坨（[PoopCleanFx]，跟著場景捲）：第 0.3 秒叫 [onPoopFxCount]，播完叫 [onPoopFxDone]。
  final List<PoopFx> poopFx;
  final ValueChanged<PoopFx>? onPoopFxCount;
  final ValueChanged<PoopFx>? onPoopFxDone;

  /// 後面（上面）的先畫，同一排從左到右（scene.js：依 depth、y 排序）。
  static List<SceneCow> paintOrder(List<SceneCow> cows) =>
      [...cows]..sort((a, b) => a.slot.y != b.slot.y ? a.slot.y.compareTo(b.slot.y) : a.slot.x.compareTo(b.slot.x));

  @override
  State<RanchScene> createState() => _RanchSceneState();
}

class _RanchSceneState extends State<RanchScene> with SingleTickerProviderStateMixin {
  RanchGame? _own;

  /// A-15 手指劃過去的軌跡：劃的時候跟著手指，放開以後 0.3 秒內淡掉（開著動畫才畫）。
  final _trail = _SwipeTrail();
  late final AnimationController _trailFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(() => _trail.fade(_trailFade.value * 0.3));

  @override
  void dispose() {
    _trailFade.dispose();
    _trail.dispose();
    super.dispose();
  }

  RanchGame get _game => widget.game ?? (_own ??= RanchGame());

  /// 手指按下的地方（拖動開始時看是不是按在大便上）。
  Offset? _down;

  /// 這一次是劃過去清大便（不是拖動場景）；[_last] 是上一次手指的位置。
  bool _sweeping = false;
  Offset? _last;

  /// 一坨大便畫在螢幕上的範圍。
  static Rect _poopRect(ScenePoop p, SceneFit fit) => _spotRect(p.spot, fit);

  /// 第 [spot] 個位置的大便畫在螢幕上的範圍。
  static Rect _spotRect(int spot, SceneFit fit) {
    final r = poopRect(kPoopSpots[spot]);
    final tl = fit.map(r.left, r.top);
    return Rect.fromLTWH(tl.dx, tl.dy, r.width * fit.k, r.height * fit.k);
  }

  /// [point] 上的那坨大便：離大便中間 22 點以內（點得到的範圍 44 點）算點到，最近的那坨。
  ScenePoop? _poopAt(Offset point, SceneFit fit) {
    ScenePoop? best;
    var bestD = double.infinity;
    for (final p in widget.poops) {
      final d = (_poopRect(p, fit).center - point).distance;
      if (d <= math.max(22, 22 * fit.k) && d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  /// 劃過去：從 [from] 到 [to] 每 6 點看一次，經過的大便各清一次（手指移得快也不會漏掉）。
  void _sweep(Offset from, Offset to, SceneFit fit) {
    final steps = math.max(1, ((to - from).distance / 6).ceil());
    final hit = <int>{};
    for (var i = 1; i <= steps; i++) {
      final p = _poopAt(Offset.lerp(from, to, i / steps)!, fit);
      if (p != null && hit.add(p.spot)) widget.onSwipePoop?.call(p);
    }
  }

  /// 手指放開：軌跡 0.05 秒以後開始淡掉（設計稿 A15：0.85 秒放開、0.9–1.15 秒淡掉）。
  void _endTrail() {
    if (_trail.points.isNotEmpty) _trailFade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final animate = AppMotion.of(context);
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
              // 大便（底部中間對準位置、寬 19；跟著場景捲）
              for (final p in widget.poops)
                Positioned.fromRect(
                  key: ValueKey('poop-${p.spot}'),
                  rect: _poopRect(p, fit),
                  child: SvgPicture.asset('assets/ui/icons/poop.svg', fit: BoxFit.fill, excludeFromSemantics: true),
                ),
              // A-14：點掉的那一坨淡掉、波紋、小星星（中心在大便底部中間往上 8，設計稿的 poopAt）
              for (final f in widget.poopFx)
                Positioned.fill(
                  key: ValueKey('poop-fx-${f.id}'),
                  child: IgnorePointer(
                    child: PoopCleanFx(
                      poop: _spotRect(f.spot, fit),
                      origin: fit.map(kPoopSpots[f.spot].dx, kPoopSpots[f.spot].dy) - const Offset(0, 8),
                      swipe: f.swipe,
                      onCount: () => widget.onPoopFxCount?.call(f),
                      onDone: () => widget.onPoopFxDone?.call(f),
                    ),
                  ),
                ),
              // A-15：手指劃過的地方留一道白色的軌跡（設計稿 .swipe-trail，畫在大便和星星上面）
              if (animate)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(key: const Key('swipe-trail'), painter: _TrailPainter(_trail)),
                  ),
                ),
            ],
          ),
        );
        final onTapCow = widget.onTapCow, onTapEmpty = widget.onTapEmpty, onPan = widget.onPan;
        final onPanStart = widget.onPanStart, onPanEnd = widget.onPanEnd;
        final onTapPoop = widget.onTapPoop, onSwipePoop = widget.onSwipePoop;
        if (onPan == null && onTapCow == null && onTapEmpty == null && onTapPoop == null && onSwipePoop == null) {
          return scene;
        }
        return Listener(
          onPointerDown: (e) => _down = e.localPosition,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 點到大便就清掉那一坨；點到牛（現在的位置，前面的優先）就是點牛，不然是點空地
            onTapUp: (d) {
              if (onTapPoop != null) {
                if (_poopAt(d.localPosition, fit) case final p?) return onTapPoop(p);
              }
              final cow = game.cowAt(d.localPosition);
              if (cow != null && onTapCow != null) {
                onTapCow(cow);
              } else if (cow == null) {
                onTapEmpty?.call();
              }
            },
            // 手指按在大便上開始劃：劃過去清大便（A-15），場景不動；不然是拖動場景
            onHorizontalDragStart: (d) {
              final down = _down ?? d.localPosition;
              _sweeping = onSwipePoop != null && _poopAt(down, fit) != null;
              if (_sweeping) {
                if (animate) {
                  _trailFade.stop();
                  _trail.start(down, d.localPosition);
                }
                _last = down;
                _sweep(down, d.localPosition, fit);
                _last = d.localPosition;
              } else {
                onPanStart?.call();
              }
            },
            onHorizontalDragUpdate: (d) {
              if (_sweeping) {
                if (animate) _trail.add(d.localPosition);
                _sweep(_last ?? d.localPosition, d.localPosition, fit);
                _last = d.localPosition;
              } else {
                onPan?.call((widget.pan - d.delta.dx / fit.k).clamp(0.0, kMaxPan));
              }
            },
            // 手指往左甩（速度是負的）場景往右捲
            onHorizontalDragEnd: (d) {
              if (_sweeping) {
                _sweeping = false;
                _endTrail();
                widget.onSwipeEnd?.call();
              } else {
                onPanEnd?.call(-d.velocity.pixelsPerSecond.dx / fit.k);
              }
            },
            onHorizontalDragCancel: () {
              if (!_sweeping) return;
              _sweeping = false;
              _endTrail();
              widget.onSwipeEnd?.call();
            },
            child: scene,
          ),
        );
      },
    );
  }
}

/// A-15 手指劃過去的軌跡（設計稿 .swipe-trail 的 .st-glow）：手指經過的點連成一條線。劃的時候不透明度 0.75，
/// 放開以後 [fade]（0.05–0.3 秒淡掉，淡完就清掉）。座標是場景這一層的。
class _SwipeTrail extends ChangeNotifier {
  final points = <Offset>[];
  double opacity = 0;

  void start(Offset a, Offset b) {
    points
      ..clear()
      ..add(a)
      ..add(b);
    opacity = 0.75;
    notifyListeners();
  }

  void add(Offset p) {
    points.add(p);
    notifyListeners();
  }

  /// 放開以後過了 [t] 秒。
  void fade(double t) {
    opacity = 0.75 * (1 - ((t - 0.05) / 0.25).clamp(0.0, 1.0));
    if (t >= 0.3) points.clear();
    notifyListeners();
  }
}

/// 白色、粗 16、圓頭圓角的線（stroke="#FFFFFF" stroke-width="16" stroke-linecap/linejoin="round"）；
/// 整條一起半透明（自己疊到的地方不會比較白）。
class _TrailPainter extends CustomPainter {
  _TrailPainter(this.trail) : super(repaint: trail);

  final _SwipeTrail trail;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = trail.points;
    if (pts.length < 2 || trail.opacity <= 0) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: trail.opacity),
    );
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => oldDelegate.trail != trail;
}
