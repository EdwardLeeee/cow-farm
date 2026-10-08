// S06 市場（設計稿 s06.js、screens.css 的 .prices-card、.headline、.sell-card、.news-card）。
// D24：沒有走勢圖；三種商品的「現在的收購價」和「比平常高或低幾 %」排成一張卡，點一列就換成那種商品的賣出面板。
// 賣的價格一律問伺服器（POST /v1/sell/quote 試算、POST /v1/sell 賣出），手機不算帳。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/fly.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/motion.dart';
import '../kit/press.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'news_tier.dart';

/// 市場分頁（整頁，含頂列和分頁列）：賣出成功、失敗的提示疊在最上面。
class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> with SingleTickerProviderStateMixin {
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  /// A-02 成交（1.4 秒，設計稿 anims.js 的 A02）：金幣從「確認賣出」飛向頂列、頂列的金幣往上跳、第 1.0 秒提示淡入。
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..addListener(_tickCoins);

  /// 賣出前的金幣、按鈕（金幣從哪裡飛）；null 是沒在播。
  SoldFx? _sold;
  final _layerKey = GlobalKey();

  /// A-02 的減少動態版：提示淡入 0.2 秒（金幣不飛、數字直接變）。
  bool _fadeToast = false;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _showToast(ToastKind kind, String text, {Duration delay = Duration.zero}) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(delay + const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 賣出成功：開著動畫時播 A-02，提示第 1.0 秒才出來；減少動態時提示淡入 0.2 秒。
  void _onSold(SoldFx fx) {
    final motion = AppMotion.read(context);
    _fadeToast = !motion && AppMotion.reducedRead(context);
    if (motion) {
      setState(() => _sold = fx);
      final hud = HudFxScope.read(context)?.notifier;
      _anim.forward(from: 0).whenComplete(() {
        hud?.value = null;
        if (mounted) setState(() => _sold = null);
      });
    }
    _showToast(ToastKind.ok, fx.toast, delay: motion ? const Duration(milliseconds: 1000) : Duration.zero);
  }

  /// A-02 現在播到第幾秒；沒在播是 null。
  double? get _t => _sold == null ? null : _anim.value * 1.4;

  /// 頂列的金幣：0.5–1.05 秒照 outCubic 從賣出前跳到伺服器的新數字，膠囊 0.55–1.05 秒放大一下。
  void _tickCoins() {
    final fx = _sold, t = _t;
    if (fx == null || t == null) return;
    final now = context.read<GameModel>().state?.coins.toDouble() ?? fx.coins;
    HudFxScope.read(context)?.notifier?.value = HudFx(
      coins: fx.coins + (now - fx.coins) * animOutCubic(animSeg(t, 0.5, 1.05)),
      pulse: math.sin(math.pi * animSeg(t, 0.55, 1.05)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return AppFrame(
      tab: AppTab.market,
      contentPadding: EdgeInsets.zero,
      content: TickerBuilder(
        builder: (context) => _MarketList(onToast: _showToast, onSold: _onSold),
      ),
      overlays: [
        // A-02：飛的金幣（不擋點擊）
        if (_sold != null)
          Positioned.fill(
            key: _layerKey,
            child: IgnorePointer(
              child: AnimatedBuilder(animation: _anim, builder: (context, _) => _coins()),
            ),
          ),
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: FrameSizes.contentBottom(safe) + 14,
            child: Center(
              // A-02 播的時候第 1.0–1.2 秒淡入、從下面 14 滑上來；減少動態時淡入 0.2 秒
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  final at = _t;
                  if (at == null) {
                    if (!_fadeToast) return child!;
                    return TweenAnimationBuilder<double>(
                      key: ObjectKey(_toast),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, o, child) => Opacity(opacity: o, child: child),
                      child: child,
                    );
                  }
                  final k = animSeg(at, 1.0, 1.2);
                  return Opacity(
                    opacity: k,
                    child: Transform.translate(offset: Offset(0, (1 - animOutCubic(k)) * 14), child: child),
                  );
                },
                child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
              ),
            ),
          ),
      ],
    );
  }

  /// A-02 的六個金幣：從「確認賣出」的中間（左右各錯開 16）沿拋物線（高 60）飛到頂列金幣膠囊的左邊 6，
  /// 一個晚 0.07 秒，越飛越小（1 → 0.7；設計稿 A02.frame）。
  Widget _coins() {
    final fx = _sold, t = _t;
    final layer = _layerKey.currentContext?.findRenderObject() as RenderBox?;
    final from = flyPoint(
      layer,
      fx?.button.currentContext?.findRenderObject() as RenderBox?,
      (s) => s.center(Offset.zero),
    );
    // 金幣膠囊外面左邊留給金幣圖示的 18（窄手機 17）
    final to = flyPoint(
      layer,
      HudFxScope.read(context)?.chipKey.currentContext?.findRenderObject() as RenderBox?,
      (s) => Offset(18 + 6, s.height / 2),
    );
    if (t == null || from == null || to == null) return const SizedBox.shrink();
    return FlyIcons(
      t: t,
      count: 6,
      from: (i) => from + Offset((i - 2.5) * 16, 0),
      to: to,
      icon: const AppIcon('coin', size: 30),
      size: 30,
      start: 0.1,
      dur: 0.55,
      stagger: 0.07,
      lift: 60,
      scale: (k) => 1 - 0.3 * k,
      keyPrefix: 'sell-coin',
    );
  }
}

/// 賣出成功（A-02）：賣出前的金幣、提示的字、「確認賣出」按鈕（金幣從這裡飛出去）。
class SoldFx {
  const SoldFx(this.coins, this.toast, this.button);
  final double coins;
  final String toast;
  final GlobalKey button;
}

class _MarketList extends StatelessWidget {
  const _MarketList({required this.onToast, required this.onSold});

  final void Function(ToastKind kind, String text) onToast;
  final ValueChanged<SoldFx> onSold;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final upIsRed = context.watch<SettingsController>().upIsRed;
    final market = m.market;
    final c = m.marketCommodity;
    // 收購價還沒拿到（S06-06）：只有一張「正在取得收購價…」
    if (market == null) {
      return ListView(
        key: const Key('market'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: const [_LoadingCard()],
      );
    }
    final news = [...market.news]..sort((a, b) => (b.time ?? 0).compareTo(a.time ?? 0));
    // 選中的商品的最新一則新聞；沒有就用全部商品的
    final headline =
        news.where((n) => n.commodity == c).firstOrNull ?? news.where((n) => n.commodity == null).firstOrNull;
    return ListView(
      key: const Key('market'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        _PricesCard(selected: c, quotes: market.quotes, upIsRed: upIsRed, onSelect: m.selectMarket),
        if (headline != null) ...[const SizedBox(height: 12), _Headline(news: headline)],
        const SizedBox(height: 12),
        // 換商品就是新的賣出面板（數量、試算重來）
        SellCard(key: ValueKey('sell-${c.wire}'), commodity: c, onToast: onToast, onSold: onSold),
        const SizedBox(height: 12),
        NewsCard(items: news),
      ],
    );
  }
}

/// 多久以前（現實時間）：不到 1 分鐘「剛剛」，不到 1 小時寫分，不到 1 天寫小時，其他寫天。
String agoText(Strings s, GameModel m, double? at) {
  if (at == null) return '';
  final sec = ((m.gameNow - at) / m.timeScale).clamp(0, double.infinity);
  if (sec < 60) return s.timeAgo();
  if (sec < 3600) return s.timeAgo(min: sec ~/ 60);
  if (sec < 24 * 3600) return s.timeAgo(h: sec ~/ 3600);
  return s.timeAgo(d: sec ~/ (24 * 3600));
}

/// .card.prices-card 載入中（S06-06）。
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('prices-loading'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spinner(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(Strings.of(context).s06Loading, style: AppText.style(16, weight: FontWeight.w900)),
          ),
        ],
      ),
    ),
  );
}

/// .prices-card：三種商品的收購價（選中的那一列黃底、深色框）；下面一行寫平常的價（基本價）。
class _PricesCard extends StatelessWidget {
  const _PricesCard({required this.selected, required this.quotes, required this.upIsRed, required this.onSelect});

  final Commodity selected;
  final Map<Commodity, Quote> quotes;
  final bool upIsRed;
  final ValueChanged<Commodity> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    String base(Commodity c) => quotes[c]?.basePrice == null ? '–' : priceText(quotes[c]!.basePrice!);
    return AppCard(
      key: const Key('prices'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(
            title: CardTitle(s.s06Title, color: AppColors.green, icon: 'coin', iconSize: 16),
            sub: s.s06TapToSell,
          ),
          const SizedBox(height: 8),
          for (final (i, c) in Commodity.values.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            _PriceRow(commodity: c, quote: quotes[c], on: c == selected, upIsRed: upIsRed, onTap: () => onSelect(c)),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s.s06BaseLine(milk: base(Commodity.milk), beef: base(Commodity.beef), rice: base(Commodity.rice)),
              style: KitText.hint(size: 12, lineHeight: 17),
            ),
          ),
        ],
      ),
    );
  }
}

/// .card-head：左邊小標籤，右邊灰色小字（放不下時換到下一行）。
class _CardHead extends StatelessWidget {
  const _CardHead({required this.title, this.sub});

  final Widget title;
  final String? sub;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      title,
      if (sub != null)
        Text(
          sub!,
          style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
        ),
    ],
  );
}

/// .price-row：圖示、商品名、右邊收購價和「比平常高 12%」。選中的黃底深框、下陰影 2；平的元件，按下蓋色（G-12）。
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.commodity,
    required this.quote,
    required this.on,
    required this.upIsRed,
    required this.onTap,
  });

  final Commodity commodity;
  final Quote? quote;
  final bool on;
  final bool upIsRed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final q = quote;
    return Semantics(
      container: true,
      button: true,
      selected: on,
      child: Pressable(
        key: Key('price-${commodity.wire}'),
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFFF1B8) : Colors.white,
              // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
              border: Border.all(color: on ? AppColors.ink : AppColors.lineSoft, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r14),
              boxShadow: on ? AppShadows.solid(2) : null,
            ),
            child: Row(
              children: [
                // .pr-ic：38×38 白底、圓角 12
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: const BorderRadius.all(AppRadii.r12),
                  ),
                  child: AppIcon(commodity.wire, size: 26),
                ),
                const SizedBox(width: 8),
                Text(s.commodity(commodity), softWrap: false, style: AppText.style(16, weight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: q == null ? '–' : priceText(q.price),
                              style: AppText.number(20, lineHeight: 24),
                            ),
                            const WidgetSpan(child: SizedBox(width: 2)),
                            TextSpan(
                              text: s.priceUnit(unit: s.unitOf(commodity)),
                              style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
                            ),
                          ],
                        ),
                        softWrap: false,
                      ),
                      const SizedBox(height: 1),
                      if (q?.vsBasePct case final v?) VsNormal(pct: v, upIsRed: upIsRed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// .vs：比平常高（紅漲綠跌，照設定）、比平常低、跟平常一樣（灰）。
class VsNormal extends StatelessWidget {
  const VsNormal({super.key, required this.pct, required this.upIsRed});

  final int pct;
  final bool upIsRed;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    if (pct == 0) {
      return Text(
        s.s06VsSame,
        style: AppText.style(12, weight: FontWeight.w900, color: AppColors.ink2),
      );
    }
    final up = pct > 0;
    final color = up ? AppColors.up(upIsRed: upIsRed) : AppColors.down(upIsRed: upIsRed);
    final text = up ? s.s06VsHigher(pct: '\u0000') : s.s06VsLower(pct: '\u0000');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(up ? 'up' : 'down', size: 11, color: color),
        const SizedBox(width: 2),
        Text.rich(
          TextSpan(
            style: AppText.style(12, weight: FontWeight.w900, color: color),
            children: fillSpans(text, AppText.number(14, color: color), '${pct.abs()}%'),
          ),
          softWrap: false,
        ),
      ],
    );
  }
}

/// .headline：選中的商品的最新一則新聞（一句）和多久以前。
class _Headline extends StatelessWidget {
  const _Headline({required this.news});

  final NewsItem news;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    return Container(
      key: const Key('headline'),
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1B8),
        // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
        boxShadow: AppShadows.solid(3),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.ink, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r12),
            ),
            child: const AppIcon('news', size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${s.newsTag(news)}${s.newsHeadline(news)}',
              style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            agoText(s, m, news.time),
            softWrap: false,
            style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// .sell-card：數量（¼、½、全部、滑桿）→ 拉完 0.3 秒後問伺服器試算 → 預估均價、總額 → 確認賣出。
/// 賣的時候從最舊的一批先賣；均價比市價差太多（伺服器的 warn_big_order）就提醒分批。
class SellCard extends StatefulWidget {
  const SellCard({super.key, required this.commodity, required this.onToast, this.onSold});

  final Commodity commodity;
  final void Function(ToastKind kind, String text) onToast;

  /// 賣出成功（A-02）；沒給就照 [onToast] 跳提示。
  final ValueChanged<SoldFx>? onSold;

  /// 拉滑桿後停多久才試算。
  static const debounce = Duration(milliseconds: 300);

  @override
  State<SellCard> createState() => _SellCardState();
}

class _SellCardState extends State<SellCard> {
  /// 滑桿位置：0 到 ceil(庫存) 的整數；最右邊 = 全部（送庫存原值，含小數）。null = 還沒動過，就是全部。
  int? _pos;
  Timer? _debounce;
  SellQuote? _quote;

  /// 上一次成功的試算：試算中、失敗時撐住預估框的高度。
  SellQuote? _lastQuote;
  bool _quoting = false;
  bool _failed = false;
  int _seq = 0;

  /// A-02 播的時候，賣出前的庫存和批數留到第 1.0 秒才換（設計稿 A02：「庫存扣掉，提示成交結果」）。
  ({double inv, int lots})? _held;
  Timer? _holdTimer;

  double _inventory(GameModel m) => _held?.inv ?? m.state?.warehouse.total(widget.commodity) ?? 0;

  /// 滑桿位置 → 要賣的量。
  static double qtyAt(int pos, double inv) {
    final steps = inv.ceil();
    if (steps <= 0 || pos <= 0) return 0;
    if (pos >= steps) return inv;
    return pos.toDouble();
  }

  @override
  void initState() {
    super.initState();
    // 一打開就試算全部的量（設計稿：賣出面板一直有預估）。直接在這裡開始，
    // 不等下一個畫面：等的話，使用者先拉的滑桿會被蓋回「全部」
    final inv = _inventory(context.read<GameModel>());
    if (inv > 0) {
      _quoting = true;
      _fetch(inv);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _requote(int pos, double inv, {bool now = false}) {
    final qty = qtyAt(pos, inv);
    setState(() {
      _pos = pos;
      _quoting = qty > 0;
      _failed = false;
      if (qty <= 0) _quote = null;
    });
    _debounce?.cancel();
    if (qty <= 0) return;
    if (now) {
      _fetch(qty);
    } else {
      _debounce = Timer(SellCard.debounce, () => _fetch(qty));
    }
  }

  Future<void> _fetch(double qty) async {
    final seq = ++_seq;
    final q = await context.read<GameModel>().quote(widget.commodity, qty);
    if (!mounted || seq != _seq) return; // 只採用最新一次
    setState(() {
      _quote = q;
      _lastQuote = q ?? _lastQuote;
      _quoting = false;
      _failed = q == null;
    });
  }

  /// 「確認賣出」：A-02 的金幣從這裡飛出去。
  final _confirmKey = GlobalKey();

  Future<void> _sell(double qty) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final coins = m.state?.coins.toDouble() ?? 0;
    final motion = AppMotion.read(context);
    final before = (inv: _inventory(m), lots: m.state?.warehouse.lotsOf(widget.commodity).length ?? 0);
    final r = await m.sell(widget.commodity, qty);
    if (!mounted) return;
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      widget.onToast(actionErrorKind(err), actionErrorTextWith(s, m, err));
      return;
    }
    final res = r.value!;
    final text = s.sold(
      qty: fmt(res.qty),
      unit: s.unitOf(widget.commodity),
      avg: priceText(res.avgPrice),
      total: fmt(res.total),
    );
    if (widget.onSold case final sold?) {
      sold(SoldFx(coins, text, _confirmKey));
    } else {
      widget.onToast(ToastKind.ok, text);
    }
    if (motion) {
      // A-02：庫存、數量、預估留到第 1.0 秒才換
      setState(() => _held = before);
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        _held = null;
        _afterSale(context.read<GameModel>());
      });
    } else {
      _afterSale(m);
    }
  }

  /// 賣完庫存變了：滑桿回到全部，重新試算。
  void _afterSale(GameModel m) {
    final inv = _inventory(m);
    _pos = null;
    if (inv > 0) {
      _requote(inv.ceil(), inv, now: true);
    } else {
      setState(() => _quote = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final c = widget.commodity;
    final name = s.commodity(c), unit = s.unitOf(c);
    final inv = _inventory(m);
    final lots = _held?.lots ?? m.state?.warehouse.lotsOf(c).length ?? 0;
    final steps = inv.ceil();
    final pos = (_pos ?? steps).clamp(0, steps);
    final qty = qtyAt(pos, inv);
    final online = m.online;
    final head = _CardHead(
      title: CardTitle(s.s06SellTitle(name: name)),
      sub: s.inventory(qty: fmt(inv), unit: unit) + (lots > 0 && inv > 0 ? s.s06Lots(n: lots) : ''),
    );

    // 倉庫裡沒有（S06-08）
    if (inv <= 0) {
      return AppCard(
        key: const Key('sell-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
              child: Text(
                s.nothingToSell(name: name),
                textAlign: TextAlign.center,
                style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 20),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(s.sellTitle, key: const Key('sell-confirm'), kind: ButtonKind.primary, block: true),
          ],
        ),
      );
    }

    final q = _quote;
    final warn = q?.serverWarn ?? false;
    final pct = steps == 0 ? 0 : (pos / steps * 100).round();
    final canSell = online && !_quoting && !_failed && q != null && qty > 0;
    void setPos(int p) => _requote(p, inv);
    return AppCard(
      key: const Key('sell-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          const SizedBox(height: 8),
          // .qty-row：英文、泰文放不下時三顆小按鈕換到下一行（screens.css 第 11 條）
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    s.s06Qty,
                    style: AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2),
                  ),
                  const SizedBox(width: 6),
                  Text(fmt(qty), key: const Key('sell-qty'), style: AppText.number(26, lineHeight: 30)),
                  const SizedBox(width: 4),
                  Text(unit, style: AppText.style(13, weight: FontWeight.w700)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, (label, p)) in [
                    ('¼', (steps / 4).round()),
                    ('½', (steps / 2).round()),
                    (s.gAll, steps),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _ChipButton(
                      label,
                      key: Key('sell-chip-$i'),
                      on: pos == p && p > 0,
                      onTap: online ? () => setPos(p) : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
          _SellSlider(
            fraction: steps == 0 ? 0 : pos / steps,
            enabled: online,
            onChanged: (f) => setPos((f * steps).round()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(s.s06OldestFirst, style: KitText.hint()),
          ),
          if (warn) const _BigWarn(),
          _Estimate(
            commodity: c,
            quote: q,
            quoting: _quoting,
            failed: _failed,
            previous: _lastQuote,
            onRetry: () => _requote(pos, inv, now: true),
          ),
          KeyedSubtree(
            key: _confirmKey,
            child: AppButton(
              s.sellConfirm(qty: fmt(qty), unit: unit),
              key: const Key('sell-confirm'),
              kind: ButtonKind.primary,
              block: true,
              busy: m.busy && online,
              onPressed: canSell && !m.busy ? () => _sell(qty) : null,
            ),
          ),
          // 試算用的百分比（給測試、截圖看）
          SizedBox(key: Key('sell-pct-$pct'), width: 0, height: 0),
        ],
      ),
    );
  }
}

/// .chip-btn：¼、½、全部（44×44 起、圓角 14；選中的黃底；停用灰色）。平的元件，按下蓋色（G-12）。
class _ChipButton extends StatelessWidget {
  const _ChipButton(this.label, {super.key, required this.on, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      container: true,
      button: true,
      selected: on,
      enabled: enabled,
      child: Pressable(
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !enabled
                  ? AppColors.disabledBg
                  : on
                  ? AppColors.yellow
                  : Colors.white,
              // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
              border: Border.all(color: enabled ? AppColors.ink : AppColors.disabledLine, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r14),
            ),
            child: Text(
              label,
              softWrap: false,
              style: AppText.style(14, weight: FontWeight.w900, color: enabled ? AppColors.ink : AppColors.ink3),
            ),
          ),
        ),
      ),
    );
  }
}

/// .slider：白色軌道（黃色填滿）加圓形把手；點或拖都可以。斷線時灰色、不能動。
class _SellSlider extends StatelessWidget {
  const _SellSlider({required this.fraction, required this.enabled, required this.onChanged});

  final double fraction;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final f = fraction.clamp(0.0, 1.0);
        void at(double x) => onChanged((x / w).clamp(0.0, 1.0));
        return GestureDetector(
          key: const Key('sell-slider'),
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (d) => at(d.localPosition.dx) : null,
          onHorizontalDragUpdate: enabled ? (d) => at(d.localPosition.dx) : null,
          child: SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 12,
                  height: 12,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: const BorderRadius.all(Radius.circular(7)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: f,
                      child: ColoredBox(color: enabled ? AppColors.yellow : AppColors.disabledLine),
                    ),
                  ),
                ),
                Positioned(
                  left: w * f - 15,
                  top: 3,
                  width: 30,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: enabled ? AppColors.ink : AppColors.disabledLine, width: 3),
                      boxShadow: enabled ? AppShadows.solid(2) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// .big-warn：一次賣太多（橘框）。
class _BigWarn extends StatelessWidget {
  const _BigWarn();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('big-warn'),
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1DC),
      // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
      border: Border.all(color: const Color(0xFFF0A04B), width: 2),
      borderRadius: const BorderRadius.all(AppRadii.r14),
    ),
    child: Row(
      children: [
        const AppIcon('warn', size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            Strings.of(context).tooMuch,
            style: AppText.style(14, weight: FontWeight.w900, color: const Color(0xFF9A4A12), lineHeight: 20),
          ),
        ),
      ],
    ),
  );
}

/// .est：試算中（轉圈）、試算失敗（重試）、試算完成（預估均價、預估總額、市價、成交價怎麼算）。
/// 試算中、失敗時：有上一次的結果就用它撐住框的高度（看不見），轉圈、重試疊在中間，
/// 捲到最底時畫面才不會跳（ceo 2026-10-02 同意，不改設計稿的樣子）；第一次試算還沒有結果就照設計稿至少 92 高。
class _Estimate extends StatelessWidget {
  const _Estimate({
    required this.commodity,
    required this.quote,
    required this.quoting,
    required this.failed,
    required this.onRetry,
    this.previous,
  });

  final Commodity commodity;
  final SellQuote? quote;
  final bool quoting;
  final bool failed;
  final VoidCallback onRetry;

  /// 上一次成功的試算（撐高度用）。
  final SellQuote? previous;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final q = quote;
    Widget box(Widget child, {bool center = false}) => Container(
      key: const Key('estimate'),
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: center ? const BoxConstraints(minHeight: 92) : null,
      alignment: center ? Alignment.center : null,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r14),
      ),
      child: child,
    );
    final bold = AppText.style(14, weight: FontWeight.w900);
    // 試算中、失敗：上一次的結果看不見但佔位子，內容疊在正中間
    Widget held(Widget content) {
      final prev = previous;
      if (prev == null) return box(content, center: true);
      return box(
        Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _okBody(s, prev, keys: false),
            ),
            content,
          ],
        ),
      );
    }

    if (quoting) {
      return held(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spinner(),
            const SizedBox(width: 10),
            Text(s.quoting, style: bold),
          ],
        ),
      );
    }
    if (failed || q == null) {
      return held(
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon('err', size: 18),
                const SizedBox(width: 4),
                Text(s.s06QuoteFailed, style: KitText.err(size: 14)),
              ],
            ),
            AppButton(s.retry, key: const Key('quote-retry'), small: true, icon: 'refresh', onPressed: onRetry),
          ],
        ),
      );
    }
    return box(_okBody(s, q));
  }

  /// 試算完成：預估均價、預估總額、市價、成交價怎麼算。[keys] 是 false 時不加 Key（撐高度的那一份）。
  Widget _okBody(Strings s, SellQuote q, {bool keys = true}) {
    final unit = s.unitOf(commodity);
    Widget row(String k, Text v) => _EstRow(
      label: Text(
        k,
        style: AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 24),
      ),
      value: v,
    );
    final mult = switch (commodity) {
      Commodity.milk => s.s06MultMilk,
      Commodity.beef => s.s06MultBeef,
      Commodity.rice => s.s06MultRice,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          s.estAvgPrice,
          Text(
            s.estAvgValue(avg: priceText(q.avgPrice), unit: unit),
            key: keys ? const Key('est-avg') : null,
            style: AppText.number(15, lineHeight: 24),
          ),
        ),
        row(
          s.s06EstTotalLabel,
          Text(
            s.costCoins(v: fmt(q.total)),
            key: keys ? const Key('est-total') : null,
            style: AppText.number(20, lineHeight: 24),
          ),
        ),
        row(
          s.s06MarketPrice,
          Text(
            s.gPricePer(price: priceText(q.marketPrice), unit: unit),
            style: AppText.number(15, lineHeight: 24),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(s.s06Formula(mult: mult), style: KitText.hint(size: 12, lineHeight: 17)),
        ),
      ],
    );
  }
}

/// .news-card：新聞列表（全部是虛構的）；沒有就一行「目前沒有新聞。」。
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.items});

  final List<NewsItem> items;

  /// 清單最多放幾則最新的（使用者 2026-10-03：「市場那邊留三個新聞就好」）。
  static const maxItems = 3;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final now = context.watch<GameModel>().gameNow;
    final pins = [
      for (final n in items)
        if (n.pinnedAt(now)) n,
    ];
    // 伺服器的新聞是新的在前；結束的超級事件回到清單，照時間排
    final rest = [
      for (final n in items)
        if (!n.pinnedAt(now)) n,
    ].take(maxItems).toList();
    return AppCard(
      key: const Key('news'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(
            title: CardTitle(s.newsTitle, color: const Color(0xFFFFC2B6), icon: 'news'),
          ),
          // 進行中的超級大事件、超級黑天鵝：大卡釘在最上面（S06-17），不算在下面的 3 則裡
          if (pins.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, n) in pins.indexed) ...[if (i > 0) const SizedBox(height: 10), NewsPinCard(news: n)],
          ],
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, n) in rest.indexed) ...[if (i > 0) const SizedBox(height: 8), _NewsItem(news: n)],
          ] else if (pins.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
              child: Text(s.noNews, style: KitText.hint()),
            ),
        ],
      ),
    );
  }
}

/// .news-item：商品標籤、級別（超級大事件、超級黑天鵝；結束以後回到清單的）、大新聞、利多／利空、多久以前；下面是標題。
class _NewsItem extends StatelessWidget {
  const _NewsItem({required this.news});

  final NewsItem news;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final upIsRed = context.watch<SettingsController>().upIsRed;
    final up = news.up;
    final dirColor = up == null
        ? AppColors.ink2
        : up
        ? AppColors.up(upIsRed: upIsRed)
        : AppColors.down(upIsRed: upIsRed);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // .n-tags：英文、泰文放不下時換行（screens.css 第 15 條）
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(s.newsTag(news), style: AppText.style(13, weight: FontWeight.w900)),
                    if (news.tier.extreme) NewsTierBadge(tier: news.tier),
                    // 超級事件的 big 也是 true（協定：大事件以上），標籤只放級別那一個
                    if (news.tier == NewsTier.big) CowBadge(BadgeKind.full, s.s06BigNews),
                    if (up != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(up ? 'up' : 'down', size: 11, color: dirColor),
                          const SizedBox(width: 2),
                          Text(
                            up ? s.s06Up : s.s06Down,
                            style: AppText.style(12, weight: FontWeight.w900, color: dirColor),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                agoText(s, m, news.time),
                softWrap: false,
                style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(s.newsHeadline(news), style: AppText.style(14, weight: FontWeight.w700, lineHeight: 20)),
        ],
      ),
    );
  }
}

/// .est-row：名稱和數字同一行、對齊字的基線（align-items: baseline），數字靠右；
/// 英文、泰文放不下時數字換到下一行、靠右（screens.css 第 15 條）。
class _EstRow extends StatelessWidget {
  const _EstRow({required this.label, required this.value});

  final Text label;
  final Text value;

  double _width(BuildContext context, Text t) {
    final painter = TextPainter(
      text: TextSpan(text: t.data, style: t.style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (_width(context, label) + 8 + _width(context, value) <= c.maxWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [label, const Spacer(), const SizedBox(width: 8), value],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          Align(alignment: Alignment.centerRight, child: value),
        ],
      );
    },
  );
}
