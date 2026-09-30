import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import 'ticker_builder.dart';

/// 頂列：牧場名、等級、金幣、遊戲時間與倍率。斷線時顯示「連線中…」。
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.ranchName.isEmpty ? S.appTitle : m.ranchName,
                    key: const Key('topbar-ranch'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (s != null) ...[
                  Text(S.level(s.level), key: const Key('topbar-level')),
                  const SizedBox(width: 12),
                  Text(S.coins(fmtInt(s.coins)), key: const Key('topbar-coins')),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (!m.online)
              Container(
                key: const Key('topbar-offline'),
                color: Palette.offline,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: const Text(S.connecting, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            else
              TickerBuilder(
                builder: (context) => Text(
                  S.gameClock(fmtGameClock(m.gameNow), fmtScale(m.timeScale)),
                  key: const Key('topbar-clock'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
