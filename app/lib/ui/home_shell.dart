import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/game_model.dart';
import 'screens/breed_screen.dart';
import 'screens/codex_screen.dart';
import 'screens/cow_detail_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/ranch_screen.dart';
import 'screens/shop_screen.dart';
import 'widgets/top_bar.dart';

/// 外框：頂列＋內容＋底部分頁。分頁切換不算「按鈕」，斷線時仍可切換查看。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _labels = [S.tabRanch, S.tabMarket, S.tabBreed, S.tabShop, S.tabCodex, S.tabRank];
  static const _icons = [
    Icons.grass,
    Icons.show_chart,
    Icons.favorite_border,
    Icons.store_outlined,
    Icons.grid_view,
    Icons.emoji_events_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    return PopScope(
      canPop: m.detailCowKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) m.closeCow();
      },
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
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(key: Key('tab-${AppTab.values[i].name}'), icon: Icon(_icons[i]), label: _labels[i]),
                ],
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
      AppTab.breed => const BreedScreen(),
      AppTab.shop => const ShopScreen(),
      AppTab.codex => const CodexScreen(),
      AppTab.rank => const LeaderboardScreen(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.startError ?? S.loadingFarm, textAlign: TextAlign.center),
          if (m.startError != null && !m.starting) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: m.start, child: const Text(S.retry)),
          ],
          const SizedBox(height: 24),
          Text(S.prototypeNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
