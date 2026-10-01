import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../l10n/strings.dart';
import '../state/game_model.dart';
import 'widgets/action_button.dart';
import 'screens/breed_screen.dart';
import 'screens/codex_screen.dart';
import 'screens/cow_detail_screen.dart';
import 'screens/fields_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/ranch_screen.dart';
import 'screens/shop_screen.dart';
import 'widgets/top_bar.dart';

/// 外框：頂列＋內容＋底部分頁。分頁切換不算「按鈕」，斷線時仍可切換查看。
/// 伺服器推來的提示（例如有人借了你的公牛）用 SnackBar 顯示。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const labels = [S.tabRanch, S.tabMarket, S.tabFields, S.tabBreed, S.tabShop, S.tabRecords];
  static const _icons = [
    Icons.grass,
    Icons.show_chart,
    Icons.agriculture,
    Icons.favorite_border,
    Icons.store_outlined,
    Icons.emoji_events_outlined,
  ];

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
    return PopScope(
      canPop: m.detailCowKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) m.closeCow();
      },
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const TopBar(),
                Expanded(child: _content(m)),
              ],
            ),
          ),
          bottomNavigationBar: m.state == null
              ? null
              : NavigationBar(
                  selectedIndex: m.tab.index,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  height: 64,
                  onDestinationSelected: (i) => m.selectTab(AppTab.values[i]),
                  destinations: [
                    for (var i = 0; i < HomeShell.labels.length; i++)
                      NavigationDestination(
                        key: Key('tab-${AppTab.values[i].name}'),
                        icon: Icon(HomeShell._icons[i]),
                        label: HomeShell.labels[i],
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _content(GameModel m) {
    if (m.state == null) return const _Loading();
    if (m.detailCowKey != null) return CowDetailScreen(cowKey: m.detailCowKey!);
    return switch (m.tab) {
      AppTab.ranch => const RanchScreen(),
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
    // M1 的原型畫面：只用文字。正式的 S01、S02、S15-03、S14-05 在第 4 步照設計稿做。
    final (String text, Widget? action) = switch (m) {
      GameModel(authLost: 'signed_in_elsewhere') => (
        s.s14ElsewhereTitle,
        OutlinedButton(onPressed: m.startOver, child: Text(s.s14NewRanch)),
      ),
      GameModel(authLost: final String _) => (
        s.s15InvalidTitle,
        OutlinedButton(onPressed: m.startOver, child: Text(s.s14NewRanch)),
      ),
      GameModel(needsRanch: true) => (s.s02Title, null),
      GameModel(startError: final ActionError e) when !m.starting => (
        actionErrorText(context, e),
        OutlinedButton(onPressed: m.start, child: Text(s.retry)),
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
