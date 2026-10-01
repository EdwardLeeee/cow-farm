import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';

/// 圖鑑：24 個品種（協定 1.6），還沒發現的顯示「？」。M1 的原型畫面；正式的 S09 在第 4 步照設計稿做。
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final codex = context.select<GameModel, Map<String, double>>((m) => m.state!.codex);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.codexTitle, style: theme.textTheme.titleSmall),
        Text(S.codexCount(codex.length, kCodexOrder.length), key: const Key('codex-count')),
        const SizedBox(height: 8),
        for (final type in CowType.values) ...[
          Text(typeName(type), style: theme.textTheme.bodySmall),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final breed in kCodexOrder.where((b) => breedInfo(b)?.type == type))
                _Cell(info: breedInfo(breed)!, found: codex.containsKey(breed)),
            ],
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.info, required this.found});
  final BreedInfo info;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('codex-${info.breed}'),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: found ? Palette.type(info.type) : Palette.unknown,
        border: found ? Border(bottom: BorderSide(color: Palette.tiers[info.tier], width: 8)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        found ? '${Strings.of(context).breedName(info.breed)}\n${tierName(info.tier)}' : S.unknown,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: found ? 12 : 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
