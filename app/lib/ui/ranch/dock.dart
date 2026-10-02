// 牧場頁下面的面板（設計稿 s03.js 的 dock、screens.css 的 .dock）：奶桶、倉庫、收購價。
// 右上角可以收起來（只剩一條奶桶和收奶鈕，S03-11、S03-12），中間的小滑塊是場景的位置（S03-13）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/press.dart';
import 'scene.dart';

/// 面板要顯示的數字（都來自伺服器的 state、行情；奶桶是平滑推算的顯示值）。
class DockData {
  const DockData({
    required this.bucket,
    required this.bucketCap,
    required this.perHour,
    required this.timeScale,
    required this.warehouse,
    required this.quotes,
    required this.upIsRed,
  });

  final double bucket;
  final double bucketCap;
  final double perHour; // 遊戲時間每小時
  final double timeScale;
  final Warehouse warehouse;
  final Map<Commodity, Quote> quotes;
  final bool upIsRed;

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
    this.onStorage,
  });

  final DockData data;
  final bool collapsed;
  final double pan;
  final VoidCallback onToggle;

  /// 點倉庫卡：打開倉庫詳細頁（S05-02）。
  final VoidCallback? onStorage;

  /// 收奶鈕（停用、轉圈由外面決定）。
  final Widget collect;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      key: const Key('dock'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .dock-head：高 44、margin-bottom −6，加上 .dock 的 gap 8：下面的卡片離它 2
        SizedBox(
          height: 44 - 6 + 8,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    label: s.s03PanAria,
                    child: _PanIndicator(pan: pan),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Semantics(
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
                          child: _TogglePill(collapsed: collapsed, look: look),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (collapsed)
          _BucketSlim(data: data, collect: collect)
        else ...[
          _BucketCard(data: data, collect: collect),
          const SizedBox(height: 8),
          // .dock-row：倉庫、收購價兩張小卡（S05-01 只拍這一塊）
          IntrinsicHeight(
            key: const Key('dock-row'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StorageMini(data: data, onTap: onStorage),
                ),
                const SizedBox(width: 8),
                Expanded(child: _MarketMini(data: data)),
              ],
            ),
          ),
        ],
      ],
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

/// .dt-pill：「收起 ⌄」「展開 ⌃」。
class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.collapsed, required this.look});

  final bool collapsed;
  final PressLook look;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PressTint(
      tint: look.tint,
      borderRadius: const BorderRadius.all(Radius.circular(15)),
      child: Container(
        height: 30,
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          boxShadow: AppShadows.solid(look.shadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              collapsed ? s.s03Expand : s.s03Collapse,
              style: AppText.style(13, weight: FontWeight.w900, lineHeight: 18),
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

/// .bucket-card：奶桶圖示（水位）、「奶桶」、百分比、進度條、「36.4 / 42 瓶」、多久滿、收奶鈕。
class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.data, required this.collect});

  final DockData data;
  final Widget collect;

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
            child: PailLevel(pct: data.pct.toDouble(), size: 44),
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
                          '${oneDecimal(data.bucket)} / ${fmt(data.bucketCap)}',
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
    final gameHours = (data.bucketCap - data.bucket) / data.perHour;
    final minutes = (gameHours * 60 / (data.timeScale > 0 ? data.timeScale : 1)).ceil();
    if (minutes < 1) return s.duration(m: 1);
    return s.duration(h: minutes ~/ 60, m: minutes % 60);
  }
}

/// .bucket-slim：收起來的那一條（S03-11、S03-12）。
class _BucketSlim extends StatelessWidget {
  const _BucketSlim({required this.data, required this.collect});

  final DockData data;
  final Widget collect;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final full = data.full;
    return Container(
      key: const Key('bucket-slim'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: _card(full ? const Color(0xFFFFF1EE) : AppColors.paper),
      child: Row(
        children: [
          PailLevel(pct: data.pct.toDouble(), size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(s.bucketTitle, style: AppText.style(13, weight: FontWeight.w900)),
                    Text('${data.pct}%', style: AppText.number(16, lineHeight: 18, color: full ? _red : AppColors.ink)),
                    if (full)
                      Text(
                        s.s03Full,
                        style: AppText.style(12, weight: FontWeight.w900, color: _red),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                MeterBar(fraction: data.pct / 100, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 76), child: collect),
        ],
      ),
    );
  }
}

/// .card.mini.storage：倉庫的牛奶（用了幾 %、最舊一批的新鮮度）、牛肉、稻米。
class _StorageMini extends StatelessWidget {
  const _StorageMini({required this.data, this.onTap});

  final DockData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final w = data.warehouse;
    final milk = w.milkTotal, cap = w.capacity;
    final whFull = cap > 0 && milk >= cap;
    final fresh = w.worstFreshness;
    return _Mini(
      key: const Key('storage-mini'),
      onTap: onTap,
      title: CardTitle(s.warehouseTitle),
      // 滿了：設計稿程式加了 err-text，但 .mini .cap 的顏色、粗細比較優先，核准的圖是灰色的字；照圖做
      caption: whFull
          ? Text(
              s.s03MilkFull,
              softWrap: false,
              style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
            )
          : Text(
              s.s03MilkUsed(pct: cap > 0 ? (milk / cap * 100).round() : 0),
              textAlign: TextAlign.right,
              style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
            ),
      lines: [
        _MiniLine(
          icon: 'milk',
          name: s.milk,
          value: compact(milk, s.lang),
          unit: s.unitMilk,
          right: fresh == null
              ? null
              : _Trailing(
                  icon: fresh < 0.3 ? 'leafBad' : (fresh < 0.7 ? 'leafOld' : 'leaf'),
                  iconSize: 13,
                  text: '${(fresh * 100).round()}%',
                  color: fresh < 0.3 ? _red : AppColors.ink,
                ),
        ),
        _MiniLine(icon: 'beef', name: s.beef, value: compact(w.beefTotal, s.lang), unit: s.unitBeef),
        _MiniLine(icon: 'rice', name: s.rice, value: compact(w.riceTotal, s.lang), unit: s.unitRice),
      ],
    );
  }
}

/// .card.mini.market：三種商品的收購價和比平常高或低幾 %（D24）。
class _MarketMini extends StatelessWidget {
  const _MarketMini({required this.data});

  final DockData data;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    Widget line(Commodity c, String icon, String name) {
      final q = data.quotes[c];
      return _MiniLine(
        icon: icon,
        name: name,
        value: q == null ? '–' : priceText(q.price),
        right: q == null ? null : _vsNormal(s, q),
      );
    }

    return _Mini(
      key: const Key('market-mini'),
      title: CardTitle(s.s03Prices, color: AppColors.green),
      caption: Text(
        s.s03VsNormal,
        style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
      ),
      lines: [
        line(Commodity.milk, 'milk', s.milk),
        line(Commodity.beef, 'beef', s.beef),
        line(Commodity.rice, 'rice', s.rice),
      ],
    );
  }

  /// 比平常（基本價）高或低幾 %，四捨五入到整數；0 就寫「平常」（fixtures.js 的 vsBase）。
  Widget _vsNormal(Strings s, Quote q) {
    final v = q.vsBasePct;
    if (v == null) return const SizedBox.shrink();
    if (v == 0) {
      return Text(
        s.s03Normal,
        style: AppText.style(12, weight: FontWeight.w900, color: AppColors.ink2),
      );
    }
    final up = v > 0;
    return _Trailing(
      icon: up ? 'up' : 'down',
      iconSize: 10,
      text: '${v.abs()}%',
      color: up ? AppColors.up(upIsRed: data.upIsRed) : AppColors.down(upIsRed: data.upIsRed),
    );
  }
}

/// .card.mini：標題列、三行。
class _Mini extends StatelessWidget {
  const _Mini({super.key, required this.title, required this.caption, required this.lines, this.onTap});

  final Widget title;
  final Widget caption;
  final List<Widget> lines;

  /// 可以點（倉庫卡）：整張卡浮起，按下往下 3（G-13）。
  final VoidCallback? onTap;

  Widget _box(double shadow) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
    decoration: _card(AppColors.paper, shadow: shadow),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .card-head：放不下時標頭換到第二行（screens.css 第 6 條）
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [title, caption],
        ),
        const SizedBox(height: 3),
        ...lines,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return _box(4);
    return Pressable(
      lift: 4,
      onTap: onTap,
      builder: (context, look) =>
          PressTint(tint: look.tint, borderRadius: const BorderRadius.all(AppRadii.r18), child: _box(look.shadow)),
    );
  }
}

/// .mini-line：圖示、名稱、數字、單位，右邊一個小欄位。窄手機字小一號，再窄就不放圖示（screens.css 的 @media）。
class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.icon, required this.name, required this.value, this.unit, this.right});

  final String icon;
  final String name;
  final String value;
  final String? unit;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 390, tiny = w < 340;
    final gap = narrow ? 3.0 : 4.0;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          // 設計稿這一行不換行；真的放不下（泰文 360 的最大數字）就把左邊整組縮小一點，不裁切、不疊到右邊
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!tiny) ...[
                    SizedBox(
                      width: narrow ? 16 : 19,
                      child: Center(child: AppIcon(icon, size: narrow ? 16 : 18)),
                    ),
                    SizedBox(width: gap),
                  ],
                  Text(name, style: AppText.style(narrow ? 12 : 13, weight: FontWeight.w700, lineHeight: 20)),
                  SizedBox(width: gap),
                  Text(value, style: AppText.number(narrow ? 13 : 14, lineHeight: 20)),
                  if (unit != null) ...[
                    SizedBox(width: gap),
                    Text(unit!, style: AppText.style(12, weight: FontWeight.w700, lineHeight: 20)),
                  ],
                ],
              ),
            ),
          ),
          if (right != null) ...[SizedBox(width: gap), right!],
        ],
      ),
    );
  }
}

/// .mini-line .r：右邊的小圖示加數字。
class _Trailing extends StatelessWidget {
  const _Trailing({required this.icon, required this.iconSize, required this.text, required this.color});

  final String icon;
  final double iconSize;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: iconSize, color: color),
      SizedBox(width: MediaQuery.sizeOf(context).width < 390 ? 1 : 2),
      // .mini-line .num：14（窄手機 13）
      Text(text, style: AppText.number(MediaQuery.sizeOf(context).width < 390 ? 13 : 14, color: color)),
    ],
  );
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
