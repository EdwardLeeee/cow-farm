import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/game_model.dart';
import '../format.dart';
import '../palette.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// 商店（S19）：只挑 A／B／C 等級，用途、公母、稀有度隨機，各項機率公開；另外有升級。
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final info = await context.read<GameModel>().shopInfo();
    if (!mounted) return;
    setState(() {
      _info = info ?? _info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = m.state!;
    final theme = Theme.of(context);
    // 價格以 state.shop.grades 為準（每次操作後都會更新）；機率來自 GET /v1/shop。
    final grades = <String>[
      for (final g in s.shopGrades) g.grade,
      if (s.shopGrades.isEmpty) ...?_info?.grades.map((g) => g.grade),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(S.shopGradesTitle, style: theme.textTheme.titleSmall),
        Text(S.penSummary(s.pen.used, s.pen.slots), style: theme.textTheme.bodySmall),
        if (s.pen.full) const Text(S.penFull, style: TextStyle(color: Palette.warn)),
        const SizedBox(height: 6),
        if (grades.isEmpty) Text(_loading ? S.loadingShop : S.loadFailed),
        for (final g in grades)
          _GradeCard(
            grade: g,
            price: s.gradePrice(g) ?? _info?.grades.where((x) => x.grade == g).firstOrNull?.price,
            odds: _info?.grades.where((x) => x.grade == g).firstOrNull,
            loading: _loading,
            state: s,
          ),
        const SizedBox(height: 16),
        Text(S.upgradesTitle, style: theme.textTheme.titleSmall),
        for (final k in const [UpgradeKind.pen, UpgradeKind.bucket, UpgradeKind.warehouse, UpgradeKind.fresh])
          _UpgradeRow(kind: k, info: s.upgrades[k] ?? const UpgradeInfo(), coins: s.coins),
        const SizedBox(height: 8),
        Text(S.prototypeNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 一個等級：價格、各項機率、購買按鈕。
class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.price,
    required this.odds,
    required this.loading,
    required this.state,
  });
  final String grade;
  final double? price;
  final ShopGrade? odds;
  final bool loading;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final o = odds;
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      key: Key('grade-$grade'),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  color: Palette.grade(grade),
                  alignment: Alignment.center,
                  child: Text(grade, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionButton(
                    key: Key('buy-grade-$grade'),
                    label: S.gradeButton(grade, price == null ? '？' : fmtInt(price!)),
                    enabled: !state.pen.full && (price == null || state.coins >= price!),
                    onPressed: () => _buy(context, m),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (o == null)
              Text(loading ? S.loadingShop : S.loadFailed, style: small)
            else ...[
              Text(
                '${S.probType}：${[for (final t in CowType.values) S.pct(typeName(t), fmtPlainPct1(o.typeProbs[t] ?? 0))].join('、')}',
                key: Key('grade-$grade-type'),
                style: small,
              ),
              Text(
                '${S.probSex}：${S.pct(S.bull, fmtPlainPct1(o.bullProb))}、${S.pct(S.cow, fmtPlainPct1(1 - o.bullProb))}',
                key: Key('grade-$grade-sex'),
                style: small,
              ),
              Text(
                '${S.probTier}：${[for (var t = 0; t < 4; t++) S.pct(tierName(t), fmtPlainPct1(o.tierProbs[t]))].join('、')}',
                key: Key('grade-$grade-tier'),
                style: small,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 買了之後顯示抽到的牛。
  Future<void> _buy(BuildContext context, GameModel m) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await m.shopBuy(grade);
    final cow = r.value?.cow;
    if (r.error != null || cow == null) {
      messenger?.showSnackBar(SnackBar(content: Text(r.error ?? S.unknownError)));
      return;
    }
    // 出貨後這頁可能已經關掉（牛不在了），用事先拿到的 Navigator 顯示結果。
    if (!navigator.mounted) return;
    await showDialog<void>(
      context: navigator.context,
      builder: (ctx) => AlertDialog(
        key: const Key('drawn-cow'),
        title: Text(S.drawnTitle(grade)),
        content: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Palette.type(cow.type),
                border: Border(bottom: BorderSide(color: Palette.tiers[cow.tier], width: 8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(S.drawnBody(typeName(cow.type), sexName(cow.bull), tierName(cow.tier), cow.key))),
          ],
        ),
        actions: [
          FilledButton(key: const Key('drawn-ok'), onPressed: () => Navigator.pop(ctx), child: const Text(S.ok)),
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
    UpgradeKind.field => S.upFieldTitle,
  };

  String _effect(double now, double next) => switch (kind) {
    UpgradeKind.pen => S.effectPen(fmtInt(now), fmtInt(next)),
    UpgradeKind.bucket || UpgradeKind.warehouse => S.effectCap(fmtInt(now), fmtInt(next)),
    UpgradeKind.fresh => S.effectFresh(fmtNum(now, 0), fmtNum(next, 0)),
    UpgradeKind.field => S.effectCap(fmtInt(now), fmtInt(next)),
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
