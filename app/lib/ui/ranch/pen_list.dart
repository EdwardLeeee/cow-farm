// S03-07 牛舍清單（設計稿 s03.js 的 listPage、cowListRow）：返回、「我的牛」、牛舍幾格用了幾格、「擴建」，
// 用途篩選（全部、乳牛、耕牛、肉牛），每頭牛一列（點了看詳細）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../kit/cow_bits.dart';
import '../kit/kit.dart';
import '../kit/page_head.dart';
import '../widgets/ticker_builder.dart';

class PenListPage extends StatefulWidget {
  const PenListPage({super.key});

  @override
  State<PenListPage> createState() => _PenListPageState();
}

class _PenListPageState extends State<PenListPage> {
  int _filter = 0; // 0 全部、1 乳牛、2 耕牛、3 肉牛

  static const _types = [null, CowType.dairy, CowType.dual, CowType.beef];

  // 每隔 uiTick 重畫：小牛「長大還要 …」的倒數
  @override
  Widget build(BuildContext context) => TickerBuilder(builder: _page);

  Widget _page(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final pen = st.pen;
    final type = _types[_filter];
    final cows = [
      for (final c in st.cows)
        if (type == null || (breedInfo(c.breed)?.type ?? c.type) == type) c,
    ];
    return ListView(
      key: const Key('pen-list'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        PageHead(
          title: s.cowsTitle,
          sub: s.penSummary(used: pen.used, slots: pen.slots) + (pen.full ? s.s03PenFullSuffix : ''),
          onBack: m.closePenList,
          // 擴建：到商店的設施升級（S10）
          action: AppButton(
            s.s03ExpandPen,
            key: const Key('expand-pen'),
            small: true,
            wrap: true,
            kind: ButtonKind.primary,
            icon: 'plus',
            onPressed: () => m.openFacility(),
          ),
        ),
        const SizedBox(height: 12),
        FilterChips(
          labels: [s.gAll, s.useName(CowType.dairy), s.useName(CowType.dual), s.useName(CowType.beef)],
          selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 12),
        // .list：每頭牛一列，間隔 10
        Column(
          key: const Key('pen-rows'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in cows.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              CowRow(key: Key('cow-${c.id}'), cow: c, meta: cowMeta(s, m, c), onTap: () => m.openCow(c.key)),
            ],
          ],
        ),
      ],
    );
  }
}

/// 牛舍清單那一行說明（設計稿 cowListRow 的 meta）：病牛「不產奶，也不能配種、上架」（S03-30）、
/// 小牛「長大還要 …」、在田裡「在第 n 塊田・稻米 x 公斤／時」、上架中「借種上架中：x 幣」、
/// 產奶的母牛「產奶 x 瓶／時・體重 x 公斤」、其他「體重 x 公斤・估值約 x 幣」。倒數一律是現實時間。
String cowMeta(Strings s, GameModel m, Cow c) {
  final sep = s.gSep;
  final adultAt = c.adultAt;
  if (c.sick) return s.s03SickNoMilk;
  if (c.stage == CowStage.calf && adultAt != null) {
    return s.growUp(v: s.countdown((adultAt - m.gameNow) / m.timeScale));
  }
  if (c.fieldIndex != null) {
    return s.s03MetaField(n: c.fieldIndex! + 1, rate: rateNum(c.ricePerH));
  }
  if (c.listed) {
    final listing = m.state?.stud.listings.where((l) => l.cowId == c.id).firstOrNull;
    final price = listing?.fee.price ?? c.studFee?.price;
    if (price != null) return s.s03MetaListed(price: fmt(price));
  }
  if (c.milkPerH > 0) {
    return '${s.milkRate(v: rateNum(c.milkPerH))}$sep${s.weight(v: fmt(c.weightKg))}';
  }
  return '${s.weight(v: fmt(c.weightKg))}$sep${s.s03MetaValue(v: fmt(c.shipValue ?? 0))}';
}

/// 每小時的產量：整數就不寫小數點，不然 1 位（設計稿的 11、14.3）。
String rateNum(double v) => fmt(v, v % 1 == 0 ? 0 : 1);
