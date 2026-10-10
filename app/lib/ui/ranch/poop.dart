// 牧場的大便（v0.3 第 5 節；使用者 2026-10-03 選第 13 輪 04-A 霜淇淋捲）：場景裡的大便（設計稿 poop.js）、
// 右上角的大便數（s03.js 的 dirtyPill、screens.css 的 .dirty）。點一下清一坨（A-14）、手指劃過去清好幾坨（A-15）。
// 開著動畫時照 A-14、A-15 播（[PoopCleanFx]）：點一下數字晚 0.3 秒變少、跳一下；劃過去每坨 0.05 秒後少、
// 手指放開時跳一下（劃過的軌跡在 scene.dart）。手機開了「減少動態」：清到的大便直接消失，數字直接變少。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/motion.dart';

/// 場景裡大便的位置（poop.js 的 POOP_SPOTS：場景座標，大便的底部中間；草地上、不擋到牛）。
/// 第 0–8 個是設計稿場景左半邊的 9 個；第 9–17 個在右半邊（往右滑才看得到），是 cow-ui 2026-10-10 排的
/// （避開池塘、石頭、水槽、花叢、乾草捲和兩頭牛的預設位置，y 都 ≤ 448，面板蓋不到；設計稿 S03-39）。
/// 最多畫 18 坨；再多的先不畫，右上角的數字照樣寫全部。
const kPoopSpots = <Offset>[
  Offset(236, 398),
  Offset(252, 452),
  Offset(38, 498),
  Offset(214, 482),
  Offset(284, 472),
  Offset(362, 448),
  Offset(204, 338),
  Offset(132, 412),
  Offset(332, 490),
  // 右半邊
  Offset(544, 398),
  Offset(700, 360),
  Offset(430, 404),
  Offset(648, 412),
  Offset(506, 366),
  Offset(740, 412),
  Offset(576, 338),
  Offset(418, 448),
  Offset(756, 356),
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

  /// 送出失敗、大便要放回去（[spots]：牛 → 原本的位置）：位置還空著就放回原位，被別的佔了就照常放進最前面的空位。
  void restore(Map<String, List<int>> spots) {
    final used = {for (final l in _byCow.values) ...l};
    for (final e in spots.entries) {
      for (final s in e.value) {
        if (used.add(s)) _byCow.putIfAbsent(e.key, () => []).add(s);
      }
    }
  }

  /// 換了牧場：新牧場的大便照編號重新排。
  void clear() => _byCow.clear();

  static int _compareId(Object a, Object b) => a is int && b is int ? a.compareTo(b) : '$a'.compareTo('$b');
}

/// 清掉的一坨在播的動畫：[id] 分開每一次，[spot] 是那一坨原本的位置（[kPoopSpots] 的第幾個）。
/// [swipe]：手指劃過去清掉的（A-15）；不是的話是點一下（A-14）。
class PoopFx {
  const PoopFx(this.id, this.spot, {this.swipe = false});
  final int id;
  final int spot;
  final bool swipe;
}

/// 一坨的動畫時間（秒，從清掉那一刻算）：整段 [length]、數字少 1 的時間 [countAt]、波紋 [ripple]（沒有是 null）、
/// 大便淡掉 [fade]、小星星 [poof]。
class _FxTiming {
  const _FxTiming({required this.length, required this.countAt, this.ripple, required this.fade, required this.poof});
  final double length, countAt;
  final (double, double)? ripple;
  final (double, double) fade, poof;
}

/// A-14 點一下（設計稿 anims.js 的 A14：手指在第 0.25 秒點下去，這裡從點下去那一刻算）。
const _tapTiming = _FxTiming(length: 0.47, countAt: 0.3, ripple: (0, 0.3), fade: (0.05, 0.2), poof: (0.07, 0.47));

/// A-15 劃過去（設計稿的 A15：手指經過那一坨的時間 tk 起算）：沒有波紋，0.1 秒淡掉，星星 0.35 秒，0.05 秒數字就少。
const _swipeTiming = _FxTiming(length: 0.35, countAt: 0.05, fade: (0, 0.1), poof: (0, 0.35));

/// 清掉一坨的動畫（A-14 點一下、A-15 劃過去）：
/// - 波紋（.ripple，只有點一下）：0–0.3 秒從 0.4 倍放大到 1.4 倍、慢慢淡掉。
/// - 大便：在原位淡掉（場景裡那一坨已經拿掉了，這裡畫一個淡掉的）。點一下 0.05–0.2 秒，劃過去 0–0.1 秒。
/// - 小星星（.poof）：冒出來再消失，往上飄 10、從 0.7 倍放大到 1.2 倍。點一下 0.07–0.47 秒，劃過去 0–0.35 秒。
/// - 右上角的數字少 1 的時候叫 [onCount]（點一下第 0.3 秒、劃過去第 0.05 秒），播完叫 [onDone]。
/// [poop] 是那一坨在螢幕上的範圍；[origin] 是波紋、星星的中心（大便底部中間往上 8，設計稿的 poopAt）。
class PoopCleanFx extends StatefulWidget {
  const PoopCleanFx({
    super.key,
    required this.poop,
    required this.origin,
    this.swipe = false,
    this.onCount,
    this.onDone,
  });

  final Rect poop;
  final Offset origin;
  final bool swipe;
  final VoidCallback? onCount;
  final VoidCallback? onDone;

  @override
  State<PoopCleanFx> createState() => _PoopCleanFxState();
}

class _PoopCleanFxState extends State<PoopCleanFx> with SingleTickerProviderStateMixin {
  late final _timing = widget.swipe ? _swipeTiming : _tapTiming;
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_timing.length * 1000).round()),
  );
  var _counted = false;

  @override
  void initState() {
    super.initState();
    _c
      ..addListener(() {
        if (!_counted && _c.value * _timing.length >= _timing.countAt) {
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
      final tm = _timing, t = _c.value * tm.length;
      final o = widget.origin;
      final rk = tm.ripple == null ? 0.0 : _seg(t, tm.ripple!.$1, tm.ripple!.$2);
      final pk = _seg(t, tm.poof.$1, tm.poof.$2);
      final poof = pk > 0 && pk < 1 ? math.sin(math.pi * pk) : 0.0;
      final scale = 0.7 + 0.5 * pk;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // 那一坨淡掉
          Positioned.fromRect(
            rect: widget.poop,
            child: Opacity(
              opacity: 1 - _seg(t, tm.fade.$1, tm.fade.$2),
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
    final w = MediaQuery.sizeOf(context).width;
    // 寬度小於 390：「會生病」的字拿掉；小於 340（320 寬）：「大便」兩個字也拿掉，只留圖示和數字（英文兩位數會蓋到牛欄膠囊）
    final narrow = w < 390, tiny = w < 340;
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
                if (!tiny) TextSpan(text: '${s.s03Poop} '),
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
