import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import 'breed_screen.dart';

/// 借種（S18）：上架／下架自己的公牛；瀏覽別人的公牛，選自己的母牛借種（先看機率與費用）。
class StudView extends StatefulWidget {
  const StudView({super.key});

  @override
  State<StudView> createState() => _StudViewState();
}

class _StudViewState extends State<StudView> {
  StudMarket? _market;
  bool _loadingMarket = false;
  String? _listingKey; // 選中的上架
  String? _damKey;
  final _loader = PreviewLoader();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loadingMarket = true);
    final mk = await context.read<GameModel>().studMarket();
    if (!mounted) return;
    setState(() {
      _market = mk ?? _market;
      _loadingMarket = false;
      if (_market != null && !_market!.listings.any((l) => l.key == _listingKey)) _listingKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final now = m.gameNow;
    final theme = Theme.of(context);
    final others = (_market?.listings ?? const <StudListing>[]).where((l) => !l.isMine).toList();
    final listing = others.where((l) => l.key == _listingKey).firstOrNull;
    final dams = s.cows.where((c) => !c.bull && c.isAdultAt(now)).toList();
    var dam = _damKey == null ? null : s.cowById(_damKey!);
    if (dam != null && !dam.canBreedAt(now)) dam = null;
    _loader.ensure(
      model: m,
      newKey: listing == null || dam == null ? null : '${listing.key}|${dam.key}',
      mounted: () => mounted,
      setState: setState,
      fetch: () => m.studPreview(listing!, dam!),
    );
    final p = _loader.value;
    final myBulls = s.cows.where((c) => c.bull && c.isAdultAt(now)).toList();

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- 我的公牛出借 ----
          Row(
            children: [
              Expanded(child: Text(S.studMineTitle, style: theme.textTheme.titleSmall)),
              Text(S.studIncome(fmtInt(s.stud.income)), key: const Key('stud-income')),
            ],
          ),
          if (!myBulls.any((c) => c.canListAt(now) || c.listed))
            const Padding(padding: EdgeInsets.all(8), child: Text(S.studNoBull)),
          for (final bull in myBulls)
            if (bull.listed || bull.canListAt(now)) _myBullRow(context, m, s, bull),
          const Divider(height: 24),
          // ---- 借種市場 ----
          Row(
            children: [
              Expanded(child: Text(S.studMarketTitle, style: theme.textTheme.titleSmall)),
              TextButton(
                key: const Key('stud-reload'),
                onPressed: _loadingMarket ? null : _reload,
                child: const Text(S.reload),
              ),
            ],
          ),
          if (_market == null)
            Text(_loadingMarket ? S.quoting : S.loadFailed)
          else if (others.isEmpty)
            const Text(S.studEmpty)
          else
            for (final l in others)
              Card(
                key: Key('stud-listing-${l.key}'),
                color: l.key == _listingKey ? theme.colorScheme.secondaryContainer : null,
                child: InkWell(
                  onTap: () => setState(() => _listingKey = l.key == _listingKey ? null : l.key),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Palette.type(l.type),
                            border: Border(bottom: BorderSide(color: Palette.tiers[l.tier], width: 6)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(S.bull, style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.studRow(typeName(l.type), tierName(l.tier), fmtInt(l.price)),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${S.studOwner(Strings.of(context).ranchText(l.owner))}　${S.weight(fmtInt(l.fee.kg))}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (l.key == _listingKey) const Icon(Icons.check),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          Text(S.pickDamForStud, style: theme.textTheme.titleSmall),
          CowChips(
            keyPrefix: 'stud-dam',
            cows: dams,
            selected: dam?.key,
            emptyText: S.noDamForStud,
            enabled: (c) => c.canBreedAt(now),
            onSelect: (k) => setState(() => _damKey = k),
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
                  if (listing == null)
                    const Text(S.pickListing)
                  else if (dam == null)
                    const Text(S.pickDamForStud)
                  else if (_loader.statusText(m) != null)
                    Text(_loader.statusText(m)!)
                  else
                    BreedOdds(preview: p!, feeText: S.fee(fmtInt(p.fee?.price ?? listing.price))),
                  const SizedBox(height: 8),
                  if (s.pen.full) const Text(S.penFull, style: TextStyle(color: Palette.warn)),
                  if (listing != null && s.coins < listing.price)
                    const Text(S.notEnoughCoins, style: TextStyle(color: Palette.warn)),
                  ActionButton(
                    key: const Key('stud-borrow'),
                    label: S.borrow(listing == null ? '—' : fmtInt(listing.price)),
                    expand: true,
                    enabled:
                        listing != null &&
                        dam != null &&
                        p != null &&
                        p.canBreed &&
                        s.coins >= listing.price &&
                        !s.pen.full,
                    onPressed: () async {
                      // 借種費用預覽時看到的價格；公牛長大了伺服器回 price_changed（S18-12 在第 4 步做）
                      final r = await m.studBorrow(listing!, dam!, price: p?.fee?.price ?? listing.price);
                      if (!context.mounted) return;
                      final c = r.value?.calf;
                      showResult(
                        context,
                        r.error,
                        c == null ? S.borrowed : '${S.borrowed} ${S.newCalf(c.key, tierName(c.tier))}',
                      );
                      if (r.ok) {
                        setState(() {
                          _listingKey = null;
                          _damKey = null;
                          _loader.clear();
                        });
                      }
                      _reload();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (m.lastCalfKey != null && s.cowById(m.lastCalfKey!) != null)
            CalfCountdown(calf: s.cowById(m.lastCalfKey!)!),
        ],
      ),
    );
  }

  Widget _myBullRow(BuildContext context, GameModel m, GameState s, Cow bull) {
    final listing = s.stud.listings.where((l) => '${l.cowId}' == bull.key).firstOrNull;
    return Card(
      key: Key('my-bull-${bull.key}'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${S.cowTitle(bull.key)}　${cowSummary(bull)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (bull.listed) ...[
              Text(listing == null ? S.badgeListed : S.listedAt(fmtInt(listing.price))),
              if (listing != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: ActionButton(
                    key: Key('unlist-${bull.key}'),
                    label: S.unlist,
                    outlined: true,
                    onPressed: () async {
                      final r = await m.studUnlist(listing.id);
                      if (context.mounted) showResult(context, r.error, S.unlistedOk);
                      _reload();
                    },
                  ),
                ),
            ] else ...[
              // 借種費由系統算（D26），主人只決定要不要上架
              if (bull.studFee != null) Text(S.costCoins(fmtInt(bull.studFee!.price)), key: Key('fee-${bull.key}')),
              Align(
                alignment: Alignment.centerRight,
                child: ActionButton(
                  key: Key('list-${bull.key}'),
                  label: S.list,
                  enabled: bull.canListAt(m.gameNow),
                  onPressed: () async {
                    final r = await m.studList(bull);
                    if (context.mounted) showResult(context, r.error, S.listedOk);
                    _reload();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
