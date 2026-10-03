// 共用元件，照設計稿 design/m2/src/css/kit.css（R1-A「圓潤Q版」：3px 可可色粗描邊、扁平粉彩、實心下陰影）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/tokens.dart';
import 'app_icon.dart';
import 'press.dart';

/// kit.css 的文字樣式。
abstract final class KitText {
  /// .hint：次要說明。
  static TextStyle hint({double size = 13, double lineHeight = 19}) =>
      AppText.style(size, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: lineHeight);

  /// .err-text：錯誤說明。
  static TextStyle err({double size = 13, double lineHeight = 19}) =>
      AppText.style(size, weight: FontWeight.w900, color: errText, lineHeight: lineHeight);

  /// .warn-text：警告說明。
  static TextStyle warn({double size = 13, double lineHeight = 19}) =>
      AppText.style(size, weight: FontWeight.w900, color: const Color(0xFFC2541B), lineHeight: lineHeight);

  static const errText = Color(0xFFC9302C);
}

/// 按鈕底色（.btn.primary、.blue…）。
enum ButtonKind {
  normal(Colors.white),
  primary(AppColors.yellow),
  blue(AppColors.blue),
  green(AppColors.green),
  pink(AppColors.pink),
  danger(AppColors.redSoft);

  const ButtonKind(this.color);
  final Color color;
}

/// .hero-bg：大圖卡的天空草地（上 62% 天空、下面草地）。牛的詳細（S04）、圖鑑的品種（S09）用。
const kHeroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBFE6FF), Color(0xFFE4F6FF), Color(0xFFCDEFB4), Color(0xFFBDEBA4)],
  stops: [0, 0.62, 0.625, 1],
);

/// 一般 div 的一行（16px、行高 normal = 19 + 5）：裡面的粗體字比較小時，行高還是照 div 的（CSS 的 strut）。
const kDivStrut = StrutStyle(fontFamily: AppText.family, fontSize: 16, height: 24 / 16);

/// .btn：粗描邊、實心下陰影。[onPressed] 是 null 就停用；[busy] 時換成轉圈、也停用（G-06）。
/// [block] 撐滿整行，字放不下可以換行（screens.css 第 12 條：英文、泰文放不下才換行）；不是 block 就不換行。
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = ButtonKind.normal,
    this.small = false,
    this.block = false,
    this.icon,
    this.busy = false,
    this.wrap = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final bool small;
  final bool block;
  final String? icon;
  final bool busy;

  /// 不是整排寬的按鈕，被擠的時候字可以換行（頁首右邊的按鈕，screens.css 第 1 條）；放得下就照自己的寬度。
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    // 處理中跟停用一樣是灰底、淡框（kit.css 的 .btn[disabled]），只有字是 ink-2、前面轉圈（.btn.busy；G-06）
    final line = enabled ? AppColors.ink : AppColors.disabledLine;
    final fg = busy ? AppColors.ink2 : (enabled ? AppColors.ink : AppColors.ink3);
    final bg = enabled ? kind.color : AppColors.disabledBg;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      softWrap: block || wrap,
      overflow: block || wrap ? null : TextOverflow.visible,
      style: AppText.style(small ? 14 : 16, weight: FontWeight.w900, color: fg, lineHeight: 20),
    );
    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[const Spinner(), const SizedBox(width: 6)],
        if (!busy && icon != null) ...[AppIcon(icon!, size: small ? 18 : 22), const SizedBox(width: 6)],
        if (block || wrap) Flexible(child: text) else text,
      ],
    );
    final radius = BorderRadius.all(small ? AppRadii.r14 : AppRadii.r16);
    // 自己一個無障礙節點（container）：不然同一張卡上的字會併進按鈕，例：田地卡片的「派耕牛」讀成
    // 「第 2 塊田 空田 空田：派一頭成年耕牛來種稻。 派耕牛」（8790 走查找不到「派耕牛」）
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      // 按下：大按鈕往下 3、小按鈕往下 2，陰影變 1（G-11、G-12）；停用和處理中不變
      child: Pressable(
        lift: small ? 3 : 4,
        onTap: enabled ? onPressed : null,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(minHeight: small ? 44 : 48, minWidth: AppSizes.minTouch),
            padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: 4),
            alignment: block ? Alignment.center : null,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: line, width: AppSizes.border),
              borderRadius: radius,
              boxShadow: [BoxShadow(color: line, offset: Offset(0, look.shadow))],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// .card：卡片底、粗描邊、圓角 18、下陰影 4。[color] 是換過底色的卡（例：田地長滿了的淡黃）。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.color = AppColors.paper,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r18),
      boxShadow: AppShadows.solid(4),
    ),
    child: child,
  );
}

/// .dialog 加 .backdrop：整個畫面蓋一層暗幕，對話框左右各留 20、在整個畫面的正中間（top: 50%）。
class AppDialog extends StatelessWidget {
  const AppDialog({super.key, this.title, required this.body, this.buttons = const []});

  final String? title;
  final Widget body;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    // 上下留一樣多（安全區比較大的那邊），對話框才會在整個畫面的正中間；太高時可以捲
    final v = pad.top > pad.bottom ? pad.top : pad.bottom;
    final card = Container(
      key: const Key('dialog'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        boxShadow: AppShadows.solid(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
            ),
            const SizedBox(height: 8),
          ],
          DefaultTextStyle.merge(
            style: AppText.style(14, weight: FontWeight.w700, lineHeight: 21),
            child: body,
          ),
          if (buttons.isNotEmpty) ...[const SizedBox(height: 16), BtnRow(children: buttons)],
        ],
      ),
    );
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.backdrop)),
        Positioned.fill(
          child: Center(
            child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, v, 20, v), child: card),
          ),
        ),
      ],
    );
  }
}

/// .spinner：18×18 的圈，上緣深色。手機開了「減少動態」就不轉。
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 18});

  final double size;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _turn,
    child: CustomPaint(size: Size.square(widget.size), painter: _SpinnerPainter()),
  );
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 3.0;
    final rect = (Offset.zero & size).deflate(w / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawArc(rect, 0, math.pi * 2, false, ring..color = AppColors.ink.withValues(alpha: 0.25));
    // border-top-color：上面那一段（−135° 到 −45°）
    canvas.drawArc(rect, -math.pi * 3 / 4, math.pi / 2, false, ring..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => false;
}

/// 提示的種類（G-04：成功、伺服器拒絕、網路錯誤…）。
enum ToastKind {
  ok('ok', Color(0xFFF1FBEA)),
  err('err', Color(0xFFFFF0EE)),
  warn('warn', Color(0xFFFFF5E6)),
  info('info', Colors.white);

  const ToastKind(this.icon, this.color);
  final String icon;
  final Color color;
}

/// .toast：膠囊形的提示（圖示＋一句話）。放在哪裡由用的地方決定。
class ToastPill extends StatelessWidget {
  const ToastPill(this.text, {super.key, this.kind = ToastKind.info, this.action});

  final String text;
  final ToastKind kind;

  /// 右邊的按鈕（.toast.action-toast，例：倉庫滿了→「加大倉庫」）。
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(10, 9, action == null ? 16 : 8, 9),
    decoration: BoxDecoration(
      color: kind.color,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r22),
      boxShadow: AppShadows.solid(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(kind.icon, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: AppText.style(14, weight: FontWeight.w900, lineHeight: action == null ? 20 : 19),
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8 + 2), action!],
      ],
    ),
  );
}

/// 把字串裡的佔位記號（\u0000）換成另一個樣式的字，例：「{v} 幣」的數字特粗大一號。
List<InlineSpan> fillSpans(String text, TextStyle style, String value) {
  final parts = text.split('\u0000');
  return [
    for (final (i, p) in parts.indexed) ...[
      if (i > 0) TextSpan(text: value, style: style),
      if (p.isNotEmpty) TextSpan(text: p),
    ],
  ];
}

/// 相鄰的全形標點擠掉半格（Chrome 預設的 text-spacing-trim: normal 裡的 trim-adjacent；設計稿是 Chrome 畫的）：
/// 收尾標點後面又接收尾標點（例：「…牧場」、所有…」的「」」），前一個擠掉後半格；開頭標點前面也是開頭標點，後一個擠掉前半格。
/// Flutter 不會自己做，用字型的 halt（半形寬）把要擠的那個字變成半格。
List<InlineSpan> cjkTrimSpans(String text) {
  bool closing(String c) => '」』）〕】》〉、。，．：；'.contains(c);
  bool opening(String c) => '「『（〔【《〈'.contains(c);
  final chars = text.characters.toList();
  final spans = <InlineSpan>[];
  final run = StringBuffer();
  for (final (i, c) in chars.indexed) {
    final trim =
        (closing(c) && i + 1 < chars.length && closing(chars[i + 1])) || (opening(c) && i > 0 && opening(chars[i - 1]));
    if (!trim) {
      run.write(c);
      continue;
    }
    if (run.isNotEmpty) spans.add(TextSpan(text: run.toString()));
    run.clear();
    spans.add(
      TextSpan(
        text: c,
        style: const TextStyle(fontFeatures: [FontFeature.enable('halt')]),
      ),
    );
  }
  if (run.isNotEmpty) spans.add(TextSpan(text: run.toString()));
  return spans;
}

/// .btn-row：並排的按鈕（每顆 flex: 1、間距 10）。放不下時換到下一排、撐滿整排（screens.css 第 12 條：英文、泰文放不下才換行）。
/// 跟 CSS 的 flex-wrap 一樣：每顆最窄是自己的字不換行的寬度；一排放得下就平分，有一顆比平分還寬就照它的寬、其他的分剩下的。
class BtnRow extends MultiChildRenderObjectWidget {
  const BtnRow({super.key, required super.children, this.gap = 10});

  final double gap;

  @override
  RenderBtnRow createRenderObject(BuildContext context) => RenderBtnRow(gap);

  @override
  void updateRenderObject(BuildContext context, RenderBtnRow renderObject) => renderObject.gap = gap;
}

class BtnRowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBtnRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, BtnRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, BtnRowParentData> {
  RenderBtnRow(this._gap);

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BtnRowParentData) child.parentData = BtnRowParentData();
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  /// 分排：一排的最窄寬度加間距超過 [width] 就換下一排（第一顆一定放得下）。
  List<List<int>> _lines(List<double> mins, double width) {
    final lines = <List<int>>[];
    var used = 0.0;
    for (var i = 0; i < mins.length; i++) {
      if (lines.isEmpty || used + gap + mins[i] > width + 0.01) {
        lines.add([i]);
        used = mins[i];
      } else {
        lines.last.add(i);
        used += gap + mins[i];
      }
    }
    return lines;
  }

  /// 一排裡每顆的寬：平分；比平分的寬還窄不下去的照自己的最窄寬度，剩下的再平分（CSS flex: 1 的最小寬度）。
  List<double> _widths(List<double> mins, double width) {
    final free = width - gap * (mins.length - 1);
    final out = List<double?>.filled(mins.length, null);
    while (true) {
      final open = [
        for (var i = 0; i < mins.length; i++)
          if (out[i] == null) i,
      ];
      if (open.isEmpty) break;
      final left =
          free -
          [
            for (var i = 0; i < mins.length; i++)
              if (out[i] != null) out[i]!,
          ].fold(0.0, (a, b) => a + b);
      final share = left / open.length;
      final frozen = [
        for (final i in open)
          if (mins[i] > share) i,
      ];
      if (frozen.isEmpty) {
        for (final i in open) {
          out[i] = math.max(0, share);
        }
        break;
      }
      for (final i in frozen) {
        out[i] = mins[i];
      }
    }
    return [for (final w in out) w!];
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final kids = _kids;
    final width = constraints.maxWidth;
    if (kids.isEmpty || !width.isFinite) return constraints.smallest;
    final mins = [for (final c in kids) c.getMaxIntrinsicWidth(double.infinity)];
    var y = 0.0;
    for (final (n, line) in _lines(mins, width).indexed) {
      final widths = _widths([for (final i in line) mins[i]], width);
      // 一排的高是最高的那顆，其他的撐到一樣高（align-items: stretch）
      final height = [
        for (final (j, i) in line.indexed)
          dry
              ? kids[i].getDryLayout(BoxConstraints.tightFor(width: widths[j])).height
              : (kids[i]..layout(BoxConstraints.tightFor(width: widths[j]), parentUsesSize: true)).size.height,
      ].reduce(math.max);
      if (n > 0) y += gap;
      var x = 0.0;
      for (final (j, i) in line.indexed) {
        if (!dry) {
          kids[i].layout(BoxConstraints.tightFor(width: widths[j], height: height));
          (kids[i].parentData! as BtnRowParentData).offset = Offset(x, y);
        }
        x += widths[j] + gap;
      }
      y += height;
    }
    return constraints.constrain(Size(width, y));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _kids.fold(0.0, (a, c) => math.max(a, c.getMaxIntrinsicWidth(double.infinity)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    final kids = _kids;
    if (kids.isEmpty) return 0;
    return kids.fold(0.0, (a, c) => a + c.getMaxIntrinsicWidth(double.infinity)) + gap * (kids.length - 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// .sheet 加 .backdrop：從下面滑上來的面板（暗幕、上緣 3px 框、上面兩個圓角 26、把手、標題）。點暗幕關掉。
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, this.title, required this.children, required this.onClose, this.maxHeight});

  /// 標題（.sheet h2）；null 是沒有標題的面板（S21 的徽章詳細，名稱放在大圖下面）。
  final String? title;
  final List<Widget> children;
  final VoidCallback onClose;

  /// 整個面板最高多高（含上緣的框和內距，跟 CSS 的 border-box 一樣）。有給的話，[children] 裡可以放 Flexible
  /// （例：選耕牛的清單），放不下時由它縮、自己捲。
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: const ColoredBox(color: AppColors.backdrop),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('sheet'),
            constraints: maxHeight == null ? null : BoxConstraints(maxHeight: maxHeight!),
            padding: EdgeInsets.fromLTRB(16, 10, 16, safe.bottom + 14),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(
                top: BorderSide(color: AppColors.ink, width: AppSizes.border),
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.disabledLine,
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
                if (title case final t?) ...[
                  Text(t, style: AppText.style(18, weight: FontWeight.w900, lineHeight: 24)),
                  const SizedBox(height: 10),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 一行不換行的字，照 Chrome（Linux）排 CSS line-height 的方式定高度和基線。設計稿是 Chrome 畫的；同一行有大小不同的字
/// （例：「14 <small>瓶／時</small>」）或字比行高大的時候，Flutter 的排法會差 1 px 左右，版面跟著偏。
/// Chrome 的算法：每段字的 ascent、descent 各自四捨五入（descent 被捨去時從 ascent 借 1 給 descent）；行高多出來（或不夠）的
/// 部分，上面放 floor(一半)、其餘放下面；整行的上緣取各段最高的、下緣取最低的，也算進外層的字（CSS 的 strut）。
/// 字型是 Noto Sans CJK 的 hhea（ascent 1.16、descent 0.288 字級）。
/// 只排一行；[wrap] 的話，一行放不下（英文、泰文的窄手機）就照一般的字換行。
class CssLine extends StatelessWidget {
  const CssLine(this.span, {super.key, this.textKey, this.wrap = false, this.textAlign, this.ellipsis = false});

  final TextSpan span;
  final Key? textKey;
  final bool wrap;

  /// 放不下時用「…」截短（CSS 的 text-overflow: ellipsis；S21 的牧場名）。
  final bool ellipsis;

  /// 放不下、換行的時候怎麼對齊（一行的時候由外層決定位置）。
  final TextAlign? textAlign;

  /// 這一行在 Chrome 的（基線以上、基線以下）。
  static (double, double) metrics(TextSpan span) {
    var above = 0.0, below = 0.0;
    void add(TextStyle s) {
      final size = s.fontSize;
      if (size == null) return;
      var asc = (size * 1.16).roundToDouble(), desc = (size * 0.288).roundToDouble();
      if (desc < size * 0.288 && asc >= 1) {
        desc += 1;
        asc -= 1;
      }
      final h = s.height;
      if (h != null) {
        final leading = h * size - (asc + desc);
        final top = (leading / 2).floorToDouble();
        asc += top;
        desc += leading - top;
      }
      above = math.max(above, asc);
      below = math.max(below, desc);
    }

    void visit(InlineSpan s, TextStyle? inherited) {
      final style = inherited == null ? s.style : inherited.merge(s.style);
      if (s is! TextSpan || style == null) return;
      if (inherited == null || (s.text ?? '').isNotEmpty) add(style);
      for (final c in s.children ?? const <InlineSpan>[]) {
        visit(c, style);
      }
    }

    visit(span, null);
    return (above, below);
  }

  @override
  Widget build(BuildContext context) {
    final (above, below) = metrics(span);
    Widget line() => SizedBox(
      height: above + below,
      child: Baseline(
        baseline: above,
        baselineType: TextBaseline.alphabetic,
        child: Text.rich(
          span,
          key: textKey,
          softWrap: false,
          maxLines: ellipsis ? 1 : null,
          overflow: ellipsis ? TextOverflow.ellipsis : null,
        ),
      ),
    );
    if (!wrap) return line();
    return LayoutBuilder(
      builder: (context, c) {
        final p = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = p.width <= c.maxWidth + 0.5;
        p.dispose();
        return fits ? line() : Text.rich(span, key: textKey, textAlign: textAlign);
      },
    );
  }
}

/// 會換行的段落，字照 Chrome 的基線畫（同一個字級的段落用）。行高跟 CSS 一樣，但 Flutter 把行高多出來（或不夠）的部分
/// 照字型的上下比例分，Chrome 是上下各自四捨五入、再上面放 floor(一半)（[CssLine]），每一行的字都差一樣多，
/// 例：14px、行高 22 的字 Flutter 比設計稿低 1.6。版面不動，只把畫出來的字移回 Chrome 的位置。
class CssParagraph extends StatelessWidget {
  const CssParagraph(this.span, {super.key, required this.style, this.textAlign});

  final TextSpan span;

  /// 整段的字級和行高（[span] 裡的字用同一個字級）。
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize!;
    final (above, _) = CssLine.metrics(TextSpan(text: ' ', style: style));
    // Flutter 的基線：有行高時照 1.16 : 0.288 分，沒有就是字型的 ascent
    final h = style.height;
    final flutter = h == null ? 1.16 * size : h * size * 1.16 / (1.16 + 0.288);
    return Transform.translate(
      offset: Offset(0, above - flutter),
      child: Text.rich(span, style: style, textAlign: textAlign),
    );
  }
}

/// 2px 的淡色虛線上緣（.link-row、.detail-actions 的 border-top: 2px dashed）：線段 6、間隔約 4，頭尾都是完整的線段。
class DashedTopLine extends CustomPainter {
  const DashedTopLine();

  static const _dash = 6.0, _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final n = ((w + _gap) / (_dash + _gap)).floor().clamp(1, 1 << 20);
    final gap = n > 1 ? (w - n * _dash) / (n - 1) : 0.0;
    final paint = Paint()..color = AppColors.lineSoft;
    for (var i = 0; i < n; i++) {
      canvas.drawRect(Rect.fromLTWH(i * (_dash + gap), 0, _dash, 2), paint);
    }
  }

  @override
  bool shouldRepaint(DashedTopLine oldDelegate) => false;
}
