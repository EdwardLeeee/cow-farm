import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/price_chart.dart';

/// 市場：牛奶／牛肉兩個分頁；現價與 24 小時漲跌（漲紅跌綠）、折線圖、新聞、賣出面板。
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: S.milk), Tab(text: S.beef)]),
          Expanded(
            child: TabBarView(
              children: [
                CommodityView(key: const PageStorageKey('m-milk'), commodity: Commodity.milk),
                CommodityView(key: const PageStorageKey('m-beef'), commodity: Commodity.beef),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommodityView extends StatefulWidget {
  const CommodityView({super.key, required this.commodity});
  final Commodity commodity;

  @override
  State<CommodityView> createState() => _CommodityViewState();
}

class _CommodityViewState extends State<CommodityView> {
  static const ranges = [('1h', S.range1h), ('1d', S.range1d), ('7d', S.range7d)];
  String _range = '1d';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameModel>().loadHistory(widget.commodity, _range);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final c = widget.commodity;
    final q = m.market?.quotes[c];
    final unit = unitName(c);
    final theme = Theme.of(context);
    final news = (m.market?.news ?? const <NewsItem>[]).where((n) => n.commodity == null || n.commodity == c).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (q != null) ...[
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(S.price, style: theme.textTheme.bodySmall),
              Text(fmtNum(q.price, 2), key: Key('price-${c.wire}'), style: theme.textTheme.headlineMedium),
              Text(S.priceUnit(unit)),
            ],
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(S.change24h, style: theme.textTheme.bodySmall),
              Text(
                '${fmtSigned(q.change24h)}（${fmtPct(q.changePct)}）',
                key: Key('change-${c.wire}'),
                style: TextStyle(color: Palette.change(q.change24h), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (q.ma24 != null) Text(S.ma24(fmtNum(q.ma24!, 2)), style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (id, label) in ranges)
              ChoiceChip(
                key: Key('range-$id'),
                label: Text(label),
                selected: _range == id,
                onSelected: (_) {
                  setState(() => _range = id);
                  m.loadHistory(c, id);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        PriceChart(points: m.history[(c, _range)] ?? const []),
        const SizedBox(height: 12),
        SellPanel(commodity: c),
        const SizedBox(height: 12),
        Text(S.newsTitle, style: theme.textTheme.titleSmall),
        if (news.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text(S.noNews)),
        for (final n in news.take(20)) NewsTile(item: n),
      ],
    );
  }
}

class NewsTile extends StatelessWidget {
  const NewsTile({super.key, required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final upcoming = item.isUpcomingAt(context.read<GameModel>().gameNow);
    final tag = (upcoming ? S.upcomingTag : '') +
        (item.commodity == null ? S.bothTag : S.commodityTag(commodityName(item.commodity!)));
    final color = item.up == null ? Palette.flat : Palette.change(item.up! ? 1 : -1);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 6, height: 32, color: color),
      title: Text('$tag${item.title}'),
      subtitle: item.time == null ? null : Text(fmtGameClock(item.time!)),
    );
  }
}

/// 賣出面板：拉數量 → 防抖動後呼叫 /v1/sell/quote → 顯示預估成交均價 → 確認賣出。
class SellPanel extends StatefulWidget {
  const SellPanel({super.key, required this.commodity});
  final Commodity commodity;

  /// 拉滑桿後停多久才試算。
  static const debounce = Duration(milliseconds: 300);

  /// 均價比市價低超過這個比例，就提示「一次賣太多」。
  static const warnDiscount = 0.05;

  @override
  State<SellPanel> createState() => _SellPanelState();
}

class _SellPanelState extends State<SellPanel> {
  /// 滑桿位置：0 到 ceil(庫存) 的整數；拉到最右邊 = 全部（送庫存原值，含小數）。
  double _pos = 0;
  Timer? _debounce;
  SellQuote? _quote;
  bool _quoting = false;
  int _seq = 0;

  double _inventory(GameModel m) {
    final w = m.state?.warehouse;
    if (w == null) return 0;
    return widget.commodity == Commodity.milk ? w.milkTotal : w.beefTotal;
  }

  /// 滑桿位置 → 要賣的量。
  static double qtyAt(double pos, double inv) {
    final steps = inv.ceil();
    if (steps <= 0 || pos <= 0) return 0;
    if (pos >= steps) return inv;
    return pos.roundToDouble();
  }

  void _onChanged(double v, double inv) {
    final qty = qtyAt(v, inv);
    setState(() {
      _pos = v;
      _quoting = qty > 0;
      if (qty <= 0) _quote = null;
    });
    _debounce?.cancel();
    if (qty <= 0) return;
    _debounce = Timer(SellPanel.debounce, () => _fetchQuote(qty));
  }

  Future<void> _fetchQuote(double qty) async {
    final seq = ++_seq;
    final q = await context.read<GameModel>().quote(widget.commodity, qty);
    if (!mounted || seq != _seq) return; // 只採用最新一次
    setState(() {
      _quote = q;
      _quoting = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final c = widget.commodity;
    final unit = unitName(c);
    final inv = _inventory(m);
    final steps = inv.ceil();
    if (_pos > steps) _pos = steps.toDouble();
    final qty = qtyAt(_pos, inv);
    final q = _quote;
    final warn = q != null && (q.serverWarn ?? q.discount >= SellPanel.warnDiscount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(S.sellTitle, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(S.inventory(fmtQty(inv), unit)),
              ],
            ),
            if (steps <= 0)
              Padding(padding: const EdgeInsets.all(8), child: Text(S.nothingToSell(commodityName(c))))
            else ...[
              Slider(
                key: Key('sell-slider-${c.wire}'),
                value: _pos,
                min: 0,
                max: steps.toDouble(),
                divisions: steps <= 2000 ? steps : null,
                label: fmtQty(qty),
                onChanged: m.online ? (v) => _onChanged(v, inv) : null,
              ),
              Text(S.sellQty(fmtQty(qty), unit)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(S.estAvgPrice),
                  const SizedBox(width: 8),
                  Text(
                    _quoting ? S.quoting : (q == null ? '—' : S.estAvgValue(fmtNum(q.avgPrice, 2), unit)),
                    key: Key('sell-avg-${c.wire}'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (q != null && !_quoting)
                Text('${S.estTotal(fmtInt(q.total))}　${S.marketPriceNow(fmtNum(q.marketPrice, 2))}'),
              if (warn && !_quoting)
                Container(
                  key: Key('sell-warn-${c.wire}'),
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(6),
                  color: Palette.warn.withValues(alpha: 0.12),
                  child: const Text(S.tooMuch, style: TextStyle(color: Palette.warn, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 8),
              ActionButton(
                key: Key('sell-confirm-${c.wire}'),
                label: S.sellConfirm(fmtQty(qty), unit),
                enabled: qty > 0 && !_quoting,
                expand: true,
                onPressed: () async {
                  final r = await m.sell(c, qty);
                  if (!context.mounted) return;
                  final v = r.value;
                  showResult(
                    context,
                    r.error,
                    v == null ? '' : S.sold(fmtQty(v.qty), unit, fmtNum(v.avgPrice, 2), fmtInt(v.total)),
                  );
                  if (r.ok) {
                    setState(() {
                      _pos = 0;
                      _quote = null;
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
