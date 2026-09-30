import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'ranch_screen.dart';

/// 牛的詳細資料：出貨（先顯示估值）、選這頭去配種。
class CowDetailScreen extends StatelessWidget {
  const CowDetailScreen({super.key, required this.cowKey});
  final String cowKey;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final cow = m.state?.cowById(cowKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('detail-back'),
            onPressed: m.closeCow,
            icon: const Icon(Icons.arrow_back),
            label: const Text(S.back),
          ),
        ),
        if (cow == null)
          const Padding(padding: EdgeInsets.all(16), child: Text(S.noCows))
        else
          Expanded(child: _Body(cow: cow)),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.cow});
  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            CowBlock(cow: cow, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${S.cowTitle(cow.key)}\n${typeName(cow.type)}・${sexName(cow.bull)}・${tierName(cow.tier)}・${stageName(cow.stage)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cow.ageH != null) Text(S.age(fmtDuration(cow.ageH! * 3600))),
        Text(cow.bull || cow.stage == CowStage.calf ? S.noMilk : S.milkRate(fmtNum(cow.milkPerH))),
        Text(S.weight(fmtInt(cow.weightKg))),
        TickerBuilder(
          builder: (context) {
            final now = m.gameNow;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cow.adultAt != null && cow.adultAt! > now)
                  Text(S.growUp(fmtCountdown(cow.adultAt! - now, m.timeScale)), key: const Key('detail-grow')),
                if (cow.isAdultAt(now))
                  Text(
                    cow.readyAt != null && cow.readyAt! > now
                        ? S.breedCooldown(fmtCountdown(cow.readyAt! - now, m.timeScale))
                        : S.breedReady,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (cow.shipValue != null)
          Text(S.shipValue(fmtInt(cow.shipValue!)), key: const Key('detail-ship-value'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 16),
        ActionButton(
          key: const Key('detail-ship'),
          label: cow.isAdultAt(m.gameNow) ? S.ship : S.shipNotAdult,
          enabled: cow.isAdultAt(m.gameNow),
          expand: true,
          onPressed: () => _confirmShip(context, m, cow),
        ),
        const SizedBox(height: 8),
        ActionButton(
          key: const Key('detail-breed'),
          label: S.pickForBreed,
          outlined: true,
          expand: true,
          enabled: cow.isAdultAt(m.gameNow),
          onPressed: () => m.selectForBreeding(cow),
        ),
      ],
    );
  }

  Future<void> _confirmShip(BuildContext context, GameModel m, Cow cow) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.shipConfirmTitle),
        content: Text(
          S.shipConfirmBody(fmtInt(cow.weightKg), cow.shipValue == null ? '？' : fmtInt(cow.shipValue!)),
          key: const Key('ship-confirm-body'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          FilledButton(key: const Key('ship-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text(S.confirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await m.ship(cow);
    messenger?.showSnackBar(SnackBar(content: Text(r.error ?? S.shipped(cow.key))));
  }
}
