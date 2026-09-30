import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// 田地（S17）：田地清單、派耕牛、叫回、收成、開新田。稻米量用伺服器給的產量平滑推算。
class FieldsScreen extends StatelessWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final theme = Theme.of(context);
    final up = s.upgrades[UpgradeKind.field];
    final cost = up?.cost;
    final count = s.fields.length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(child: Text(S.fieldsTitle, style: theme.textTheme.titleSmall)),
            if (up?.current != null || count > 0)
              Text(S.fieldCount(count, (_max(up) ?? count)), key: const Key('field-count')),
          ],
        ),
        Text('${S.riceStock(fmtNum(s.rice.stock))}　${S.riceRate(fmtNum(s.rice.perHour))}', key: const Key('rice-summary')),
        const SizedBox(height: 8),
        TickerBuilder(
          builder: (context) {
            final inFields = s.fields.fold<double>(0, (a, f) => a + m.fieldRiceNow(f));
            return ActionButton(
              key: const Key('harvest'),
              label: S.harvestAll(fmtNum(inFields)),
              expand: true,
              enabled: inFields > 0,
              onPressed: () async {
                final r = await m.fieldHarvest();
                if (!context.mounted) return;
                final got = r.value?['harvested'];
                showResult(context, r.error, S.harvested(fmtNum(got is num ? got : 0)));
              },
            );
          },
        ),
        const SizedBox(height: 8),
        for (final f in s.fields) FieldCard(field: f),
        const SizedBox(height: 8),
        ActionButton(
          key: const Key('field-expand'),
          label: cost == null ? '${S.upFieldTitle}（${S.maxed}）' : S.expandField(fmtInt(cost)),
          outlined: true,
          expand: true,
          enabled: cost != null && s.coins >= cost,
          onPressed: () async {
            final r = await m.fieldExpand();
            if (context.mounted) showResult(context, r.error, S.fieldExpanded);
          },
        ),
        if (cost != null && s.coins < cost) const Text(S.notEnoughCoins, style: TextStyle(color: Palette.warn)),
      ],
    );
  }

  static int? _max(UpgradeInfo? up) => up?.maxLevel;
}

class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.field});
  final FieldInfo field;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final ox = field.cowId == null ? null : s.cowById('${field.cowId}');
    return Card(
      key: Key('field-${field.index}'),
      color: field.empty ? null : Palette.rice,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: TickerBuilder(
          builder: (context) {
            final now = m.fieldRiceNow(field);
            final cap = field.capacity;
            final ratio = cap == null || cap <= 0 ? 0.0 : (now / cap).clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${S.fieldName(field.index)}　${field.empty ? S.fieldEmpty : S.fieldOx('${field.cowId}')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (ox != null) Text(tierName(ox.tier)),
                  ],
                ),
                if (cap != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: ratio, minHeight: 10),
                  Text(S.fieldRice(fmtNum(now), fmtInt(cap)), key: Key('field-rice-${field.index}')),
                  Text(ratio >= 1 ? S.fieldFull : S.fieldRate(fmtNum(field.perHour)), style: Theme.of(context).textTheme.bodySmall),
                ] else if (field.rice > 0)
                  Text(S.fieldRice(fmtNum(field.rice), '—')),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: field.empty
                      ? ActionButton(
                          key: Key('field-assign-${field.index}'),
                          label: S.assignOx,
                          onPressed: () => _assign(context, m, field.index),
                        )
                      : ActionButton(
                          key: Key('field-recall-${field.index}'),
                          label: S.recall,
                          outlined: true,
                          enabled: ox != null,
                          onPressed: () async {
                            final r = await m.fieldRecall(ox!);
                            if (context.mounted) showResult(context, r.error, S.recalled);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 選一頭能下田的成年耕牛，派到這塊田。
  Future<void> _assign(BuildContext context, GameModel m, int index) async {
    final now = m.gameNow;
    final oxen = (m.state?.cows ?? const <Cow>[]).where((c) => c.canWorkAt(now)).toList();
    final pick = await showDialog<Cow>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(S.pickOx),
        children: [
          if (oxen.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text(S.noOx)),
          for (final c in oxen)
            SimpleDialogOption(
              key: Key('pick-ox-${c.key}'),
              onPressed: () => Navigator.pop(ctx, c),
              child: Text('${S.cowTitle(c.key)}　${cowSummary(c)}'),
            ),
        ],
      ),
    );
    if (pick == null || !context.mounted) return;
    final r = await m.fieldAssign(pick, field: index);
    if (context.mounted) showResult(context, r.error, S.assigned);
  }
}
