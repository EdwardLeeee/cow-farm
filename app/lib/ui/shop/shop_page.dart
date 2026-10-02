// 商店（設計稿 s10.js、screens.css 的 .grade-card、.prob-grid、.up-card）：上面切換「抽牛」（S19）和「設施」（S10）。
// 抽牛只挑 A／B／C 等級，用途、公母、稀有度的精確機率由伺服器給（GET /v1/shop），app 不寫死；抽到的是小牛。
// 設施升級的費用、效果、等級都看 state.upgrades；錢夠不夠只是先把按鈕停用，帳一律由伺服器算。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/note_line.dart';
import '../kit/press.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// A／B／C 的底色（s10.js 的 GC）。
const kShopGradeColors = {'A': Color(0xFFFFD45E), 'B': Color(0xFFCFE6FF), 'C': Color(0xFFFFD9C2)};

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  ShopInfo? _info;
  bool _loading = true;
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  /// 剛升級完的那一列（S10-05：淡綠底）。
  UpgradeKind? _done;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await context.read<GameModel>().shopInfo();
    if (!mounted) return;
    setState(() {
      _info = info ?? _info;
      _loading = false;
    });
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _buy(String grade) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await m.shopBuy(grade);
    if (!mounted) return;
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(ToastKind.err, actionErrorTextWith(s, m, err));
      return;
    }
    final cow = r.value?.cow;
    if (cow == null) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent, // 暗幕由 AppDialog 自己畫
      useSafeArea: false,
      builder: (context) => DrawnDialog(grade: grade, cow: cow),
    );
  }

  Future<void> _upgrade(UpgradeKind kind) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final before = m.state?.upgrades[kind];
    final r = await m.upgrade(kind);
    if (!mounted) return;
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(ToastKind.err, actionErrorTextWith(s, m, err));
      return;
    }
    setState(() => _done = kind);
    // 「升級完成：奶桶 42 → 63 瓶」：效果是升級前的「現在 → 下一級」
    final effect = before == null ? '' : upgradeEffect(s, kind, before);
    _showToast(ToastKind.ok, s.s10Upgraded(what: upgradeWhat(s, kind), effect: effect).trim());
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final safe = MediaQuery.paddingOf(context);
    final facility = m.shopFacility;
    return AppFrame(
      tab: AppTab.shop,
      contentPadding: EdgeInsets.zero,
      content: ListView(
        key: const Key('shop'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          SegControl(
            labels: [s.s19SegDraw, s.s19SegFacility],
            selected: facility ? 1 : 0,
            onSelect: (i) => m.selectShop(facility: i == 1),
          ),
          const SizedBox(height: 12),
          if (facility) ..._facility(context, m) else ..._draw(context, m),
        ],
      ),
      overlays: [
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: FrameSizes.contentBottom(safe) + 14,
            child: Center(
              child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
            ),
          ),
      ],
    );
  }

  /// 抽牛（S19）：規則一行、牛舍滿了的提醒、A／B／C 三張卡。
  List<Widget> _draw(BuildContext context, GameModel m) {
    final s = Strings.of(context);
    final st = m.state!;
    final penFull = st.pen.full;
    final grades = <String>[
      for (final g in st.shopGrades) g.grade,
      if (st.shopGrades.isEmpty) ...?_info?.grades.map((g) => g.grade),
    ];
    return [
      NoteLine(icon: 'info', text: s.s19Rule, kind: NoteKind.info),
      if (penFull) ...[
        const SizedBox(height: 12),
        NoteLine(
          key: const Key('pen-full'),
          icon: 'warn',
          text: s.s19PenFull(used: st.pen.used, slots: st.pen.slots),
          kind: NoteKind.warn,
        ),
      ],
      for (final g in grades) ...[
        const SizedBox(height: 12),
        GradeCard(
          grade: g,
          price: st.gradePrice(g) ?? _info?.grades.where((x) => x.grade == g).firstOrNull?.price,
          odds: _info?.grades.where((x) => x.grade == g).firstOrNull,
          loading: _loading && _info == null,
          failed: !_loading && _info == null,
          coins: st.coins,
          penFull: penFull,
          canAct: m.canAct,
          onBuy: () => _buy(g),
          onRetry: _load,
        ),
      ],
    ];
  }

  /// 設施（S10）：擴建牛舍、加大奶桶、加大倉庫、冷藏設備；下面一句田地在別的分頁開。
  List<Widget> _facility(BuildContext context, GameModel m) {
    final s = Strings.of(context);
    final st = m.state!;
    return [
      for (final (i, k) in const [
        UpgradeKind.pen,
        UpgradeKind.bucket,
        UpgradeKind.warehouse,
        UpgradeKind.fresh,
      ].indexed) ...[
        if (i > 0) const SizedBox(height: 12),
        _UpgradeCard(
          kind: k,
          info: st.upgrades[k] ?? const UpgradeInfo(),
          coins: st.coins,
          done: _done == k,
          canAct: m.canAct,
          busy: m.busy,
          onUpgrade: () => _upgrade(k),
        ),
      ],
      const SizedBox(height: 12),
      Text(s.s10FieldsNote, textAlign: TextAlign.center, style: KitText.hint()),
    ];
  }
}

/// .seg：一排切換（白底、粗框、圓角 22、下陰影 3）；選中的黃底。平的元件，按下蓋色（G-12）。
class SegControl extends StatelessWidget {
  const SegControl({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r22),
      boxShadow: AppShadows.solid(3),
    ),
    child: Row(
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: Pressable(
                key: Key('seg-$i'),
                onTap: () => onSelect(i),
                builder: (context, look) => PressTint(
                  tint: look.tint,
                  borderRadius: const BorderRadius.all(AppRadii.r16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    decoration: i == selected
                        ? BoxDecoration(
                            color: AppColors.yellow,
                            // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: const BorderRadius.all(AppRadii.r16),
                          )
                        : null,
                    child: Text(
                      label,
                      softWrap: false,
                      style: AppText.style(
                        15,
                        weight: i == selected ? FontWeight.w900 : FontWeight.w700,
                        color: i == selected ? AppColors.ink : AppColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// .grade-card：等級、說明、價格鈕；下面是用途、公母、稀有度的機率（伺服器給的）。
class GradeCard extends StatelessWidget {
  const GradeCard({
    super.key,
    required this.grade,
    required this.price,
    required this.odds,
    required this.loading,
    required this.failed,
    required this.coins,
    required this.penFull,
    required this.canAct,
    required this.onBuy,
    required this.onRetry,
  });

  final String grade;
  final double? price;
  final ShopGrade? odds;
  final bool loading;
  final bool failed;
  final double coins;
  final bool penFull;
  final bool canAct;
  final VoidCallback onBuy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final p = price;
    final short = p != null && coins < p;
    final enabled = canAct && p != null && !short && !penFull && odds != null;
    final desc = switch (grade) {
      'A' => s.s19DescA,
      'B' => s.s19DescB,
      _ => s.s19DescC,
    };
    return AppCard(
      key: Key('grade-$grade'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // .gc-badge：46×46、粗框、圓角 14、下陰影 3
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kShopGradeColors[grade] ?? Colors.white,
                  border: Border.all(color: AppColors.ink, width: AppSizes.border),
                  borderRadius: const BorderRadius.all(AppRadii.r14),
                  boxShadow: AppShadows.solid(3),
                ),
                child: Text(grade, style: AppText.style(24, weight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.gGrade(g: grade),
                      style: AppText.style(17, weight: FontWeight.w900, lineHeight: 22),
                    ),
                    Text(desc, style: KitText.hint()),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                p == null ? '–' : s.costCoins(v: fmt(p)),
                key: Key('buy-$grade'),
                small: true,
                kind: ButtonKind.primary,
                icon: 'coin',
                onPressed: enabled ? onBuy : null,
              ),
            ],
          ),
          // 金幣不夠（S19-03）：還差多少（只是顯示，買不買得起由伺服器判斷）
          if (short && !penFull)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.notEnoughCoins(n: fmt((p - coins).ceil())), style: KitText.warn()),
            ),
          if (loading)
            _OddsEmpty(
              children: [
                const Spinner(),
                const SizedBox(width: 8),
                Flexible(child: Text(s.loadingShop, style: _emptyStyle)),
              ],
            )
          else if (failed || odds == null)
            _OddsEmpty(
              children: [
                const AppIcon('err', size: 20),
                const SizedBox(width: 4),
                Flexible(child: Text(s.s19ProbFailed, style: KitText.err(size: 14))),
                const SizedBox(width: 8),
                AppButton(s.retry, key: Key('odds-retry-$grade'), small: true, icon: 'refresh', onPressed: onRetry),
              ],
            )
          else
            _ProbGrid(odds: odds!),
        ],
      ),
    );
  }
}

final _emptyStyle = AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2);

/// .oc-empty：載入中、載入失敗（置中，至少 64 高）。
class _OddsEmpty extends StatelessWidget {
  const _OddsEmpty({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 64),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
  );
}

/// 機率：1% 以上寫一位小數（整數就不寫），0.01% 以上寫兩位，更小寫「<0.01%」（s10.js 的 p1）。
String probText(double p) {
  final v = p * 100;
  if (v >= 1) {
    final t = v.toStringAsFixed(1);
    return '${t.endsWith('.0') ? t.substring(0, t.length - 2) : t}%';
  }
  if (v >= 0.01) {
    var t = v.toStringAsFixed(2);
    while (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    return '${t.endsWith('.') ? t.substring(0, t.length - 1) : t}%';
  }
  return '<0.01%';
}

/// .prob-grid：左邊一欄小標（用途、公母、稀有度），右邊每一項「名稱 數字%」，放不下就換行。
class _ProbGrid extends StatelessWidget {
  const _ProbGrid({required this.odds});

  final ShopGrade odds;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    Widget item(String name, double p) => Text.rich(
      TextSpan(
        style: AppText.style(13, weight: FontWeight.w700, lineHeight: 20),
        children: [
          TextSpan(text: '$name '),
          TextSpan(text: probText(p), style: AppText.number(14, lineHeight: 20)),
        ],
      ),
      softWrap: false,
    );
    Widget values(List<Widget> items) => Wrap(spacing: 12, runSpacing: 2, children: items);
    final key = AppText.style(12, weight: FontWeight.w900, color: AppColors.ink2, lineHeight: 20);
    final rows = [
      (s.probType, values([for (final t in CowType.values) item(s.useName(t), odds.typeProbs[t] ?? 0)])),
      (s.probSex, values([item(s.bull, odds.bullProb), item(s.cow, 1 - odds.bullProb)])),
      (s.probTier, values([for (final (i, p) in odds.tierProbs.indexed) item(s.tierName(i.clamp(0, 3)), p)])),
    ];
    return Container(
      key: const Key('prob-grid'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r12),
      ),
      // grid-template-columns: auto 1fr：左欄跟最寬的小標一樣寬
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          for (final (i, (k, v)) in rows.indexed)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 10, top: i == 0 ? 0 : 4),
                  child: Text(k, softWrap: false, style: key),
                ),
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                  child: v,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 升級完成的提示裡「升級了什麼」（S10-05：「升級完成：奶桶 42 → 63 瓶」）。
String upgradeWhat(Strings s, UpgradeKind k) => switch (k) {
  UpgradeKind.pen => s.upPen,
  UpgradeKind.bucket => s.bucketTitle,
  UpgradeKind.warehouse => s.warehouseTitle,
  UpgradeKind.fresh => s.upFresh,
  UpgradeKind.field => s.tabFields, // 田地在「田地」分頁開，商店不會用到
};

/// 升級的效果「現在 → 下一級」。
String upgradeEffect(Strings s, UpgradeKind k, UpgradeInfo info) {
  final a = info.current, b = info.next;
  if (a == null || b == null) return '';
  return switch (k) {
    UpgradeKind.pen => s.effectPen(a: fmt(a), b: fmt(b)),
    UpgradeKind.fresh => s.s10EffectFresh(a: fmt(a), b: fmt(b)),
    _ => s.s10EffectBottles(a: fmt(a), b: fmt(b)),
  };
}

/// .up-card：設施的圖示、名稱、等級、效果；右邊價格鈕（已滿級、還沒開放、處理中各有樣子）。
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.kind,
    required this.info,
    required this.coins,
    required this.done,
    required this.canAct,
    required this.busy,
    required this.onUpgrade,
  });

  final UpgradeKind kind;
  final UpgradeInfo info;
  final double coins;
  final bool done;
  final bool canAct;
  final bool busy;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final cost = info.cost;
    final maxed = cost == null;
    final level = info.level ?? 0;
    final (icon, name) = switch (kind) {
      UpgradeKind.pen => ('barn', s.upPen),
      UpgradeKind.bucket => ('pail', s.upBucket),
      UpgradeKind.warehouse => ('box', s.upWarehouse),
      UpgradeKind.fresh => ('leaf', s.upFresh),
      UpgradeKind.field => ('field', s.tabFields),
    };
    final lv = maxed
        ? s.s10MaxLevel
        : switch (kind) {
            UpgradeKind.pen => level == 0 ? s.s10PenNever : s.s10PenTimes(n: level),
            // 冷藏有最高幾級（伺服器給 max 才寫「第 1 / 4 級」）
            UpgradeKind.fresh when info.maxLevel != null => s.s10LevelOf(n: level, max: info.maxLevel!),
            _ => s.gLevelN(n: level),
          };
    final effect = maxed
        ? (kind == UpgradeKind.fresh && info.current != null ? s.s10FreshMax(h: fmt(info.current!)) : s.s10MaxedEffect)
        : upgradeEffect(s, kind, info);
    return TickerBuilder(
      builder: (context) {
        // 第一次擴建開局 15 遊戲分鐘後才開放（S10-04）：倒數寫現實時間
        final openAt = info.openAt;
        final wait = openAt != null && openAt > m.gameNow ? (openAt - m.gameNow) / m.timeScale : null;
        final short = !maxed && coins < cost;
        final Widget action;
        if (maxed) {
          action = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.disabledBg,
              border: Border.all(color: AppColors.disabledLine, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r12),
            ),
            child: Text(
              s.maxed,
              key: Key('up-maxed-${kind.wire}'),
              style: AppText.style(13, weight: FontWeight.w900, color: AppColors.ink2, lineHeight: 28),
            ),
          );
        } else if (wait != null) {
          action = AppButton(
            s.opensIn(v: s.countdown(wait)),
            key: Key('up-${kind.wire}'),
            small: true,
            icon: 'clock',
          );
        } else {
          action = AppButton(
            s.costCoins(v: fmt(cost)),
            key: Key('up-${kind.wire}'),
            small: true,
            kind: ButtonKind.primary,
            icon: 'coin',
            busy: busy && canAct,
            onPressed: canAct && !short && !busy ? onUpgrade : null,
          );
        }
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 英文、泰文放不下時名稱、等級可以換行（screens.css 第 10 條、第二輪）
            Text(name, style: _upName),
            Text(lv, style: _upLv),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(effect, style: _upEff),
            ),
            if (short && wait == null) Text(s.notEnoughCoins(n: fmt((cost - coins).ceil())), style: KitText.warn()),
          ],
        );
        final pic = Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: const BorderRadius.all(AppRadii.r16),
          ),
          child: AppIcon(icon, size: 30),
        );
        return Container(
          key: Key('up-card-${kind.wire}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // 剛升級完的那一列淡綠底（S10-05）
            color: done ? const Color(0xFFF1FBEA) : AppColors.paper,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(AppRadii.r18),
            boxShadow: AppShadows.solid(4),
          ),
          child: _UpRowLayout(
            words: [name, lv, effect],
            pic: pic,
            info: details,
            action: action,
            actionWidth: _buttonWidth(context, maxed ? s.maxed : null, action),
          ),
        );
      },
    );
  }
}

final _upName = AppText.style(16, weight: FontWeight.w900, lineHeight: 21);
final _upLv = AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 17);
final _upEff = AppText.style(13, weight: FontWeight.w700, lineHeight: 19);

/// 右邊按鈕大概多寬（字、圖示 18、間隔 6、左右留白 12、框 3）；已滿級的灰色小框（字、左右留白 10、框 2）。
double _buttonWidth(BuildContext context, String? maxedText, Widget action) {
  final scaler = MediaQuery.textScalerOf(context);
  double w(String t, TextStyle st) {
    final p = TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final r = p.width;
    p.dispose();
    return r;
  }

  if (maxedText != null) return w(maxedText, AppText.style(13, weight: FontWeight.w900)) + 20 + 4;
  if (action is AppButton) {
    return w(action.label, AppText.style(14, weight: FontWeight.w900)) + 18 + 6 + 24 + 6;
  }
  return 120;
}

/// 設施的一列：圖示、說明、右邊按鈕排一排；英文、泰文窄手機放不下（最長的一個字擠不進說明欄）時，
/// 按鈕換到下一行、靠右，字才不會從單字中間斷開（「放不下才換行」）。
class _UpRowLayout extends StatelessWidget {
  const _UpRowLayout({
    required this.words,
    required this.pic,
    required this.info,
    required this.action,
    required this.actionWidth,
  });

  final List<String> words;
  final Widget pic;
  final Widget info;
  final Widget action;
  final double actionWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final scaler = MediaQuery.textScalerOf(context);
      double longest = 0;
      for (final (i, text) in words.indexed) {
        final style = switch (i) {
          0 => _upName,
          1 => _upLv,
          _ => _upEff,
        };
        for (final word in text.split(RegExp(r'\s+'))) {
          final p = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          if (p.width > longest) longest = p.width;
          p.dispose();
        }
      }
      final infoWidth = c.maxWidth - 50 - 10 - 10 - actionWidth;
      if (infoWidth >= longest) {
        return Row(
          children: [
            pic,
            const SizedBox(width: 10),
            Expanded(child: info),
            const SizedBox(width: 10),
            action,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              pic,
              const SizedBox(width: 10),
              Expanded(child: info),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      );
    },
  );
}

/// 抽到的結果（S19-05）：抽到的小牛（大圖）、名字、用途、公母、稀有度；多久長大。
class DrawnDialog extends StatelessWidget {
  const DrawnDialog({super.key, required this.grade, required this.cow});

  final String grade;
  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final id = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    final adultAt = cow.adultAt;
    final grow = adultAt == null ? null : s.countdown((adultAt - m.gameNow) / m.timeScale);
    // 設計稿只寫了耕牛的一句（長大後可以派去田裡）；其他的牛只寫長大還要多久
    final hint = grow == null
        ? null
        : cow.type == CowType.dual
        ? s.s19DrawnDraft(time: grow)
        : s.growUp(v: grow);
    return AppDialog(
      key: const Key('drawn-cow'),
      title: s.drawnTitle(g: grade),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .draw-pic：上面天空、下面草地
          Container(
            height: 154,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE4F6FF), Color(0xFFE4F6FF), Color(0xFFCDEFB4), Color(0xFFCDEFB4)],
                stops: [0, 0.62, 0.62, 1],
              ),
              border: Border.all(color: AppColors.lineSoft, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r18),
            ),
            child: CowPicture(
              breed: cow.breed,
              bull: cow.bull,
              calf: cow.stage == CowStage.calf,
              variant: id,
              width: 170,
              height: 150,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              s.cowName(cow.breed, id),
              textAlign: TextAlign.center,
              style: AppText.style(20, weight: FontWeight.w900),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: cowChips(context, cow),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(hint, textAlign: TextAlign.center, style: KitText.hint()),
            ),
        ],
      ),
      buttons: [
        AppButton(
          s.ok,
          key: const Key('drawn-ok'),
          kind: ButtonKind.primary,
          block: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
