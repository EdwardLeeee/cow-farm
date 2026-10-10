// S18 借種市場（設計稿 s08.js 的 studPage、studRow、myBulls；screens.css 的 .my-bulls、.mb-row、.mb-note、.link-row、
// .market-sec、.stud-row、.sr-*）：配種頁的「借種」分頁。借種紀錄在 stud_log_page.dart。
// 借種費是伺服器算的（D26）；市場列表、機率、能不能借都看伺服器。錢夠不夠只是先把按鈕停用，帳一律由伺服器算。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/note_line.dart';
import '../kit/press.dart';
import '../kit/pull_refresh.dart';
import '../widgets/action_button.dart';
import 'breed_page.dart';

/// 「借種」分頁：我的公牛出借、借種市場、選自己的母牛、可能生出的小牛、借種。[seg] 是最上面的分頁膠囊。
class StudTab extends StatefulWidget {
  const StudTab({super.key, required this.seg});

  final Widget seg;

  @override
  State<StudTab> createState() => _StudTabState();
}

class _StudTabState extends State<StudTab> {
  StudMarket? _market;
  bool _loading = true;
  String? _listingKey;
  String? _damKey;
  late final _fetch = PreviewFetcher(isMounted: () => mounted, setState: setState);

  /// 剛借到的（S18-09）：那一筆和母牛照樣顯示成選好的、留著機率，按鈕換成「已借種」，下面放新小牛。換選別的才清掉。
  /// 那一筆留整個物件：重新整理市場以後伺服器的列表已經沒有它了（借出去的公牛下架），下面的卡片也不能跟著不見。
  ({StudListing listing, String dam, BreedPreview preview, Cow? calf})? _done;
  bool _borrowing = false;

  /// 預覽說這頭公牛已經借不到了（listing_gone）：同一筆只跳一次對話框。
  String? _goneShown;

  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;
  final _scroll = ScrollController();
  final _calfKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _fetch.dispose();
    _toastTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 重抓市場（第一次打開、下拉、按「重新整理」）。選的那一筆不在了（被借走、下架）就取消。
  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final mk = await context.read<GameModel>().studMarket();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _market = mk ?? _market;
      final listings = _market?.listings ?? const <StudListing>[];
      if (_done == null && !listings.any((l) => l.key == _listingKey)) _listingKey = null;
    });
  }

  void _pickListing(StudListing l) => setState(() {
    _done = null;
    _listingKey = _listingKey == l.key ? null : l.key;
  });

  void _pickDam(Cow c, {required bool on}) => setState(() {
    _done = null;
    _damKey = on ? null : c.key;
  });

  Future<void> _showDialog(Widget Function(BuildContext) builder) => showDialog<void>(
    context: context,
    barrierColor: Colors.transparent, // 暗幕由 AppDialog 自己畫
    useSafeArea: false,
    builder: builder,
  );

  /// 預覽回 404：那一筆已經被借走或下架（例：看了列表、過一段時間才選）。跳 S18-10（同一筆只跳一次），
  /// 不再每 3 秒重試；按「重新整理市場」取消選擇、重抓市場。
  void _previewGone() {
    final key = _fetch.key;
    if (!mounted || _goneShown == key) return;
    _goneShown = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetch.stopRetry();
      _gone();
    });
  }

  /// S18-10：這頭公牛剛被別人借走、或主人下架了。按「重新整理市場」重抓、取消選擇。
  Future<void> _gone() async {
    final s = Strings.of(context, listen: false);
    await _showDialog(
      (context) => AppDialog(
        title: s.s18GoneTitle,
        body: Text(s.s18GoneBody, key: const Key('gone-body'), textAlign: TextAlign.center),
        buttons: [
          AppButton(
            s.s18ReloadMarket,
            key: const Key('gone-reload'),
            kind: ButtonKind.primary,
            icon: 'refresh',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _listingKey = null;
      _done = null;
    });
    unawaited(_reload());
  }

  Future<void> _borrow(StudListing l, Cow dam, BreedPreview p, int price) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    setState(() => _borrowing = true);
    final r = await m.studBorrow(l, dam, price: price);
    if (!mounted) return;
    setState(() => _borrowing = false);
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error)) {
        if (error.maintenance || error.unauthorized) return;
        switch (error.code) {
          // S18-12：公牛長大了，借種費跟剛剛看的不一樣；按「用新價格借」用新的價格重送
          case 'price_changed':
            final now = error.detail['price'];
            if (now is num) {
              await _feeChanged(l, dam, p, old: price, now: now.round());
              return;
            }
          case 'listing_not_found' || 'listing_gone':
            await _gone();
            return;
        }
      }
      // 其他原因（例如母牛剛被別的手機用掉了）：重抓機率，下面的提醒照最新的原因
      setState(_fetch.invalidate);
      _showToast(actionErrorKind(err), actionErrorTextWith(s, m, err));
      return;
    }
    final calf = r.value?.calf;
    setState(() => _done = (listing: l, dam: dam.key, preview: p, calf: calf));
    _showToast(ToastKind.ok, s.borrowed(price: fmt(price)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCalf());
  }

  Future<void> _feeChanged(StudListing l, Cow dam, BreedPreview p, {required int old, required int now}) async {
    final s = Strings.of(context, listen: false);
    var again = false;
    await _showDialog(
      (context) => AppDialog(
        title: s.s18FeeChangedTitle,
        body: Text.rich(
          TextSpan(
            children: [
              for (final part in _boldParts(
                s.s18FeeChangedBody(old: '\u0001${fmt(old)}\u0001', now: '\u0001${fmt(now)}\u0001'),
              ))
                TextSpan(text: part.$1, style: part.$2 ? AppText.number(14, lineHeight: 21) : null),
            ],
          ),
          key: const Key('fee-changed-body'),
          textAlign: TextAlign.center,
        ),
        buttons: [
          AppButton(s.cancel, key: const Key('fee-changed-cancel'), onPressed: () => Navigator.of(context).pop()),
          AppButton(
            s.s18BorrowNew(price: fmt(now)),
            key: const Key('fee-changed-borrow'),
            kind: ButtonKind.pink,
            onPressed: () {
              again = true;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (again) {
      await _borrow(l, dam, p, now);
    } else {
      setState(_fetch.invalidate); // 不借了：重抓機率和新的借種費
    }
  }

  /// 借到以後捲到新小牛的卡片：卡片的下緣在內容區下緣往上 18（設計稿 S18-09 的 scrollTo）。
  void _revealCalf() {
    final box = _calfKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !_scroll.hasClients) return;
    final p = _scroll.position;
    final target = (RenderAbstractViewport.of(box).getOffsetToReveal(box, 1).offset + 18).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      p.jumpTo(target);
    } else {
      p.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final now = m.gameNow;
    final done = _done;
    // 市場列表不放自己上架的（缺口清單 3-4，它們在上面「我的公牛」那張卡）
    final others = [
      for (final l in _market?.listings ?? const <StudListing>[])
        if (!l.isMine) l,
    ];
    final listing = done?.listing ?? others.where((l) => l.key == _listingKey).firstOrNull;
    var dam = (done?.dam ?? _damKey) == null ? null : st.cowById(done?.dam ?? _damKey!);
    if (done == null && dam != null && !dam.canBreedAt(now)) dam = null;
    _fetch.ensure(m, listing == null || dam == null ? null : '${listing.key}|${dam.key}', () async {
      final r = await m.studPreview(listing!, dam!);
      if (r.gone) _previewGone();
      return r.preview;
    }, hold: done != null);
    final preview = done?.preview ?? _fetch.value;
    final outcome = _fetch.state(m, picked: listing != null && dam != null, shown: preview);
    // 借種費：預覽的是這一刻的價格（公牛長大會漲），還沒有預覽就看市場列表的
    final price = preview?.fee?.price ?? listing?.price;
    // 剛借到（已借種）不放提醒：新小牛可能剛好把牛舍佔滿、錢也可能不夠再借，成功下面跳橘字像是失敗（設計稿 S18-09
    // 沒有；ceo 2026-10-02）。換選別的、清掉剛借到的那一筆以後照常提醒
    final notes = listing == null || done != null
        ? const <String>[]
        : studNotes(s, m, preview: outcome == OutcomeState.ok ? preview : null, dam: dam, price: price);
    if (done == null &&
        preview != null &&
        preview.blockers.any((b) => b.code == 'listing_gone') &&
        _goneShown != _fetch.key) {
      _goneShown = _fetch.key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _gone());
    }
    final canBorrow =
        done == null &&
        listing != null &&
        outcome == OutcomeState.ok &&
        preview!.canBreed &&
        notes.isEmpty &&
        price != null &&
        m.canAct &&
        !_borrowing;
    final calf = done == null ? null : (st.cowById(done.calf?.key ?? '') ?? done.calf);
    final dams = [
      for (final c in st.cows)
        if (!c.bull) c,
    ];

    Widget pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: child);
    final safe = MediaQuery.paddingOf(context);
    return AppFrame(
      tab: AppTab.breed,
      contentPadding: EdgeInsets.zero,
      content: PullRefresh(
        onRefresh: _reload,
        builder: (context, refreshing) => ListView(
          key: const Key('stud'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
          children: [
            // G-09：下拉重新整理時，最上面多一行「轉圈＋重新整理中…」
            if (refreshing) ...[const PullIndicator(), const SizedBox(height: 10)],
            pad(widget.seg),
            const SizedBox(height: 12),
            pad(MyBullsCard(onToast: _showToast)),
            const SizedBox(height: 12),
            pad(_MarketHead(s: s)),
            const SizedBox(height: 8),
            pad(
              _loading && _market == null
                  ? MarketEmpty(kind: MarketEmptyKind.loading, onReload: _reload)
                  : _market == null
                  ? MarketEmpty(kind: MarketEmptyKind.failed, onReload: _reload)
                  : others.isEmpty
                  ? MarketEmpty(kind: MarketEmptyKind.empty, onReload: _reload)
                  : Column(
                      key: const Key('stud-list'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, l) in others.indexed) ...[
                          if (i > 0) const SizedBox(height: 10),
                          StudRow(
                            key: Key('stud-listing-${l.key}'),
                            listing: l,
                            on: l.key == listing?.key,
                            onTap: () => _pickListing(l),
                          ),
                        ],
                      ],
                    ),
            ),
            if (listing != null) ...[
              const SizedBox(height: 12),
              PickSection(
                title: s.pickDamForStud,
                child: dams.any((c) => c.isAdultAt(now))
                    ? PickRow(
                        key: const Key('stud-dam-row'),
                        children: [
                          for (final (c, off) in pickOrder(dams, now, keep: {?done?.dam}))
                            PickCard(
                              key: Key('stud-dam-${c.key}'),
                              cow: c,
                              on: c.key == dam?.key,
                              off: off,
                              onTap: () => _pickDam(c, on: c.key == dam?.key),
                            ),
                        ],
                      )
                    : PickEmpty(key: const Key('stud-no-dam'), title: s.noDam, hint: s.s08NoDamHint),
              ),
              const SizedBox(height: 12),
              pad(
                OutcomeCard(
                  state: outcome,
                  preview: preview,
                  fee: price == null ? null : s.s18FeeLine(price: fmt(price)),
                  noneText: s.pickListing,
                ),
              ),
              for (final (i, n) in notes.indexed) ...[
                const SizedBox(height: 12),
                pad(NoteLine(key: Key('stud-note-$i'), icon: 'warn', text: n, kind: NoteKind.warn)),
              ],
              const SizedBox(height: 12),
              pad(
                AppButton(
                  done != null ? s.s18BorrowedBtn : s.borrow(price: fmt(price ?? listing.price)),
                  key: const Key('stud-borrow'),
                  kind: ButtonKind.pink,
                  block: true,
                  icon: 'heart',
                  busy: _borrowing,
                  onPressed: canBorrow ? () => _borrow(listing, dam!, preview, price) : null,
                ),
              ),
              if (calf != null) ...[const SizedBox(height: 12), pad(CalfCard(key: _calfKey, calf: calf))],
            ],
          ],
        ),
      ),
      overlays: [
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: FrameSizes.contentBottom(safe) + 14,
            child: Center(
              child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
            ),
          ),
      ],
    );
  }
}

/// 字串裡用 \u0001 包起來的部分要粗體（例：「借種費從 {old} 幣變成 {now} 幣」的兩個數字）。回傳（字，是不是粗體）。
List<(String, bool)> _boldParts(String text) => [
  for (final (i, p) in text.split('\u0001').indexed)
    if (p.isNotEmpty) (p, i.isOdd),
];

/// 借種的橘字提醒（S18-08）：伺服器的 blockers 一個一行（缺口清單 3-1）；錢不夠、牛舍滿了另外看 state（還沒選母牛也提醒），
/// 跟 blockers 的同一種只放一次。`listing_gone` 不寫在這裡，跳對話框（S18-10）。
List<String> studNotes(
  Strings s,
  GameModel m, {
  required BreedPreview? preview,
  required Cow? dam,
  required int? price,
}) {
  final st = m.state!;
  final out = <String>[];
  var coins = false, penFull = false;
  for (final b in preview?.blockers ?? const <Blocker>[]) {
    switch (b.code) {
      case 'listing_gone':
        continue;
      case 'own_listing':
        out.add(s.unknownError);
      case 'pen_full':
        if (penFull) continue;
        penFull = true;
        out.add(s.s08PenFull);
      case 'not_enough_coins':
        if (coins) continue;
        coins = true;
        out.add(s.blockerText(b));
      case 'already_bred':
        out.add(s.s08AlreadyBred(cow: dam == null ? '' : s.cowLabel(dam)));
      default:
        out.add(s.blockerText(b, gameNow: m.gameNow, timeScale: m.timeScale));
    }
  }
  if (!coins && price != null && st.coins < price) out.insert(0, s.notEnoughCoins(n: fmt(price - st.coins)));
  if (!penFull && st.pen.full) out.add(s.s08PenFull);
  return out;
}

/// .market-sec 的標題列：「借種市場」、右邊「下拉重新整理」；下面一行說明。
class _MarketHead extends StatelessWidget {
  const _MarketHead({required this.s});

  final Strings s;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('market-head'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            Text(s.studMarketTitle, style: AppText.style(16, weight: FontWeight.w900, lineHeight: 22)),
            const SizedBox(width: 6),
            const Spacer(),
            Text(s.s18PullHint, style: KitText.hint()),
          ],
        ),
      ),
      Text(s.s18MarketHint, style: KitText.hint()),
    ],
  );
}

enum MarketEmptyKind { loading, failed, empty }

/// 市場還沒有列表的時候（S18-05）：載入中、載入失敗（重新整理）、沒有別人上架。卡片裡一句話置中。
class MarketEmpty extends StatelessWidget {
  const MarketEmpty({super.key, required this.kind, required this.onReload});

  final MarketEmptyKind kind;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final style = AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2);
    final children = switch (kind) {
      MarketEmptyKind.loading => [
        const Spinner(),
        const SizedBox(width: 8),
        Flexible(child: Text(s.gLoading, style: style)),
      ],
      MarketEmptyKind.failed => [
        Flexible(
          child: Text.rich(
            TextSpan(
              style: KitText.err(),
              children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: AppIcon('err', size: 20),
                ),
                TextSpan(text: ' ${s.loadFailed}'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        AppButton(s.reload, key: const Key('market-reload'), small: true, icon: 'refresh', onPressed: onReload),
      ],
      MarketEmptyKind.empty => [
        Flexible(
          child: Text(s.studEmpty, textAlign: TextAlign.center, style: style),
        ),
      ],
    };
    return AppCard(
      key: Key('market-${kind.name}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    );
  }
}

/// .card.stud-row：別人上架的一頭公牛：小圖、品種＋「公」、用途和稀有度、主人（電腦標記、名字、#編號），右邊借種費
/// （還會漲的寫「還在長」）。選中的淡黃底、外圈黃色、右上角勾勾。浮起的元件，按下往下 3（G-13）。
class StudRow extends StatelessWidget {
  const StudRow({super.key, required this.listing, required this.on, required this.onTap});

  final StudListing listing;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final l = listing;
    final owner = l.owner;
    final tag = Strings.ranchTag(owner);
    final ownerStyle = AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 17);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      child: Pressable(
        lift: 4,
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFFFF1B8) : AppColors.paper,
                  border: Border.all(color: AppColors.ink, width: AppSizes.border),
                  borderRadius: const BorderRadius.all(AppRadii.r18),
                  boxShadow: [
                    if (on) const BoxShadow(color: AppColors.yellow, spreadRadius: 3),
                    BoxShadow(color: AppColors.ink, offset: Offset(0, look.shadow)),
                  ],
                ),
                child: Row(
                  children: [
                    CowPicBox(
                      radius: 14,
                      child: CowPicture(
                        // 雜種牛照用途的體型（#157）
                        breed: lookOf(l.breed, l.type),
                        bull: true,
                        variant: _variant(l),
                        width: 60,
                        height: 60,
                        pad: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // .sr-name：品種名，後面小字「公」；英文、泰文中間空一格（breedSexGap）。
                          // 英文、泰文放不下（例 Taiwan Yellow Ox Bull）就換行，不截掉也不蓋到右邊的借種費
                          CssLine(
                            TextSpan(
                              style: AppText.style(15, weight: FontWeight.w900, lineHeight: 20),
                              children: [
                                TextSpan(text: '${s.breedName(l.breed)}${s.breedSexGap}'),
                                TextSpan(
                                  text: s.bull,
                                  style: AppText.style(12, weight: FontWeight.w900, lineHeight: 18),
                                ),
                              ],
                            ),
                            wrap: true,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [UseChip(l.type), rarityChip(l.breed, l.tier)],
                          ),
                          const SizedBox(height: 2),
                          // .sr-owner：主人：［電腦］名字 #編號；太長只截名字，「電腦」和 #編號一定看得到（S18-13）
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(s.s18OwnerLabel, style: ownerStyle),
                              if (owner != null && owner.isBot)
                                Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.ink2,
                                    borderRadius: BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: Text(
                                    s.botPrefix,
                                    style: AppText.style(
                                      12,
                                      weight: FontWeight.w900,
                                      color: Colors.white,
                                      lineHeight: 15,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  s.ranchName(owner),
                                  key: Key('stud-owner-${l.key}'),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: ownerStyle,
                                ),
                              ),
                              if (tag != null && !(owner?.isBot ?? false)) ...[
                                const SizedBox(width: 4),
                                Text(tag, style: ownerStyle),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // .sr-price：金幣、借種費；還會漲的下面寫「還在長」
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon('coin', size: 22),
                            const SizedBox(width: 3),
                            Text(fmt(l.price), style: AppText.number(17, lineHeight: 25)),
                          ],
                        ),
                        if (!l.fee.atMax) ...[
                          const SizedBox(height: 1),
                          Text(
                            s.s18Growing,
                            softWrap: false,
                            style: AppText.style(12, weight: FontWeight.w900, color: const Color(0xFF3F8F4A)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (on) const Positioned(right: -6, top: -6, child: AppIcon('ok', size: 22)),
            ],
          ),
        ),
      ),
    );
  }

  /// 花色變體：主人牧場裡的牛編號（公營種牛站沒有，用上架編號）。
  static int _variant(StudListing l) {
    final id = l.cowId ?? l.id;
    return id is int ? id : int.tryParse('$id') ?? 0;
  }
}

/// .card.my-bulls：我的公牛出借。能上架的（成年、沒配過種、不在田裡）放「上架」，上架中的放「下架」；
/// 都沒有就放虛線框（S18-02）。下面一句借種費怎麼算、「借種紀錄」。
class MyBullsCard extends StatelessWidget {
  const MyBullsCard({super.key, required this.onToast});

  final void Function(ToastKind kind, String text) onToast;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state!;
    final now = m.gameNow;
    final canList = [
      for (final c in st.cows)
        if (c.canListAt(now)) c,
    ];
    final listed = [
      for (final c in st.cows)
        if (c.bull && c.listed) c,
    ];
    final sub = AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16);
    Future<void> act(Future<ActionResult<Object?>> Function() f) async {
      final r = await f();
      final err = r.error;
      if (err == null) return;
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      onToast(actionErrorKind(err), actionErrorTextWith(s, m, err));
    }

    return AppCard(
      key: const Key('my-bulls'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CardTitle(s.studMineTitle, color: AppColors.orange, icon: 'tag', iconSize: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: sub,
                    children: fillSpans(
                      s.studIncome(v: '\u0000'),
                      AppText.number(12, color: AppColors.ink2, lineHeight: 16),
                      fmt(st.stud.income),
                    ),
                  ),
                  key: const Key('stud-income'),
                ),
              ),
            ],
          ),
          if (canList.isEmpty && listed.isEmpty) ...[
            const SizedBox(height: 6),
            PickEmpty(key: const Key('no-bull'), title: s.s18NoBullTitle, hint: s.s18NoBullHint, side: 0),
          ] else ...[
            for (final c in canList)
              _MyBullRow(
                key: Key('my-bull-${c.key}'),
                cow: c,
                meta: cowRarityChip(c),
                fee: s.s18FeeLabel(price: '\u0000'),
                price: c.studFee?.price,
                button: AppButton(
                  s.list,
                  key: Key('list-${c.key}'),
                  small: true,
                  kind: ButtonKind.primary,
                  icon: 'tag',
                  onPressed: m.canAct && c.studFee != null ? () => act(() => m.studList(c)) : null,
                ),
              ),
            for (final c in listed)
              _MyBullRow(
                key: Key('my-bull-${c.key}'),
                cow: c,
                meta: CowBadge(BadgeKind.listed, s.badgeListed),
                fee: s.costCoins(v: '\u0000'),
                price: _listingOf(st, c)?.fee.price ?? c.studFee?.price,
                button: AppButton(
                  s.unlist,
                  key: Key('unlist-${c.key}'),
                  small: true,
                  onPressed: m.canAct ? () => act(() => m.studUnlist(_listingOf(st, c)?.id ?? c.listedId!)) : null,
                ),
              ),
            const SizedBox(height: 6),
            Text(s.s18FeeNote, style: KitText.hint(size: 12, lineHeight: 17)),
          ],
          const SizedBox(height: 8),
          _LinkRow(label: s.s18LogTitle, onTap: m.openStudLog),
        ],
      ),
    );
  }

  static StudListing? _listingOf(GameState st, Cow c) =>
      st.stud.listings.where((l) => '${l.cowId}' == c.key).firstOrNull;
}

/// .mb-row：公牛的正面小圖（56）、名字、標籤和借種費、右邊一顆小按鈕。
class _MyBullRow extends StatelessWidget {
  const _MyBullRow({
    super.key,
    required this.cow,
    required this.meta,
    required this.fee,
    required this.price,
    required this.button,
  });

  final Cow cow;
  final Widget meta;

  /// 借種費那一句（{price}／{v} 換成 \u0000）。
  final String fee;
  final int? price;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r14),
      ),
      child: Row(
        children: [
          CowPicture(breed: cow.look, bull: true, variant: cow.number, width: 56, height: 56, pad: 3),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // <b> 15px：一般字的 400 → 700；在 .grow（16px、行高 normal）裡，這一行照 div 的 24 高
                Text(
                  s.cowLabel(cow),
                  strutStyle: kDivStrut,
                  style: AppText.style(15, weight: FontWeight.w700, lineHeight: 21),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    meta,
                    Text.rich(
                      TextSpan(
                        style: KitText.hint(),
                        children: fillSpans(fee, AppText.number(14, lineHeight: 19), price == null ? '–' : fmt(price!)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          button,
        ],
      ),
    );
  }
}

/// .link-row：上面一條虛線，圖示、一行字、右邊箭頭；整列可以點（平的元件，按下蓋色）。
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const DashedTopLine(),
    child: Semantics(
      container: true,
      button: true,
      child: Pressable(
        key: const Key('stud-log-link'),
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Row(
              children: [
                const AppIcon('history', size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: AppText.style(14, weight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                const AppIcon('chevron', size: 18),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
