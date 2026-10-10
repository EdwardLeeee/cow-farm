// 小牛長大揭曉（v0.3 C1；協定 2.3「長大揭曉」）：牧場頁蓋一層暗幕，中間是長大的牛和名牌（設計稿 anims.js 的
// revealLayer、screens.css 的 .reveal、.disc-title、.grow-stage、.reveal-name）。
// - 一般的牛：動畫 A-13 的最後一格（A13、「減少動態」那張的「之後」）：「小乳牛 #16 長大了！」、正面的牛、名牌寫品種名、
//   用途、公母、稀有度；下面「點一下跳過」，點哪裡都關掉（設計稿沒有「好」按鈕）。
// - 雜種牛：S03-25（s03.js 的 mixGrown）：名牌多寫小時候沒吃到哪幾種、倍數，按「好」關掉。
// A-13 的發光、白光一閃還沒做：開著動畫和「減少動態」都跟減少動態版一樣，整個淡入 0.2 秒；測試（沒開動畫）是靜態的。
// 第一次長出的品種接著「發現新品種」（A-06）也還沒做。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/motion.dart';

class GrowReveal extends StatelessWidget {
  const GrowReveal({super.key, required this.cow, required this.mult, required this.onDone});

  /// 長大了的牛（伺服器的 state：品種、稀有度、雜種牛都揭曉了）。
  final Cow cow;

  /// 雜種牛的倍數（economy.hybrid_mult）；舊的伺服器沒有是 null。
  final double? mult;

  /// 揭曉完了：一般的牛點一下，雜種牛按「好」。
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mq = MediaQuery.of(context);
    final mix = cow.hybrid;
    // screens.css 的 @media (max-height: 640px)：雜種牛的舞台矮一點、標題的行高小一點、名牌的間距小一點
    // （那一段的字級、名牌的內距、說明的行高被後面的規則蓋掉了，設計稿 320 寬量到的也是這樣）
    final short = mq.size.height <= 640;
    // .disc-title 寫在 .mix-title 後面（screens.css），字級 26、下面 14 蓋過 .mix-title 的 24、4（設計稿量到的也是 26）；
    // 雜種牛只多了行高 30（很矮的手機 26）、左右留 16、置中。一般的牛行高 normal（Noto Sans CJK 的 26px 是 30 + 7）
    final title = _StrokeTitle(
      s.animGrownUp(cow: s.calfName(cow.type, cow.number)),
      lineHeight: mix ? (short ? 26 : 30) : 37,
      maxWidth: mq.size.width - 32,
    );
    final reveal = Column(
      key: const Key('grow-reveal'),
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        const SizedBox(height: 14),
        mix ? _MixStage(cow: cow, short: short) : _Stage(cow: cow),
        const SizedBox(height: 12),
        mix ? _MixName(cow: cow, mult: mult, short: short, onDone: onDone) : _Name(cow: cow),
      ],
    );
    final layer = Stack(
      children: [
        // 暗幕：一般的牛點哪裡都關（外面的 GestureDetector；ModalBarrier 自己會搶走點擊，不能用）；雜種牛要按「好」
        Positioned.fill(
          child: mix
              ? const ModalBarrier(color: AppColors.backdrop, dismissible: false)
              : const ColoredBox(color: AppColors.backdrop),
        ),
        // .reveal：整個畫面的正中間（很矮的手機放不下就可以捲）
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(child: reveal),
              ),
            ),
          ),
        ),
        // .skip-hint：分頁列上方 22（A-13 的最後一格；雜種牛的 S03-25 沒有）
        if (!mix)
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.padding.bottom + FrameSizes.tab + 22,
            child: Center(
              child: Semantics(
                button: true,
                onTap: onDone,
                child: SkipHint(s.animSkip, key: const Key('grow-skip')),
              ),
            ),
          ),
      ],
    );
    final body = BlockSemantics(
      child: mix ? layer : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onDone, child: layer),
    );
    // 開著動畫、減少動態：淡入 0.2 秒（A-13 的減少動態版）；測試沒開動畫是靜態的
    final fade = AppMotion.read(context) || AppMotion.reducedRead(context);
    return Positioned.fill(child: fade ? FadeIn(child: body) : body);
  }
}

/// .disc-title：26 特粗白字、6 的深色描邊（paint-order: stroke fill，看得到外面那 3），置中、左右至少留 16。
class _StrokeTitle extends StatelessWidget {
  const _StrokeTitle(this.text, {required this.lineHeight, required this.maxWidth});

  final String text;
  final double lineHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? fg) => AppText.style(
      26,
      weight: FontWeight.w900,
      color: Colors.white,
      lineHeight: lineHeight,
    ).copyWith(color: fg == null ? Colors.white : null, foreground: fg);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Stack(
        children: [
          Text(text, textAlign: TextAlign.center, style: style(stroke)),
          Text(text, key: const Key('grow-title'), textAlign: TextAlign.center, style: style(null)),
        ],
      ),
    );
  }
}

/// .grow-stage（240 × 210）：長大的牛（.gs-adult，正面 200 × 176）離下緣 8、置中。
class _Stage extends StatelessWidget {
  const _Stage({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: 210,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: CowPicture(breed: cow.look, bull: cow.bull, variant: cow.number, width: 200, height: 176),
          ),
        ),
      ],
    ),
  );
}

/// .grow-stage.mix-stage（200 × 166；很矮的手機 112）：雜種牛的體型（180 × 158）離下緣 8、置中。
/// 很矮的手機設計稿的牛還是 158 高（會蓋到標題），這裡縮到放得進舞台（104 高）。
class _MixStage extends StatelessWidget {
  const _MixStage({required this.cow, required this.short});

  final Cow cow;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final h = short ? 112.0 : 166.0, picH = h - 8;
    return SizedBox(
      width: 200,
      height: h,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: CowPicture(
                breed: cow.look,
                bull: cow.bull,
                variant: cow.number,
                width: 180 * picH / 158,
                height: picH,
                pad: 4 * picH / 158,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// .reveal-name 的框：米色底、3 的深色框、圓角 18、下面 4 的影子。
BoxDecoration _plate() => const BoxDecoration(
  color: AppColors.paper,
  border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 3)),
  borderRadius: BorderRadius.all(AppRadii.r18),
  boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, 4))],
);

/// .reveal-name b：20、粗體（bolder：400 → 700），行高 normal（Noto Sans CJK 的 20px 是 23 + 6）。
TextStyle _nameStyle() => AppText.style(20, weight: FontWeight.w700, lineHeight: 29);

/// .reveal-name.gs-name（A-13 的最後一格）：至少 190 × 68。長大前的名字（.gs-old）看不到了，但照樣撐出名牌的大小；
/// 品種名和標籤（.gs-new）從上面 8 開始、左右撐滿，標籤會壓到下框一點（跟設計稿一樣）。
class _Name extends StatelessWidget {
  const _Name({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Container(
      key: const Key('grow-name'),
      constraints: const BoxConstraints(minWidth: 190, minHeight: 68),
      decoration: _plate(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: ExcludeSemantics(
              child: Visibility.maintain(
                visible: false,
                child: Text(s.calfName(cow.type, cow.number), style: _nameStyle()),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.cowLabel(cow), textAlign: TextAlign.center, style: _nameStyle()),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    UseChip(cow.type),
                    SexText(bull: cow.bull),
                    rarityChip(cow.breed, cow.tier),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .reveal-name.gs-name.mix-end（S03-25）：寬 min(300, 畫面 − 32)、內距 10／16／16；名字、標籤（灰星、「雜種」）、
/// 「沒吃到苜蓿，長成了雜種牛」（.warn-text 16／22）、倍數的說明（.hint）、「好」，間距 6（很矮的手機 4）。
class _MixName extends StatelessWidget {
  const _MixName({required this.cow, required this.mult, required this.short, required this.onDone});

  final Cow cow;
  final double? mult;
  final bool short;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final gap = SizedBox(height: short ? 4 : 6);
    return Container(
      key: const Key('grow-name'),
      width: math.min(300, w - 32),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: _plate(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.cowLabel(cow), textAlign: TextAlign.center, style: _nameStyle()),
          gap,
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UseChip(cow.type),
              SexText(bull: cow.bull),
              const MixStarChip(),
              CowBadge(BadgeKind.mix, s.badgeMix),
            ],
          ),
          gap,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              s.animMixGrown(feeds: s.feedList(cow.missed)),
              key: const Key('grow-mix-why'),
              textAlign: TextAlign.center,
              style: AppText.style(16, weight: FontWeight.w900, color: const Color(0xFFC2541B), lineHeight: 22),
            ),
          ),
          gap,
          Text(
            s.animMixHint(mult: mult?.toStringAsFixed(1) ?? '–'),
            textAlign: TextAlign.center,
            style: KitText.hint(),
          ),
          gap,
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AppButton(s.ok, key: const Key('grow-ok'), kind: ButtonKind.primary, block: true, onPressed: onDone),
          ),
        ],
      ),
    );
  }
}
