// 紀錄分頁：上面的分段鈕切「圖鑑」（S09，設計稿 s09.js；screens.css 的 .dex-*）和「排行榜」（S12，rank_page.dart）。
// 圖鑑：已發現 n / 24、三種用途各 8 格（發現的是牛的正面小圖，沒發現的是深色剪影和「？？？」）；點一格看品種詳細
// （S09-03 已發現：大圖、介紹、數值、怎麼配出來、配種表（pair_table.dart）、第一次發現的日期；S09-04 還沒發現：剪影和提示）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/kv.dart';
import '../kit/meter.dart';
import '../kit/page_head.dart';
import '../kit/press.dart';
import '../kit/seg.dart';
import 'pair_table.dart';
import 'rank_page.dart';

/// 圖鑑的三種用途，照設計稿的順序（乳牛、耕牛、肉牛）。
const _uses = [CowType.dairy, CowType.dual, CowType.beef];

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final seg = SegControl(
      labels: [s.subCodex, s.subRank],
      selected: m.recordsRank ? 1 : 0,
      onSelect: (i) => m.selectRecords(rank: i == 1),
    );
    if (m.recordsRank) return RankPage(seg: seg);
    if (m.codexBreed case final breed?) {
      // 雜種牛（「其他」那一格，#157）：S09-06、S09-07
      return breed == kHybrid
          ? const MixDetailPage(key: ValueKey('codex-$kHybrid'))
          : CodexDetailPage(key: ValueKey('codex-$breed'), breed: breed);
    }
    return CodexPage(seg: seg);
  }
}

/// S09-01、S09-02：已發現 n / 24 的卡、三種用途各 8 格。
class CodexPage extends StatelessWidget {
  const CodexPage({super.key, required this.seg});

  final Widget seg;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final codex = m.state!.codex;
    final n = kCodexOrder.where(codex.containsKey).length;
    final total = kCodexOrder.length;
    return AppFrame(
      tab: AppTab.records,
      contentPadding: EdgeInsets.zero,
      content: ListView(
        key: const Key('codex'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          seg,
          const SizedBox(height: 12),
          _DexHead(found: n, total: total),
          for (final use in _uses) ...[
            const SizedBox(height: 12),
            _UseSection(use: use, codex: codex, onOpen: m.openCodex, s: s),
          ],
          // 「其他」：雜種牛一格（不算在 24 種裡，也不算完成度；#157）
          const SizedBox(height: 12),
          _OtherSection(found: codex.containsKey(kHybrid), onOpen: () => m.openCodex(kHybrid), s: s),
        ],
      ),
    );
  }
}

/// .card.dex-head：「已發現」標籤、n / 24、粗的黃進度條、一句說明。全部發現了底色變淡黃，說明換成「全部發現了！」。
class _DexHead extends StatelessWidget {
  const _DexHead({required this.found, required this.total});

  final int found;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final all = found >= total;
    final count = AppText.number(26, lineHeight: 30);
    return AppCard(
      key: const Key('dex-head'),
      color: all ? const Color(0xFFFFF6D6) : AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CardTitle(s.s09Found, icon: 'book'),
              const Spacer(),
              CssLine(
                TextSpan(
                  style: count,
                  children: [
                    TextSpan(text: '$found '),
                    // 小字繼承 .dex-count 的 30px 行高：大小字一起排，這一行是 35 高（Chrome 的算法，CssLine）
                    TextSpan(
                      text: '/ $total',
                      style: AppText.number(14, color: AppColors.ink2, lineHeight: 30),
                    ),
                  ],
                ),
                textKey: const Key('codex-count'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MeterBar.yellow(fraction: total == 0 ? 0 : found / total, height: 18, radius: 10),
          const SizedBox(height: 6),
          Text(all ? s.s09AllFound(n: total) : s.s09Hint, style: KitText.hint()),
        ],
      ),
    );
  }
}

/// 一種用途：標題（用途的圖示和名字、「乳牛 8 種」）、四欄的格子（同一排一樣高）。
class _UseSection extends StatelessWidget {
  const _UseSection({required this.use, required this.codex, required this.onOpen, required this.s});

  final CowType use;
  final Map<String, double> codex;
  final void Function(String breed) onOpen;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final breeds = [
      for (final b in kCodexOrder)
        if (breedInfo(b)?.type == use) b,
    ];
    // .dex-grid 一排 4 格；畫面寬度小於 390 排 3 格（screens.css 的 @media (max-width: 389px)；#126、ceo 2026-10-03：
    // 360 寬排 4 格時，英文的長牛名要換三行）
    final cols = MediaQuery.sizeOf(context).width < 390 ? 3 : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .sec-title：用途的圖示和名字，後面小字「乳牛 8 種」。上面的 margin 2 跟外層 section 的 12 合併（CSS 的
        // margin collapsing），所以上面不另外留
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              UseChip(use),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.s09UseCount(use: s.useName(use), n: breeds.length),
                  style: KitText.hint(),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < breeds.length; i += cols) ...[
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + cols; j++) ...[
                  if (j > i) const SizedBox(width: 8),
                  Expanded(
                    child: j < breeds.length
                        ? DexCell(
                            key: Key('codex-${breeds[j]}'),
                            breed: breeds[j],
                            found: codex.containsKey(breeds[j]),
                            onTap: () => onOpen(breeds[j]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// .dex-cell：一格。發現的：白底、牛的正面小圖、品種名、稀有度；沒發現的：灰底淡框、深色剪影、「？？？」。
/// 品種名繁中一行；英文、泰文放不下換兩行（screens.css 第 3 條），同一排的格子一起變高。整格可以點（G-13）。
class DexCell extends StatelessWidget {
  const DexCell({super.key, required this.breed, required this.found, this.onTap});

  final String breed;
  final bool found;
  final VoidCallback? onTap;

  static const _unknownBg = Color(0xFFF1EBE3);
  static const _unknownLine = Color(0xFFB8A89A);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final info = breedInfo(breed);
    final line = found ? AppColors.ink : _unknownLine;
    return Semantics(
      container: true,
      button: true,
      child: Pressable(
        lift: 3,
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
            decoration: BoxDecoration(
              color: found ? Colors.white : _unknownBg,
              border: Border.all(color: line, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r14),
              boxShadow: [BoxShadow(color: line, offset: Offset(0, look.shadow))],
            ),
            child: Column(
              children: [
                // 小圖 74 寬、名字和稀有度不換行：比格子裡面寬（320 寬、英文的稀有度）就往兩邊一樣多超出去（flex 的
                // align-items: center），跟 CSS 一樣不擠壞
                OverflowBox(
                  maxWidth: 74,
                  fit: OverflowBoxFit.deferToChild,
                  child: found
                      ? CowPicture(breed: breed, width: 74, height: 64, pad: 3)
                      : CowSilhouette.dark(breed: breed, width: 74, height: 64, pad: 3),
                ),
                const SizedBox(height: 2),
                // .dex-name：放不下就換行、置中（screens.css「英文、泰文」第 3 條；繁中的牛名放得下，不會換）
                Text(
                  found ? s.breedName(breed) : s.gUnknownBreed,
                  textAlign: TextAlign.center,
                  style: AppText.style(
                    12,
                    weight: FontWeight.w900,
                    color: found ? AppColors.ink : AppColors.ink2,
                    lineHeight: 16,
                  ),
                ),
                const SizedBox(height: 2),
                OverflowBox(
                  maxWidth: double.infinity,
                  fit: OverflowBoxFit.deferToChild,
                  child: TierChip(info?.tier ?? 0, compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「其他」那一區（#157；設計稿 s09.js 的 mixTile）：小標「其他」＋「不算在 24 種裡，也不算完成度」，
/// 下面一格整排寬的雜種牛：三種體型並排、名字、灰星、「3 種體型」。還沒長出過雜種牛是剪影。
/// 寬度小於 390（screens.css 的 @media (max-width: 389px)）名字換到三頭牛下面、置中。
class _OtherSection extends StatelessWidget {
  const _OtherSection({required this.found, required this.onOpen, required this.s});

  final bool found;
  final VoidCallback onOpen;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;
    final line = found ? AppColors.ink : DexCell._unknownLine;
    final pics = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final look in kMixLook.values)
          found
              ? CowPicture(breed: look, width: 70, height: 62, pad: 2)
              : CowSilhouette.dark(breed: look, width: 70, height: 62, pad: 2),
      ],
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          found ? s.breedName(kHybrid) : s.gUnknownBreed,
          style: AppText.style(
            15,
            weight: FontWeight.w900,
            color: found ? AppColors.ink : AppColors.ink2,
            lineHeight: 20,
          ),
        ),
        const SizedBox(height: 2),
        const MixStarChip(compact: true),
        const SizedBox(height: 2),
        Text(s.s09MixBodies, style: KitText.hint()),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .sec-title：「其他」（.use 的字）、小字說明
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Text(s.s09Other, style: AppText.style(12, weight: FontWeight.w900, lineHeight: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(s.s09OtherHint(n: kCodexOrder.length), style: KitText.hint()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // .dex-cell.dex-mix-tile：整排寬，三頭牛和字並排（隔 10）、置中；框、陰影、按下的樣子跟一般的格子一樣
        Semantics(
          container: true,
          button: true,
          child: Pressable(
            key: const Key('codex-hybrid'),
            lift: 3,
            onTap: onOpen,
            builder: (context, look) => PressTint(
              tint: look.tint,
              borderRadius: const BorderRadius.all(AppRadii.r14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                decoration: BoxDecoration(
                  color: found ? Colors.white : DexCell._unknownBg,
                  border: Border.all(color: line, width: 2),
                  borderRadius: const BorderRadius.all(AppRadii.r14),
                  boxShadow: [BoxShadow(color: line, offset: Offset(0, look.shadow))],
                ),
                child: narrow
                    ? Column(children: [pics, const SizedBox(height: 2), text])
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [pics, const SizedBox(width: 10), text],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 雜種牛的詳細（#157；設計稿 s09.js 的 mixDetail）：S09-06 已發現、S09-07 還沒發現。
/// 三種體型的正面並排（下面寫用途）、沒有編號；灰星和「雜種」標籤；一句話介紹；產奶、耕田、賣價倍數（耕田和倍數乘
/// economy.hybrid_mult）；「怎麼會長成雜種牛」；第一次發現的日期。還沒發現：剪影、「還沒發現這個品種」、怎麼會長成雜種牛。
class MixDetailPage extends StatelessWidget {
  const MixDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final foundAt = st.codex[kHybrid];
    final found = foundAt != null;
    final e = st.economy;
    final mult = e?.hybridMult;
    final ox = e?.oxRicePerH;
    final milk = e?.dairyMilkPerH;
    final how = Text(s.s09MixHow, style: KitText.hint().copyWith(color: AppColors.ink));
    return AppFrame(
      tab: AppTab.records,
      contentPadding: EdgeInsets.zero,
      content: ListView(
        key: const Key('codex-detail'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          // .page-head：返回、名字和標籤（灰星、「雜種」；還沒發現加「還沒發現」），沒有編號
          Row(
            children: [
              CircleIconButton(icon: 'back', label: s.back, onTap: m.closeCodex),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      found ? s.breedName(kHybrid) : s.gUnknownBreed,
                      key: const Key('codex-name'),
                      style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const MixStarChip(),
                        CowBadge(BadgeKind.mix, s.badgeMix),
                        if (!found) CowBadge(BadgeKind.lock, s.s09NotFoundYet),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MixHero(found: found),
          if (found) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                s.byKey('breed.mix.intro'),
                style: AppText.style(16, weight: FontWeight.w700, lineHeight: 24),
              ),
            ),
            const SizedBox(height: 12),
            KvGrid(
              key: const Key('codex-kv'),
              cells: [
                (s.s09MilkCow, milk == null ? '–' : rateText(milk), s.gPerHourMilk),
                (s.gPlow, ox == null || mult == null ? '–' : rateText(ox * mult), s.gPerHourRice),
                (s.s09Mult, mult == null ? '–' : '×${mult.toStringAsFixed(1)}', null),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardTitle(s.s09MixHowTitle, color: AppColors.pink, icon: 'heart', iconSize: 16),
                  const SizedBox(height: 6),
                  how,
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.s09FirstFound(
                date: () {
                  final at = m.realLocalTime(foundAt);
                  return s.dateMdOnly(m: at.month, d: at.day);
                }(),
                n: st.cows.where((c) => c.hybrid).length,
              ),
              key: const Key('codex-first'),
              style: KitText.hint(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                child: Column(
                  children: [
                    Text(
                      s.s09UnknownTitle,
                      textAlign: TextAlign.center,
                      style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.s09MixHow,
                      textAlign: TextAlign.center,
                      style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// .card.dex-hero 的 .mix-pics：三種體型的正面（88×92）並排（隔 2）、靠下，下面寫用途；還沒發現是深色剪影、沒有用途。
class _MixHero extends StatelessWidget {
  const _MixHero({required this.found});

  final bool found;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('codex-hero'),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r18),
      boxShadow: AppShadows.solid(4),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18 - AppSizes.border)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: kHeroGradient),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, e) in kMixLook.entries.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    found
                        ? CowPicture(breed: e.value, width: 88, height: 92, pad: 3)
                        : CowSilhouette.dark(breed: e.value, width: 88, height: 92, pad: 3),
                    if (found) ...[const SizedBox(height: 2), UseChip(e.key)],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// 品種詳細（S09-03 已發現、S09-04 還沒發現）。
class CodexDetailPage extends StatelessWidget {
  const CodexDetailPage({super.key, required this.breed});

  final String breed;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final info = breedInfo(breed);
    final type = info?.type ?? CowType.dairy;
    final tier = info?.tier ?? 0;
    final foundAt = st.codex[breed];
    final found = foundAt != null;
    final no = kCodexOrder.indexOf(breed) + 1;
    return AppFrame(
      tab: AppTab.records,
      contentPadding: EdgeInsets.zero,
      content: ListView(
        key: const Key('codex-detail'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          // .page-head：返回、品種名和標籤、右邊 No.03
          Row(
            children: [
              CircleIconButton(icon: 'back', label: s.back, onTap: m.closeCodex),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      found ? s.breedName(breed) : s.gUnknownBreed,
                      key: const Key('codex-name'),
                      style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [UseChip(type), TierChip(tier), if (!found) CowBadge(BadgeKind.lock, s.s09NotFoundYet)],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.s09No(n: '$no'.padLeft(2, '0')),
                style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DexHero(breed: breed, found: found),
          if (found) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(s.breedIntro(breed), style: AppText.style(16, weight: FontWeight.w700, lineHeight: 24)),
            ),
            const SizedBox(height: 12),
            KvGrid(key: const Key('codex-kv'), cells: codexStats(s, m, type, tier)),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardTitle(s.s09HowTitle, color: AppColors.pink, icon: 'heart', iconSize: 16),
                  const SizedBox(height: 6),
                  // 相鄰的全形標點擠掉半格（「帶著）。」），跟設計稿（Chrome）一樣
                  Text.rich(
                    TextSpan(children: cjkTrimSpans(breedHint(s, info))),
                    key: const Key('codex-how'),
                    style: KitText.hint().copyWith(color: AppColors.ink),
                  ),
                ],
              ),
            ),
            // 配種表（v0.3 第 13.2 節）：代表配法拿到了才放（打開紀錄分頁就先拿）；舊的伺服器沒有代表配法、也沒配出過就不放
            if (m.codexPairings case final table?)
              if (pairRows(breed, table[breed] ?? const [], st.pairings) case final rows when rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                PairTable(breed: breed, rows: rows),
              ],
            const SizedBox(height: 12),
            Text(
              s.s09FirstFound(
                date: () {
                  final at = m.realLocalTime(foundAt);
                  return s.dateMdOnly(m: at.month, d: at.day);
                }(),
                n: st.cows.where((c) => c.breed == breed).length,
              ),
              key: const Key('codex-first'),
              style: KitText.hint(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                child: Column(
                  children: [
                    Text(
                      s.s09UnknownTitle,
                      textAlign: TextAlign.center,
                      style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.s09UnknownBody(use: s.useName(type), tier: s.tierName(tier)),
                      textAlign: TextAlign.center,
                      style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 品種詳細的數值（設計稿 detailPage 的 stats）：乳牛先寫產奶、耕牛先寫耕田；再來最佳體重、賣價倍數。
/// 數字都讀伺服器的 economy（協定 2.3，app 不寫死）；沒給的寫「–」。產量是每遊戲小時（跟牛的詳細 S04 一樣）。
/// 「小牛長大 N 小時」那一格 v0.3 拿掉了（#151：所有小牛長大的時間一樣）。
List<KvCell> codexStats(Strings s, GameModel m, CowType type, int tier) {
  final e = m.state?.economy;
  final mult = e == null || e.tierMult.isEmpty ? null : e.tierMult[tier.clamp(0, e.tierMult.length - 1)];
  final cells = <KvCell>[];
  if (type == CowType.dairy) {
    final milk = e?.dairyMilkPerH;
    cells.add((s.s09MilkCow, milk == null ? '–' : rateText(milk), s.gPerHourMilk));
  }
  if (type == CowType.dual) {
    final ox = e?.oxRicePerH;
    cells.add((s.gPlow, ox == null || mult == null ? '–' : rateText(ox * mult), s.gPerHourRice));
  }
  final peak = e?.peakWeightKg[type];
  cells.add((s.s09BestKg, peak == null ? '–' : fmt(peak), s.gKg));
  // 設計稿是「×1.3 <small></small>」：不是耕牛的小字是空的，這一行照樣跟有單位的一樣高
  cells.add((s.s09Mult, mult == null ? '–' : '×${mult.toStringAsFixed(1)}', type == CowType.dual ? s.s09MultBeef : ''));
  return cells;
}

/// 「怎麼配出來」（設計稿的 hintFor）：爸媽的用途，加上要帶的特徵（長毛、淡色、光澤，照 A、B、C 的順序）。
String breedHint(Strings s, BreedInfo? info) {
  final use = switch (info?.type) {
    CowType.beef => s.s09HowBeef,
    CowType.dual => s.s09HowDraft,
    _ => s.s09HowDairy,
  };
  final traits = [
    if (info?.longHair ?? false) s.traitName('A'),
    if (info?.light ?? false) s.traitName('B'),
    if (info?.gloss ?? false) s.traitName('C'),
  ];
  return traits.isEmpty ? s.s09HowNoTrait(use: use) : s.s09HowTraits(use: use, traits: traits.join(s.gListSep));
}

/// .card.dex-hero：天空草地的底，牛的側面（160×130）和正面（130×130）並排、靠下；還沒發現只有側面的深色剪影。
class _DexHero extends StatelessWidget {
  const _DexHero({required this.breed, required this.found});

  final String breed;
  final bool found;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('codex-hero'),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r18),
      boxShadow: AppShadows.solid(4),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18 - AppSizes.border)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: kHeroGradient),
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          // 兩張圖加起來 294 寬：卡片裡面比較窄（320 寬的手機）就置中往兩邊超出、被卡片裁掉（CSS 的 justify-content: center）
          child: OverflowBox(
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: found
                  ? [
                      CowPicture(breed: breed, front: false, width: 160, height: 130),
                      const SizedBox(width: 4),
                      CowPicture(breed: breed, width: 130, height: 130),
                    ]
                  : [CowSilhouette.dark(breed: breed, front: false, width: 160, height: 130)],
            ),
          ),
        ),
      ),
    ),
  );
}
