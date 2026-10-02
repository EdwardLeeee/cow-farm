import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../l10n/strings.dart';
import 'kit/frame.dart';
import 'ranch/pen_list.dart';
import 'ranch/ranch_page.dart';
import '../state/game_model.dart';
import 'widgets/action_button.dart';
import 'screens/breed_screen.dart';
import 'screens/codex_screen.dart';
import 'screens/cow_detail_screen.dart';
import 'screens/fields_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/shop_screen.dart';
import 'start/start_flow.dart';
import 'warehouse/warehouse_page.dart';
import 'widgets/ticker_builder.dart';

/// 外框：照 M2 設計稿的頂列（G-02）、底部分頁列（G-01）。牧場分頁是正式的 S03；其他分頁先把 M1 的畫面放在內容區，
/// 之後照設計稿一組一組換掉。分頁切換不算「按鈕」，斷線時仍可切換查看。
/// 伺服器推來的提示（例如有人借了你的公牛）用 SnackBar 顯示。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<GameNotice>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = context.read<GameModel>().notices.listen((notice) {
      if (!mounted) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          key: const Key('notice'),
          content: Text(noticeText(context, notice)),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    // 還沒進牧場：S01 啟動與載入、S02 取名（正式畫面）
    if (showsStartFlow(m)) return const StartFlow();
    final Widget page;
    if (m.maintenance != null || m.state == null || m.authLost != null) {
      // 維護中、token 失效（原型文字）：整頁，沒有頂列和分頁列
      page = AppFrame(hud: false, content: _content(m));
    } else if (m.tab == AppTab.ranch && m.detailCowKey == null && !m.penListOpen && !m.warehouseOpen) {
      page = const RanchPage();
    } else {
      page = AppFrame(tab: m.tab, content: _content(m), contentPadding: EdgeInsets.zero);
    }
    final safe = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: m.detailCowKey == null && !m.penListOpen && !m.warehouseOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (m.detailCowKey != null) {
          m.closeCow();
        } else if (m.warehouseOpen) {
          m.closeWarehouse();
        } else {
          m.closePenList();
        }
      },
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: page),
              // S15-04（原型）：照設計稿 .long-off 的位置，在「連線中…」膠囊下面（頂列下 56），不蓋到它
              if (m.maintenance == null && m.state != null)
                Positioned(left: 12, right: 12, top: safe.top + FrameSizes.hud + 56, child: const _LongOffline()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(GameModel m) {
    if (m.maintenance != null) return const _Maintenance();
    // 玩到一半 token 失效（401、WebSocket 4401）也要換成 S15-03／S14-05，不能留在牧場畫面
    if (m.state == null || m.authLost != null) return const _Loading();
    if (m.detailCowKey != null) return CowDetailScreen(cowKey: m.detailCowKey!);
    return switch (m.tab) {
      // 倉庫（S05-02）、牛舍清單（S03-07）
      AppTab.ranch => m.warehouseOpen ? const WarehousePage() : const PenListPage(),
      AppTab.market => const MarketScreen(),
      AppTab.fields => const FieldsScreen(),
      AppTab.breed => const BreedScreen(),
      AppTab.shop => const ShopScreen(),
      AppTab.records => const _Records(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    // M1 的原型畫面：只用文字。正式的 S15-03、S14-05 照設計稿做（S01、S02 已經是正式畫面，在 start/）。
    final (String text, Widget? action) = switch (m) {
      GameModel(authLost: 'signed_in_elsewhere') => (
        s.s14ElsewhereTitle,
        OutlinedButton(onPressed: m.startOver, child: Text(s.s14NewRanch)),
      ),
      GameModel(authLost: final String _) => (
        s.s15InvalidTitle,
        OutlinedButton(onPressed: m.startOver, child: Text(s.s14NewRanch)),
      ),
      _ => (s.loadingFarm, null),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
          const SizedBox(height: 24),
          Text(S.prototypeNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// S16-01 維護中（原型文字）。正式畫面在第 4 步照設計稿做。
class _Maintenance extends StatelessWidget {
  const _Maintenance();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final ends = m.maintenance?.endsAtReal;
    return Center(
      key: const Key('maintenance'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.s16Title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(s.s16Lead, textAlign: TextAlign.center),
            // ends_at_real 是現實時間的 Unix 秒，照手機的時區顯示
            if (ends != null) Text(s.maintenanceEta(DateTime.fromMillisecondsSinceEpoch((ends * 1000).round()))),
            const SizedBox(height: 8),
            Text(s.s16Body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: m.checkMaintenance, child: Text(s.reload)),
            const SizedBox(height: 24),
            Text(S.prototypeNote, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// S15-04 斷線超過 60 秒（原型文字）：畫面上方提示，可以按「重試」。正式畫面在第 4 步照設計稿做。
/// 斷線時間一直在走，用 TickerBuilder 定時重畫。
class _LongOffline extends StatelessWidget {
  const _LongOffline();

  @override
  Widget build(BuildContext context) {
    return TickerBuilder(
      builder: (context) {
        final m = context.watch<GameModel>();
        if (!m.longOffline) return const SizedBox.shrink();
        final s = Strings.of(context);
        return Material(
          key: const Key('long-offline'),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.s15LongOffTitle(n: m.offlineMinutes),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(s.s15LongOffBody),
                    ],
                  ),
                ),
                TextButton(onPressed: m.retryConnection, child: Text(s.retry)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 紀錄：圖鑑與排行榜兩個分頁。
class _Records extends StatelessWidget {
  const _Records();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: S.subCodex),
              Tab(text: S.subRank),
            ],
          ),
          Expanded(child: TabBarView(children: [CodexScreen(), LeaderboardScreen()])),
        ],
      ),
    );
  }
}
