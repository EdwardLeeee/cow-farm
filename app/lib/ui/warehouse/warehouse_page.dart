// S05 倉庫（設計稿 s05.js、screens.css 的 .lot、.cap-box）：牛奶、牛肉、稻米每一批，新的在上面（賣的時候從最舊的先賣）。
// 容量只算牛奶；牛肉、稻米不佔容量（企劃書 4.3）。時間一律寫現實時間（遊戲時間 ÷ 倍率）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/grade.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/page_head.dart';
import '../widgets/ticker_builder.dart';

class WarehousePage extends StatelessWidget {
  const WarehousePage({super.key});

  // 每隔 uiTick 重畫：「幾小時前收」、新鮮度跟著時間變
  @override
  Widget build(BuildContext context) => TickerBuilder(builder: _page);

  Widget _page(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final w = st.warehouse;
    final used = w.milkTotal, cap = w.capacity;
    final pct = cap > 0 ? (used / cap * 100).round() : 0;
    final full = cap > 0 && used >= cap;
    final empty = w.milkLots.isEmpty && w.beefLots.isEmpty && w.riceLots.isEmpty;
    // 新的在上面（設計稿：1 小時前、15 小時前…）；沒有時間的照伺服器的順序
    List<Lot> newestFirst(List<Lot> lots) =>
        [...lots]..sort((a, b) => (a.at == null || b.at == null) ? 0 : b.at!.compareTo(a.at!));
    final ago = _Ago(s, m);

    return ListView(
      key: const Key('warehouse'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        PageHead(
          title: s.warehouseTitle,
          sub: s.gLevelN(n: st.upgrades[UpgradeKind.warehouse]?.level ?? 0),
          onBack: m.closeWarehouse,
          // 加大倉庫：到商店的設施升級（S10）；快滿、滿了的時候是黃色
          action: AppButton(
            s.upWarehouse,
            key: const Key('upgrade-warehouse'),
            small: true,
            wrap: true,
            kind: full || pct >= 90 ? ButtonKind.primary : ButtonKind.normal,
            icon: 'plus',
            onPressed: () => m.openFacility(),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          key: const Key('section-milk'),
          title: CardTitle(s.milk, color: AppColors.blue, icon: 'milk'),
          count: w.milkLots.length,
          extra: _CapBox(used: used, cap: cap, pct: pct, full: full),
          empty: s.s05EmptyMilk,
          lots: [for (final l in newestFirst(w.milkLots)) _MilkLot(lot: l, ago: ago)],
        ),
        const SizedBox(height: 12),
        _Section(
          key: const Key('section-beef'),
          title: CardTitle(s.beef, color: const Color(0xFFFFC2B6), icon: 'beef'),
          count: w.beefLots.length,
          empty: s.s05EmptyBeef,
          lots: [for (final l in newestFirst(w.beefLots)) _BeefLot(lot: l, ago: ago)],
        ),
        const SizedBox(height: 12),
        _Section(
          key: const Key('section-rice'),
          title: CardTitle(s.rice, color: AppColors.green, icon: 'rice'),
          count: w.riceLots.length,
          empty: s.s05EmptyRice,
          lots: [for (final l in newestFirst(w.riceLots)) _RiceLot(lot: l, ago: ago)],
        ),
        const SizedBox(height: 12),
        AppButton(
          s.s05GoSell,
          key: const Key('go-sell'),
          kind: ButtonKind.primary,
          block: true,
          icon: 'coin',
          onPressed: empty ? null : () => m.selectTab(AppTab.market),
        ),
        const SizedBox(height: 12),
        Text(s.s05PriceNote, textAlign: TextAlign.center, style: KitText.hint()),
      ],
    );
  }
}

/// 「多久以前」：牛奶一律寫分鐘或小時（新鮮度看小時）；牛肉、稻米超過一天寫天（設計稿：67 小時前、2 天前）。
class _Ago {
  _Ago(this.s, this.m);

  final Strings s;
  final GameModel m;

  /// 現實時間過了幾秒。
  double _since(double at) => ((m.gameNow - at) / m.timeScale).clamp(0, double.infinity);

  String of(double? at, {bool days = true}) {
    if (at == null) return '';
    final sec = _since(at);
    if (sec < 60) return s.timeAgo();
    if (sec < 3600) return s.timeAgo(min: sec ~/ 60);
    if (!days || sec < 24 * 3600) return s.timeAgo(h: sec ~/ 3600);
    return s.timeAgo(d: sec ~/ (24 * 3600));
  }

  /// 還要幾小時壞掉（四捨五入，至少 1）。
  int hoursUntil(double at) => (((at - m.gameNow) / m.timeScale) / 3600).round().clamp(1, 1 << 20);
}

/// .card：標頭（小標籤＋「n 批・從最舊的先賣」）、額外的一塊（牛奶容量）、每一批，沒有就一行說明。
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.count,
    required this.empty,
    required this.lots,
    this.extra,
  });

  final Widget title;
  final int count;
  final String empty;
  final List<Widget> lots;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .card-head：放不下時小字換到下一行
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              title,
              if (count > 0)
                Text(
                  s.s05LotsOldestFirst(n: count),
                  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                ),
            ],
          ),
          ?extra,
          if (lots.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
              child: Text(empty, style: KitText.hint()),
            )
          else ...[
            const SizedBox(height: 8),
            for (final (i, lot) in lots.indexed) ...[if (i > 0) const SizedBox(height: 8), lot],
          ],
        ],
      ),
    );
  }
}

/// .cap-box：牛奶容量（用量／容量、百分比、進度條）；快滿黃字、滿了紅字和紅底。
class _CapBox extends StatelessWidget {
  const _CapBox({required this.used, required this.cap, required this.pct, required this.full});

  final double used;
  final double cap;
  final int pct;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final f = cap > 0 ? used / cap : 0.0;
    return Container(
      key: const Key('cap-box'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _lotBox(bad: full),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(s.s05MilkCap, style: AppText.style(13, weight: FontWeight.w900, lineHeight: 19)),
                Text.rich(
                  TextSpan(
                    style: AppText.style(13, weight: FontWeight.w700, lineHeight: 19),
                    children: fillSpans(
                      s.s05CapLine(amount: '\u0000', pct: pct),
                      // 15px 的數字把這一行撐到 21（Chrome 的 line-height: normal）
                      AppText.number(15, lineHeight: 21),
                      '${fmt(used)} / ${fmt(cap)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (full)
            MeterBar.red(fraction: f)
          else if (pct >= 90)
            MeterBar.yellow(fraction: f)
          else
            MeterBar(fraction: f),
          if (full)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.s05Full, style: KitText.err()),
            )
          else if (pct >= 90)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.s05NearFull, style: KitText.warn()),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.s05CapNote, style: KitText.hint()),
          ),
        ],
      ),
    );
  }
}

/// .lot 的框：白底、淡色框、圓角 14；快壞了（.bad）淡紅底紅框。
BoxDecoration _lotBox({bool bad = false}) => BoxDecoration(
  color: bad ? const Color(0xFFFFF0EE) : Colors.white,
  border: Border.all(color: bad ? const Color(0xFFF2A59E) : AppColors.lineSoft, width: 2),
  borderRadius: const BorderRadius.all(AppRadii.r14),
);

/// 一批（.lot）：上面一排（圖示、數量、單位、標籤…），下面幾行小字。
/// 行高照 Chrome 的 line-height: normal（Noto Sans CJK 上 1.16、下 0.288 各自四捨五入）：18px 26、14px 20、12px 17。
class _Lot extends StatelessWidget {
  const _Lot({super.key, required this.top, required this.below, this.badge, this.bad = false});

  final List<Widget> top;
  final List<Widget> below;

  /// 靠右的標籤（.lot .badge { margin-left: auto }）。
  final Widget? badge;
  final bool bad;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: _lotBox(bad: bad),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // .lot-top：英文、泰文放不下時換到下一行（screens.css 第 8 條）
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(spacing: 5, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: top),
            ),
            if (badge != null) ...[const SizedBox(width: 5), badge!],
          ],
        ),
        ...below,
      ],
    ),
  );
}

/// .lot-q 數量（18、特粗）和 .u 單位（12）。
List<Widget> _qty(String icon, double qty, String unit) => [
  AppIcon(icon, size: 22),
  Text(fmt(qty), style: AppText.number(18, lineHeight: 26)),
  Padding(
    padding: const EdgeInsets.only(right: 2),
    child: Text(unit, style: AppText.style(12, weight: FontWeight.w700, lineHeight: 17)),
  ),
];

/// .lot-name：灰色小字。
Widget _lotName(String text) => Text(
  text,
  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 17),
);

/// .lot-sub：下面一行灰色小字（快壞了是紅字）。
Widget _lotSub(String text, {bool bad = false}) => Padding(
  padding: const EdgeInsets.only(top: 4),
  child: Text(
    text,
    style: AppText.style(
      12,
      weight: FontWeight.w700,
      color: bad ? const Color(0xFFC9302C) : AppColors.ink2,
      lineHeight: 17,
    ),
  ),
);

/// 一批牛奶：數量、稀有度、「優良牛奶」；新鮮度條；幾小時前收（快壞了：大約幾小時後壞掉）。
class _MilkLot extends StatelessWidget {
  const _MilkLot({required this.lot, required this.ago});

  final Lot lot;
  final _Ago ago;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final fresh = (lot.freshness ?? 1).clamp(0.0, 1.0);
    // 快壞了：新鮮度低於 30%（ceo 2026-10-01）
    final bad = fresh < 0.3;
    final tier = lot.tier.clamp(0, 3);
    final mult = context.read<GameModel>().state?.economy?.tier(tier);
    final collected = s.s05CollectedAgo(ago: ago.of(lot.at, days: false));
    return _Lot(
      key: bad ? const Key('lot-bad') : null,
      bad: bad,
      top: [
        ..._qty('milk', lot.qty, s.unitMilk),
        TierChip(tier),
        // 稀有度的賣價倍數（×1.3）由伺服器給（協定 2.3 的 economy）；舊的伺服器沒有就只寫「優良牛奶」
        _lotName([s.s05MilkName(tier: s.tierName(tier)), if (mult != null) '×${mult.toStringAsFixed(1)}'].join(' ')),
      ],
      badge: bad ? CowBadge(BadgeKind.full, s.s05Spoiling) : null,
      below: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              AppIcon(
                bad
                    ? 'leafBad'
                    : fresh < 0.7
                    ? 'leafOld'
                    : 'leaf',
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(s.s05Fresh, style: AppText.style(12, weight: FontWeight.w700, lineHeight: 17)),
              const SizedBox(width: 6),
              Expanded(
                child: bad
                    ? MeterBar.red(fraction: fresh, height: 12)
                    : fresh < 0.7
                    ? MeterBar.yellow(fraction: fresh, height: 12)
                    : MeterBar.green(fraction: fresh, height: 12),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36),
                child: Text(
                  '${(fresh * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: AppText.number(14, color: bad ? const Color(0xFFD9443F) : AppColors.ink, lineHeight: 20),
                ),
              ),
            ],
          ),
        ),
        _lotSub(
          bad && lot.spoilsAt != null
              ? '$collected${s.gSep}${s.s05SpoilIn(h: ago.hoursUntil(lot.spoilsAt!))}'
              : collected,
          bad: bad,
        ),
      ],
    );
  }
}

/// 一批牛肉：數量、評級、稀有度、存放折價；哪一頭牛出貨、多久以前。
class _BeefLot extends StatelessWidget {
  const _BeefLot({required this.lot, required this.ago});

  final Lot lot;
  final _Ago ago;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final grade = lot.grade;
    final id = lot.cowId is int ? lot.cowId as int : int.tryParse('${lot.cowId}');
    // 出貨的牛的品種：協定還沒有的時候（舊的批次）只寫編號
    final cow = id == null ? null : (lot.breed == null ? '#$id' : s.cowName(lot.breed!, id));
    return _Lot(
      top: [
        ..._qty('beef', lot.qty, s.unitBeef),
        if (grade != null) GradeChip(grade),
        TierChip(lot.tier.clamp(0, 3)),
        if (lot.storageFactor != null) _lotName(s.s05Stored(pct: (lot.storageFactor! * 100).round())),
      ],
      below: [
        _lotSub([if (cow != null) s.s05ShippedFrom(cow: cow), ago.of(lot.at)].where((t) => t.isNotEmpty).join(s.gSep)),
      ],
    );
  }
}

/// 一批稻米：數量、存放折價；多久以前收。
class _RiceLot extends StatelessWidget {
  const _RiceLot({required this.lot, required this.ago});

  final Lot lot;
  final _Ago ago;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return _Lot(
      top: [
        ..._qty('rice', lot.qty, s.unitRice),
        if (lot.quality != null) _lotName(s.s05Stored(pct: (lot.quality! * 100).round())),
      ],
      below: [_lotSub(s.s05CollectedAgo(ago: ago.of(lot.at)))],
    );
  }
}
