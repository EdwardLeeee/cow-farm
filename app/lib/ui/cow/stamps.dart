// 小牛的飼料集點卡（v0.3 第 1 節；使用者 2026-10-08 選第 15 輪 01-C、D35 補充 3；設計稿 stamps.js、screens.css 的
// .stamp-card、.fl-stamps、.want、.grow-alert）：小牛長大前要吃到的飼料（稀有、傳說的品種各指定 1–2 種，伺服器出生時就
// 知道：cows[].need），吃過一種蓋一個章（cows[].ate）；一般、優良的寫「什麼都可以吃」。不寫機率。
// 牛的詳細（StampCard）、牛舍清單（StampLine）、牧場的想吃泡泡（WantBubble）、快長大的提醒卡（GrowAlertCard）。
import 'package:flutter/material.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/press.dart';

/// 還沒吃的飼料（照 need 的順序）。
List<String> feedTodo(Cow c) => [
  for (final k in c.need)
    if (!c.ate.contains(k)) k,
];

/// 「1 / 2」：吃過幾種 / 要吃幾種。
String stampCount(Cow c) => '${c.need.length - feedTodo(c).length} / ${c.need.length}';

/// app 有圖示的飼料（assets/ui/icons/feed_*.svg，協定 1.6 的六種）。
const kFeedIcons = {'grass', 'hay', 'oats', 'alfalfa', 'corn', 'soy'};

/// 飼料圖示（ui/icons/feed_<種類>）；還沒吃的淡淡的（.feed-ic 的 opacity 0.45）。
Widget feedIcon(String feed, double size, {bool faded = false}) {
  // 伺服器之後新加的飼料（app 還沒有圖示）：留一樣大的空位，不去讀不存在的圖
  if (!kFeedIcons.contains(feed)) return SizedBox.square(dimension: size);
  final icon = AppIcon('feed_$feed', size: size);
  return faded ? Opacity(opacity: 0.45, child: icon) : icon;
}

const _green = Color(0xFF3E8E2F);
const _stampRed = Color(0xFFE0483E);
const _ringLine = Color(0xFFD9B98C);

/// .stamp-card：牛的詳細（S04-08、S04-22）的飼料集點卡。米黃底、深色虛線框；右上角「1 / 2」。
/// 一格一種要吃的飼料：吃過的是實線圈、右下角一個紅色「吃過」章；還沒吃的是淡色虛線圈、飼料淡淡的。
/// 下面一行「集滿再長大，才不會變成雜種牛」。不用吃指定飼料的（一般、優良）寫「什麼都可以吃」。
class StampCard extends StatelessWidget {
  const StampCard({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final title = Text(s.s04StampTitle, style: AppText.style(16, weight: FontWeight.w700, lineHeight: 22));
    return CustomPaint(
      key: const Key('stamp-card'),
      foregroundPainter: const DashedBorder(color: AppColors.ink, radius: 18, width: AppSizes.border, chrome: true),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12 + 3, 10 + 3, 12 + 3, 12 + 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          borderRadius: const BorderRadius.all(AppRadii.r18),
          boxShadow: AppShadows.solid(4),
        ),
        child: cow.need.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 2),
                  // .any-line：綠色勾、「什麼都可以吃」
                  Row(
                    children: [
                      const AppIcon('ok', size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.s04EatAny,
                          style: AppText.style(16, weight: FontWeight.w900, color: _green, lineHeight: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // .sc-head：右邊「1 / 2」是 18 特粗、行高 normal（Noto Sans CJK 的 18px 是 21 + 5），這一列 26 高
                  Row(
                    children: [
                      Expanded(child: title),
                      Text(stampCount(cow), key: const Key('stamp-count'), style: AppText.number(18, lineHeight: 26)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 22,
                    runSpacing: 8,
                    children: [for (final k in cow.need) _Stamp(feed: k, done: cow.ate.contains(k))],
                  ),
                  const SizedBox(height: 8),
                  Text(s.s04StampRule, style: KitText.hint()),
                ],
              ),
      ),
    );
  }
}

/// 一格章：圈 70（.st-ring）裡面飼料 34，下面飼料名（15／20）。
class _Stamp extends StatelessWidget {
  const _Stamp({required this.feed, required this.done});

  final String feed;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final ring = Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: done ? const Color(0xFFFFFDF6) : Colors.white,
        shape: BoxShape.circle,
        border: done ? Border.all(color: AppColors.ink, width: 3) : null,
      ),
      child: Center(child: feedIcon(feed, 34, faded: !done)),
    );
    return Column(
      key: Key('stamp-$feed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            done
                ? ring
                : CustomPaint(
                    foregroundPainter: const DashedBorder(color: _ringLine, radius: 35, width: 3, chrome: true),
                    child: ring,
                  ),
            // .st-ink：右下角的紅色「吃過」章（右 −14、下 −8，從圈的框內量；轉 −14°）
            if (done)
              Positioned(
                right: -14 + 3,
                bottom: -8 + 3,
                child: Transform.rotate(
                  angle: -14 * 3.141592653589793 / 180,
                  child: Container(
                    key: Key('stamp-ink-$feed'),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EE),
                      shape: BoxShape.circle,
                      border: Border.all(color: _stampRed, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        s.s04Stamped,
                        softWrap: false,
                        style: AppText.style(12, weight: FontWeight.w900, color: _stampRed, lineHeight: 12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(s.feedName(feed), style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20)),
      ],
    );
  }
}

/// .fl-stamps：牛舍清單小牛那一列（S03-07、S03-33）的一排小章（28，裡面飼料 18）和「1 / 2」；都吃過了加「集滿了」。
/// 不用吃指定飼料的寫「什麼都可以吃」（.meta.fl-any）。
class StampLine extends StatelessWidget {
  const StampLine({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    if (cow.need.isEmpty) {
      // .cow-row .meta.fl-any：跟上面那行說明一樣（12／17、粗、淡色）。.fl-any 寫的綠色特粗被 .cow-row .meta 蓋掉了，
      // 設計稿畫出來是淡色，照畫出來的
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          s.s04EatAny,
          key: const Key('stamp-any'),
          style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 17),
        ),
      );
    }
    final full = feedTodo(cow).isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        key: const Key('stamp-line'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in cow.need) ...[_MiniStamp(feed: k, done: cow.ate.contains(k)), const SizedBox(width: 4)],
          Text(stampCount(cow), style: AppText.number(13, lineHeight: 19)),
          if (full) ...[
            const SizedBox(width: 4),
            Text(
              s.s03StampsFull,
              softWrap: false,
              style: AppText.style(13, weight: FontWeight.w900, color: _green, lineHeight: 19),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStamp extends StatelessWidget {
  const _MiniStamp({required this.feed, required this.done});

  final String feed;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: done ? const Color(0xFFFFF1EE) : Colors.white,
        shape: BoxShape.circle,
        border: done ? Border.all(color: _stampRed, width: 2.5) : null,
      ),
      child: Center(child: feedIcon(feed, 18, faded: !done)),
    );
    return done
        ? box
        : CustomPaint(
            foregroundPainter: const DashedBorder(color: _ringLine, radius: 14, chrome: true),
            child: box,
          );
  }
}

/// .want：牧場小牛頭上的想吃泡泡（S03-31）：第一種還沒吃的飼料（22）和「1 / 2」，下面一個尖角指著小牛。
class WantBubble extends StatelessWidget {
  const WantBubble({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final todo = feedTodo(cow);
    return CustomPaint(
      foregroundPainter: const _WantTail(),
      child: Container(
        key: Key('want-${cow.id}'),
        padding: const EdgeInsets.fromLTRB(4, 2, 9, 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          border: Border.all(color: AppColors.ink, width: 2.5),
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          boxShadow: AppShadows.solid(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (todo.isNotEmpty) feedIcon(todo.first, 22),
            const SizedBox(width: 3),
            Text(stampCount(cow), softWrap: false, style: AppText.number(13, lineHeight: 22)),
          ],
        ),
      ),
    );
  }
}

/// .want::after：內容 12 × 12、右邊和下面 2.5 的框（::after 不吃 `* { box-sizing: border-box }`，整塊 14.5），
/// 左邊在泡泡中間往左 6、下緣在框內往下 9，轉 45°。畫在泡泡上面：方塊的米黃底蓋掉泡泡下框的一段，尖角才接得起來。
class _WantTail extends CustomPainter {
  const _WantTail();

  @override
  void paint(Canvas canvas, Size size) {
    const b = 2.5, box = 12 + b;
    // 方塊的中心：泡泡的內框（padding box）下緣是 size.height − b
    final center = Offset(size.width / 2 - 6 + box / 2, size.height - b + 9 - box / 2);
    canvas
      ..save()
      // 方塊的上半伸進泡泡裡：只留下框那一段以下，免得米黃底蓋到泡泡裡的字（設計稿剛好只擦到一點點）
      ..clipRect(Rect.fromLTRB(0, size.height - b - 0.5, size.width, size.height + box))
      ..translate(center.dx, center.dy)
      ..rotate(3.141592653589793 / 4);
    const half = box / 2;
    canvas
      ..drawRect(const Rect.fromLTWH(-half, -half, box, box), Paint()..color = const Color(0xFFFFF8E6))
      ..drawRect(const Rect.fromLTWH(half - b, -half, b, box), Paint()..color = AppColors.ink)
      ..drawRect(const Rect.fromLTWH(-half, half - b, box, b), Paint()..color = AppColors.ink)
      ..restore();
  }

  @override
  bool shouldRepaint(_WantTail oldDelegate) => false;
}

/// .grow-alert：快長大了、還有沒吃的（S03-32）：小牛的圖、「小乳牛 #15 再 42 分就長大」、「還沒吃：」加飼料、「去餵食」、右上角 ×。
class GrowAlertCard extends StatelessWidget {
  const GrowAlertCard({super.key, required this.cow, required this.time, required this.onGo, required this.onClose});

  final Cow cow;

  /// 還要多久長大（「42 分」）。
  final String time;
  final VoidCallback onGo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final hint = AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 19);
    final feedStyle = AppText.style(13, weight: FontWeight.w900, lineHeight: 19);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: Key('grow-alert-${cow.id}'),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6D6),
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(AppRadii.r18),
            boxShadow: AppShadows.solid(4),
          ),
          child: Row(
            children: [
              // .ga-pic：56 的淡綠框，牛 52（靠下置中）
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4DA),
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.bottomCenter,
                child: OverflowBox(
                  maxWidth: 52,
                  maxHeight: 52,
                  alignment: Alignment.bottomCenter,
                  child: CowPicture(
                    breed: cow.look,
                    bull: cow.bull,
                    calf: true,
                    variant: cow.number,
                    width: 52,
                    height: 52,
                    pad: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.s03GrowSoon(cow: s.cowLabel(cow), time: time),
                      style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: hint,
                        children: [
                          TextSpan(text: s.s03NotEaten),
                          for (final k in feedTodo(cow)) ...[
                            const WidgetSpan(child: SizedBox(width: 4)),
                            WidgetSpan(alignment: PlaceholderAlignment.middle, child: feedIcon(k, 18)),
                            const WidgetSpan(child: SizedBox(width: 1)),
                            TextSpan(text: s.feedName(k), style: feedStyle),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: AppButton(
                  s.s03GoFeed,
                  key: Key('grow-alert-go-${cow.id}'),
                  small: true,
                  kind: ButtonKind.primary,
                  onPressed: onGo,
                ),
              ),
            ],
          ),
        ),
        // .bn-close：右 −4、上 −4（框裡面量）
        Positioned(
          right: AppSizes.border - 4,
          top: AppSizes.border - 4,
          child: Semantics(
            container: true,
            button: true,
            label: s.gClose,
            child: Pressable(
              key: Key('grow-alert-close-${cow.id}'),
              onTap: onClose,
              builder: (context, look) => PressTint(
                tint: look.tint,
                shape: BoxShape.circle,
                child: const SizedBox(width: 44, height: 44, child: Center(child: AppIcon('close', size: 18))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
