import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// 配種：選公牛、選母牛 → 顯示稀有度機率與費用 → 配種 → 顯示倒數。
class BreedScreen extends StatefulWidget {
  const BreedScreen({super.key});

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen> {
  String? _previewFor; // "sire|dam"
  BreedPreview? _preview;
  bool _loading = false;
  DateTime? _failedAt; // 上次試算失敗的時間（只用來限制重試頻率）

  static const _retryAfter = Duration(seconds: 3);

  void _maybePreview(GameModel m, Cow? sire, Cow? dam) {
    if (sire == null || dam == null) {
      _previewFor = null;
      _preview = null;
      _failedAt = null;
      return;
    }
    final key = '${sire.key}|${dam.key}';
    final failed = _failedAt != null;
    if (key == _previewFor && !failed) return;
    // 失敗過（例如斷線）：連回來之後、隔幾秒再試，不要每次重畫都打一次
    if (key == _previewFor && (!m.online || DateTime.now().difference(_failedAt!) < _retryAfter)) return;
    if (!m.online) return;
    _previewFor = key;
    _preview = null;
    _failedAt = null;
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await m.breedPreview(sire, dam);
      if (!mounted || _previewFor != key) return;
      setState(() {
        _preview = p;
        _loading = false;
        _failedAt = p == null ? DateTime.now() : null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final now = m.gameNow;
    final bulls = s.cows.where((c) => c.bull && c.isAdultAt(now)).toList();
    final cows = s.cows.where((c) => !c.bull && c.isAdultAt(now)).toList();
    final sire = m.breedSireKey == null ? null : s.cowById(m.breedSireKey!);
    final dam = m.breedDamKey == null ? null : s.cowById(m.breedDamKey!);
    _maybePreview(m, sire, dam);
    final theme = Theme.of(context);
    final p = _preview;
    final ready = sire != null && dam != null && _isReady(sire, now) && _isReady(dam, now);
    final affordable = p != null && s.coins >= p.fee;
    final calf = m.lastCalfKey == null ? null : s.cowById(m.lastCalfKey!);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.pickSire, style: theme.textTheme.titleSmall),
        _Picker(
          keyPrefix: 'sire',
          cows: bulls,
          selected: sire?.key,
          emptyText: S.noSire,
          onSelect: m.setBreedSire,
        ),
        const SizedBox(height: 12),
        Text(S.pickDam, style: theme.textTheme.titleSmall),
        _Picker(
          keyPrefix: 'dam',
          cows: cows,
          selected: dam?.key,
          emptyText: S.noDam,
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
                else if (!m.online && p == null)
                  const Text(S.connecting)
                else if (_failedAt != null)
                  const Text(S.loadFailed)
                else if (_loading || p == null)
                  const Text(S.quoting)
                else ...[
                  for (var t = 0; t < 4; t++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(width: 14, height: 14, color: Palette.tiers[t]),
                          const SizedBox(width: 6),
                          SizedBox(width: 40, child: Text(tierName(t))),
                          Expanded(
                            child: LinearProgressIndicator(value: p.tierProbs[t].clamp(0.0, 1.0), minHeight: 8),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${(p.tierProbs[t] * 100).toStringAsFixed(1)}%',
                              key: Key('prob-$t'),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(p.fee <= 0 ? S.feeFree : S.fee(fmtInt(p.fee)), key: const Key('breed-fee')),
                ],
                const SizedBox(height: 8),
                if (s.pen.full) const Text(S.penFull, style: TextStyle(color: Palette.warn)),
                if (p != null && !affordable) const Text(S.notEnoughCoins, style: TextStyle(color: Palette.warn)),
                ActionButton(
                  key: const Key('breed-go'),
                  label: S.breed,
                  expand: true,
                  enabled: ready && affordable && !s.pen.full,
                  onPressed: () async {
                    final r = await m.breed(sire!, dam!);
                    if (!context.mounted) return;
                    final c = r.value?.calf;
                    showResult(context, r.error, c == null ? S.breedDone : '${S.breedDone} ${S.newCalf(c.key, tierName(c.tier))}');
                    setState(() {
                      _previewFor = null;
                      _failedAt = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        if (calf != null)
          Card(
            key: const Key('breed-countdown'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TickerBuilder(
                builder: (context) {
                  final t = m.gameNow;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.newCalf(calf.key, tierName(calf.tier)), style: theme.textTheme.titleSmall),
                      Text(
                        calf.adultAt != null && calf.adultAt! > t
                            ? S.growUp(fmtCountdown(calf.adultAt! - t, m.timeScale))
                            : S.growUp(S.now),
                      ),
                      if (dam != null && dam.readyAt != null && dam.readyAt! > t)
                        Text('${S.cowTitle(dam.key)} ${S.breedCooldown(fmtCountdown(dam.readyAt! - t, m.timeScale))}'),
                      if (sire != null && sire.readyAt != null && sire.readyAt! > t)
                        Text('${S.cowTitle(sire.key)} ${S.breedCooldown(fmtCountdown(sire.readyAt! - t, m.timeScale))}'),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  static bool _isReady(Cow c, double now) => c.readyAt == null || c.readyAt! <= now;
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.keyPrefix,
    required this.cows,
    required this.selected,
    required this.emptyText,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<Cow> cows;
  final String? selected;
  final String emptyText;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    if (cows.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(emptyText));
    return TickerBuilder(
      builder: (context) {
        final now = m.gameNow;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cows)
              ChoiceChip(
                key: Key('$keyPrefix-${c.key}'),
                avatar: Container(width: 14, height: 14, color: Palette.type(c.type)),
                label: Text(
                  '#${c.key} ${typeName(c.type)} ${tierName(c.tier)}'
                  '${c.readyAt != null && c.readyAt! > now ? '（${S.coolingDown} ${S.realApprox(fmtDuration((c.readyAt! - now) / m.timeScale))}）' : ''}',
                ),
                selected: selected == c.key,
                onSelected: (sel) => onSelect(sel ? c.key : null),
              ),
          ],
        );
      },
    );
  }
}
