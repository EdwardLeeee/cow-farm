// 牧場頁下面的面板（設計稿 s03.js 的 dock、screens.css 的 .dock；v0.3 第 2.2 節，使用者看第 19、23、26、29 輪）：
// 頂列（左邊「倉庫」小鈕、中間場景的位置 S03-13、右邊收起／展開）、飼料列（沒有底板）、奶桶。
// 收起來奶桶和飼料一起收，只剩頂列；「展開」那顆帶著奶桶的 %，滿了變藍、寫「滿了」（S03-11、S03-12）。
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/press.dart';
import 'scene.dart';

/// 面板要顯示的數字（都來自伺服器的 state；奶桶是平滑推算的顯示值）。
class DockData {
  const DockData({
    required this.bucket,
    required this.bucketCap,
    required this.perHour,
    required this.timeScale,
    double? rateBucket,
    this.draining = false,
    this.feeds = const {},
  }) : rateBucket = rateBucket ?? bucket;

  final double bucket;

  /// 「幾分鐘後滿」用的奶桶量（A-01 收奶的動畫：水位往下降時還寫原本的，降完才換）。
  final double rateBucket;

  /// A-01 水位往下降中：奶桶的瓶數固定寫一位小數（31.0），快到 0 寫 0（設計稿 A01.frame）。
  final bool draining;

  /// 奶桶卡上的瓶數。
  String get bucketText => draining ? (bucket < 0.05 ? '0' : bucket.toStringAsFixed(1)) : oneDecimal(bucket);
  final double bucketCap;
  final double perHour; // 遊戲時間每小時
  final double timeScale;

  /// 倉庫裡每種飼料幾份（state 的 feeds；沒有的是 0）。
  final Map<String, int> feeds;

  int get pct => bucketCap <= 0 ? 0 : (bucket / bucketCap * 100).round();
  bool get full => pct >= 100;
}

class Dock extends StatelessWidget {
  const Dock({
    super.key,
    required this.data,
    required this.collapsed,
    required this.pan,
    required this.onToggle,
    required this.collect,
    this.onWarehouse,
    this.pailKey,
    this.warehouseKey,
    this.warehouseScale = 1,
    this.gutter = 12,
  });

  /// 奶桶圖示、頂列的「倉庫」小鈕：A-01 收奶的奶瓶從哪裡飛到哪裡。
  final Key? pailKey;
  final Key? warehouseKey;

  /// A-01：奶瓶飛進「倉庫」小鈕時，小鈕跳一下（放大的倍數）。
  final double warehouseScale;

  final DockData data;
  final bool collapsed;
  final double pan;
  final VoidCallback onToggle;

  /// 點「倉庫」小鈕：打開倉庫詳細頁（S05-02）。
  final VoidCallback? onWarehouse;

  /// 收奶鈕（停用、轉圈由外面決定）。
  final Widget collect;

  /// 面板離畫面左右的距離（.dock 的 left、right 12）。飼料列不受這個限制，延伸到畫面的左右邊緣。
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final side = EdgeInsets.symmetric(horizontal: gutter);
    return Column(
      key: const Key('dock'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: side,
          child: SizedBox(
            key: const Key('dock-head'),
            height: 44,
            // 跟設計稿的順序一樣：收起鈕在最上面（320 寬的英文「87% Show」會蓋到場景位置的右邊一點）
            child: Stack(
              alignment: Alignment.center,
              children: [
                Semantics(
                  label: s.s03PanAria,
                  child: _PanIndicator(pan: pan),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _WarehouseButton(onTap: onWarehouse, pillKey: warehouseKey, scale: warehouseScale),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: collapsed ? s.s03ExpandAria : s.s03CollapseAria,
                    // 按下：膠囊往下 1、陰影變 1（G-12）
                    child: Pressable(
                      key: const Key('dock-toggle'),
                      lift: 2,
                      onTap: onToggle,
                      builder: (context, look) => Container(
                        constraints: const BoxConstraints(minWidth: 72),
                        alignment: Alignment.centerRight,
                        child: _TogglePill(collapsed: collapsed, look: look, data: data),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          // .dock-head 的 margin-bottom 8，加上 .dock 的 gap 8
          const SizedBox(height: 8 + 8),
          _FeedBar(feeds: data.feeds, inset: gutter + 2),
          // .fbar 的 margin-bottom 4，加上 .dock 的 gap 8
          const SizedBox(height: 4 + 8),
          Padding(
            padding: side,
            child: _BucketCard(data: data, collect: collect, pailKey: pailKey),
          ),
        ],
      ],
    );
  }
}

/// .wh-btn：頂列左邊的「倉庫」小鈕（第 23 輪 03-B）。按的範圍至少 72 × 44，膠囊高 30。
class _WarehouseButton extends StatelessWidget {
  const _WarehouseButton({required this.onTap, required this.pillKey, required this.scale});

  final VoidCallback? onTap;
  final Key? pillKey;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Semantics(
      container: true,
      button: true,
      label: s.warehouseTitle,
      // 按下：膠囊往下 1、陰影變 1（跟收起鈕一樣）
      child: Pressable(
        key: const Key('warehouse-btn'),
        lift: 2,
        onTap: onTap,
        builder: (context, look) => Container(
          constraints: const BoxConstraints(minWidth: 72),
          alignment: Alignment.centerLeft,
          child: Transform.scale(
            scale: scale,
            child: PressTint(
              tint: look.tint,
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              child: Container(
                key: pillKey,
                height: 30,
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  // CSS 寫 2.5px，Chrome 畫成 2px（跟收起鈕一樣）
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  boxShadow: AppShadows.solid(look.shadow),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon('barn', size: 18),
                      const SizedBox(width: 4),
                      CssLine(
                        TextSpan(
                          text: s.warehouseTitle,
                          style: AppText.style(13, weight: FontWeight.w900, lineHeight: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// .pan-ind：場景兩個螢幕寬，滑塊佔一半，往右捲到底時在右半邊。
class _PanIndicator extends StatelessWidget {
  const _PanIndicator({required this.pan});

  final double pan;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pan-indicator'),
    width: 64,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(5)),
    ),
    child: LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Positioned(
            left: c.maxWidth * (pan / kMaxPan).clamp(0, 1) * 0.5,
            top: 0,
            bottom: 0,
            width: c.maxWidth * 0.5,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.all(Radius.circular(3))),
            ),
          ),
        ],
      ),
    ),
  );
}

/// .dt-pill：「收起 ⌄」；收起來時「🪣 87% ｜ 展開 ⌃」，奶桶滿了整顆變藍、寫「滿了」（.dt-pill.full，第 29 輪）。
class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.collapsed, required this.look, required this.data});

  final bool collapsed;
  final PressLook look;
  final DockData data;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final full = collapsed && data.full;
    final fg = full ? const Color(0xFF1F5A93) : AppColors.ink;
    return PressTint(
      tint: look.tint,
      borderRadius: const BorderRadius.all(Radius.circular(15)),
      child: Container(
        height: 30,
        // 收起來時 .dt-pail 的 margin-left −4：左邊的 12 少 4
        padding: EdgeInsets.fromLTRB(collapsed ? 12 - 4 : 12, 0, 8, 0),
        decoration: BoxDecoration(
          color: full ? const Color(0xFFDDF0FF) : Colors.white,
          // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
          border: Border.all(color: full ? const Color(0xFF2F6FB0) : AppColors.ink, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          boxShadow: AppShadows.solid(look.shadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collapsed) ...[
              // .dt-pail：奶桶圖示、百分比（滿了寫「滿了」），右邊一條分隔線
              Container(
                key: const Key('dock-pail'),
                height: 18,
                padding: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: full ? const Color(0xFF9CC6EE) : AppColors.lineSoft, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon('pail', size: 16),
                    const SizedBox(width: 2),
                    CssLine(
                      TextSpan(
                        text: full ? s.s03Full : '${data.pct}%',
                        style: AppText.number(13, lineHeight: 18, color: fg),
                      ),
                    ),
                  ],
                ),
              ),
              // margin-right 6，加上 .dt-pill 的 gap 2
              const SizedBox(width: 6 + 2),
            ],
            CssLine(
              TextSpan(
                text: collapsed ? s.s03Expand : s.s03Collapse,
                style: AppText.style(13, weight: FontWeight.w900, lineHeight: 18, color: fg),
              ),
            ),
            const SizedBox(width: 2),
            // 箭頭轉 90°（向下）；收起來時轉 −90°（向上）
            Transform.rotate(angle: (collapsed ? -1 : 1) * math.pi / 2, child: const AppIcon('chevron', size: 14)),
          ],
        ),
      ),
    );
  }
}

/// .fbar：飼料列（v0.3 第 2.2 節；沒有底板，第 26 輪）。一袋 68 寬、間隔 6，照設計稿 feeds.js 的順序；左右滑看其他的。
/// 延伸到畫面的左右邊緣（設計稿沒有裁切）：一開始第一袋在面板內 2，滑到底時最後一袋離畫面右邊 [inset]。
class _FeedBar extends StatelessWidget {
  const _FeedBar({required this.feeds, required this.inset});

  final Map<String, int> feeds;
  final double inset;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('feed-bar'),
    height: 73,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: inset),
      // 名字的白色描邊、泰文的上下標會超出袋子的範圍一點：不裁切（左右本來就是畫面的邊緣）
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, k) in kFeedOrder.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            _FeedItem(feed: k, n: feeds[k] ?? 0),
          ],
        ],
      ),
    ),
  );
}

/// .fb-item：飼料袋（54 × 58，置中）上面畫飼料的圖示、右上角剩幾份；下面寫名字（不寫公斤數，每次長幾公斤是隨機的）。
/// 沒有了（0 份）：袋子換淺灰的，袋子和名字都淡到 0.4（.fb-item.none）。
class _FeedItem extends StatelessWidget {
  const _FeedItem({required this.feed, required this.n});

  final String feed;
  final int n;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final name = s.feedName(feed);
    final none = n <= 0;
    Widget faded(Widget child) => none ? Opacity(opacity: 0.4, child: child) : child;
    return Semantics(
      container: true,
      label: s.s03FeedAria(name: name, n: n),
      child: ExcludeSemantics(
        child: SizedBox(
          key: Key('feed-$feed'),
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              faded(_Sack(feed: feed, n: n)),
              faded(_FeedName(name)),
            ],
          ),
        ),
      ),
    );
  }
}

/// .sack：袋子（parts/feed_sack，0 份用 feed_sack_empty）、飼料圖示（左上角 (15, 22)、24 × 24），兩張圖都有下面的影子
/// （.sack svg 的 drop-shadow 也套到圖示的 svg）；右上角的份數（.sk-n：右 −4、上 2、高 20、至少 20 寬，深色底白字）。
class _Sack extends StatelessWidget {
  const _Sack({required this.feed, required this.n});

  final String feed;
  final int n;

  @override
  Widget build(BuildContext context) {
    final asset = 'assets/ui/parts/${n <= 0 ? 'feed_sack_empty' : 'feed_sack'}.svg';
    return SizedBox(
      width: 54,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _DropShadow(child: SvgPicture.asset(asset, width: 54, height: 58, excludeFromSemantics: true)),
          Positioned(left: 15, top: 22, child: _DropShadow(child: AppIcon('feed_$feed', size: 24))),
          Positioned(
            right: -4,
            top: 2,
            child: Container(
              key: Key('feed-$feed-n'),
              height: 20,
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Center(
                widthFactor: 1,
                child: CssLine(
                  TextSpan(
                    text: '$n',
                    style: AppText.number(12, lineHeight: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS 的 filter: drop-shadow(0 3px 2px rgba(46, 29, 20, 0.35))：同一張圖染成影子的顏色、往下 3、模糊，墊在下面。
/// drop-shadow 的模糊值 Chrome 直接當標準差用（跟 box-shadow 不一樣，box-shadow 是一半），所以標準差是 2。
class _DropShadow extends StatelessWidget {
  const _DropShadow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: const Offset(0, 3),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x592E1D14), BlendMode.srcIn), child: child),
        ),
      ),
      child,
    ],
  );
}

/// .fb-name：12 特粗、行高 15，白色描邊 3（paint-order: stroke fill，描邊在字的下面）。不換行，比 68 寬的
/// （泰文的豆粕）兩邊一樣多超出去。
class _FeedName extends StatelessWidget {
  const _FeedName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final style = AppText.style(12, weight: FontWeight.w900, lineHeight: 15);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    return SizedBox(
      width: 68,
      height: 15,
      child: OverflowBox(
        minWidth: 0,
        maxWidth: double.infinity,
        child: Stack(
          children: [
            CssLine(
              TextSpan(
                text: name,
                style: style.copyWith(foreground: stroke),
              ),
            ),
            CssLine(TextSpan(text: name, style: style)),
          ],
        ),
      ),
    );
  }
}

/// .bucket-card：奶桶圖示（水位）、「奶桶」、百分比、進度條、「36.4 / 42 瓶」、多久滿、收奶鈕。
class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.data, required this.collect, this.pailKey});

  final DockData data;
  final Widget collect;
  final Key? pailKey;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final full = data.full;
    return Container(
      key: const Key('bucket-card'),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: _card(full ? const Color(0xFFFFF1EE) : AppColors.paper),
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-2, 0),
            child: PailLevel(key: pailKey, pct: data.pct.toDouble(), size: 44),
          ),
          const SizedBox(width: 8 - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // .bk-top：放不下時百分比換到下一行（screens.css 英文、泰文第二輪）
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    CardTitle(s.bucketTitle, color: AppColors.blue),
                    Text('${data.pct}%', style: AppText.number(20, lineHeight: 22, color: full ? _red : AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 4),
                MeterBar(fraction: data.pct / 100),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: AppText.style(12, weight: FontWeight.w700, lineHeight: 16),
                        children: fillSpans(
                          s.s03BucketCount(amount: '\u0000'),
                          AppText.number(13, lineHeight: 16),
                          '${data.bucketText} / ${fmt(data.bucketCap)}',
                        ),
                      ),
                      softWrap: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        full
                            ? s.s03FullStopped
                            : data.perHour > 0
                            ? s.s03FullIn(time: _untilFull(s))
                            : s.s03NoMilkers,
                        softWrap: false,
                        style: full
                            ? AppText.style(12, weight: FontWeight.w900, color: _red, lineHeight: 16)
                            : AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 76), child: collect),
        ],
      ),
    );
  }

  /// 還要多久滿：遊戲時間換成現實時間，進位到分鐘（設計稿 untilFull）。
  String _untilFull(Strings s) {
    final gameHours = (data.bucketCap - data.rateBucket) / data.perHour;
    final minutes = (gameHours * 60 / (data.timeScale > 0 ? data.timeScale : 1)).ceil();
    if (minutes < 1) return s.duration(m: 1);
    return s.duration(h: minutes ~/ 60, m: minutes % 60);
  }
}

const _red = Color(0xFFD9443F);

BoxDecoration _card(Color color, {double shadow = 4}) => BoxDecoration(
  color: color,
  border: Border.all(color: AppColors.ink, width: AppSizes.border),
  borderRadius: const BorderRadius.all(AppRadii.r18),
  boxShadow: AppShadows.solid(shadow),
);

/// 奶桶的瓶數：1000 以上寫整數加千分位，以下寫 1 位小數，.0 不寫（設計稿 oneDec）。
String oneDecimal(double v) {
  if (v >= 1000) return fmt(v.roundToDouble());
  final t = (v * 10).round() / 10;
  final str = t.toStringAsFixed(1);
  return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
}

/// 奶桶圖示，牛奶的水位跟著百分比（設計稿 s03.js 的 pailLevel，48×48 的座標）。
class PailLevel extends StatelessWidget {
  const PailLevel({super.key, required this.pct, required this.size});

  final double pct;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PailPainter(pct.clamp(0, 100).toDouble()));
}

class _PailPainter extends CustomPainter {
  _PailPainter(this.pct);

  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    const ink = AppColors.ink;
    Paint stroke(double w, [Color c = ink]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = c
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // 提把
    canvas.drawPath(
      Path()
        ..moveTo(11, 17)
        ..cubicTo(11, 5.5, 37, 5.5, 37, 17),
      stroke(2.6)..strokeCap = StrokeCap.butt,
    );
    // 桶身：M8 16.5h32l-3.4 25.4a3 3 0 0 1-3 2.6H14.4a3 3 0 0 1-3-2.6z
    final body = Path()
      ..moveTo(8, 16.5)
      ..lineTo(40, 16.5)
      ..lineTo(36.6, 41.9)
      ..arcToPoint(const Offset(33.6, 44.5), radius: const Radius.circular(3))
      ..lineTo(14.4, 44.5)
      ..arcToPoint(const Offset(11.4, 41.9), radius: const Radius.circular(3))
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFD6ECFA));
    // 牛奶：水位線是一道波浪
    const top = 17.0, bot = 44.5;
    final l = bot - (bot - top) * (pct / 100);
    final wave = Path()..moveTo(0, l);
    for (var i = 0; i < 4; i++) {
      wave.quadraticBezierTo(i * 12 + 6, l + (i.isEven ? -2.6 : 2.6), i * 12 + 12, l);
    }
    final milk = Path.from(wave)
      ..lineTo(48, 48)
      ..lineTo(0, 48)
      ..close();
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(milk, Paint()..color = Colors.white);
    canvas.drawPath(wave, stroke(1.6, const Color(0xFFB9DDF5))..strokeCap = StrokeCap.butt);
    canvas.restore();
    canvas.drawPath(body, stroke(2.6));
    // 反光
    canvas.drawLine(const Offset(13.5, 22), const Offset(13.5, 37), stroke(2.4, Colors.white.withValues(alpha: 0.9)));
    // 桶口
    final rim = RRect.fromRectAndRadius(const Rect.fromLTWH(6.4, 13.6, 35.2, 5.4), const Radius.circular(2.7));
    canvas.drawRRect(rim, Paint()..color = const Color(0xFFEAF5FC));
    canvas.drawRRect(rim, stroke(2.4));
  }

  @override
  bool shouldRepaint(_PailPainter old) => old.pct != pct;
}
