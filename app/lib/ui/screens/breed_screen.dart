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
import 'stud_screen.dart';

/// 配種：「自己配種」與「借種」（S18）兩個分頁。
class BreedScreen extends StatelessWidget {
  const BreedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: S.subOwnBreed), Tab(text: S.subStud)]),
          Expanded(child: TabBarView(children: [OwnBreedView(), StudView()])),
        ],
      ),
    );
  }
}

/// 預覽（配種／借種機率）的載入狀態：換了組合才重抓；失敗（例如斷線）時連回來、隔幾秒再試。
class PreviewLoader {
  String? key;
  BreedPreview? value;
  bool loading = false;
  DateTime? failedAt;

  static const retryAfter = Duration(seconds: 3);

  void clear() {
    key = null;
    value = null;
    loading = false;
    failedAt = null;
  }

  /// 在 build 裡呼叫。[newKey] 是 null 代表還沒選齊。
  void ensure({
    required GameModel model,
    required String? newKey,
    required bool Function() mounted,
    required void Function(VoidCallback) setState,
    required Future<BreedPreview?> Function() fetch,
  }) {
    if (newKey == null) {
      clear();
      return;
    }
    if (newKey == key && failedAt == null) return;
    if (newKey == key && (!model.online || DateTime.now().difference(failedAt!) < retryAfter)) return;
    if (!model.online) return;
    key = newKey;
    value = null;
    failedAt = null;
    loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await fetch();
      if (!mounted() || key != newKey) return;
      setState(() {
        value = p;
        loading = false;
        failedAt = p == null ? DateTime.now() : null;
      });
    });
  }

  /// 還沒有結果時要顯示的文字；有結果回傳 null。
  String? statusText(GameModel m) {
    if (!m.online && value == null) return S.connecting;
    if (failedAt != null) return S.loadFailed;
    if (loading || value == null) return S.quoting;
    return null;
  }
}

/// 小牛稀有度、用途、公母的機率與費用（配種、借種共用）。
class BreedOdds extends StatelessWidget {
  const BreedOdds({super.key, required this.preview, required this.feeText});
  final BreedPreview preview;
  final String feeText;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var t = 0; t < 4; t++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(width: 14, height: 14, color: Palette.tiers[t]),
                const SizedBox(width: 6),
                SizedBox(width: 40, child: Text(tierName(t))),
                Expanded(child: LinearProgressIndicator(value: p.tierProbs[t].clamp(0.0, 1.0), minHeight: 8)),
                SizedBox(
                  width: 56,
                  child: Text('${(p.tierProbs[t] * 100).toStringAsFixed(1)}%', key: Key('prob-$t'), textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        if (p.typeProbs.isNotEmpty)
          Text(
            S.typeProbLine([for (final e in p.typeProbs.entries) if (e.value > 0) S.pct(typeName(e.key), fmtPlainPct1(e.value))].join('、')),
            key: const Key('breed-type-probs'),
          ),
        if (p.bullProb != null) Text(S.bullProbLine(fmtPlainPct1(p.bullProb!))),
        const SizedBox(height: 6),
        Text(feeText, key: const Key('breed-fee')),
        for (final b in p.blockers) Text(b, style: const TextStyle(color: Palette.warn)),
      ],
    );
  }
}

/// 選牛的 chip：不能配的牛也列出來，但停用並標示原因（已配種、工作中、上架中）。
class CowChips extends StatelessWidget {
  const CowChips({
    super.key,
    required this.keyPrefix,
    required this.cows,
    required this.selected,
    required this.emptyText,
    required this.enabled,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<Cow> cows;
  final String? selected;
  final String emptyText;
  final bool Function(Cow) enabled;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (cows.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(emptyText));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in cows)
          ChoiceChip(
            key: Key('$keyPrefix-${c.key}'),
            avatar: Container(width: 14, height: 14, color: Palette.type(c.type)),
            label: Text('#${c.key} ${typeName(c.type)} ${tierName(c.tier)}${_suffix(c)}'),
            selected: selected == c.key,
            onSelected: enabled(c) ? (sel) => onSelect(sel ? c.key : null) : null,
          ),
      ],
    );
  }

  static String _suffix(Cow c) {
    final b = cowBadges(c);
    return b.isEmpty ? '' : '（${b.join('、')}）';
  }
}

/// 自己的公牛 × 自己的母牛：免費，每頭一輩子一次。
class OwnBreedView extends StatefulWidget {
  const OwnBreedView({super.key});

  @override
  State<OwnBreedView> createState() => _OwnBreedViewState();
}

class _OwnBreedViewState extends State<OwnBreedView> {
  final _loader = PreviewLoader();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final now = m.gameNow;
    final bulls = s.cows.where((c) => c.bull && c.isAdultAt(now)).toList();
    final cows = s.cows.where((c) => !c.bull && c.isAdultAt(now)).toList();
    var sire = m.breedSireKey == null ? null : s.cowById(m.breedSireKey!);
    var dam = m.breedDamKey == null ? null : s.cowById(m.breedDamKey!);
    if (sire != null && !sire.canBreedAt(now)) sire = null; // 已配過的不能再選
    if (dam != null && !dam.canBreedAt(now)) dam = null;
    _loader.ensure(
      model: m,
      newKey: sire == null || dam == null ? null : '${sire.key}|${dam.key}',
      mounted: () => mounted,
      setState: setState,
      fetch: () => m.breedPreview(sire!, dam!),
    );
    final theme = Theme.of(context);
    final p = _loader.value;
    final calf = m.lastCalfKey == null ? null : s.cowById(m.lastCalfKey!);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.breedOnce, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(S.pickSire, style: theme.textTheme.titleSmall),
        CowChips(
          keyPrefix: 'sire',
          cows: bulls,
          selected: sire?.key,
          emptyText: S.noSire,
          enabled: (c) => c.canBreedAt(now),
          onSelect: m.setBreedSire,
        ),
        const SizedBox(height: 12),
        Text(S.pickDam, style: theme.textTheme.titleSmall),
        CowChips(
          keyPrefix: 'dam',
          cows: cows,
          selected: dam?.key,
          emptyText: S.noDam,
          enabled: (c) => c.canBreedAt(now),
          onSelect: m.setBreedDam,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(S.probTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                if (sire == null || dam == null)
                  const Text(S.pickBoth)
                else if (_loader.statusText(m) != null)
                  Text(_loader.statusText(m)!)
                else
                  BreedOdds(preview: p!, feeText: p.fee <= 0 ? S.breedFree : S.fee(fmtInt(p.fee))),
                const SizedBox(height: 8),
                if (s.pen.full) const Text(S.penFull, style: TextStyle(color: Palette.warn)),
                ActionButton(
                  key: const Key('breed-go'),
                  label: S.breed,
                  expand: true,
                  enabled: sire != null && dam != null && p != null && p.canBreed && s.coins >= p.fee && !s.pen.full,
                  onPressed: () async {
                    final r = await m.breed(sire!, dam!);
                    if (!context.mounted) return;
                    final c = r.value?.calf;
                    showResult(context, r.error, c == null ? S.breedDone : '${S.breedDone} ${S.newCalf(c.key, tierName(c.tier))}');
                    setState(_loader.clear);
                  },
                ),
              ],
            ),
          ),
        ),
        if (calf != null) CalfCountdown(calf: calf),
      ],
    );
  }
}

/// 新小牛長大的倒數。
class CalfCountdown extends StatelessWidget {
  const CalfCountdown({super.key, required this.calf});
  final Cow calf;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    return Card(
      key: const Key('breed-countdown'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TickerBuilder(
          builder: (context) {
            final t = m.gameNow;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${S.newCalf(calf.key, tierName(calf.tier))}　${typeName(calf.type)}・${sexName(calf.bull)}',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(calf.adultAt != null && calf.adultAt! > t
                    ? S.growUp(fmtCountdown(calf.adultAt! - t, m.timeScale))
                    : S.growUp(S.now)),
              ],
            );
          },
        ),
      ),
    );
  }
}
