// A-03 出貨卡車（S07 出貨確認 → S20 評級結果）：牧場的出貨場景、路，卡車倒車進來接牛，牛跳上車斗、轉過來揮手說
// 「謝謝你的照顧！」，卡車往前開走，白光轉場。3.6 秒，點一下跳過。設計稿 anims.js 的 A03（使用者 2026-10-01：倒車接牛、
// 往前載走），每個時間點的數字在 truck_motion.dart，卡車的圖和量測在 truck.dart（可以換造型）。
// 手機設定「減少動態」時不播：出貨流程直接到 S20（設計稿的減少動態版）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/frame.dart';
import '../ranch/herd.dart';
import '../ranch/scene.dart';
import 'truck.dart';
import 'truck_motion.dart';

/// 留在牧場的牛站在後面看（設計稿 truck.js 的 A03_HERD）：場景座標、朝右、大小。
const kShipHerdSpots = <({double x, double y, bool right, double scale})>[
  (x: 318, y: 338, right: false, scale: 0.8),
  (x: 148, y: 420, right: true, scale: 0.9),
  (x: 262, y: 404, right: false, scale: 0.9),
];

/// 設計稿畫出貨的牛用固定的比例（anims.js 的 cowFixed：scale 1.04，不跟畫面大小縮放）。
const _cowScale = 1.04;

/// 出貨那一幕。播完或點一下就呼叫 [onDone]（接著顯示評級結果）。
class TruckScene extends StatefulWidget {
  const TruckScene({
    super.key,
    required this.cow,
    required this.ranchName,
    required this.herd,
    required this.onDone,
    this.skin,
  });

  /// 被載走的牛。
  final Cow cow;

  /// 車身上寫的牧場名。
  final String ranchName;

  /// 留在牧場的牛（最多 3 頭站在後面看）。
  final List<Cow> herd;
  final VoidCallback onDone;

  /// 卡車造型；不給就用預設的卡車。
  final TruckSkin? skin;

  @override
  State<TruckScene> createState() => _TruckSceneState();
}

class _TruckSceneState extends State<TruckScene> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  TruckSkin? _skin;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final given = widget.skin;
    if (given != null) {
      _skin = given;
      _clock.forward();
    } else {
      // 卡車的量測讀進來才開始播（第一次 1 個檔，之後記住）
      TruckSkin.loadDefault().then((s) {
        if (!mounted) return;
        setState(() => _skin = s);
        _clock.forward();
      });
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final skin = _skin;
    final s = Strings.of(context);
    final safe = MediaQuery.paddingOf(context);
    return GestureDetector(
      key: const Key('truck-scene'),
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = c.biggest;
          final fit = SceneFit(size, 0);
          final still = [
            // 出貨的場景（cow-ui 匯出，一個螢幕 390×844，cover）
            Positioned(
              left: fit.ox,
              top: fit.oy,
              width: kScreenWidth * fit.k,
              height: kScreenHeight * fit.k,
              child: SvgPicture.asset('assets/ui/scenes/ship.svg', fit: BoxFit.fill, excludeFromSemantics: true),
            ),
            ..._herd(fit),
            // 路：上緣 = 螢幕高 × 0.74 − 34，高 70，左右各多 10；48 寬一段接下去
            Positioned(
              left: -10,
              top: size.height * 0.74 - 34,
              width: size.width + 20,
              height: 70,
              child: const _Road(),
            ),
          ];
          if (skin == null) return Stack(clipBehavior: Clip.hardEdge, children: still);
          return AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final f = truckFrame(_clock.value * kTruckSeconds, size, skin.geometry);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  ...still,
                  for (final p in f.puffs) _Puff(p),
                  _TruckLayer(skin: skin, at: f.truck, child: _TruckBack(skin)),
                  ..._cow(f),
                  _TruckLayer(
                    skin: skin,
                    at: f.truck,
                    child: _TruckFront(skin: skin, frame: f, name: widget.ranchName),
                  ),
                  for (final b in f.beeps) _Beep(b, text: s.animBeep),
                  for (final h in f.hearts) _Heart(h),
                  _Say(text: s.animThanks, opacity: f.sayOpacity, at: f.sayAt, scale: f.sayScale),
                  // 點一下跳過（分頁列上方 22，設計稿的 .skip-hint）
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: safe.bottom + FrameSizes.tab + 22,
                    child: Center(child: _SkipHint(s.animSkip)),
                  ),
                  if (f.flash > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(color: Colors.white.withValues(alpha: f.flash)),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 留在牧場的牛（最多 3 頭，站在設計稿 A03_HERD 的位置，後面的先畫）：影子加牛，跟牧場一樣大。
  List<Widget> _herd(SceneFit fit) {
    final cows = [
      for (final c in widget.herd)
        if (c.id != widget.cow.id && c.fieldIndex == null) c,
    ].take(kShipHerdSpots.length).toList();
    final spots = [for (var i = 0; i < cows.length; i++) (cows[i], kShipHerdSpots[i])]
      ..sort((a, b) => a.$2.y.compareTo(b.$2.y));
    return [
      for (final (cow, spot) in spots)
        ...() {
          final slot = HerdSlot(spot.x, spot.y, right: spot.right, scale: spot.scale);
          final p = CowPlacement.of(SceneCow(cow, slot), fit);
          if (p == null) return const <Widget>[];
          return [
            Positioned.fromRect(
              rect: p.shadow,
              child: const DecoratedBox(
                decoration: ShapeDecoration(color: Color(0xFF86CC70), shape: OvalBorder()),
              ),
            ),
            Positioned.fromRect(
              rect: p.image,
              child: _CowSvg(name: p.name, mirror: p.mirror),
            ),
          ];
        }(),
    ];
  }

  /// 被載走的牛：等的時候側面朝著卡車（一彈一彈），跳上車斗、落地後轉成正面揮手（擠一下）。
  List<Widget> _cow(TruckFrame f) {
    final cow = widget.cow;
    final variant = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    final art = CowArt.instance;
    if (art == null) return const [];
    Widget at(Offset foot, {required bool front, required bool right}) {
      final (name, mirror) = art.pick(
        breed: cow.breed,
        bull: cow.bull,
        calf: cow.stage == CowStage.calf,
        front: front,
        right: right,
        variant: variant,
      );
      final m = art.meta(name);
      if (m == null) return const SizedBox.shrink();
      const s = _cowScale;
      final left = mirror ? foot.dx - (m.x0 + m.w) * s : foot.dx + m.x0 * s;
      return Positioned(
        left: left,
        top: foot.dy + m.y0 * s,
        width: m.w * s,
        height: m.h * s,
        child: _CowSvg(name: name, mirror: mirror),
      );
    }

    final base = f.frontBase;
    return [
      if (!f.showFront) at(f.sideFoot, front: false, right: true),
      if (f.showFront)
        // 以那一格的下緣中間為軸：rotate(揮手) scale(2 − 擠, 擠)；腳底在它上面 3
        Positioned.fill(
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(base.dx, base.dy, 0, 1)
              ..rotateZ(f.wave * math.pi / 180)
              ..scaleByDouble(2 - f.squash, f.squash, 1, 1)
              ..translateByDouble(-base.dx, -base.dy, 0, 1),
            child: Stack(clipBehavior: Clip.none, children: [at(base.translate(0, -3), front: true, right: false)]),
          ),
        ),
    ];
  }
}

class _CowSvg extends StatelessWidget {
  const _CowSvg({required this.name, required this.mirror});

  final String name;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final pic = SvgPicture.asset('assets/cows/svg/$name.svg', fit: BoxFit.fill, excludeFromSemantics: true);
    return mirror ? Transform.flip(flipX: true, child: pic) : pic;
  }
}

/// 一層卡車：卡車座標的原點放在 [at]，畫成 kTruckScale 倍。
class _TruckLayer extends StatelessWidget {
  const _TruckLayer({required this.skin, required this.at, required this.child});

  final TruckSkin skin;
  final Offset at;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = skin.geometry.size;
    return Positioned(
      left: at.dx,
      top: at.dy,
      width: size.width,
      height: size.height,
      child: Transform.scale(
        scale: kTruckScale,
        alignment: Alignment.topLeft,
        child: IgnorePointer(child: child),
      ),
    );
  }
}

class _TruckBack extends StatelessWidget {
  const _TruckBack(this.skin);

  final TruckSkin skin;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fromRect(
        rect: skin.backBox,
        child: SvgPicture.asset(skin.back, fit: BoxFit.fill, excludeFromSemantics: true),
      ),
    ],
  );
}

/// 卡車前面那層：車身、車身上的牧場名、亮著的倒車燈、擋板、輪子（照設計稿 truckFront 的先後）。
class _TruckFront extends StatelessWidget {
  const _TruckFront({required this.skin, required this.frame, required this.name});

  final TruckSkin skin;
  final TruckFrame frame;
  final String name;

  @override
  Widget build(BuildContext context) {
    final light = skin.light;
    final hinge = skin.hinge - skin.gateBox.topLeft;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: skin.frontBox,
          child: SvgPicture.asset(skin.front, fit: BoxFit.fill, excludeFromSemantics: true),
        ),
        Positioned.fill(child: CustomPaint(painter: _NamePlatePainter(name, skin.namePlate))),
        if (frame.lightOn)
          // SVG 的描邊 1.6 畫在邊線兩側：往外 0.8 再畫框（truck.js 的 tk-rev：圓角 2）
          Positioned.fromRect(
            rect: light.rect.inflate(0.8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: light.on,
                border: Border.all(color: skin.namePlate.color, width: 1.6),
                borderRadius: const BorderRadius.all(Radius.circular(2.8)),
              ),
            ),
          ),
        Positioned.fromRect(
          rect: skin.gateBox,
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(hinge.dx, hinge.dy, 0, 1)
              ..rotateZ(skin.gateOpenDeg * frame.gateOpen * math.pi / 180)
              ..translateByDouble(-hinge.dx, -hinge.dy, 0, 1),
            child: SvgPicture.asset(skin.gate, fit: BoxFit.fill, excludeFromSemantics: true),
          ),
        ),
        for (final w in skin.wheels)
          Positioned.fromRect(
            rect: skin.wheelBox.shift(w),
            child: Transform.rotate(
              angle: frame.wheelDeg * math.pi / 180,
              child: SvgPicture.asset(skin.wheel, fit: BoxFit.fill, excludeFromSemantics: true),
            ),
          ),
      ],
    );
  }
}

/// 車身上的牧場名：基線在 namePlate 的 (x, y)，置中。
class _NamePlatePainter extends CustomPainter {
  _NamePlatePainter(this.name, this.plate);

  final String name;
  final TruckNamePlate plate;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: AppText.style(
          plate.size,
          weight: FontWeight.values[(plate.weight ~/ 100 - 1).clamp(0, 8)],
          color: plate.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(plate.at.dx - tp.width / 2, plate.at.dy - baseline));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_NamePlatePainter old) => old.name != name;
}

/// 路的一段（cow-ui 匯出的 parts/road.svg，48 寬），左右接下去。
class _Road extends StatelessWidget {
  const _Road();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < (c.maxWidth / 48).ceil(); i++)
              SvgPicture.asset('assets/ui/parts/road.svg', width: 48, height: 70, excludeFromSemantics: true),
          ],
        ),
      ),
    ),
  );
}

/// 車尾的一團煙（.cut-puffs i：28 的白色圓、3 的框）。
class _Puff extends StatelessWidget {
  const _Puff(this.p);

  final ({Offset at, double scale, double opacity}) p;

  @override
  Widget build(BuildContext context) => Positioned(
    left: p.at.dx,
    top: p.at.dy,
    width: 28,
    height: 28,
    child: Opacity(
      opacity: p.opacity,
      child: Transform.scale(
        scale: p.scale,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 3)),
          ),
        ),
      ),
    ),
  );
}

/// 「嗶」（.cut-beep）。
class _Beep extends StatelessWidget {
  const _Beep(this.b, {required this.text});

  final ({Offset at, double deg, double opacity}) b;
  final String text;

  @override
  Widget build(BuildContext context) => Positioned(
    left: b.at.dx,
    top: b.at.dy,
    child: Opacity(
      opacity: b.opacity,
      child: Transform.rotate(
        angle: b.deg * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1B8),
            border: Border.all(color: AppColors.ink, width: 2.5),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Text(text, style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20)),
        ),
      ),
    ),
  );
}

/// 一顆愛心（20 的圖示）。
class _Heart extends StatelessWidget {
  const _Heart(this.h);

  final ({Offset at, double scale, double opacity}) h;

  @override
  Widget build(BuildContext context) => Positioned(
    left: h.at.dx,
    top: h.at.dy,
    width: 20,
    height: 20,
    child: Opacity(
      opacity: h.opacity,
      child: Transform.scale(scale: h.scale, child: const AppIcon('heart', size: 20)),
    ),
  );
}

/// 「謝謝你的照顧！」（.cut-say）：白底、3 的框、圓角 16、下面 3 的實心陰影；以左下角為軸放大。
class _Say extends StatelessWidget {
  const _Say({required this.text, required this.opacity, required this.at, required this.scale});

  final String text;
  final double opacity;
  final Offset at;
  final double scale;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx,
    top: at.dy,
    child: Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.ink, width: 3),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3))],
          ),
          child: Text(text, softWrap: false, style: AppText.style(16, weight: FontWeight.w900, lineHeight: 22)),
        ),
      ),
    ),
  );
}

/// 「點一下跳過」（.skip-hint）。
class _SkipHint extends StatelessWidget {
  const _SkipHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: const BoxDecoration(color: Color(0x8C2E1D14), borderRadius: BorderRadius.all(Radius.circular(14))),
    child: Text(
      text,
      softWrap: false,
      style: AppText.style(13, weight: FontWeight.w700, color: Colors.white),
    ),
  );
}
