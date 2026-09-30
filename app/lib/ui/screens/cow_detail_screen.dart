import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'ranch_screen.dart';

/// 牛的詳細資料：出貨（先看評級機率，出貨後揭曉評級）、選這頭去配種、下田／叫回、上架／下架借種。
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

String _gradeProbsText(Map<String, double> p) =>
    [for (final g in gradeNames) if (p[g] != null) S.gradeProb(g, fmtPlainPct1(p[g]!))].join('　');

class _Body extends StatelessWidget {
  const _Body({required this.cow});
  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final theme = Theme.of(context);
    final now = m.gameNow;
    final listing = cow.listed ? m.state?.stud.listings.where((l) => '${l.cowId}' == cow.key).firstOrNull : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            CowBlock(cow: cow, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${S.cowTitle(cow.key)}\n${cowSummary(cow)}・${stageName(cow.stage)}', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cow.ageH != null) Text(S.age(fmtDuration(cow.ageH! * 3600))),
        Text(cowOutput(cow)),
        Text(S.weight(fmtInt(cow.weightKg))),
        if (cow.origin != null) Text(S.origin(S.originName(cow.origin!))),
        if (cow.working) Text(S.workingIn(cow.fieldIndex!), key: const Key('detail-working')),
        if (cow.listed) Text(listing == null ? S.badgeListed : S.listedAt(fmtInt(listing.price)), key: const Key('detail-listed')),
        if (cow.bred) Text('${S.badgeBred}（${S.breedOnce}）', key: const Key('detail-bred')),
        TickerBuilder(
          builder: (context) {
            final t = m.gameNow;
            return cow.adultAt != null && cow.adultAt! > t
                ? Text(S.growUp(fmtCountdown(cow.adultAt! - t, m.timeScale)), key: const Key('detail-grow'))
                : const SizedBox.shrink();
          },
        ),
        const SizedBox(height: 8),
        if (cow.shipValue != null && cow.isAdultAt(now))
          Text(S.shipValue(fmtInt(cow.shipValue!)), key: const Key('detail-ship-value'), style: theme.textTheme.titleSmall),
        if (cow.gradeProbs != null && cow.gradeProbs!.isNotEmpty)
          Text('${S.shipGradeTitle}：${_gradeProbsText(cow.gradeProbs!)}', key: const Key('detail-grade-probs')),
        if (cow.working) const Text(S.recallFirst, style: TextStyle(color: Palette.warn)),
        if (cow.listed) const Text(S.unlistFirst, style: TextStyle(color: Palette.warn)),
        const SizedBox(height: 16),
        ActionButton(
          key: const Key('detail-ship'),
          label: cow.isAdultAt(now) ? S.ship : S.shipNotAdult,
          enabled: cow.canShipAt(now),
          expand: true,
          onPressed: () => _ship(context, m, cow),
        ),
        const SizedBox(height: 8),
        ActionButton(
          key: const Key('detail-breed'),
          label: S.pickForBreed,
          outlined: true,
          expand: true,
          enabled: cow.canBreedAt(now),
          onPressed: () => m.selectForBreeding(cow),
        ),
        if (cow.type == CowType.dual) ...[
          const SizedBox(height: 8),
          if (cow.working)
            ActionButton(
              key: const Key('detail-recall'),
              label: S.recall,
              outlined: true,
              expand: true,
              onPressed: () async {
                final r = await m.fieldRecall(cow);
                if (context.mounted) showResult(context, r.error, S.recalled);
              },
            )
          else
            ActionButton(
              key: const Key('detail-assign'),
              label: S.assignOx,
              outlined: true,
              expand: true,
              enabled: cow.canWorkAt(now),
              onPressed: () async {
                final r = await m.fieldAssign(cow);
                if (context.mounted) showResult(context, r.error, S.assigned);
              },
            ),
        ],
        if (cow.bull) ...[
          const SizedBox(height: 8),
          if (cow.listed && listing != null)
            ActionButton(
              key: const Key('detail-unlist'),
              label: S.unlist,
              outlined: true,
              expand: true,
              onPressed: () async {
                final r = await m.studUnlist(listing.id);
                if (context.mounted) showResult(context, r.error, S.unlistedOk);
              },
            )
          else if (!cow.listed)
            ActionButton(
              key: const Key('detail-list'),
              label: S.list,
              outlined: true,
              expand: true,
              enabled: cow.canListAt(now),
              onPressed: () => _list(context, m, cow),
            ),
        ],
      ],
    );
  }

  /// 出貨：先拿評級機率給玩家看，確定後出貨，再揭曉評到的等級（S20）。
  Future<void> _ship(BuildContext context, GameModel m, Cow cow) async {
    final preview = await m.shipPreview(cow);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.shipConfirmTitle),
        content: Column(
          key: const Key('ship-confirm-body'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.shipConfirmBody(fmtInt(preview?.weightKg ?? cow.weightKg), fmtInt(preview?.expectedValue ?? cow.shipValue ?? 0))),
            const SizedBox(height: 8),
            const Text(S.shipGradeTitle, style: TextStyle(fontWeight: FontWeight.bold)),
            if (preview == null)
              Text(cow.gradeProbs == null ? S.loadFailed : _gradeProbsText(cow.gradeProbs!))
            else ...[
              for (final g in gradeNames)
                Row(
                  children: [
                    Container(width: 14, height: 14, color: Palette.grade(g)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.gradeLine(g, fmtPlainPct1(preview.gradeProbs[g] ?? 0), fmtInt(preview.valueByGrade[g] ?? 0)),
                        key: Key('ship-grade-$g'),
                      ),
                    ),
                  ],
                ),
              if (preview.expectedValue != null) Text(S.expectedValue(fmtInt(preview.expectedValue!))),
              for (final b in preview.blockers) Text(b, style: const TextStyle(color: Palette.warn)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          FilledButton(
            key: const Key('ship-confirm'),
            onPressed: preview?.canShip == false ? null : () => Navigator.pop(ctx, true),
            child: const Text(S.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final r = await m.ship(cow);
    final res = r.value;
    if (r.error != null || res == null) {
      messenger?.showSnackBar(SnackBar(content: Text(r.error ?? S.unknownError)));
      return;
    }
    // 揭曉評級（原型不做動畫，只顯示結果）
    // 出貨後這頁可能已經關掉（牛不在了），用事先拿到的 Navigator 顯示結果。
    if (!navigator.mounted) return;
    await showDialog<void>(
      context: navigator.context,
      builder: (ctx) => AlertDialog(
        key: const Key('ship-result'),
        title: Text(S.shipResultTitle(res.grade ?? '?')),
        content: Text(S.shipResultBody(fmtNum(res.beefQty ?? 0), fmtInt(res.valueEstimate ?? 0))),
        actions: [FilledButton(key: const Key('ship-result-ok'), onPressed: () => Navigator.pop(ctx), child: const Text(S.ok))],
      ),
    );
  }

  /// 上架借種：從伺服器給的價位挑一個。
  Future<void> _list(BuildContext context, GameModel m, Cow cow) async {
    final prices = m.state?.stud.prices ?? const <double>[];
    final price = await showDialog<double>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(S.list),
        children: [
          for (final p in prices)
            SimpleDialogOption(
              key: Key('list-price-${p.round()}'),
              onPressed: () => Navigator.pop(ctx, p),
              child: Text(S.costCoins(fmtInt(p))),
            ),
        ],
      ),
    );
    if (price == null || !context.mounted) return;
    final r = await m.studList(cow, price);
    if (context.mounted) showResult(context, r.error, S.listedOk);
  }
}
