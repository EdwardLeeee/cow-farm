import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// 商店／升級：買小牛（三種用途 × 公母）、擴建、奶桶、倉庫、冷藏。錢不夠就停用。
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.buyCalfTitle, style: theme.textTheme.titleSmall),
        Text(S.penSummary(s.pen.used, s.pen.slots), style: theme.textTheme.bodySmall),
        if (s.pen.full) const Text(S.penFull, style: TextStyle(color: Palette.warn)),
        const SizedBox(height: 6),
        for (final t in CowType.values) _CalfRow(type: t, state: s),
        const SizedBox(height: 16),
        Text(S.upgradesTitle, style: theme.textTheme.titleSmall),
        for (final k in UpgradeKind.values) _UpgradeRow(kind: k, info: s.upgrades[k] ?? const UpgradeInfo(), coins: s.coins),
        const SizedBox(height: 8),
        Text(S.prototypeNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 一種用途的小牛：母、公兩個按鈕。
class _CalfRow extends StatelessWidget {
  const _CalfRow({required this.type, required this.state});
  final CowType type;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final price = state.calfPrice(type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 28, height: 28, color: Palette.type(type)),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text(typeName(type))),
          for (final bull in const [false, true]) ...[
            Expanded(
              child: ActionButton(
                key: Key('buy-${type.wire}-${bull ? 'bull' : 'cow'}'),
                label: '${S.calfButton(typeName(type), sexName(bull))}\n${price == null ? '' : S.costCoins(fmtInt(price))}',
                enabled: !state.pen.full && (price == null || state.coins >= price),
                onPressed: () async {
                  final r = await m.buyCalf(type, bull);
                  if (!context.mounted) return;
                  showResult(context, r.error, S.boughtCalf(typeName(type), sexName(bull)));
                },
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.kind, required this.info, required this.coins});
  final UpgradeKind kind;
  final UpgradeInfo info;
  final double coins;

  String get _title => switch (kind) {
    UpgradeKind.pen => S.upPen,
    UpgradeKind.bucket => S.upBucket,
    UpgradeKind.warehouse => S.upWarehouse,
    UpgradeKind.fresh => S.upFresh,
  };

  String _effect(double now, double next) => switch (kind) {
    UpgradeKind.pen => S.effectPen(fmtInt(now), fmtInt(next)),
    UpgradeKind.bucket || UpgradeKind.warehouse => S.effectCap(fmtInt(now), fmtInt(next)),
    UpgradeKind.fresh => S.effectFresh(fmtNum(now, 0), fmtNum(next, 0)),
  };

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final cost = info.cost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: TickerBuilder(
          builder: (context) {
            final now = m.gameNow;
            final locked = info.openAt != null && info.openAt! > now;
            final subtitle = <String>[
              if (info.level != null) S.levelNow(info.level!),
              if (info.current != null && info.next != null) _effect(info.current!, info.next!),
              if (cost == null) S.maxed else S.costCoins(fmtInt(cost)),
              if (locked) S.opensIn(fmtCountdown(info.openAt! - now, m.timeScale)),
              if (cost != null && coins < cost) S.notEnoughCoins,
            ].join('・');
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(subtitle, key: Key('up-info-${kind.wire}')),
                    ],
                  ),
                ),
                ActionButton(
                  key: Key('up-${kind.wire}'),
                  label: _title,
                  enabled: cost != null && coins >= cost && !locked,
                  onPressed: () async {
                    final r = await m.upgrade(kind);
                    if (!context.mounted) return;
                    showResult(context, r.error, S.upgraded);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
