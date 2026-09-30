import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// 牧場：奶桶、收奶、倉庫摘要、每頭牛一張卡。
class RanchScreen extends StatelessWidget {
  const RanchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const BucketCard(),
        const SizedBox(height: 8),
        WarehouseCard(state: s),
        const SizedBox(height: 12),
        Text('${S.cowsTitle}（${S.penSummary(s.pen.used, s.pen.slots)}）', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (s.cows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text(S.noCows)),
        for (final c in s.cows) CowCard(cow: c, onTap: () => m.openCow(c.key)),
      ],
    );
  }
}

class BucketCard extends StatelessWidget {
  const BucketCard({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final b = m.state!.bucket;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TickerBuilder(
          builder: (context) {
            final now = m.bucketNow;
            final ratio = b.capacity <= 0 ? 0.0 : (now / b.capacity).clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(S.bucketTitle, style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(S.bucketAmount(fmtNum(now), fmtInt(b.capacity)), key: const Key('bucket-amount')),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(key: const Key('bucket-bar'), value: ratio, minHeight: 14),
                const SizedBox(height: 4),
                Text(ratio >= 1 ? S.bucketFull : S.bucketRate(fmtNum(b.perHour)), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                ActionButton(
                  key: const Key('collect'),
                  label: S.collect,
                  expand: true,
                  onPressed: () async {
                    final r = await m.collect();
                    if (!context.mounted) return;
                    final got = r.value?['collected'];
                    showResult(context, r.error, got is num ? S.collected(fmtNum(got)) : S.collected(fmtNum(now)));
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

class WarehouseCard extends StatelessWidget {
  const WarehouseCard({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final w = state.warehouse;
    final fresh = w.worstFreshness;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.warehouseTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(S.warehouseMilk(fmtNum(w.milkTotal), fmtInt(w.capacity), w.milkLots.length), key: const Key('wh-milk')),
            if (fresh != null) Text(S.warehouseFresh(fmtPlainPct(fresh)), style: Theme.of(context).textTheme.bodySmall),
            Text(S.warehouseBeef(fmtNum(w.beefTotal), w.beefLots.length), key: const Key('wh-beef')),
          ],
        ),
      ),
    );
  }
}

/// 牛的卡片：用途色塊、公母、稀有度、階段、產奶量、體重。
class CowCard extends StatelessWidget {
  const CowCard({super.key, required this.cow, this.onTap});
  final Cow cow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('cow-${cow.key}'),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CowBlock(cow: cow),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${S.cowTitle(cow.key)}　${typeName(cow.type)}・${sexName(cow.bull)}・${stageName(cow.stage)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tierName(cow.tier)}　'
                      '${cow.bull || cow.stage == CowStage.calf ? S.noMilk : S.milkRate(fmtNum(cow.milkPerH))}　'
                      '${S.weight(fmtInt(cow.weightKg))}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用途色塊＋稀有度色條（原型只用色塊，不畫牛）。
class CowBlock extends StatelessWidget {
  const CowBlock({super.key, required this.cow, this.size = 48});
  final Cow cow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Palette.type(cow.type),
        border: Border(bottom: BorderSide(color: Palette.tiers[cow.tier], width: 8)),
      ),
      alignment: Alignment.center,
      child: Text('${typeName(cow.type)}\n${sexName(cow.bull)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
    );
  }
}
