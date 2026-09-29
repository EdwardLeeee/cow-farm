// 牧場畫面（Flame）：草地上 N 頭用程式畫的牛，邊走邊上下晃。
//
// 牛全部用基本圖形畫（橢圓、圓角矩形、線），每頭約 16 個繪圖指令，沒有圖檔。
// 正式版多半用圖片精靈（一頭一次 drawImage），所以這是偏嚴格的測法。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

class CowGame extends FlameGame {
  CowGame({int seed = 42}) : _random = math.Random(seed);

  final math.Random _random;
  final List<Cow> _cows = <Cow>[];
  int _targetCount = 0;

  int get cowCount => _cows.length;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF8CC152);

  @override
  Future<void> onLoad() async {
    // 世界座標＝螢幕的邏輯像素，左上角是 (0, 0)。
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.add(Meadow());
    _sync();
  }

  /// 把牛的數量調成 [count]：多的移除、少的補上。同一個種子，每次跑出來的牛一樣。
  void setCowCount(int count) {
    _targetCount = count;
    if (isLoaded) _sync();
  }

  void _sync() {
    while (_cows.length < _targetCount) {
      final Cow cow = Cow.random(_random);
      _cows.add(cow);
      world.add(cow);
    }
    while (_cows.length > _targetCount) {
      _cows.removeLast().removeFromParent();
    }
  }
}

/// 草地：畫面大小改變時畫一次存成圖片，之後每張畫面只貼圖。
class Meadow extends Component with HasGameReference<CowGame> {
  Meadow() : super(priority: -1);

  ui.Image? _image;
  Vector2 _imageSize = Vector2.zero();
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

  @override
  void render(ui.Canvas canvas) {
    final Vector2 size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    if (_image == null || _imageSize != size) {
      _image?.dispose();
      _image = _paintMeadow(size);
      _imageSize = size.clone();
    }
    final ui.Image image = _image!;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      _paint,
    );
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  static ui.Image _paintMeadow(Vector2 size) {
    final double dpr = ui.PlatformDispatcher.instance.views.isEmpty
        ? 1
        : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder)..scale(dpr);
    final ui.Rect rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const <ui.Color>[ui.Color(0xFFA5D66F), ui.Color(0xFF7DB548)],
        ),
    );
    final math.Random random = math.Random(7);
    final ui.Paint patch = ui.Paint()..color = const ui.Color(0x2EFFFFFF);
    for (int i = 0; i < 28; i++) {
      final double w = 40 + random.nextDouble() * 90;
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(random.nextDouble() * size.x, random.nextDouble() * size.y),
          width: w,
          height: w * 0.45,
        ),
        patch,
      );
    }
    final ui.Paint blade = ui.Paint()
      ..color = const ui.Color(0xFF5E9A35)
      ..strokeWidth = 1.6
      ..strokeCap = ui.StrokeCap.round;
    for (int i = 0; i < 70; i++) {
      final ui.Offset base = ui.Offset(random.nextDouble() * size.x, random.nextDouble() * size.y);
      canvas.drawLine(base, base.translate(-3, -7), blade);
      canvas.drawLine(base, base.translate(0, -9), blade);
      canvas.drawLine(base, base.translate(3, -7), blade);
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(
      math.max(1, (size.x * dpr).round()),
      math.max(1, (size.y * dpr).round()),
    );
    picture.dispose();
    return image;
  }
}

/// 一頭牛。原點在身體中心，面向右；往左走時用 scale.x = -1 翻面。
class Cow extends PositionComponent with HasGameReference<CowGame> {
  Cow._({
    required this.speed,
    required this.yFraction,
    required this.startXFraction,
    required this.bobPhase,
    required this.bobFrequency,
    required this.spots,
    required this.spotPaint,
    required this.facing,
  }) : super(priority: (yFraction * 1000).round());

  factory Cow.random(math.Random r) {
    final List<ui.Rect> spots = <ui.Rect>[
      for (int i = 0; i < 3; i++)
        ui.Rect.fromCenter(
          center: ui.Offset(-16 + r.nextDouble() * 30, -8 + r.nextDouble() * 12),
          width: 8 + r.nextDouble() * 9,
          height: 6 + r.nextDouble() * 7,
        ),
    ];
    return Cow._(
      speed: 12 + r.nextDouble() * 28,
      yFraction: r.nextDouble(),
      startXFraction: r.nextDouble(),
      bobPhase: r.nextDouble() * math.pi * 2,
      bobFrequency: 5 + r.nextDouble() * 3,
      spots: spots,
      spotPaint: r.nextDouble() < 0.8 ? _black : _brown,
      facing: r.nextBool() ? 1 : -1,
    );
  }

  /// 每秒走幾個邏輯像素。
  final double speed;

  /// 在草地上的高度位置（0 是最上面，1 是最下面）；越下面的牛畫在越前面。
  final double yFraction;
  final double startXFraction;
  final double bobPhase;
  final double bobFrequency;
  final List<ui.Rect> spots;
  final ui.Paint spotPaint;

  /// 1 面向右、-1 面向左。
  double facing;
  double _t = 0;
  bool _placed = false;

  static const double _cowScale = 0.8;
  static const double _topMargin = 70;
  static const double _bottomMargin = 40;
  static const double _sideMargin = 36;

  static final ui.Paint _white = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  static final ui.Paint _black = ui.Paint()..color = const ui.Color(0xFF2B2B2B);
  static final ui.Paint _brown = ui.Paint()..color = const ui.Color(0xFF8D5A3B);
  static final ui.Paint _pink = ui.Paint()..color = const ui.Color(0xFFF7B7C3);
  static final ui.Paint _leg = ui.Paint()..color = const ui.Color(0xFF5B5B5B);
  static final ui.Paint _shadow = ui.Paint()..color = const ui.Color(0x33000000);
  static final ui.Paint _tail = ui.Paint()
    ..color = const ui.Color(0xFF5B5B5B)
    ..strokeWidth = 2.4
    ..strokeCap = ui.StrokeCap.round;

  @override
  void update(double dt) {
    final Vector2 field = game.size;
    if (field.x <= 0 || field.y <= 0) return;
    _t += dt;
    final double minX = _sideMargin;
    final double maxX = math.max(minX, field.x - _sideMargin);
    if (!_placed) {
      position.x = minX + (maxX - minX) * startXFraction;
      _placed = true;
    }
    position.x += speed * dt * facing;
    if (position.x < minX) {
      position.x = minX;
      facing = 1;
    } else if (position.x > maxX) {
      position.x = maxX;
      facing = -1;
    }
    final double usableHeight = math.max(0, field.y - _topMargin - _bottomMargin);
    position.y =
        _topMargin + usableHeight * yFraction + math.sin(_t * bobFrequency + bobPhase) * 2.2;
    scale.setValues(_cowScale * facing, _cowScale);
  }

  static const List<double> _legX = <double>[-20, -10, 9, 19];
  static final ui.Rect _shadowRect = ui.Rect.fromCenter(
    center: const ui.Offset(0, 24),
    width: 62,
    height: 10,
  );
  static final ui.RRect _bodyRRect = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTWH(-30, -17, 58, 30),
    const ui.Radius.circular(14),
  );
  static final ui.Rect _headRect = ui.Rect.fromCenter(
    center: const ui.Offset(30, -17),
    width: 25,
    height: 22,
  );
  static final ui.Rect _earBackRect = ui.Rect.fromCenter(
    center: const ui.Offset(19, -27),
    width: 10,
    height: 6,
  );
  static final ui.Rect _earFrontRect = ui.Rect.fromCenter(
    center: const ui.Offset(41, -27),
    width: 10,
    height: 6,
  );
  static final ui.Rect _muzzleRect = ui.Rect.fromCenter(
    center: const ui.Offset(35, -10),
    width: 17,
    height: 11,
  );

  @override
  void render(ui.Canvas canvas) {
    final double swing = math.sin(_t * bobFrequency * 1.3 + bobPhase) * 2.5;
    // 影子
    canvas.drawOval(_shadowRect, _shadow);
    // 四條腿，前後交錯擺動
    for (int i = 0; i < 4; i++) {
      final double x = _legX[i] + (i.isEven ? swing : -swing);
      canvas.drawRRect(
        ui.RRect.fromLTRBR(x - 3.5, 6, x + 3.5, 23, const ui.Radius.circular(3)),
        _leg,
      );
    }
    // 尾巴
    canvas.drawLine(const ui.Offset(-28, -6), ui.Offset(-35, 6 + swing * 0.6), _tail);
    // 身體與斑點
    canvas.drawRRect(_bodyRRect, _white);
    for (final ui.Rect spot in spots) {
      canvas.drawOval(spot, spotPaint);
    }
    // 頭、耳朵、鼻子、眼睛
    canvas.drawOval(_headRect, _white);
    canvas.drawOval(_earBackRect, spotPaint);
    canvas.drawOval(_earFrontRect, _pink);
    canvas.drawOval(_muzzleRect, _pink);
    canvas.drawCircle(const ui.Offset(26, -20), 2.2, _black);
    canvas.drawCircle(const ui.Offset(35, -20), 2.2, _black);
  }
}
