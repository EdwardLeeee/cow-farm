// 牛的標籤和清單列（設計稿 kit.js 的 useChip、tierChip、badge、cowRow；kit.css 的 .use、.tier、.badge、.cow-row）。
// G-07：用途、稀有度、狀態；S03-07 牛舍清單、S03-10 工作中的耕牛。
import 'package:flutter/material.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'app_icon.dart';
import 'cow_art.dart';
import 'press.dart';

/// .use：用途的小圖示加名字（乳牛、耕牛、肉牛）。
class UseChip extends StatelessWidget {
  const UseChip(this.type, {super.key});

  final CowType type;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(switch (type) {
        CowType.dairy => 'milk',
        CowType.dual => 'rice',
        CowType.beef => 'beef',
      }, size: 16),
      const SizedBox(width: 2),
      Text(Strings.of(context).useName(type), style: _chipText()),
    ],
  );
}

/// 公、母（.use 的字，沒有圖示）。
class SexText extends StatelessWidget {
  const SexText({super.key, required this.bull});

  final bool bull;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Text(bull ? s.bull : s.cow, style: _chipText());
  }
}

TextStyle _chipText() => AppText.style(12, weight: FontWeight.w900, lineHeight: 18);

/// .tier：稀有度（一般、優良、稀有、傳說；傳說是漸層加星星）。
class TierChip extends StatelessWidget {
  const TierChip(this.tier, {super.key, this.compact = false});

  final int tier;

  /// 圖鑑格子裡的小號（.dex-cell .tier：高 20、框 1.5、左右 5）。
  final bool compact;

  static const _colors = [Color(0xFFF1EADF), Color(0xFFCFEFC4), Color(0xFFCFE6FF)];

  @override
  Widget build(BuildContext context) {
    final legend = tier >= 3;
    return Container(
      height: compact ? 20 : 22,
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: legend ? null : _colors[tier.clamp(0, 2)],
        gradient: legend ? const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFC4D6)]) : null,
        border: Border.all(color: AppColors.ink, width: compact ? 1.5 : 2),
        borderRadius: BorderRadius.all(Radius.circular(compact ? 10 : 11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (legend) ...[const AppIcon('sparkle', size: 12), const SizedBox(width: 2)],
          Text(
            Strings.of(context).tierName(tier.clamp(0, 3)),
            style: compact ? AppText.style(12, weight: FontWeight.w900, lineHeight: 16) : _chipText(),
          ),
        ],
      ),
    );
  }
}

/// .badge 的種類和底色；.badge.lock（空田）的字是 ink-2、框是停用的淡色。
enum BadgeKind {
  bred(AppColors.pink),
  working(AppColors.green),
  listed(AppColors.orange),
  calf(Color(0xFFD5EBFF)),
  old(Color(0xFFE8E1D8)),
  full(Color(0xFFFFC2B6)),
  fresh(AppColors.yellow),

  /// .badge.new：還沒發現過的品種（S08-06）。
  newBreed(AppColors.yellow),

  /// .badge.lock：空田（S17）。
  lock(AppColors.disabledBg, fg: AppColors.ink2, line: AppColors.disabledLine);

  const BadgeKind(this.color, {this.fg = AppColors.ink, this.line = AppColors.ink});
  final Color color;
  final Color fg;
  final Color line;
}

/// .badge：狀態標籤（小牛、老牛、工作中、上架中、已配種…）。
class CowBadge extends StatelessWidget {
  const CowBadge(this.kind, this.text, {super.key});

  final BadgeKind kind;
  final String text;

  // 不設 alignment：設了 Container 會撐滿 Wrap 的寬度。高 22 = 框 2 + 字的行高 18 + 框 2，字自然在正中間
  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: kind.color,
      border: Border.all(color: kind.line, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(11)),
    ),
    child: Text(text, softWrap: false, style: _chipText().copyWith(color: kind.fg)),
  );
}

/// 一頭牛的標籤（設計稿 cowListRow 的 chips）：用途、公母、稀有度，加上小牛、老牛、工作中、上架中、已配種。
List<Widget> cowChips(BuildContext context, Cow c) {
  final s = Strings.of(context);
  final info = breedInfo(c.breed);
  return [
    UseChip(info?.type ?? c.type),
    SexText(bull: c.bull),
    TierChip(info?.tier ?? c.tier),
    if (c.stage == CowStage.calf) CowBadge(BadgeKind.calf, s.stageCalf),
    if (c.stage == CowStage.old) CowBadge(BadgeKind.old, s.stageOld),
    if (c.fieldIndex != null) CowBadge(BadgeKind.working, s.badgeWorking),
    if (c.listed) CowBadge(BadgeKind.listed, s.badgeListed),
    if (c.bred) CowBadge(BadgeKind.bred, s.badgeBred),
  ];
}

/// 牛的小圖框（kit.css 的 .cow-row .pic、screens.css 的 .sr-pic）：[size]×[size]、淺綠底、框 2。
/// 裡面是 grid（place-items: end center）：[size] 的圖比框裡（少了框的 2 × 2）大，格子跟著圖變大，
/// 圖從框裡的左上角開始放，右邊、下面各超出 4 被裁掉（place-items 在格子裡沒有作用）。
class CowPicBox extends StatelessWidget {
  const CowPicBox({super.key, required this.child, this.size = 60, this.radius = 16});

  final Widget child;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFE4F4DA),
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(radius)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(radius - 2)),
      child: OverflowBox(maxWidth: size, maxHeight: size, alignment: Alignment.topLeft, child: child),
    ),
  );
}

/// .card.cow-row：牛的小圖（正面）、名字、標籤、一行說明，右邊一個箭頭。整張卡可以點（G-13：浮起，按下往下 3）。
class CowRow extends StatelessWidget {
  const CowRow({super.key, required this.cow, required this.meta, this.onTap});

  final Cow cow;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final id = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    return Pressable(
      lift: 4,
      onTap: onTap,
      builder: (context, look) => PressTint(
        tint: look.tint,
        borderRadius: const BorderRadius.all(AppRadii.r18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.paper,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(AppRadii.r18),
            boxShadow: AppShadows.solid(look.shadow),
          ),
          child: Row(
            children: [
              // .pic：60×60、淺綠底、圓角 16
              CowPicBox(
                radius: 16,
                child: CowPicture(
                  breed: cow.breed,
                  bull: cow.bull,
                  calf: cow.stage == CowStage.calf,
                  variant: id,
                  width: 60,
                  height: 60,
                  pad: 3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名字放不下就換行（字級不變），編號才不會被截掉
                    Text(s.cowName(cow.breed, id), style: AppText.style(16, weight: FontWeight.w900, lineHeight: 21)),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: cowChips(context, cow),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      // .meta：英文、泰文放不下可以換行（screens.css 第 13 條）
                      Text(
                        meta,
                        style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 17),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const AppIcon('chevron', size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
