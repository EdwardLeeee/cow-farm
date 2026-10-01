import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';

/// 圖鑑：用途 × 稀有度共 12 格，還沒發現的顯示「？」。
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final codex = context.select<GameModel, Set<CodexKey>>((m) => m.state!.codex);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.codexTitle, style: theme.textTheme.titleSmall),
        Text(S.codexCount(codex.length, 12), key: const Key('codex-count')),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 44),
            for (var t = 0; t < 4; t++)
              Expanded(
                child: Center(child: Text(tierName(t), style: theme.textTheme.bodySmall)),
              ),
          ],
        ),
        for (final type in CowType.values)
          Row(
            children: [
              SizedBox(width: 44, child: Text(typeName(type))),
              for (var t = 0; t < 4; t++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Cell(type: type, tier: t, found: codex.contains((type: type, tier: t))),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.type, required this.tier, required this.found});
  final CowType type;
  final int tier;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('codex-${type.wire}-$tier'),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: found ? Palette.type(type) : Palette.unknown,
        border: found ? Border(bottom: BorderSide(color: Palette.tiers[tier], width: 8)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        found ? '${typeName(type)}\n${tierName(tier)}' : S.unknown,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: found ? 12 : 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
