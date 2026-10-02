// S17 田地（設計稿 s17.js；screens.css 的 .field-scene、.kv3、.field-card、.fc-*、.ox-opt）：田地場景、三格數字（田地、
// 倉庫稻米、每小時）、收成、每塊田一張卡、開新田。空田按「派耕牛」打開選耕牛的面板（S17-03；能下田的耕牛都沒了是 S17-04）。
// 稻米在田裡持續長，每塊田最多存這頭耕牛壯年 8 小時的量、長滿就停（企劃書 4.0）；畫面上的量照伺服器給的產量推算（協定 3.10）。
// 時間一律寫現實時間（遊戲時間 ÷ 倍率）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
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
import '../kit/kv.dart';
import '../kit/meter.dart';
import '../kit/press.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'field_scene.dart';

/// 「約 {time}後長滿」的時間（設計稿的 until）：還要幾分鐘，無條件進位；一小時以上寫「x 小時 y 分」（0 分也寫）。
String fullInText(Strings s, double minutes) {
  final m = math.max(1, minutes.ceil());
  return m >= 60 ? '${s.hours(h: m ~/ 60)} ${s.minutes(m: m % 60)}' : s.minutes(m: m);
}

/// 每塊田最多存耕牛壯年幾小時的量（「最多存 8 小時的量」）。協定的 economy 沒有這個數字（伺服器的 params.field_cap_h），
/// 用田的上限 ÷ 這頭牛壯年的產量（ox_rice_per_h × 稀有度倍率；伺服器的 field_cap_for 就是這樣算上限）算回來；算不出來寫 8。
int fieldCapHours(Economy? e, double? capacity, Cow? ox) {
  final per = e?.oxRicePerH, mult = e?.tierMult;
  if (capacity == null || ox == null || per == null || per <= 0 || mult == null || mult.isEmpty) return 8;
  final h = capacity / (per * mult[ox.tier.clamp(0, mult.length - 1)]);
  return h.isFinite && h > 0 ? h.round() : 8;
}

/// 選耕牛的面板裡，不能選的原因。
enum OxOff { working, listed, calf, other }

/// 選耕牛的面板（S17-03）：全部的耕牛（乳牛、肉牛不列）。能下田的在前面（產量高的先），再來在田裡的（田號小的先）、
/// 上架中的、小牛（快長大的先）。
List<(Cow, OxOff?)> oxOptions(List<Cow> cows, double now) {
  OxOff? off(Cow c) => c.canWorkAt(now)
      ? null
      : c.working
      ? OxOff.working
      : c.listed
      ? OxOff.listed
      : !c.isAdultAt(now)
      ? OxOff.calf
      : OxOff.other;
  final out = [
    for (final c in cows)
      if ((breedInfo(c.breed)?.type ?? c.type) == CowType.dual) (c, off(c)),
  ];
  int rank(OxOff? o) => o == null ? 0 : o.index + 1;
  out.sort((a, b) {
    final r = rank(a.$2).compareTo(rank(b.$2));
    if (r != 0) return r;
    final (ca, cb) = (a.$1, b.$1);
    final c = switch (a.$2) {
      null => cb.ricePerH.compareTo(ca.ricePerH),
      OxOff.working => (ca.fieldIndex ?? 0).compareTo(cb.fieldIndex ?? 0),
      OxOff.calf => (ca.adultAt ?? 0).compareTo(cb.adultAt ?? 0),
      _ => 0,
    };
    return c != 0 ? c : ca.number.compareTo(cb.number);
  });
  return out;
}

class FieldsPage extends StatefulWidget {
  const FieldsPage({super.key});

  @override
  State<FieldsPage> createState() => _FieldsPageState();
}

class _FieldsPageState extends State<FieldsPage> {
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  /// 選耕牛的面板開著的那塊田（index）；null 是沒開。
  int? _picking;

  /// 面板裡選好的耕牛；null 是照預設（第一頭能下田的）。
  String? _picked;

  /// 正在等伺服器的那顆按鈕：harvest、expand、assign、recall-<田的 index>。
  String? _busy;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 送一個動作給伺服器：按鈕先轉圈；失敗顯示原因（維護、token 失效由外層換畫面，不提示），成功做 [ok]。
  Future<void> _act(
    String busy,
    Future<ActionResult<Map<String, dynamic>>> Function(GameModel m) send,
    void Function(Strings s, GameModel m, Map<String, dynamic>? value)? ok,
  ) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    setState(() => _busy = busy);
    final r = await send(m);
    if (!mounted) return;
    setState(() => _busy = null);
    final err = r.error;
    if (err != null) {
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(ToastKind.err, actionErrorTextWith(s, m, err));
      return;
    }
    ok?.call(s, m, r.value);
  }

  void _harvest() => _act('harvest', (m) => m.fieldHarvest(), (s, m, v) {
    final got = v?['harvested'];
    _showToast(ToastKind.ok, s.harvested(kg: fmt(got is num ? got : 0)));
  });

  void _expand() => _act('expand', (m) => m.fieldExpand(), (s, m, v) {
    _showToast(ToastKind.ok, s.fieldExpanded(n: m.state?.fields.length ?? 0));
  });

  void _recall(FieldInfo f, Cow ox) => _act('recall-${f.index}', (m) => m.fieldRecall(ox), null);

  void _openPicker(int index) => setState(() {
    _picking = index;
    _picked = null;
  });

  void _closePicker() => setState(() => _picking = null);

  Future<void> _assign(int index, Cow ox) async {
    await _act('assign', (m) => m.fieldAssign(ox, field: index), null);
    if (mounted) _closePicker();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final safe = MediaQuery.paddingOf(context);
    final st = m.state!;
    // 面板開著的那塊田已經不是空田（例：別的手機派了牛）就不顯示面板
    final picking = st.fields.where((f) => f.index == _picking && f.empty).firstOrNull;
    return AppFrame(
      tab: AppTab.fields,
      contentPadding: EdgeInsets.zero,
      // 稻米一直在長：數字、進度條、場景的稻子跟著重畫
      content: TickerBuilder(builder: (context) => _list(context, m)),
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
        if (picking != null) Positioned.fill(child: _sheet(context, m, picking)),
      ],
    );
  }

  Widget _list(BuildContext context, GameModel m) {
    final s = Strings.of(context);
    final st = m.state!;
    final now = m.gameNow;
    final up = st.upgrades[UpgradeKind.field];
    final max = up?.maxLevel, cost = up?.cost;
    final count = st.fields.length;
    final oxen = oxOptions(st.cows, now);
    final noOx = !oxen.any((o) => o.$2 == null);
    var inFields = 0.0, rate = 0.0;
    final plots = <FieldPlot>[];
    for (final f in st.fields) {
      final rice = m.fieldRiceNow(f), cap = f.capacity;
      inFields += rice;
      final ox = f.cowId == null ? null : st.cowById('${f.cowId}');
      // 每小時：長滿的田不算（設計稿 S17-01 是 11.0，收成以後 S17-09 是 25.3）
      if (!f.empty && cap != null && rice < cap) rate += f.perHour;
      plots.add(FieldPlot(number: f.index + 1, cow: ox, ratio: cap == null || cap <= 0 ? 0 : rice / cap));
    }
    final canAct = m.canAct;
    Widget gap() => const SizedBox(height: 12);
    return ListView(
      key: const Key('fields'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        // .card.field-scene：沒有內距，場景填滿卡片裡面
        Container(
          key: const Key('field-scene'),
          decoration: BoxDecoration(
            color: AppColors.paper,
            border: Border.all(color: AppColors.ink, width: AppSizes.border),
            borderRadius: const BorderRadius.all(AppRadii.r18),
            boxShadow: AppShadows.solid(4),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(18 - AppSizes.border)),
            child: FieldScene(plots: plots),
          ),
        ),
        gap(),
        KvGrid(
          key: const Key('field-kv'),
          columns: 3,
          valueSize: 16,
          cells: [
            (s.fieldsTitle, '$count', max == null ? null : s.s17OfMax(max: max)),
            (s.s17Stock, fmt(st.rice.stock), s.gKg),
            (s.s17PerHour, fmt(rate, 1), s.gKg),
          ],
        ),
        gap(),
        AppButton(
          inFields > 0 ? s.harvestAll(kg: fmt(inFields)) : s.s17HarvestNone,
          key: const Key('harvest'),
          kind: ButtonKind.green,
          block: true,
          icon: 'rice',
          busy: _busy == 'harvest',
          onPressed: inFields > 0 && canAct ? _harvest : null,
        ),
        for (final f in st.fields) ...[
          gap(),
          FieldCard(
            key: Key('field-${f.index}'),
            field: f,
            rice: m.fieldRiceNow(f),
            ox: f.cowId == null ? null : st.cowById('${f.cowId}'),
            noOx: noOx,
            capHours: fieldCapHours(st.economy, f.capacity, f.cowId == null ? null : st.cowById('${f.cowId}')),
            recalling: _busy == 'recall-${f.index}',
            onAssign: canAct ? () => _openPicker(f.index) : null,
            onRecall: canAct ? (ox) => _recall(f, ox) : null,
          ),
        ],
        gap(),
        ExpandField(
          count: count,
          max: max,
          cost: cost,
          coins: st.coins,
          busy: _busy == 'expand',
          onPressed: canAct ? _expand : null,
        ),
      ],
    );
  }

  /// 選耕牛的面板（S17-03）：一頭一張卡，預選第一頭能下田的；「取消」「派去田裡」。能下田的都沒了換成 S17-04。
  Widget _sheet(BuildContext context, GameModel m, FieldInfo field) {
    final s = Strings.of(context);
    final now = m.gameNow;
    final options = oxOptions(m.state!.cows, now);
    final free = [
      for (final (c, off) in options)
        if (off == null) c,
    ];
    final picked = free.where((c) => c.key == _picked).firstOrNull ?? free.firstOrNull;
    final title = s.pickOx(n: field.index + 1);
    if (picked == null) {
      // S17-04：.empty（剪影、兩行字）加「知道了」
      return AppSheet(
        title: title,
        onClose: _closePicker,
        children: [
          Padding(
            key: const Key('ox-none'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              children: [
                const CowSilhouette(breed: 'yellow', bull: true, size: 90),
                const SizedBox(height: 10),
                Text(
                  s.noOx,
                  textAlign: TextAlign.center,
                  style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  s.s17NoOxHint,
                  textAlign: TextAlign.center,
                  style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
                ),
              ],
            ),
          ),
          AppButton(s.gGotIt, key: const Key('ox-got-it'), block: true, onPressed: _closePicker),
        ],
      );
    }
    final screen = MediaQuery.sizeOf(context).height;
    return AppSheet(
      title: title,
      onClose: _closePicker,
      children: [
        // 耕牛很多的時候清單可以捲（設計稿沒畫到；面板最高到畫面的 6 成）
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screen * 0.6),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (c, off)) in options.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  OxOption(
                    key: Key('ox-${c.key}'),
                    cow: c,
                    off: off,
                    on: c.key == picked.key,
                    onTap: off == null ? () => setState(() => _picked = c.key) : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        BtnRow(
          children: [
            AppButton(s.cancel, key: const Key('ox-cancel'), onPressed: _closePicker),
            AppButton(
              s.gAssign,
              key: const Key('ox-assign'),
              kind: ButtonKind.green,
              icon: 'sprout',
              busy: _busy == 'assign',
              onPressed: m.canAct && _busy == null ? () => _assign(field.index, picked) : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// 開新田（S17-10、S17-11）：「開新田（4,608 幣）」。已經最多塊換成停用的「田地已經 12 塊（最多）」；
/// 錢不夠停用，下面置中一行橘字寫還差多少。
class ExpandField extends StatelessWidget {
  const ExpandField({
    super.key,
    required this.count,
    required this.max,
    required this.cost,
    required this.coins,
    this.busy = false,
    this.onPressed,
  });

  final int count;
  final int? max;

  /// 再開一塊的價格；null 是已經最多塊。
  final double? cost;
  final double coins;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final cost = this.cost, max = this.max;
    if (cost == null || (max != null && count >= max)) {
      return AppButton(s.s17MaxFields(n: max ?? count), key: const Key('field-expand'), block: true);
    }
    final short = coins < cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          s.expandField(cost: fmt(cost)),
          key: const Key('field-expand'),
          block: true,
          icon: 'plus',
          busy: busy,
          onPressed: short ? null : onPressed,
        ),
        if (short) ...[
          const SizedBox(height: 12),
          Text(
            s.notEnoughCoins(n: fmt(cost - coins)),
            key: const Key('field-expand-coins'),
            textAlign: TextAlign.center,
            style: KitText.warn(),
          ),
        ],
      ],
    );
  }
}

/// .card.field-card：一塊田。有牛（S17-05）：田號、工作中／長滿了、耕牛的小圖和名字、「叫回」、進度條和公斤數、多久長滿。
/// 長滿了（S17-06）底色變淡黃、進度條變黃、寫「快收成」；剩的稻米比上限多（S17-12）進度條滿格、只寫公斤數。
/// 空田（S17-02、S17-07）：置中的田號加「空田」、一行說明（叫回後還有稻米就寫多少）、「派耕牛」。
class FieldCard extends StatelessWidget {
  const FieldCard({
    super.key,
    required this.field,
    required this.rice,
    required this.ox,
    required this.noOx,
    required this.capHours,
    this.recalling = false,
    this.onAssign,
    this.onRecall,
  });

  final FieldInfo field;

  /// 田裡現在大概有多少稻米（推算）。
  final double rice;
  final Cow? ox;

  /// 沒有能下田的耕牛：空田的「派耕牛」停用，加一行橘字（S17-02）。
  final bool noOx;
  final int capHours;
  final bool recalling;
  final VoidCallback? onAssign;
  final void Function(Cow ox)? onRecall;

  static const _fullBg = Color(0xFFFFF6DC);
  static const _emptyBg = Color(0xFFFBF4EA);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final number = CssLine(
      TextSpan(
        text: s.fieldName(n: field.index + 1),
        style: AppText.style(16, weight: FontWeight.w900),
      ),
    );
    final cap = field.capacity;
    if (field.empty || cap == null) {
      final hint = KitText.hint();
      return AppCard(
        color: _emptyBg,
        child: Column(
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [number, CowBadge(BadgeKind.lock, s.fieldEmpty)]),
            const SizedBox(height: 8),
            // 叫回後田裡還有稻米（S17-07）：寫多少，收成時一起收
            CssLine(
              TextSpan(
                style: hint,
                children: rice > 0
                    ? fillSpans(
                        s.s17Leftover(kg: '\u0000'),
                        AppText.number(13, color: AppColors.ink2, lineHeight: 19),
                        fmt(rice, 1),
                      )
                    : [TextSpan(text: s.s17EmptyHint)],
              ),
              wrap: true,
              textAlign: TextAlign.center,
            ),
            if (noOx) ...[
              const SizedBox(height: 8),
              Text.rich(
                key: const Key('field-no-ox'),
                TextSpan(
                  style: KitText.warn(),
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: AppIcon('warn', size: 16),
                    ),
                    TextSpan(text: ' ${s.noOx}'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            AppButton(
              s.assignOx,
              key: Key('field-assign-${field.index}'),
              kind: ButtonKind.green,
              small: true,
              block: true,
              icon: 'sprout',
              onPressed: noOx ? null : onAssign,
            ),
          ],
        ),
      );
    }
    final cow = ox;
    final full = rice >= cap;
    // 剩的比上限多（叫回稀有耕牛後改派一般耕牛）：照長滿了顯示，數字只寫公斤數（S17-12）
    final over = rice > cap;
    final rate = field.perHour;
    final left = rate > 0 ? (cap - rice) / rate * 60 / m.timeScale : 0.0;
    final bar = full ? MeterBar.yellow(fraction: 1) : MeterBar.green(fraction: cap > 0 ? rice / cap : 0);
    return AppCard(
      color: full ? _fullBg : AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: number),
              ),
              if (full) CowBadge(BadgeKind.full, s.s17Full) else CowBadge(BadgeKind.working, s.badgeWorking),
            ],
          ),
          const SizedBox(height: 8),
          // .fc-ox：小圖（框畫在 52 的 svg 上，裡面的牛照 48 排）、名字和稀有度、每小時、「叫回」
          Row(
            children: [
              CowPicBox(
                size: 52,
                radius: 12,
                child: cow == null
                    ? const SizedBox.shrink()
                    : CowPicture(
                        breed: cow.breed,
                        bull: cow.bull,
                        variant: cow.number,
                        width: 48,
                        height: 48,
                        pad: 2 * 48 / 52,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cow != null)
                      Text(
                        s.cowName(cow.breed, cow.number),
                        strutStyle: kDivStrut,
                        style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20),
                      ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 標籤不換行：比這一欄寬（320 寬的英文，叫回鈕比較寬）就往右超出去，跟 CSS 一樣不擠壞
                        if (cow != null)
                          OverflowBox(
                            maxWidth: double.infinity,
                            alignment: Alignment.centerLeft,
                            fit: OverflowBoxFit.deferToChild,
                            child: TierChip(breedInfo(cow.breed)?.tier ?? cow.tier),
                          ),
                        Text(s.fieldRate(v: rateText(rate)), style: KitText.hint()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                s.recall,
                key: Key('field-recall-${field.index}'),
                small: true,
                leading: const _HandInRing(),
                busy: recalling,
                onPressed: cow == null || onRecall == null ? null : () => onRecall!(cow),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // .fc-bar：進度條、「62.5 / 88.0」、「公斤」
          Row(
            children: [
              Expanded(child: bar),
              const SizedBox(width: 6),
              CssLine(
                TextSpan(text: over ? fmt(rice, 1) : '${fmt(rice, 1)} / ${fmt(cap, 1)}', style: AppText.number(15)),
                textKey: Key('field-rice-${field.index}'),
              ),
              const SizedBox(width: 6),
              CssLine(
                TextSpan(
                  text: s.gKg,
                  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CssLine(
            TextSpan(
              text: full ? s.fieldFull : s.s17FullIn(time: fullInText(s, left), h: capHours),
              style: full ? KitText.warn() : KitText.hint(),
            ),
            wrap: true,
          ),
        ],
      ),
    );
  }
}

/// 「叫回」的手掌：設計稿的 .fc-ox svg（耕牛小圖的淡綠底、2px 框、圓角 12）也套到了按鈕裡 18px 的圖示，所以核准的
/// 圖上手掌外面有一圈淡綠底的圓框，手掌畫在裡面 14px（box-sizing: border-box）。
class _HandInRing extends StatelessWidget {
  const _HandInRing();

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFE4F4DA),
      border: Border.all(color: AppColors.ink, width: 2),
    ),
    child: const AppIcon('hand', size: 14),
  );
}

/// .card.ox-opt：面板裡的一頭耕牛。能選的：稀有度、每小時；選好的淡綠底、綠框、右邊打勾。
/// 不能選的：灰底、牛和名字半透明，寫原因（在第幾塊田、上架中、小牛幾小時後長大）。
class OxOption extends StatelessWidget {
  const OxOption({super.key, required this.cow, required this.off, required this.on, this.onTap});

  final Cow cow;
  final OxOff? off;
  final bool on;
  final VoidCallback? onTap;

  static const _onBg = Color(0xFFEFFAE6);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final disabled = off != null;
    final line = disabled ? AppColors.disabledLine : AppColors.ink;
    Widget faded(Widget child) => disabled ? Opacity(opacity: 0.5, child: child) : child;
    final hint = KitText.hint();
    final chips = switch (off) {
      null || OxOff.other => [
        TierChip(breedInfo(cow.breed)?.tier ?? cow.tier),
        if (off == null) Text(s.fieldRate(v: rateText(cow.ricePerH)), style: hint),
      ],
      OxOff.working => [CowBadge(BadgeKind.working, s.s17InField(n: (cow.fieldIndex ?? 0) + 1))],
      OxOff.listed => [CowBadge(BadgeKind.listed, s.badgeListed)],
      OxOff.calf => [
        CowBadge(BadgeKind.calf, s.stageCalf),
        if (cow.adultAt case final at?)
          Text(s.gGrowsIn(time: s.countdown(math.max(0, at - m.gameNow) / m.timeScale)), style: hint),
      ],
    };
    return Semantics(
      button: true,
      selected: on,
      enabled: !disabled,
      child: Pressable(
        lift: 4,
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
            decoration: BoxDecoration(
              color: disabled ? AppColors.disabledBg : (on ? _onBg : AppColors.paper),
              border: Border.all(color: line, width: AppSizes.border),
              borderRadius: const BorderRadius.all(AppRadii.r18),
              boxShadow: [
                // 選好的：綠色的外框（0 0 0 3px green-2）在實心下陰影的下面
                if (on) const BoxShadow(color: AppColors.green2, spreadRadius: 3),
                BoxShadow(color: line, offset: Offset(0, disabled ? 4 : look.shadow)),
              ],
            ),
            child: Row(
              children: [
                faded(
                  CowPicture(
                    breed: cow.breed,
                    bull: cow.bull,
                    calf: cow.stage == CowStage.calf,
                    variant: cow.number,
                    width: 56,
                    height: 56,
                    pad: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      faded(
                        Text(
                          s.cowName(cow.breed, cow.number),
                          strutStyle: kDivStrut,
                          style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20),
                        ),
                      ),
                      Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
                    ],
                  ),
                ),
                if (on) ...[const SizedBox(width: 8), const AppIcon('ok', size: 24)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
