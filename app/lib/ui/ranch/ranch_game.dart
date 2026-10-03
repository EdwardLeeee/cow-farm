// 牧場裡的牛（D4、T3：Flame）：影子、牛、傳說品種的星星。背景還是 RanchScene 用 SvgPicture 畫。
// 牛會走動（A-11）、轉身（A-07），動作的數字在 walk.dart。
//
// 牛的 SVG 依手機解析度畫成點陣圖（T3），每一格只貼圖：
// - 站著不動時照實際像素對齊（位置的小數一起畫進圖裡），貼上去跟直接畫 SVG 一模一樣。
// - 走動、轉身、拖動場景時，用同一張圖移動、翻轉、搖晃；停下來以後再重新對齊（每一格最多重畫幾張）。
// 牛不會動的時候（減少動態、測試）遊戲迴圈停著，畫面有變化才畫一格。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../theme/tokens.dart';
import 'herd.dart';
import 'scene.dart';
import 'walk.dart';

/// 牧場的牛。RanchScene 每次重建時用 [configure] 告訴它要畫哪些牛、場景怎麼放。
class RanchGame extends FlameGame {
  RanchGame();

  @override
  Color backgroundColor() => const Color(0x00000000);

  final _byId = <Object, CowComponent>{};
  final _pictures = <String, PictureInfo>{};
  final _loading = <String>{};

  SceneFit _fit = SceneFit(Size.zero, 0);
  double _dpr = 1;

  /// 牛會走動、轉身（不是減少動態，也不是測試）。
  bool get animate => _animate;
  bool _animate = false;

  /// 這一格場景被拖動了（或換了大小）：點陣圖先不重新對齊。
  bool _moved = false;

  /// 這一格還可以重畫幾張點陣圖（重新對齊像素）。
  int _budget = 0;

  /// 這一格有幾頭站著不動、但還沒對齊像素的牛。
  int _unaligned = 0;

  /// 這一格要畫的牛、場景怎麼放、手機的像素倍率；[animate] 是牛會不會動。
  void configure(List<SceneCow> cows, SceneFit fit, double dpr, {required bool animate}) {
    var changed = fit.pan != _fit.pan || fit.k != _fit.k || fit.ox != _fit.ox || fit.oy != _fit.oy || dpr != _dpr;
    _moved = _moved || changed;
    _fit = fit;
    _dpr = dpr;
    final ids = {for (final c in cows) c.cow.id};
    for (final id in [..._byId.keys]) {
      if (!ids.contains(id)) {
        _byId.remove(id)!.removeFromParent();
        changed = true;
      }
    }
    final order = RanchScene.paintOrder(cows);
    for (var i = 0; i < order.length; i++) {
      final c = order[i];
      final comp = _byId[c.cow.id];
      if (comp == null) {
        add(_byId[c.cow.id] = CowComponent(c)..priority = i);
        changed = true;
      } else {
        changed = comp.scene.front != c.front || comp.scene.slot != c.slot || changed;
        comp
          ..scene = c
          ..priority = i;
      }
    }
    for (final c in cows) {
      final p = CowPlacement.of(c, fit);
      if (p != null) _ensurePicture(p.name);
      final front = CowPlacement.of(SceneCow(c.cow, c.slot, front: !c.front), fit);
      if (front != null) _ensurePicture(front.name);
    }
    if (animate != _animate) {
      _animate = animate;
      changed = true;
    }
    if (paused == animate) paused = !animate;
    // 牛不會動的時候遊戲迴圈停著：有變化才畫一格（不前進時間）
    if (!animate && changed) stepEngine(stepTime: 0);
  }

  /// [point]（場景裡的座標）上最前面的那頭牛。
  Cow? cowAt(Offset point) {
    final front = [..._byId.values]..sort((a, b) => b.priority.compareTo(a.priority));
    for (final c in front) {
      if (c.bounds(_fit)?.contains(point) ?? false) return c.scene.cow;
    }
    return null;
  }

  /// 這頭牛往右走出去多遠（場景座標，往左是負的；CowPlacement.of 的 dx）。停下來（轉正面）的牛停在這裡，
  /// 泡泡和名片跟著它。
  double dxOf(Object id) => _find(id)?.dx ?? 0;

  /// 這頭牛現在畫在哪裡（場景元件裡的座標），測試點牛用；不在場景裡（去田裡了）是 null。
  Rect? cowRect(Object id) => _find(id)?.bounds(_fit);

  /// 這頭牛現在畫的是哪一張圖（cows.json 的名字），測試用。
  String? artOf(Object id) => _find(id)?.artName(_fit);

  /// 牛的編號可能是數字或字串（協定）：兩種都認。
  CowComponent? _find(Object id) =>
      _byId[id] ??
      [
        for (final e in _byId.entries)
          if ('${e.key}' == '$id') e.value,
      ].firstOrNull;

  PictureInfo? _picture(String name) => _pictures[name];

  void _ensurePicture(String name) {
    if (_pictures.containsKey(name) || !_loading.add(name)) return;
    vg.loadPicture(SvgAssetLoader('assets/cows/svg/$name.svg'), null).then((info) {
      _loading.remove(name);
      if (_disposed) {
        info.picture.dispose();
        return;
      }
      _pictures[name] = info;
      if (paused) stepEngine(stepTime: 0);
    });
  }

  bool _takeBudget() {
    if (_budget <= 0) return false;
    _budget--;
    return true;
  }

  @override
  void update(double dt) {
    // 遊戲迴圈在跑：每一格最多重畫 4 張，慢慢對齊。停著（不會動）：下一格一次全部對齊
    _budget = paused ? 1 << 30 : 4;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    _unaligned = 0;
    super.render(canvas);
    // 遊戲迴圈停著時，剛拖完或還有牛沒對齊：下一格再畫一次（這一次就對齊）
    if (paused && (_moved || _unaligned > 0)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && isAttached && paused) stepEngine(stepTime: 0);
      });
    }
    _moved = false;
  }

  bool _disposed = false;

  /// 接上 GameWidget（再接回來時圖要重新讀）。
  @override
  void onAttach() {
    _disposed = false;
    super.onAttach();
  }

  /// GameWidget 拆掉了（離開牧場分頁）：放掉讀進來的 SVG。
  @override
  void onDispose() {
    _disposed = true;
    for (final p in _pictures.values) {
      p.picture.dispose();
    }
    _pictures.clear();
    _loading.clear();
    super.onDispose();
  }
}

/// 一張畫好的點陣圖：照 [rect]（螢幕座標）的位置畫的，左上角對齊到實際像素 [origin]。
class _Raster {
  _Raster(this.image, this.name, this.mirror, this.rect, this.origin);

  final ui.Image image;
  final String name;
  final bool mirror;
  final Rect rect;
  final Offset origin;

  /// 一樣的圖、一樣的大小（只差位置）。
  bool sameArt(String n, bool m, Rect r) =>
      n == name && m == mirror && (r.width - rect.width).abs() < 1e-6 && (r.height - rect.height).abs() < 1e-6;

  /// 位置也一樣（貼上去一個像素對一個像素）。
  bool aligned(Rect r) => (r.left - rect.left).abs() < 1e-6 && (r.top - rect.top).abs() < 1e-6;

  /// 照 [p] 的位置畫：位置的小數（實際像素）先畫進圖裡，貼的時候對齊整數像素。
  static _Raster make(PictureInfo info, CowPlacement p, double dpr) {
    final r = p.image;
    final left = r.left * dpr, top = r.top * dpr;
    final origin = Offset(left.floorToDouble(), top.floorToDouble());
    final fx = left - origin.dx, fy = top - origin.dy;
    final pw = (fx + r.width * dpr).ceil(), ph = (fy + r.height * dpr).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..translate(fx, fy)
      ..scale(dpr);
    // SvgPicture 的 fit: BoxFit.fill；朝向不同時以圖的中間左右翻（Transform.flip）
    if (p.mirror) {
      canvas
        ..translate(r.width, 0)
        ..scale(-1, 1);
    }
    canvas
      ..scale(r.width / info.size.width, r.height / info.size.height)
      ..drawPicture(info.picture);
    final picture = rec.endRecording();
    final image = picture.toImageSync(math.max(1, pw), math.max(1, ph));
    picture.dispose();
    return _Raster(image, p.name, p.mirror, r, origin);
  }

  /// 畫在 [r] 的位置。
  void draw(Canvas canvas, Rect r, double dpr, Paint paint) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(
      origin.dx / dpr + (r.left - rect.left),
      origin.dy / dpr + (r.top - rect.top),
      image.width / dpr,
      image.height / dpr,
    );
    canvas.drawImageRect(image, src, dst, paint);
  }

  void dispose() => image.dispose();
}

/// 一頭牛。
class CowComponent extends Component with HasGameReference<RanchGame> {
  CowComponent(this.scene) : _front = scene.front;

  /// 牛、位置、該不該轉正面（RanchGame.configure 更新）。
  SceneCow scene;

  late final int _slot = kHerdSlots.indexOf(scene.slot);

  // 走動（A-11）：只在側面、沒在轉身時往前走；停下來時記住走到哪裡、是不是在往回走
  double _clock = 0;
  WalkPose _pose = WalkPose.rest;
  bool _back = false;

  /// 往右走出去多遠（場景座標，往左是負的）。
  double get dx => _dir * _pose.x;

  // 轉身（A-07）：[_front] 是轉完的樣子；[_turn] 是轉到哪裡（0 側面–0.5 正面），沒在轉是 null
  bool _front;
  double? _turn;

  final _raster = <bool, _Raster>{};

  static final _shadowPaint = Paint()..color = const Color(0xFF86CC70);
  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  bool get _turnToFront => scene.front;

  @override
  void update(double dt) {
    final animate = game.animate;
    if (!animate) {
      // 減少動態：直接換成另一個角度、站在原位（設計稿的「減少動態」）
      _front = scene.front;
      _turn = null;
      _pose = WalkPose.rest;
      _back = false;
      return;
    }
    // 該轉身了：從現在的角度開始轉（正面轉回側面時倒著播）
    if (_turn == null && _front != scene.front) _turn = _front ? kTurnSeconds : 0;
    var left = dt;
    if (_turn case final t?) {
      final need = _turnToFront ? kTurnSeconds - t : t;
      if (left >= need) {
        // 轉完了；這一格剩下的時間才拿去走
        _front = _turnToFront;
        _turn = null;
        left -= need;
      } else {
        _turn = _turnToFront ? t + left : t - left;
        left = 0;
      }
    }
    final plan = walkPlanFor(_slot);
    if (plan == null) {
      _pose = WalkPose.rest;
      _back = false;
    } else if (!_front && _turn == null) {
      // 側面：照自己的時鐘走（停下來的時候時鐘也停著，轉回側面後從停下來的地方接著走）
      _clock += left;
      _pose = walkPose(_clock, plan, calf: scene.cow.stage == CowStage.calf);
      _back = _pose.back;
    } else {
      // 正面或轉身中：停在原地，不彈不搖
      _pose = WalkPose(_pose.x, back: _back);
    }
  }

  /// 現在畫的是正面還是側面、縮放和跳多高。
  ({bool front, double scaleX, double hop}) _look() {
    final t = _turn;
    if (t == null) return (front: _front, scaleX: 1.0, hop: 0.0);
    final p = turnPose(t);
    return (front: p.front, scaleX: p.scaleX, hop: p.hop);
  }

  double get _dir => scene.slot.right ? 1 : -1;

  CowPlacement? _placement(SceneFit fit, bool front) =>
      CowPlacement.of(SceneCow(scene.cow, scene.slot, front: front), fit, dx: dx);

  String? artName(SceneFit fit) => _placement(fit, _look().front)?.name;

  /// 現在畫在哪裡（不算搖晃）：點牛用。
  Rect? bounds(SceneFit fit) {
    final look = _look();
    final p = _placement(fit, look.front);
    if (p == null) return null;
    return p.image.shift(Offset(0, -(_pose.bob + look.hop) * fit.k));
  }

  @override
  void render(Canvas canvas) {
    final fit = game._fit;
    final look = _look();
    final p = _placement(fit, look.front);
    if (p == null) return;
    final info = game._picture(p.name);
    if (info == null) return;
    // 轉身時影子用正面的（anims.js 的 A07）
    final shadow = _turn == null ? p.shadow : (_placement(fit, true)?.shadow ?? p.shadow);
    canvas.drawPath(const OvalBorder().getOuterPath(shadow), _shadowPaint);

    final flip = look.front || !_back ? 1.0 : -1.0;
    final bob = (_pose.bob + look.hop) * fit.k;
    final still = bob == 0 && _pose.tilt == 0 && flip == 1 && look.scaleX == 1;
    final foot = p.foot;
    canvas.save();
    if (!still) {
      // anims.js：translate(cx, cy − bob) rotate(tilt × dir × flip) scale(flip × 轉身的縮放, 1) translate(−cx, −cy)
      canvas
        ..translate(foot.dx, foot.dy - bob)
        ..rotate(_pose.tilt * _dir * flip * math.pi / 180)
        ..scale(flip * look.scaleX, 1)
        ..translate(-foot.dx, -foot.dy);
    }
    final aligned = _drawArt(canvas, info, p, look.front, exact: still && !game._moved);
    if (still && !aligned) game._unaligned++;
    if (breedInfo(scene.cow.breed)?.tier == 3) _sparkles(canvas, p.head, p.unit / fit.k, fit.k);
    canvas.restore();
  }

  /// 畫牛；回傳是不是一個像素對一個像素（跟直接畫 SVG 一樣）。
  bool _drawArt(Canvas canvas, PictureInfo info, CowPlacement p, bool front, {required bool exact}) {
    final dpr = game._dpr;
    var r = _raster[front];
    final stale = r == null || !r.sameArt(p.name, p.mirror, p.image);
    if (stale || (exact && !r.aligned(p.image) && game._takeBudget())) {
      r?.dispose();
      r = _raster[front] = _Raster.make(info, p, dpr);
    }
    r.draw(canvas, p.image, dpr, _imagePaint);
    return r.aligned(p.image);
  }

  /// 傳說品種頭上的兩顆星星（scene.js 的 sparkle）：右上大的、左上小的。
  static void _sparkles(Canvas canvas, Offset head, double s, double k) {
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
  void onRemove() {
    for (final r in _raster.values) {
      r.dispose();
    }
    _raster.clear();
    super.onRemove();
  }
}
