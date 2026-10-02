// 共用元件，照設計稿 design/m2/src/css/kit.css（R1-A「圓潤Q版」：3px 可可色粗描邊、扁平粉彩、實心下陰影）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final line = enabled || busy ? AppColors.ink : AppColors.disabledLine;
    final fg = busy ? AppColors.ink2 : (enabled ? AppColors.ink : AppColors.ink3);
    final bg = enabled || busy ? kind.color : AppColors.disabledBg;
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
    return Semantics(
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

/// .card：卡片底、粗描邊、圓角 18、下陰影 4。
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.paper,
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
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: b)],
              ],
            ),
          ],
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
