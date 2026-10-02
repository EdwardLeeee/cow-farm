// S03 牧場主畫面（設計稿 design/m2/src/js/screens/s03.js 的 ranchPage）：場景、跑馬燈、「我的牛」、下面的面板，
// 以及收奶的結果提示（S03-03、S03-04）、奶桶滿了的泡泡（S03-02）、第一次的滑動提示（S03-14）、大新聞（S03-15）、
// 空牧場（S03-08）。牛的小名片（S03-06）和牛舍清單（S03-07）在下一個 PR。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/press.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'dock.dart';
import 'pen_list.dart';
import 'scene.dart';

class RanchPage extends StatefulWidget {
  const RanchPage({super.key});

  @override
  State<RanchPage> createState() => _RanchPageState();
}

class _RanchPageState extends State<RanchPage> {
  double _pan = 0;

  /// 被點到的牛（S03-06：轉正面、跳出小名片）。
  Object? _popId;
  _Toast? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(_Toast t) {
    _toastTimer?.cancel();
    setState(() => _toast = t);
    _toastTimer = Timer(t.action == null ? const Duration(milliseconds: 2500) : const Duration(seconds: 5), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _collect() async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await m.collect();
    if (!mounted) return;
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(_Toast(ToastKind.err, actionErrorTextWith(s, m, err)));
      return;
    }
    final res = r.value ?? const {};
    final got = (res['collected'] as num?)?.toDouble() ?? 0;
    if (res['warehouse_full'] == true) {
      // 倉庫滿了，奶只收進一部分（S03-04）：剩下的留在奶桶；可以去加大倉庫
      final left = m.state?.bucket.amount ?? 0;
      _showToast(
        _Toast(
          ToastKind.warn,
          s.s03Partial(n: oneDecimal(got), left: oneDecimal(left)),
          action: AppButton(
            s.upWarehouse,
            key: const Key('go-upgrade'),
            small: true,
            kind: ButtonKind.primary,
            onPressed: () {
              setState(() => _toast = null);
              m.selectTab(AppTab.shop); // 設施升級（S10）做好之前先到商店分頁
            },
          ),
        ),
      );
    } else {
      _showToast(_Toast(ToastKind.ok, s.collected(v: oneDecimal(got))));
    }
  }

  // 每隔 uiTick 重畫：奶桶照伺服器的產量一直往上加，「幾分鐘後滿」、牛轉正面也跟著變（M1 也是這樣）
  @override
  Widget build(BuildContext context) => TickerBuilder(builder: _page);

  Widget _page(BuildContext context) {
    final m = context.watch<GameModel>();
    final settings = context.watch<SettingsController>();
    final s = Strings.of(context);
    final st = m.state!;
    final mq = MediaQuery.of(context);
    final safe = mq.padding;
    final bucket = m.bucketNow;
    final data = DockData(
      bucket: bucket,
      bucketCap: st.bucket.capacity,
      perHour: st.bucket.perHour,
      timeScale: m.timeScale,
      warehouse: st.warehouse,
      quotes: m.market?.quotes ?? const {},
      upIsRed: settings.upIsRed,
    );
    // 奶桶滿了：跟奶桶卡同一個判斷（百分比四捨五入到 100 就算滿），場景和面板才會一致
    final full = data.full;
    final herd = m.herdLayout.place(st.cows);
    // 奶桶滿了：產奶的牛轉正面（D11），編號最小的那頭頭上冒泡泡（S03-02）
    final producers = [
      for (final (c, _) in herd)
        if (c.milkPerH > 0) c,
    ];
    final bubbleCow = full && producers.isNotEmpty ? producers.first : null;
    // 被點到的牛也轉正面（D11）
    final cows = [for (final (c, slot) in herd) SceneCow(c, slot, front: (full && c.milkPerH > 0) || c.id == _popId)];
    final popCow = [
      for (final sc in cows)
        if (sc.cow.id == _popId) sc.cow,
    ].firstOrNull;
    final empty = st.cows.isEmpty;
    // 空牧場在很矮的手機（320×568）放不下「去商店」卡片：面板收成一條，卡片才不會疊到奶桶（m3-backlog）
    final shortScreen = mq.size.height < 700;
    final collapsed = settings.dockCollapsed || (empty && shortScreen);
    final bigNews = _bigNews(m, settings);
    final collectButton = AppButton(
      s.collect,
      key: const Key('collect'),
      kind: ButtonKind.blue,
      small: true,
      busy: m.busy && m.online,
      // 奶桶是 0（S03-05）或斷線時停用（M1 問題 4）
      onPressed: m.canAct && bucket > 0 ? _collect : null,
    );
    final top = safe.top + FrameSizes.hud;
    final news = m.market?.news.firstOrNull;
    final showSwipeHint = !settings.swipeHintSeen && !empty;

    return AppFrame(
      tab: AppTab.ranch,
      scene: RanchScene(
        cows: cows,
        pan: _pan,
        onPan: (p) {
          setState(() => _pan = p);
          if (!settings.swipeHintSeen) settings.markSwipeHintSeen();
        },
        // 點一頭牛：轉正面、跳出小名片；再點一次或點空地就收起來
        onTapCow: (c) => setState(() => _popId = _popId == c.id ? null : c.id),
        onTapEmpty: _popId == null ? null : () => setState(() => _popId = null),
      ),
      underlays: [if (bubbleCow != null) _BubbleAnchor(cows: cows, cow: bubbleCow, pan: _pan)],
      body: [
        if (news != null)
          Positioned(
            left: 12,
            right: 12,
            top: top + 14,
            height: 32,
            child: _Ticker(news: news),
          ),
        Positioned(
          left: 12,
          top: top + 58,
          child: _PenPill(used: st.pen.used, slots: st.pen.slots),
        ),
        if (empty)
          Positioned(
            left: 24,
            right: 24,
            top: top + 112,
            child: _EmptyRanch(onShop: () => m.selectTab(AppTab.shop)),
          ),
        if (showSwipeHint)
          Positioned(
            left: 0,
            right: 0,
            // 很矮的手機往上放，免得壓到奶桶（screens.css 的 @media (max-height: 700px)）
            top: top + (shortScreen ? 112 : 236),
            child: const Center(child: _SwipeHint()),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: FrameSizes.contentBottom(safe) + 10,
          child: Dock(
            data: data,
            collapsed: collapsed,
            pan: _pan,
            onToggle: () => settings.setDockCollapsed(!collapsed),
            collect: collectButton,
          ),
        ),
      ],
      overlays: [
        if (popCow != null) _CowPopAnchor(cows: cows, cow: popCow, pan: _pan),
        if (bigNews != null)
          Positioned(
            left: 16,
            right: 16,
            top: top + 120,
            child: _BigNews(
              news: bigNews,
              quote: m.market?.quotes[bigNews.commodity],
              upIsRed: settings.upIsRed,
              onClose: () => settings.markBigNewsSeen(bigNews.id),
              onGo: () {
                settings.markBigNewsSeen(bigNews.id);
                m.selectTab(AppTab.market);
              },
            ),
          ),
        if (_toast != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: FrameSizes.contentBottom(safe) + 14,
            child: Center(
              child: ToastPill(_toast!.text, kind: _toast!.kind, action: _toast!.action, key: const Key('toast')),
            ),
          ),
      ],
    );
  }

  /// 大新聞（收購價大漲或大跌 20% 以上，企劃書 4.7、D24、m3-backlog）：還沒看過的那一則，跳出一次（S03-15）。
  /// 觸發條件只看幅度，不看伺服器的 big（big 是 ±30–40% 的罕見新聞；ceo 2026-10-02）。
  /// 全部商品一起漲跌的新聞：等 cow-ui 補「全部商品」的文案、使用者核准之前，先不跳。
  static NewsItem? _bigNews(GameModel m, SettingsController settings) {
    for (final n in m.market?.news ?? const <NewsItem>[]) {
      if (n.pct.abs() >= 0.2 && n.commodity != null && !n.upcoming && !settings.bigNewsSeen(n.id)) return n;
    }
    return null;
  }
}

class _Toast {
  const _Toast(this.kind, this.text, {this.action});
  final ToastKind kind;
  final String text;
  final Widget? action;
}

/// 「奶桶滿了」泡泡（.bubble）：在那頭牛的頭頂上方，跟著場景左右捲。
class _BubbleAnchor extends StatelessWidget {
  const _BubbleAnchor({required this.cows, required this.cow, required this.pan});

  final List<SceneCow> cows;
  final Cow cow;
  final double pan;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final fit = SceneFit(c.biggest, pan);
          final sc = cows.firstWhere((x) => x.cow.id == cow.id);
          final p = CowPlacement.of(sc, fit);
          if (p == null) return const SizedBox.shrink();
          // left: 頭頂 x、top: 頭頂 y − 4，再往上移自己的高度、置中（translate(-50%, -100%)），margin-top −8
          return Stack(
            children: [
              Positioned(
                left: p.head.dx - 150,
                width: 300,
                bottom: c.maxHeight - (p.head.dy - 4 - 8),
                child: const Center(child: _Bubble()),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return CustomPaint(
      painter: _BubbleTail(),
      child: Container(
        key: const Key('bubble-full'),
        padding: const EdgeInsets.fromLTRB(5, 2, 10, 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.ink, width: AppSizes.border),
          borderRadius: const BorderRadius.all(AppRadii.r16),
          boxShadow: AppShadows.solid(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('pail', size: 22),
            const SizedBox(width: 3),
            Text(s.s03BubbleFull, style: AppText.style(13, weight: FontWeight.w900, lineHeight: 22)),
          ],
        ),
      ),
    );
  }
}

/// 泡泡下面的小尖角：外面深色（寬 18、高 11）、裡面白色（寬 12、高 8）。
class _BubbleTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    Path tri(double halfW, double h, double top) => Path()
      ..moveTo(cx - halfW, top)
      ..lineTo(cx + halfW, top)
      ..lineTo(cx, top + h)
      ..close();
    canvas.drawPath(tri(9, 11, size.height + 2), Paint()..color = AppColors.ink);
    canvas.drawPath(tri(6, 8, size.height - 1), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) => false;
}

/// .ticker：最新一則新聞，太長就跑馬燈（減少動態時不跑）。
class _Ticker extends StatelessWidget {
  const _Ticker({required this.news});

  final NewsItem news;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = news.commodity;
    final tag = c == null ? s.bothTag : s.commodityTag(name: commodityName(s, c));
    return Container(
      key: const Key('ticker'),
      padding: const EdgeInsets.fromLTRB(3, 0, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1B8),
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        boxShadow: AppShadows.solid(),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 24,
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
            child: Marquee(
              '$tag${s.newsHeadline(news)}',
              style: AppText.style(13, weight: FontWeight.w700, lineHeight: 26),
            ),
          ),
        ],
      ),
    );
  }
}

/// 商品名（牛奶、牛肉、稻米）。
String commodityName(Strings s, Commodity c) => switch (c) {
  Commodity.milk => s.milk,
  Commodity.beef => s.beef,
  Commodity.rice => s.rice,
};

/// 一行字：放得下就不動；放不下就慢慢往左跑、接著再出現（設計稿 data-marquee）。手機開了「減少動態」就不跑，超出的切掉。
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  static const _gap = 48.0;
  static const _speed = 36.0; // 每秒幾點
  late final _run = AnimationController(vsync: this);

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = tp.width;
      final still = MediaQuery.disableAnimationsOf(context);
      final text = Text(widget.text, style: widget.style, maxLines: 1, softWrap: false, overflow: TextOverflow.clip);
      if (width <= c.maxWidth || still) {
        if (_run.isAnimating) _run.stop();
        return ClipRect(
          child: Align(alignment: Alignment.centerLeft, child: text),
        );
      }
      final period = Duration(milliseconds: ((width + _gap) / _speed * 1000).round());
      if (_run.duration != period || !_run.isAnimating) {
        _run
          ..duration = period
          ..repeat();
      }
      return ClipRect(
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, child) =>
              Transform.translate(offset: Offset(-(width + _gap) * _run.value, 0), child: child),
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                const SizedBox(width: _gap),
                text,
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// .pen-pill：「我的牛 10 / 12 ›」；滿了變粉紅。按下去開牛舍清單。
class _PenPill extends StatelessWidget {
  const _PenPill({required this.used, required this.slots});

  final int used;
  final int slots;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    // 按下：往下 2、陰影變 1（G-12）
    return Pressable(
      key: const Key('pen-pill'),
      lift: 3,
      onTap: m.openPenList,
      builder: (context, look) => PressTint(
        tint: look.tint,
        borderRadius: const BorderRadius.all(AppRadii.r22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
          decoration: BoxDecoration(
            color: used >= slots ? const Color(0xFFFFE1DB) : Colors.white,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(AppRadii.r22),
            boxShadow: AppShadows.solid(look.shadow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon('barn', size: 22),
              const SizedBox(width: 6),
              Text(s.cowsTitle, style: AppText.style(14, weight: FontWeight.w900)),
              const SizedBox(width: 6),
              Text('$used / $slots', style: AppText.number(15)),
              const SizedBox(width: 6),
              const AppIcon('chevron', size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一頭牛都沒有（S03-08）：「牛舍裡還沒有牛」、到商店抽一頭、「去商店」。
class _EmptyRanch extends StatelessWidget {
  const _EmptyRanch({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('empty-ranch'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          children: [
            Text(
              s.noCows,
              textAlign: TextAlign.center,
              style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
            ),
            const SizedBox(height: 10),
            Text(s.s03EmptyHint, textAlign: TextAlign.center, style: KitText.hint(size: 14, lineHeight: 21)),
            const SizedBox(height: 10),
            AppButton(s.s03GoShop, key: const Key('go-shop'), kind: ButtonKind.primary, onPressed: onShop),
          ],
        ),
      ),
    );
  }
}

/// 第一次打開牧場的滑動提示（S03-14），拖動一次就不再出現。
class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      key: const Key('swipe-hint'),
      // 英文放不下一行（360、320）就換行，左右留 16
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(AppRadii.r22),
        boxShadow: AppShadows.solid(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('back', size: 18),
          const SizedBox(width: 6),
          const AppIcon('hand', size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              Strings.of(context).s03SwipeHint,
              textAlign: TextAlign.center,
              style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20),
            ),
          ),
          const SizedBox(width: 6),
          const AppIcon('chevron', size: 18),
        ],
      ),
    ),
  );
}

/// 大新聞提示（S03-15）：標籤、商品圖示、標題、「牛肉收購價 +25%，現在 15 幣／公斤」、「去市場看看」、右上角關閉。
class _BigNews extends StatelessWidget {
  const _BigNews({
    required this.news,
    required this.quote,
    required this.upIsRed,
    required this.onClose,
    required this.onGo,
  });

  final NewsItem news;
  final Quote? quote;
  final bool upIsRed;
  final VoidCallback onClose;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = news.commodity!;
    final up = news.pct >= 0;
    final pct = '${up ? '+' : '−'}${(news.pct.abs() * 100).round()}%';
    final unit = switch (c) {
      Commodity.milk => s.unitMilk,
      Commodity.beef => s.unitBeef,
      Commodity.rice => s.unitRice,
    };
    final body = s.s03BigNewsBody(
      name: commodityName(s, c),
      chg: '\u0000',
      price: priceText(quote?.price ?? 0),
      unit: unit,
    );
    return Container(
      key: const Key('big-news'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(AppRadii.r18),
        boxShadow: AppShadows.solid(4),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: const BorderRadius.all(AppRadii.r10),
                  ),
                  child: Text(
                    s.s06BigNews,
                    style: AppText.style(12, weight: FontWeight.w900, color: Colors.white, lineHeight: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      borderRadius: const BorderRadius.all(AppRadii.r16),
                    ),
                    child: AppIcon(c.wire, size: 34),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.newsHeadline(news), style: AppText.style(18, weight: FontWeight.w900, lineHeight: 24)),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            style: AppText.style(14, weight: FontWeight.w700, lineHeight: 20),
                            children: fillSpans(
                              body,
                              AppText.style(
                                16,
                                weight: FontWeight.w900,
                                color: up ? AppColors.up(upIsRed: upIsRed) : AppColors.down(upIsRed: upIsRed),
                              ),
                              pct,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                s.s03BigNewsGo,
                key: const Key('big-news-go'),
                kind: ButtonKind.primary,
                block: true,
                icon: 'coin',
                onPressed: onGo,
              ),
            ],
          ),
          Positioned(
            right: -12 + 4,
            top: -12 + 4,
            child: Semantics(
              button: true,
              label: s.gClose,
              // 平的元件：按下蓋一層顏色（圓形，G-13）
              child: Pressable(
                key: const Key('big-news-close'),
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
      ),
    );
  }
}

/// 牛的小名片（S03-06，.cow-pop）：在那頭牛頭頂上方 14，左右夾在螢幕左 12 到右 220 之間；下面一個小尖角對著牛。
/// 設計稿沒畫到：後排的牛名片會超出畫面上緣（320×568 最多超出 70），所以名片的上緣最高到安全區下面 6，
/// 這時名片會蓋到牛（先這樣做，等 cow-ui 定規則）。
class _CowPopAnchor extends StatelessWidget {
  const _CowPopAnchor({required this.cows, required this.cow, required this.pan});

  final List<SceneCow> cows;
  final Cow cow;
  final double pan;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) {
          final p = CowPlacement.of(cows.firstWhere((x) => x.cow.id == cow.id), SceneFit(c.biggest, pan));
          if (p == null) return const SizedBox.shrink();
          return CustomSingleChildLayout(
            delegate: _PopLayout(head: p.head, minTop: safeTop + 6),
            child: _CowPop(cow: cow),
          );
        },
      ),
    );
  }
}

/// 名片寬 208：左邊 = 頭的 x − 43（夾在 12 到 寬 − 220），下緣 = 頭頂 − 14，上緣不高過 [minTop]。
class _PopLayout extends SingleChildLayoutDelegate {
  _PopLayout({required this.head, required this.minTop});

  final Offset head;
  final double minTop;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints.tightFor(width: 208);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset((head.dx - 43).clamp(12.0, size.width - 220), math.max(head.dy - 14 - childSize.height, minTop));

  @override
  bool shouldRelayout(_PopLayout oldDelegate) => oldDelegate.head != head || oldDelegate.minTop != minTop;
}

class _CowPop extends StatelessWidget {
  const _CowPop({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final s = Strings.of(context);
    final id = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    // 設計稿只畫了產奶的牛：寫產量。其他的牛狀態看標籤（小牛、老牛、上架中、已配種），不另外寫一行（等 cow-ui 定）
    final meta = cow.milkPerH > 0
        ? s.s03PopMilk(tier: s.tierName((breedInfo(cow.breed)?.tier ?? cow.tier).clamp(0, 3)), n: rateNum(cow.milkPerH))
        : null;
    return CustomPaint(
      key: const Key('cow-pop'),
      // 尖角畫在名片上面，蓋掉下框的一段
      foregroundPainter: _PopTail(),
      // .cow-pop 的框、圓角、陰影、內距跟 .card 一樣
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 名字放不下（英文「Strawberry Cow #12」）就換行，字級不變，編號才不會被截掉
            Text(s.cowName(cow.breed, id), style: AppText.style(17, weight: FontWeight.w900, lineHeight: 22)),
            const SizedBox(height: 4),
            // 用途、公母、稀有度，再加上狀態（scope.md S03-06：品種、稀有度、狀態）
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: cowChips(context, cow),
            ),
            if (meta != null) ...[
              const SizedBox(height: 2),
              Text(
                meta,
                style: AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 19),
              ),
            ],
            const SizedBox(height: 8),
            AppButton(
              s.s03PopDetail,
              key: const Key('pop-detail'),
              small: true,
              block: true,
              kind: ButtonKind.primary,
              onPressed: () => m.openCow(cow.key),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小名片下面的尖角（.cow-pop::after）：一個方塊轉 45°，只有右邊和下面有 3 的框、右下角圓角 4。
/// `* { box-sizing: border-box }` 管不到 ::after，所以方塊是內容 18 加框 3 = 21×21。
/// 方塊的左邊在框內 34（外框往右 3 + 34），下緣在框內往下 12（外框下緣往下 9），
/// 所以中心在外框左邊往右 47.5、外框下緣往上 1.5。方塊的底色蓋掉名片下框的一段，看起來是名片長出一個尖角。
class _PopTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(3 + 34 + 10.5, size.height - 1.5);
    canvas.rotate(math.pi / 4);
    // 底色只畫到框線的中間：底色的鋸齒邊藏在框線底下，名片的下框上才不會多一條淡淡的邊
    canvas.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTRB(-10.5, -10.5, 9, 9), bottomRight: const Radius.circular(2.5)),
      Paint()..color = AppColors.paper,
    );
    // CSS 的框畫在方塊裡面：線的中心在邊往內 1.5，轉角的半徑 4 − 1.5
    canvas.drawPath(
      Path()
        ..moveTo(9, -10.5)
        ..lineTo(9, 6.5)
        ..arcToPoint(const Offset(6.5, 9), radius: const Radius.circular(2.5))
        ..lineTo(-10.5, 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PopTail oldDelegate) => false;
}
