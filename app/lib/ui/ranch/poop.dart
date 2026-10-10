// 牧場的大便（v0.3 第 5 節；使用者 2026-10-03 選第 13 輪 04-A 霜淇淋捲）：場景裡的大便（設計稿 poop.js）、
// 右上角的大便數（s03.js 的 dirtyPill、screens.css 的 .dirty）。點一下清一坨（A-14）、手指劃過去清好幾坨（A-15）。
// 開著動畫時點一下照 A-14 播（[PoopCleanFx]、數字晚 0.3 秒變少、跳一下）；劃過去（A-15）現在是減少動態版：
// 清到的大便直接消失，數字直接變少。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/motion.dart';
import 'scene.dart' show kSceneWidth;

/// 場景裡大便的位置（poop.js 的 POOP_SPOTS：場景座標，大便的底部中間；草地上、不擋到牛）。
/// 設計稿只畫了場景左半邊這 9 個（第 0–8 個）。第 10 坨以後照 ceo 2026-10-10 的暫定做法放到右半邊（第 9–12 個）：
/// 左半邊第 0、5、6、7 個的左右鏡射。其他 5 個鏡射過去會落在池塘上、被「收起」擋住，先不用；所以最多畫 13 坨，
/// 再多的先不畫，右上角的數字照樣寫全部。cow-ui 給了右半邊正式的位置再換。
const _leftPoopSpots = <Offset>[
  Offset(236, 398),
  Offset(252, 452),
  Offset(38, 498),
  Offset(214, 482),
  Offset(284, 472),
  Offset(362, 448),
  Offset(204, 338),
  Offset(132, 412),
  Offset(332, 490),
];

/// 右半邊的位置：x 換成 場景的寬（兩個畫面寬）− x。
final kPoopSpots = <Offset>[
  ..._leftPoopSpots,
  for (final i in const [0, 5, 6, 7]) Offset(kSceneWidth - _leftPoopSpots[i].dx, _leftPoopSpots[i].dy),
];

/// 場景裡一坨的寬（poop.js 的 POOP_W：圖示 poop 的 20 放大成 19）。
const kPoopWidth = 19.0;

/// 圖示 poop.svg 的 viewBox（−12 −19 24 22）：原點是底部中間。
const _viewBox = Rect.fromLTWH(-12, -19, 24, 22);

/// 一坨大便在場景裡的範圍（場景座標）：底部中間對準 [spot]。
Rect poopRect(Offset spot) {
  const s = kPoopWidth / 20;
  return Rect.fromLTWH(
    spot.dx + _viewBox.left * s,
    spot.dy + _viewBox.top * s,
    _viewBox.width * s,
    _viewBox.height * s,
  );
}

/// 場景裡的一坨大便：畫在第 [spot] 個位置，是 [cow] 旁邊的（清的時候送這頭牛的編號，協定 2.6）。
class ScenePoop {
  const ScenePoop(this.spot, this.cow);
  final int spot;
  final Cow cow;
}

/// 哪一坨畫在哪個位置。跟牛的位置（HerdLayout）一樣記住：清掉一坨時其他的不會跳位；新的大便放進最前面的空位，
/// 剛打開時照牛的編號從第 0 個位置排起（設計稿 S03-26 的 4 坨是第 0–3 個位置；第 10 坨起到右半邊）。
class PoopLayout {
  final _byCow = <String, List<int>>{};

  /// 這一坨清掉了（點到、劃過去）：那個位置空出來。那個位置本來就是空的（同一格畫面裡被劃到兩次、連點兩下）回 false。
  bool take(int spot) {
    for (final l in _byCow.values) {
      if (l.remove(spot)) return true;
    }
    return false;
  }

  /// [cows] 每頭現在要畫幾坨（[count]，已經扣掉正在清的）。多出來的先拿掉最後放的，少的放進最前面的空位；
  /// 位置不夠就先不畫。
  List<ScenePoop> place(Iterable<Cow> cows, int Function(Cow) count) {
    final byKey = {for (final c in cows) c.key: c};
    _byCow.removeWhere((k, _) => !byKey.containsKey(k));
    for (final e in _byCow.entries) {
      final n = count(byKey[e.key]!);
      while (e.value.length > n) {
        e.value.removeLast();
      }
    }
    final used = {for (final l in _byCow.values) ...l};
    var free = 0;
    for (final c in [...byKey.values]..sort((a, b) => _compareId(a.id, b.id))) {
      final n = count(c);
      final l = _byCow.putIfAbsent(c.key, () => []);
      while (l.length < n) {
        while (free < kPoopSpots.length && used.contains(free)) {
          free++;
        }
        if (free == kPoopSpots.length) break;
        l.add(free);
        used.add(free);
      }
    }
    return [
      for (final e in _byCow.entries)
        for (final s in e.value) ScenePoop(s, byKey[e.key]!),
    ]..sort((a, b) => a.spot.compareTo(b.spot));
  }

  /// 換了牧場：新牧場的大便照編號重新排。
  void clear() => _byCow.clear();

  static int _compareId(Object a, Object b) => a is int && b is int ? a.compareTo(b) : '$a'.compareTo('$b');
}

/// 點一下清掉的一坨（A-14 的動畫）：[id] 分開每一次，[spot] 是那一坨原本的位置（[kPoopSpots] 的第幾個）。
class PoopFx {
  const PoopFx(this.id, this.spot);
  final int id;
  final int spot;
}

/// A-14 清大便：點一下（設計稿 anims.js 的 A14：手指在第 0.25 秒點下去，這裡從點下去那一刻算，播 0.47 秒）。
/// - 波紋（.ripple）：0–0.3 秒從 0.4 倍放大到 1.4 倍、慢慢淡掉。
/// - 大便：0.05–0.2 秒淡掉（場景裡那一坨已經拿掉了，這裡在原位畫一個淡掉的）。
/// - 小星星（.poof）：0.07–0.47 秒冒出來再消失，往上飄 10、從 0.7 倍放大到 1.2 倍。
/// - 第 0.3 秒叫 [onCount]（右上角的數字這時才少 1、跳一下），播完叫 [onDone]。
/// [poop] 是那一坨在螢幕上的範圍；[origin] 是波紋、星星的中心（大便底部中間往上 8，設計稿的 poopAt）。
class PoopCleanFx extends StatefulWidget {
  const PoopCleanFx({super.key, required this.poop, required this.origin, this.onCount, this.onDone});

  final Rect poop;
  final Offset origin;
  final VoidCallback? onCount;
  final VoidCallback? onDone;

  /// 整段的長度、數字變少的時間（秒）。
  static const length = 0.47, countAt = 0.3;

  @override
  State<PoopCleanFx> createState() => _PoopCleanFxState();
}

class _PoopCleanFxState extends State<PoopCleanFx> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (PoopCleanFx.length * 1000).round()),
  );
  var _counted = false;

  @override
  void initState() {
    super.initState();
    _c
      ..addListener(() {
        if (!_counted && _c.value * PoopCleanFx.length >= PoopCleanFx.countAt) {
          _counted = true;
          widget.onCount?.call();
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [t] 在 [a]–[b] 之間走到哪裡（0–1）。
  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = _c.value * PoopCleanFx.length;
      final o = widget.origin;
      final rk = _seg(t, 0, 0.3), pk = _seg(t, 0.07, 0.47);
      final poof = pk > 0 && pk < 1 ? math.sin(math.pi * pk) : 0.0;
      final scale = 0.7 + 0.5 * pk;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // 那一坨淡掉
          Positioned.fromRect(
            rect: widget.poop,
            child: Opacity(
              opacity: 1 - _seg(t, 0.05, 0.2),
              child: SvgPicture.asset('assets/ui/icons/poop.svg', fit: BoxFit.fill, excludeFromSemantics: true),
            ),
          ),
          // 小星星（16、11、9）：.poof 是中心上的 0×0 方塊，放大和往上飄都對著中心
          if (poof > 0)
            for (final (size, dx, dy) in const [(16.0, -8.0, -20.0), (11.0, 6.0, -10.0), (9.0, -16.0, -6.0)])
              Positioned(
                left: o.dx + dx * scale,
                top: o.dy + dy * scale - 10 * pk,
                width: size * scale,
                height: size * scale,
                child: Opacity(
                  opacity: poof,
                  child: SvgPicture.asset('assets/ui/icons/sparkle.svg', fit: BoxFit.fill, excludeFromSemantics: true),
                ),
              ),
          // 波紋
          if (rk > 0 && rk < 1)
            Positioned(
              left: o.dx - 19,
              top: o.dy - 19,
              width: 38,
              height: 38,
              child: Opacity(
                opacity: 1 - rk,
                child: Transform.scale(
                  scale: 0.4 + rk,
                  child: const CustomPaint(painter: _Ripple()),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// .ripple：直徑 34 的圈，白色邊框 3（在圈裡面），外面再一圈 2 的淡色（box-shadow 0 0 0 2px rgba(75, 51, 38, 0.35)）。
/// 畫在 38×38 的中間。
class _Ripple extends CustomPainter {
  const _Ripple();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x594B3326),
    );
    canvas.drawCircle(
      c,
      15.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Ripple oldDelegate) => false;
}

/// .dirty：右上角的大便數（有大便才出現）。髒的程度超過會生病的門檻（[bad]）就變紅、加警告圖示和「會生病」；
/// 寬度小於 390 只留圖示（screens.css 的 @media (max-width: 389px)）。
/// [bump] 變了（點一下清掉的那一坨算進來了，A-14）就跳一下：0.15 秒放大到 1.1 倍再回來；開著動畫才跳。
class DirtPill extends StatefulWidget {
  const DirtPill({super.key, required this.count, required this.bad, this.bump = 0});

  final int count;
  final bool bad;
  final int bump;

  @override
  State<DirtPill> createState() => _DirtPillState();
}

class _DirtPillState extends State<DirtPill> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));

  @override
  void didUpdateWidget(DirtPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bump != oldWidget.bump && AppMotion.read(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) =>
        Transform.scale(scale: _c.isAnimating ? 1 + 0.1 * math.sin(math.pi * _c.value) : 1, child: child),
    child: _pill(context),
  );

  Widget _pill(BuildContext context) {
    final count = widget.count, bad = widget.bad;
    final s = Strings.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 390;
    const warn = Color(0xFFC2412F);
    return Container(
      key: const Key('dirt-pill'),
      height: 36,
      padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
      decoration: BoxDecoration(
        color: bad ? const Color(0xFFFFE1DC) : Colors.white,
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('poop', size: 22),
          const SizedBox(width: 4),
          // 「大便 9」：字 14 特粗、數字 16（.num），這一段行高 20
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${s.s03Poop} '),
                TextSpan(text: '$count', style: AppText.number(16, lineHeight: 20)),
              ],
            ),
            key: const Key('dirt-count'),
            softWrap: false,
            style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20),
          ),
          if (bad) ...[
            const SizedBox(width: 4 + 2),
            const AppIcon('warn', size: 16),
            if (!narrow) ...[
              const SizedBox(width: 2),
              Text(
                s.s03PoopDanger,
                softWrap: false,
                style: AppText.style(12, weight: FontWeight.w900, color: warn, lineHeight: 20),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
