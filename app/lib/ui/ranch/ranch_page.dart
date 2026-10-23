// S03 牧場主畫面（設計稿 design/m2/src/js/screens/s03.js 的 ranchPage）：場景、跑馬燈、「我的牛」、下面的面板，
// 以及收奶的結果提示（S03-03、S03-04）、奶桶滿了的泡泡（S03-02）、第一次的滑動提示（S03-14）、大新聞（S03-15）、
// 空牧場（S03-08）。牛的小名片（S03-06）和牛舍清單（S03-07）在下一個 PR。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../cow/stamps.dart';
import '../cow/treat.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/motion.dart';
import '../kit/press.dart';
import '../market/news_tier.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'coach_card.dart';
import 'dock.dart';
import 'grow_reveal.dart';
import 'poop.dart';
import 'pen_list.dart';
import 'ranch_game.dart';
import 'scene.dart';

class RanchPage extends StatefulWidget {
  const RanchPage({super.key});

  @override
  State<RanchPage> createState() => _RanchPageState();
}

class _RanchPageState extends State<RanchPage> with TickerProviderStateMixin {
  double _pan = 0;

  /// A-12 左右滑動牧場（設計稿 anims.js 的 A12）：手指放開以後照放開時的速度再滑一小段停下（跟 iOS 捲動一樣的摩擦力），
  /// 到兩邊就停、不回彈。減少動態時拖多少就移多少、不滑行。
  late final _glide = AnimationController.unbounded(vsync: this)..addListener(_glideTick);

  /// A-01 收奶（1.4 秒，設計稿 anims.js 的 A01）：奶瓶從奶桶飛進倉庫卡、奶桶的數字往下降、倉庫的牛奶往上跳，最後提示。
  late final _collectAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  /// 收奶前的數字（動畫中從這裡變到伺服器的新數字）；null 是沒在播。
  _CollectFx? _fx;

  /// A-01 的減少動態版：提示淡入 0.2 秒（不飛奶瓶、數字直接變）。
  bool _fadeToast = false;
  final _pailKey = GlobalKey();
  final _warehouseKey = GlobalKey();
  final _fxLayerKey = GlobalKey();

  /// 畫牛的 Flame 遊戲（A-11、A-07）：泡泡和小名片從這裡知道停下來的牛走到哪裡。
  final _game = RanchGame();

  /// 被點到的牛（S03-06：轉正面、跳出小名片）。
  Object? _popId;

  /// 清大便還在播的那幾坨（[PoopCleanFx]；A-14 點一下、A-15 劃過去）。[_poopFxPending] 是還沒到數字少 1 的時間的
  /// （點一下 0.3 秒、劃過去 0.05 秒）：右上角的數字還算著它們。數字跳一下（[_dirtBump]）：點一下是少 1 的時候，
  /// 劃過去是手指放開的時候。[_swiped] 是這一次劃過去清掉幾坨。
  final _poopFx = <PoopFx>[];
  final _poopFxPending = <int>{};
  var _poopFxId = 0;
  var _dirtBump = 0;
  var _swiped = 0;

  /// 還沒送出的那幾坨的動畫（下一次 [_sendPoop] 送的就是它們）：送出失敗只收掉這一批，別批的照常播完。
  final _unsentFx = <int>{};
  _Toast? _toast;
  Timer? _toastTimer;

  /// 放開（A-12）：場景座標每秒 [v]（往右捲是正的）。照 iOS 捲動的摩擦力（FrictionSimulation 0.135）滑下去，
  /// 滑的距離是 v ÷ ln(1 ÷ 0.135) ≈ v ÷ 2；太慢（每秒不到 50）就不滑。
  void _panEnd(double v) {
    if (!AppMotion.read(context) || v.abs() < 50) return;
    // 每秒不到 1（場景座標，約 1 點）就算停了：不然會一直往終點逼近、很久才停
    _glide.animateWith(FrictionSimulation(0.135, _pan, v, tolerance: const Tolerance(velocity: 1)));
  }

  void _glideTick() {
    final x = _glide.value;
    final p = x.clamp(0.0, kMaxPan);
    if (p != _pan) setState(() => _pan = p);
    // 滑到兩邊就停（不回彈）
    if (x < 0 || x > kMaxPan) _glide.stop();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _collectAnim.dispose();
    _glide.dispose();
    super.dispose();
  }

  /// [delay]：A-01 播完前提示先不出來（第 1.0 秒才淡入），停留的時間從那時候算。
  void _showToast(_Toast t, {Duration delay = Duration.zero}) {
    _toastTimer?.cancel();
    setState(() => _toast = t);
    _toastTimer = Timer(
      delay + (t.action == null ? const Duration(milliseconds: 2500) : const Duration(seconds: 5)),
      () {
        if (mounted) setState(() => _toast = null);
      },
    );
  }

  /// A-01 現在播到第幾秒；沒在播是 null。
  double? get _fxT => _fx == null ? null : _collectAnim.value * 1.4;

  /// 動畫中面板上的數字：奶桶照 inOut 從原本降到新的（0.1–0.85 秒），「幾分鐘後滿」降完才換（設計稿 A01.frame）。
  DockData _fxData(DockData data) {
    final fx = _fx, t = _fxT;
    if (fx == null || t == null) return data;
    final drain = _inOut(_seg(t, 0.1, 0.85));
    return DockData(
      bucket: fx.bucket + (data.bucket - fx.bucket) * drain,
      bucketCap: data.bucketCap,
      perHour: data.perHour,
      timeScale: data.timeScale,
      rateBucket: drain >= 1 ? data.bucket : fx.bucket,
      draining: drain > 0 && drain < 1,
      feeds: data.feeds,
    );
  }

  /// A-01 奶瓶飛進「倉庫」小鈕時（0.55–1.05 秒），小鈕跳一下（放大到 1.12 再回來）。
  double get _warehouseBump {
    final t = _fxT;
    return t == null ? 1 : 1 + 0.12 * math.sin(math.pi * _seg(t, 0.55, 1.05));
  }

  /// 病牛的名片按「治療」（S03-29）：一樣先問（S04-19），治好了在牧場頁提示「荷斯坦 #3 好了！」（S04-21）。
  Future<void> _treat(Cow cow) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await treatCow(context, cow);
    if (r == null || !mounted) return;
    final err = r.error;
    if (err == null) {
      setState(() => _popId = null);
      _showToast(_Toast(ToastKind.ok, s.s04Treated(cow: s.cowLabel(cow))));
      return;
    }
    if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
    _showToast(_Toast(actionErrorKind(err), actionErrorTextWith(s, m, err)));
  }

  /// 清掉一坨大便：先從畫面拿掉（位置空出來，其他的不跳位），斷線的時候不能清。清掉了回 true。
  bool _takePoop(ScenePoop p) {
    final m = context.read<GameModel>();
    if (!m.online || m.poopOf(p.cow) <= 0) return false;
    // 場景的大便下一格畫面才更新：同一格裡被劃到兩次（或連點兩下）的，第二次不算
    if (!m.poopLayout.take(p.spot)) return false;
    return m.takePoop(p.cow, spot: p.spot);
  }

  /// 點一下清一坨（A-14）：開著動畫就在原位播淡掉、波紋、小星星，數字晚 0.3 秒才少；減少動態版直接消失、數字直接變少。
  void _tapPoop(ScenePoop p) {
    if (!_takePoop(p)) return;
    if (AppMotion.read(context)) {
      final fx = PoopFx(_poopFxId++, p.spot);
      setState(() {
        _poopFx.add(fx);
        _unsentFx.add(fx.id);
        _poopFxPending.add(fx.id);
      });
    }
    _sendPoop();
  }

  /// 手指劃過一坨（A-15）：開著動畫就在原位播淡掉、小星星（沒有波紋），數字 0.05 秒後少；減少動態版直接消失。
  void _swipePoop(ScenePoop p) {
    if (!_takePoop(p)) return;
    _swiped++;
    if (AppMotion.read(context)) {
      final fx = PoopFx(_poopFxId++, p.spot, swipe: true);
      setState(() {
        _poopFx.add(fx);
        _unsentFx.add(fx.id);
        _poopFxPending.add(fx.id);
      });
    }
  }

  /// 手指放開：劃到的一次送出；開著動畫時右上角的數字跳一下（設計稿 A15 第 0.85–1.0 秒）。
  void _swipeEnd() {
    if (_swiped > 0 && AppMotion.read(context)) setState(() => _dirtBump++);
    _swiped = 0;
    _sendPoop();
  }

  /// 送出清掉的大便（點一下馬上送，劃過去的手指放開才送）；失敗的話大便放回去，跳一般的錯誤提示。
  Future<void> _sendPoop() async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final batch = {..._unsentFx};
    _unsentFx.clear();
    final r = await m.sendPoop();
    final err = r?.error;
    if (!mounted || err == null) return;
    // 沒清成：這一批的大便放回原位了，它們還在播的動畫收掉（數字也不再晚一步）；別批的照常播完
    if (batch.isNotEmpty) {
      setState(() {
        _poopFx.removeWhere((f) => batch.contains(f.id));
        _poopFxPending.removeAll(batch);
      });
    }
    if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
    _showToast(_Toast(actionErrorKind(err), actionErrorTextWith(s, m, err)));
  }

  Future<void> _collect() async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    // A-01：收奶前的奶桶、倉庫；減少動態（或測試）時不播，數字直接變（設計稿的減少動態版）
    final motion = AppMotion.read(context);
    final reduced = AppMotion.reducedRead(context);
    final before = _CollectFx(m.bucketNow);
    final r = await m.collect();
    if (!mounted) return;
    final delay = r.ok && motion ? const Duration(milliseconds: 1000) : Duration.zero;
    _fadeToast = r.ok && reduced;
    if (delay > Duration.zero) {
      setState(() => _fx = before);
      _collectAnim.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _fx = null);
      });
    }
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(_Toast(actionErrorKind(err), actionErrorTextWith(s, m, err)));
      return;
    }
    final res = r.value ?? const {};
    final got = (res['collected'] as num?)?.toDouble() ?? 0;
    if (res['warehouse_full'] == true) {
      // 倉庫滿了，奶只收進一部分（S03-04）：剩下的留在奶桶；可以去加大倉庫
      final left = m.state?.bucket.amount ?? 0;
      _showToast(
        delay: delay,
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
              m.openFacility(); // 到商店的設施升級（S10）
            },
          ),
        ),
      );
    } else {
      // 順便丟掉倉庫裡壞掉的牛奶（S03-18，D29）
      final spoiled = (res['spoiled'] as num?)?.toDouble() ?? 0;
      _showToast(
        delay: delay,
        _Toast(
          ToastKind.ok,
          spoiled > 0
              ? s.collectedSpoiled(v: oneDecimal(got), n: oneDecimal(spoiled))
              : s.collected(v: oneDecimal(got)),
        ),
      );
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
      feeds: st.feeds,
    );
    // 奶桶滿了：跟奶桶卡同一個判斷（百分比四捨五入到 100 就算滿），場景和面板才會一致
    final full = data.full;
    final herd = m.herdLayout.place(st.cows);
    // 奶桶滿了：產奶的牛轉正面（D11），編號最小的那頭頭上冒泡泡（S03-02）
    final producers = [
      for (final (c, _) in herd)
        if (c.milkPerH > 0 && !c.sick) c,
    ];
    final bubbleCow = full && producers.isNotEmpty ? producers.first : null;
    // 被點到的牛也轉正面（D11）；病牛一律轉正面看玩家、不冒奶桶的泡泡（S03-28）
    final cows = [
      for (final (c, slot) in herd) SceneCow(c, slot, front: c.sick || (full && c.milkPerH > 0) || c.id == _popId),
    ];
    final popCow = [
      for (final sc in cows)
        if (sc.cow.id == _popId) sc.cow,
    ].firstOrNull;
    final empty = st.cows.isEmpty;
    // 空牧場在很矮的手機（320×568）放不下「去商店」卡片：面板收成一條，卡片才不會疊到奶桶（m3-backlog）
    final shortScreen = mq.size.height < 700;
    final collapsed = settings.dockCollapsed || (empty && shortScreen);
    // 小牛長大揭曉（A-13 的最後一格、S03-25）：一頭一頭來，揭曉的時候大新聞、引導卡先不出
    final grown = m.grownCow;
    final bigNews = grown == null ? _bigNews(m, settings) : null;
    // 快長大的提醒卡（S03-32）：再 1 小時內長大、還有沒吃的小牛，一頭一張（先長大的先），按過就不再跳
    final alertCow = grown == null && bigNews == null ? _growAlertCow(m, settings, st) : null;
    // 新手引導卡（S11-03）：大新聞、空牧場的卡片、提醒卡開著時先不出（一次一張）
    final coach = grown == null && bigNews == null && alertCow == null && st.cows.isNotEmpty
        ? coachToShow(m, settings)
        : null;
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
    // 大便（v0.3 第 5 節）：場景裡每一坨的位置（記住，清掉一坨時其他的不跳位）、右上角的數字（扣掉正在清的）。
    // 髒的程度 = 大便 ÷ 牛的頭數，超過會生病的門檻就變紅（S03-27）
    final poops = m.poopLayout.place(st.cows, m.poopOf);
    // 右上角的數字：點一下清掉的（A-14）到第 0.3 秒才少
    final poopTotal = m.poopTotal + _poopFxPending.length;
    final dirty = st.cows.isNotEmpty && poopTotal / st.cows.length > (st.economy?.sickDirtFree ?? 0.5);
    final showSwipeHint = !settings.swipeHintSeen && !empty;

    return AppFrame(
      tab: AppTab.ranch,
      scene: RanchScene(
        game: _game,
        cows: cows,
        pan: _pan,
        onPan: (p) {
          setState(() => _pan = p);
          if (!settings.swipeHintSeen) settings.markSwipeHintSeen();
        },
        onPanStart: _glide.stop,
        onPanEnd: _panEnd,
        // 點一頭牛：轉正面、跳出小名片；再點一次或點空地就收起來
        onTapCow: (c) => setState(() => _popId = _popId == c.id ? null : c.id),
        onTapEmpty: _popId == null ? null : () => setState(() => _popId = null),
        // 清大便：點一下清一坨（A-14），從大便上開始劃、劃過的都清掉（A-15）；開著動畫時播淡掉、小星星（點一下加波紋）
        poops: poops,
        onTapPoop: _tapPoop,
        onSwipePoop: _swipePoop,
        onSwipeEnd: _swipeEnd,
        poopFx: _poopFx,
        onPoopFxCount: (f) => setState(() {
          if (_poopFxPending.remove(f.id) && !f.swipe) _dirtBump++;
        }),
        onPoopFxDone: (f) => setState(() {
          _poopFx.remove(f);
          _poopFxPending.remove(f.id);
        }),
      ),
      underlays: [
        if (bubbleCow != null) _BubbleAnchor(cows: cows, cow: bubbleCow, pan: _pan, game: _game),
        // 小牛頭上的想吃泡泡（S03-31）：還有沒吃的飼料才冒（集滿了、一般優良的不冒；病牛頭上已經有溫度計，先不冒）
        _WantAnchors(
          cows: [
            for (final sc in cows)
              if (sc.cow.stage == CowStage.calf && !sc.cow.sick && feedTodo(sc.cow).isNotEmpty) sc,
          ],
          pan: _pan,
          game: _game,
        ),
      ],
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
        // .dirty：右上角的大便數，跟牛欄膠囊同一列（有大便才出現）
        if (poopTotal > 0)
          Positioned(
            right: 12,
            top: top + 62,
            child: DirtPill(count: poopTotal, bad: dirty, bump: _dirtBump),
          ),
        if (empty)
          Positioned(
            left: 24,
            right: 24,
            top: top + 112,
            child: _EmptyRanch(
              // 去商店抽牛（S19）
              onShop: () {
                m.selectShop(facility: false);
                m.selectTab(AppTab.shop);
              },
            ),
          ),
        if (showSwipeHint)
          Positioned(
            left: 0,
            right: 0,
            // 很矮的手機往上放，免得壓到奶桶（screens.css 的 @media (max-height: 700px)）
            top: top + (shortScreen ? 112 : 236),
            child: const Center(child: _SwipeHint()),
          ),
        // .dock 的左右 12 由面板自己留：飼料列要延伸到畫面的左右邊緣
        Positioned(
          left: 0,
          right: 0,
          bottom: FrameSizes.contentBottom(safe) + 10,
          child: AnimatedBuilder(
            animation: _collectAnim,
            builder: (context, _) => Dock(
              data: _fxData(data),
              collapsed: collapsed,
              pan: _pan,
              onToggle: () => settings.setDockCollapsed(!collapsed),
              collect: collectButton,
              onWarehouse: m.openWarehouse,
              pailKey: _pailKey,
              warehouseKey: _warehouseKey,
              warehouseScale: _warehouseBump,
            ),
          ),
        ),
      ],
      overlays: [
        // S11-03：跑馬燈下面 12、左右各 12，× 疊在卡片的右上角。跟大新聞一樣在最上層：蓋在場景、「我的牛」上，
        // 很矮的手機（320 × 568 英文、泰文）卡片比較高，會暫時蓋到面板的上緣（按卡上的按鈕或 × 就收起來）
        if (alertCow case final c?)
          Positioned(
            left: 12,
            right: 12,
            top: top + 56,
            child: GrowAlertCard(
              cow: c,
              time: s.countdown((c.adultAt! - m.gameNow) / m.timeScale),
              // 去餵食：餵食還沒做（ceo），先打開這頭小牛的詳細，看得到集點卡
              onGo: () {
                settings.markGrowAlertSeen(c.id, st.playerId);
                m.openCow(c.key);
              },
              onClose: () => settings.markGrowAlertSeen(c.id, st.playerId),
            ),
          ),
        if (coach != null) ...[
          Positioned(
            left: 12,
            right: 12,
            top: top + 58,
            child: CoachCard(
              kind: coach,
              penPrice: st.upgrades[UpgradeKind.pen]?.cost ?? st.pen.nextCost,
              onGo: () {
                settings.markCoachSeen(coach.id, st.playerId);
                if (coach == CoachKind.pen) {
                  // 去擴建：商店的設施（S10）
                  m.selectShop(facility: true);
                  m.selectTab(AppTab.shop);
                } else {
                  // 去配種：自己配種（S08）
                  m.selectBreed(stud: false);
                  m.selectTab(AppTab.breed);
                }
              },
            ),
          ),
          Positioned(
            right: 12 - CoachClose.outRight,
            top: top + 58 - CoachClose.outTop,
            child: CoachClose(
              key: Key('coach-close-${coach.id}'),
              onTap: () => settings.markCoachSeen(coach.id, st.playerId),
            ),
          ),
        ],
        if (popCow != null)
          _CowPopAnchor(cows: cows, cow: popCow, pan: _pan, game: _game, onTreat: () => _treat(popCow)),
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
              // 去市場看看：到市場頁、選好那種商品（S03-15）
              onGo: () {
                settings.markBigNewsSeen(bigNews.id);
                // 全部商品的新聞不換商品
                if (bigNews.commodity case final c?) m.selectMarket(c);
                m.selectTab(AppTab.market);
              },
            ),
          ),
        // A-01：飛的奶瓶（不擋點擊）
        if (_fx != null)
          Positioned.fill(
            key: _fxLayerKey,
            child: IgnorePointer(
              child: AnimatedBuilder(animation: _collectAnim, builder: (context, _) => _bottles()),
            ),
          ),
        if (_toast != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: FrameSizes.contentBottom(safe) + 14,
            child: Center(
              // A-01 播的時候第 1.0–1.2 秒淡入、從下面 14 滑上來
              child: AnimatedBuilder(
                animation: _collectAnim,
                builder: (context, child) {
                  final t = _fxT;
                  if (t == null) {
                    if (!_fadeToast) return child!;
                    return FadeIn(key: ObjectKey(_toast), child: child!);
                  }
                  final k = _seg(t, 1.0, 1.2);
                  return Opacity(
                    opacity: k,
                    child: Transform.translate(offset: Offset(0, (1 - _outCubic(k)) * 14), child: child),
                  );
                },
                child: ToastPill(_toast!.text, kind: _toast!.kind, action: _toast!.action, key: const Key('toast')),
              ),
            ),
          ),
        // 蓋在最上面（暗幕連頂列、分頁列一起蓋）；換一頭就從頭淡入
        if (grown != null)
          GrowReveal(
            key: ValueKey(('grow', grown.id)),
            cow: grown,
            mult: st.economy?.hybridMult,
            onDone: () => m.dismissGrown(grown),
          ),
      ],
    );
  }

  /// A-01 的五個奶瓶：從奶桶圖示的中間，沿拋物線（高 90）飛到頂列「倉庫」小鈕的中間，一個晚 0.08 秒；
  /// 飛的時候變大再變小（0.7 → 1.2 → 0.7）、從 −20 度轉到 20 度（設計稿 A01.frame）。面板收起來（沒有奶桶）就不飛。
  Widget _bottles() {
    final t = _fxT;
    final layer = _fxLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final pail = _pailKey.currentContext?.findRenderObject() as RenderBox?;
    final wh = _warehouseKey.currentContext?.findRenderObject() as RenderBox?;
    if (t == null || layer == null || pail == null || wh == null || !layer.hasSize) return const SizedBox.shrink();
    final from = layer.globalToLocal(pail.localToGlobal(pail.size.center(Offset.zero)));
    final to = layer.globalToLocal(wh.localToGlobal(wh.size.center(Offset.zero)));
    return Stack(
      children: [
        for (var i = 0; i < 5; i++)
          if (_seg(t, 0.1 + i * 0.08, 0.6 + i * 0.08) case final k when k > 0 && k < 1)
            Positioned(
              key: Key('collect-bottle-$i'),
              left: from.dx + (to.dx - from.dx) * _outCubic(k) - 14,
              top: from.dy + (to.dy - from.dy) * _outCubic(k) - math.sin(math.pi * _outCubic(k)) * 90 - 14,
              child: Transform.rotate(
                angle: (-20 + 40 * k) * math.pi / 180,
                child: Transform.scale(
                  scale: 0.7 + 0.5 * math.sin(math.pi * k),
                  child: const AppIcon('milk', size: 28),
                ),
              ),
            ),
      ],
    );
  }

  /// 快長大的提醒卡（S03-32）要提醒哪一頭：還有沒吃的飼料、再 1 小時（現實時間）內長大、這支手機還沒提醒過；先長大的先。
  static Cow? _growAlertCow(GameModel m, SettingsController settings, GameState st) {
    Cow? best;
    for (final c in st.cows) {
      final at = c.adultAt;
      if (c.stage != CowStage.calf || at == null || feedTodo(c).isEmpty) continue;
      final left = (at - m.gameNow) / m.timeScale;
      if (left <= 0 || left > 3600 || settings.growAlertSeen(c.id, st.playerId)) continue;
      if (best == null || at < best.adultAt!) best = c;
    }
    return best;
  }

  /// 大新聞（收購價大漲或大跌 20% 以上，企劃書 4.7、D24、m3-backlog）：還沒看過的那一則，跳出一次（S03-15）。
  /// 觸發條件只看幅度，不看伺服器的 big（big 是 ±30–40% 的罕見新聞；ceo 2026-10-02）。
  /// 全部商品一起漲跌的也跳（S03-16、17，D29）。
  static NewsItem? _bigNews(GameModel m, SettingsController settings) {
    for (final n in m.market?.news ?? const <NewsItem>[]) {
      if (n.pct.abs() >= 0.2 && !n.upcoming && !settings.bigNewsSeen(n.id)) return n;
    }
    return null;
  }
}

/// A-01：收奶前的奶桶。
class _CollectFx {
  const _CollectFx(this.bucket);
  final double bucket;
}

// 設計稿 anims.js 的小工具：seg 是 t 在 a–b 之間走了幾成（0–1）。
double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _outCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _inOut(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

class _Toast {
  const _Toast(this.kind, this.text, {this.action});
  final ToastKind kind;
  final String text;
  final Widget? action;
}

/// 「奶桶滿了」泡泡（.bubble）：在那頭牛的頭頂上方，跟著場景左右捲。
class _BubbleAnchor extends StatelessWidget {
  const _BubbleAnchor({required this.cows, required this.cow, required this.pan, required this.game});

  final List<SceneCow> cows;
  final Cow cow;
  final double pan;
  final RanchGame game;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final fit = SceneFit(c.biggest, pan);
          final sc = cows.firstWhere((x) => x.cow.id == cow.id);
          // 牛轉正面時停在走到的地方
          final p = CowPlacement.of(sc, fit, dx: game.dxOf(cow.id));
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

/// 小牛頭上的想吃泡泡（S03-31，.want）：頭頂上方 10、置中（translate(−50%, −100%)、margin-top −10）。
/// 小牛會走動（A-11）：開著動畫的時候每一格跟著小牛走到的地方。
class _WantAnchors extends StatefulWidget {
  const _WantAnchors({required this.cows, required this.pan, required this.game});

  final List<SceneCow> cows;
  final double pan;
  final RanchGame game;

  @override
  State<_WantAnchors> createState() => _WantAnchorsState();
}

class _WantAnchorsState extends State<_WantAnchors> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_WantAnchors oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// 有泡泡、牛會走動才每一格重畫。
  void _sync() {
    final on = widget.cows.isNotEmpty && AppMotion.of(context);
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cows.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, c) {
            final fit = SceneFit(c.biggest, widget.pan);
            return Stack(
              children: [
                for (final sc in widget.cows)
                  if (CowPlacement.of(sc, fit, dx: widget.game.dxOf(sc.cow.id)) case final p?)
                    Positioned(
                      left: p.head.dx - 150,
                      width: 300,
                      bottom: c.maxHeight - (p.head.dy - 10),
                      child: Center(child: WantBubble(cow: sc.cow)),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// .ticker：最新一則新聞，太長就跑馬燈（減少動態時不跑）。
class _Ticker extends StatelessWidget {
  const _Ticker({required this.news});

  final NewsItem news;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final tag = s.newsTag(news);
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

/// 大新聞提示（S03-15～17）：標籤、商品圖示、標題、「牛肉收購價 +25%，現在 15 幣／公斤」、「去市場看看」、右上角關閉。
/// 超級大事件、超級黑天鵝（S03-22～24，D33）：同一個位置、一樣大，換成金色（兩顆小星星）、深色（白字、白色的 ✕），
/// 標籤換成級別，幅度的字放大（20），標題那一列往下 6（專屬標題比較長，第一行才不會碰到 ✕ 的點擊範圍）。
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

  static const _radius = BorderRadius.all(AppRadii.r18);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = news.commodity;
    final up = news.pct >= 0;
    final sup = news.tier == NewsTier.superUp, swan = news.tier == NewsTier.crash;
    final extreme = sup || swan;
    final pct = newsPctText(news);
    // 全部商品一起漲跌（S03-16、17、24）：說明句只寫漲跌幅，不寫單一商品的名字和價格
    final body = c == null
        ? s.s03BigNewsAll(chg: '\u0000')
        : s.s03BigNewsBody(name: s.commodity(c), chg: '\u0000', price: priceText(quote?.price ?? 0), unit: s.unitOf(c));
    final fg = swan ? Colors.white : AppColors.ink;
    final line = swan ? kSwanLine : AppColors.ink;
    final pctColor = swan
        ? crashPctColor(upIsRed: upIsRed)
        : up
        ? AppColors.up(upIsRed: upIsRed)
        : AppColors.down(upIsRed: upIsRed);
    // 卡片裡的字沒設字級：外層是 16、行高 normal（CSS 的 strut）。標籤、標題、說明都是行內的字，每一行的高度和基線
    // 照 Chrome 的算法（CssLine）：標籤那一行 27 高（標籤的字對齊外層的基線），說明那一行跟著幅度的字（.bn-main b 的行高 24）是 24 高
    final strut = AppText.style(16);
    final (strutAbove, strutBelow) = CssLine.metrics(TextSpan(style: strut));
    final tagHeight = extreme ? 26.0 : 24.0;
    final tagBaseline =
        2 +
        CssLine.metrics(
          TextSpan(
            style: extreme
                ? NewsTierBadge.textStyle(prompt: true)
                : AppText.style(12, weight: FontWeight.w900, lineHeight: 20),
          ),
        ).$1;
    final tagAbove = math.max(strutAbove, tagBaseline), tagBelow = math.max(strutBelow, tagHeight - tagBaseline);
    // 整張卡是一個 Stack（內距 12 加框 3 包在裡面）：右上角 ✕ 的 44 × 44 整塊都在範圍裡，才點得到
    final content = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12 + AppSizes.border),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: tagAbove + tagBelow,
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(top: tagAbove - tagBaseline),
                child: extreme
                    ? NewsTierBadge(tier: news.tier, onDark: swan, prompt: true)
                    : Container(
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
              SizedBox(height: extreme ? 14 : 8),
              Row(
                children: [
                  NewsIconBox(commodity: c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CssLine(
                          TextSpan(
                            style: strut,
                            children: [
                              TextSpan(
                                text: s.newsHeadline(news),
                                style: AppText.style(18, weight: FontWeight.w900, color: fg, lineHeight: 24),
                              ),
                            ],
                          ),
                          wrap: true,
                        ),
                        const SizedBox(height: 2),
                        CssLine(
                          TextSpan(
                            style: AppText.style(
                              14,
                              weight: FontWeight.w700,
                              color: swan ? const Color(0xFFE5DEEE) : AppColors.ink,
                              lineHeight: 20,
                            ),
                            children: fillSpans(
                              body,
                              AppText.style(
                                extreme ? 20 : 16,
                                weight: FontWeight.w900,
                                color: pctColor,
                                lineHeight: 24,
                              ),
                              pct,
                            ),
                          ),
                          wrap: true,
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
        ),
        // 超級大事件的兩顆小星星（.bn-spark：卡片框裡的左 146、上 8 和左 168、上 22）
        if (sup) ...[
          const Positioned(
            left: AppSizes.border + 146,
            top: AppSizes.border + 8,
            child: IgnorePointer(child: AppIcon('sparkle', size: 16)),
          ),
          const Positioned(
            left: AppSizes.border + 168,
            top: AppSizes.border + 22,
            child: IgnorePointer(child: AppIcon('sparkle', size: 10)),
          ),
        ],
        // .bn-close：卡片框裡的右 4、上 4
        Positioned(
          right: AppSizes.border + 4,
          top: AppSizes.border + 4,
          child: Semantics(
            container: true,
            button: true,
            label: s.gClose,
            // 平的元件：按下蓋一層顏色（圓形，G-13）
            child: Pressable(
              key: const Key('big-news-close'),
              onTap: onClose,
              builder: (context, look) => PressTint(
                tint: look.tint,
                shape: BoxShape.circle,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    // 深色的超級黑天鵝：✕ 是白的
                    child: swan
                        ? const ColorFiltered(
                            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            child: AppIcon('close', size: 18),
                          )
                        : const AppIcon('close', size: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Container(
      key: const Key('big-news'),
      decoration: BoxDecoration(
        color: extreme ? null : const Color(0xFFFFF6D6),
        borderRadius: _radius,
        boxShadow: [BoxShadow(color: line, offset: const Offset(0, 4))],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: line, width: AppSizes.border),
        borderRadius: _radius,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        clipBehavior: extreme ? Clip.antiAlias : Clip.none,
        child: CustomPaint(
          painter: extreme ? NewsTierBackground.prompt(swan: swan) : null,
          child: content,
        ),
      ),
    );
  }
}

/// 牛的小名片（S03-06、S03-20、S03-21，.cow-pop；設計稿 kit.js 的 placeCowPop）：寬 208，左邊 = 頭的 x − 43
/// （夾在螢幕左 12 到右 220 之間）。平常在頭頂上方 14、尖角朝下；名片上緣會碰到頂列（頂列下緣再留 6）時，
/// 改放到牛腳下 14、尖角朝上（D30）。名片被擋在畫面裡時，尖角跟著移到對準那頭牛。
class _CowPopAnchor extends StatelessWidget {
  const _CowPopAnchor({
    required this.cows,
    required this.cow,
    required this.pan,
    required this.game,
    required this.onTreat,
  });

  final List<SceneCow> cows;
  final Cow cow;
  final double pan;
  final RanchGame game;

  /// 病牛的名片按「治療」（S03-29）。
  final VoidCallback onTreat;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) {
          final p = CowPlacement.of(
            cows.firstWhere((x) => x.cow.id == cow.id),
            SceneFit(c.biggest, pan),
            dx: game.dxOf(cow.id),
          );
          if (p == null) return const SizedBox.shrink();
          return _PopPlacer(
            head: p.head,
            foot: p.foot,
            // 頂列在安全區下面 6、高 52；再留 6
            limit: safeTop + 6 + FrameSizes.hud + 6,
            // 病牛的名片寬 236（.cow-pop.sick；S03-29），一樣左右留 12
            width: cow.sick ? 236 : 208,
            child: _CowPop(cow: cow, onTreat: onTreat),
          );
        },
      ),
    );
  }
}

/// 擺名片、畫尖角：要先量名片的高，才知道上面放不放得下。
class _PopPlacer extends SingleChildRenderObjectWidget {
  const _PopPlacer({
    required this.head,
    required this.foot,
    required this.limit,
    required this.width,
    required super.child,
  });

  final Offset head;
  final Offset foot;
  final double limit;
  final double width;

  @override
  RenderPopPlacer createRenderObject(BuildContext context) => RenderPopPlacer(head, foot, limit, width);

  @override
  void updateRenderObject(BuildContext context, RenderPopPlacer renderObject) => renderObject
    ..head = head
    ..foot = foot
    ..limit = limit
    ..width = width;
}

/// 名片的位置（測試會讀 [below]、[tip]）。
class RenderPopPlacer extends RenderShiftedBox {
  RenderPopPlacer(this._head, this._foot, this._limit, this._width) : super(null);

  /// 名片的寬：一般 208，病牛 236（S03-29）。
  double get width => _width;
  double _width;
  set width(double v) {
    if (v == _width) return;
    _width = v;
    markNeedsLayout();
  }

  Offset _head;
  set head(Offset v) {
    if (v == _head) return;
    _head = v;
    markNeedsLayout();
  }

  Offset _foot;
  set foot(Offset v) {
    if (v == _foot) return;
    _foot = v;
    markNeedsLayout();
  }

  double _limit;
  set limit(double v) {
    if (v == _limit) return;
    _limit = v;
    markNeedsLayout();
  }

  /// 放到牛的下面了（尖角朝上）。
  bool below = false;

  /// 尖角的方塊在框內往右多少（CSS 的 --tip，預設 34）。
  double tip = 34;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    // 左右都留 12（s03.js：left = max(12, min(畫面寬 − 12 − 名片寬, 頭的 x − 43))）
    final left = math.max(12.0, math.min(size.width - 12 - width, _head.dx - 43));
    final above = _head.dy - 14 - child.size.height;
    below = above < _limit - 0.5;
    tip = math.max(18.0, math.min(width - 36, _head.dx - left - 9));
    (child.parentData! as BoxParentData).offset = Offset(left, below ? _foot.dy + 14 : above);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final at = offset + (child.parentData! as BoxParentData).offset;
    context.paintChild(child, at);
    // 尖角畫在名片上面，蓋掉框的一段
    _paintTail(context.canvas, at, child.size, up: below, tip: tip);
  }
}

class _CowPop extends StatelessWidget {
  const _CowPop({required this.cow, required this.onTreat});

  final Cow cow;
  final VoidCallback onTreat;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final s = Strings.of(context);
    // 名片那一行（ceo 2026-10-02）：產奶的母牛寫產量（S03-06）；小牛寫長大還要多久；
    // 其他的牛（公牛、肉牛、耕牛、不產奶的老牛）寫體重，照 D30 狀態表上公牛的寫法
    final adultAt = cow.adultAt;
    // 雜種牛不透露原本的稀有度（協定 2.3）：寫「產雜種牛奶」（設計稿沒畫雜種牛的名片）
    final meta = cow.milkPerH > 0
        ? s.s03PopMilk(
            tier: cow.hybrid ? s.badgeMix : s.tierName((breedInfo(cow.breed)?.tier ?? cow.tier).clamp(0, 3)),
            n: rateNum(cow.milkPerH),
          )
        : !cow.isAdultAt(m.gameNow) && adultAt != null
        ? s.growUp(v: s.countdown((adultAt - m.gameNow) / m.timeScale))
        : s.weight(v: fmt(cow.weightKg));
    final metaStyle = AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 19);
    final price = curePrice(m), coins = m.state?.coins ?? 0;
    // .cow-pop 的框、圓角、陰影、內距跟 .card 一樣
    return AppCard(
      key: const Key('cow-pop'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 名字放不下（英文「Strawberry Cow #12」）就換行，字級不變，編號才不會被截掉
          Text(s.cowLabel(cow), style: AppText.style(17, weight: FontWeight.w900, lineHeight: 22)),
          const SizedBox(height: 4),
          // 用途、公母、稀有度，再加上狀態（scope.md S03-06：品種、稀有度、狀態；病牛加「生病了」）
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: cowChips(context, cow),
          ),
          // 病牛（S03-29）：兩行說明（可以換行，.meta.wrap），按鈕換成「治療（5,000 幣）」。
          // 金幣不夠（ceo 2026-10-10）：照牛的詳細 S04-20，「治療」停用、下面寫還差多少（只是畫面判斷，扣錢照樣是伺服器算）
          if (cow.sick) ...[
            const SizedBox(height: 2),
            Text(s.s03SickNoMilk, key: const Key('pop-meta'), style: metaStyle),
            const SizedBox(height: 2),
            Text(s.s03SickShip, style: metaStyle),
            const SizedBox(height: 8),
            AppButton(
              s.treat(price: fmt(price)),
              key: const Key('pop-treat'),
              small: true,
              block: true,
              kind: ButtonKind.primary,
              icon: 'coin',
              onPressed: m.canAct && coins >= price ? onTreat : null,
            ),
            if (coins < price)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.notEnoughCoins(n: fmt(price - coins)),
                  key: const Key('pop-treat-short'),
                  textAlign: TextAlign.center,
                  style: KitText.warn(),
                ),
              ),
          ] else ...[
            const SizedBox(height: 2),
            Text(meta, key: const Key('pop-meta'), style: metaStyle),
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
        ],
      ),
    );
  }
}

/// 小名片的尖角（.cow-pop::after）：一個方塊轉 45°，只有右邊和下面有 3 的框、右下角圓角 4。
/// `* { box-sizing: border-box }` 管不到 ::after，所以方塊是內容 18 加框 3 = 21×21，左邊在框內 [tip]（外框往右 3 + tip）。
/// 朝下（平常）：下緣在框內往下 12（外框下緣往下 9），中心在外框下緣往上 1.5。
/// 朝上（.cow-pop.below，放到牛的下面）：上緣在框內往上 12（外框上緣往上 9），中心在外框上緣往下 1.5，再多轉 180°。
/// 方塊的底色蓋掉名片框的一段，看起來是名片長出一個尖角。
void _paintTail(Canvas canvas, Offset card, Size size, {required bool up, required double tip}) {
  canvas.save();
  canvas.translate(card.dx + 3 + tip + 10.5, up ? card.dy + 1.5 : card.dy + size.height - 1.5);
  canvas.rotate(up ? math.pi * 5 / 4 : math.pi / 4);
  // 底色只畫到框線的中間：底色的鋸齒邊藏在框線底下，名片的框上才不會多一條淡淡的邊
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
