import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';

/// 排行榜：總資產、收藏、本週收入三個分頁；前 50 名＋自己的名次。電腦假玩家名字前面標「電腦」。
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: S.rankNetworth),
              Tab(text: S.rankCollection),
              Tab(text: S.rankWeekly),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                RankList(kind: RankKind.networth),
                RankList(kind: RankKind.collection),
                RankList(kind: RankKind.weekly),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RankList extends StatefulWidget {
  const RankList({super.key, required this.kind});
  final RankKind kind;

  @override
  State<RankList> createState() => _RankListState();
}

class _RankListState extends State<RankList> {
  late Future<Leaderboard?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<GameModel>().leaderboard(widget.kind);
  }

  Future<void> _reload() async {
    final f = context.read<GameModel>().leaderboard(widget.kind);
    setState(() => _future = f);
    await f;
  }

  static String displayName(RankEntry e) =>
      e.isBot && !e.name.startsWith(S.botPrefix) ? '${S.botPrefix} ${e.name}' : e.name;

  String _score(double v) => widget.kind == RankKind.collection ? fmtInt(v) : S.costCoins(fmtInt(v));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Leaderboard?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: Text(S.quoting));
        }
        final lb = snap.data;
        if (lb == null) {
          return Center(
            child: TextButton(onPressed: _reload, child: const Text('${S.loadFailed}，${S.retry}')),
          );
        }
        final me = lb.me ?? lb.entries.where((e) => e.isMe).firstOrNull;
        return Column(
          children: [
            Container(
              key: Key('rank-me-${widget.kind.wire}'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(10),
              child: Text(
                me == null ? S.myRank(S.notRanked) : '${S.myRank('${me.rank}')}　${_score(me.score)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  itemCount: lb.entries.length,
                  itemBuilder: (context, i) {
                    final e = lb.entries[i];
                    return ListTile(
                      dense: true,
                      selected: e.isMe,
                      leading: SizedBox(width: 32, child: Text('${e.rank}', textAlign: TextAlign.end)),
                      title: Text(displayName(e)),
                      trailing: Text(_score(e.score)),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
