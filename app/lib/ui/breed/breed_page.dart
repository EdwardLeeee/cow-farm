// S08 配種（設計稿 s08.js 的 breedPage、pickCard、outcomeCard、calfCard；screens.css 的 .rule-line、.pick-row、.pick、
// .pick-empty、.outcome-card、.oc-row、.oc-foot、.calf-card）。上面切換「自己配種」和「借種」（S18，stud_tab.dart）。
// 能不能配看伺服器的 can_breed 和預覽的 blockers；可能生出的小牛和機率是伺服器給的（distribution[]），手機不算。
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
import '../kit/meter.dart';
import '../kit/note_line.dart';
import '../kit/press.dart';
import '../kit/seg.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';
import 'stud_log_page.dart';
import 'stud_tab.dart';

/// 配種頁：自己配種（S08）；「借種」那一邊（S18）是 [StudTab]、借種紀錄是 [StudLogPage]。
class BreedPage extends StatefulWidget {
  const BreedPage({super.key});

  /// 機率載入失敗後，隔多久自動再試（S08-05）。
  static const retryAfter = Duration(seconds: 3);

  @override
  State<BreedPage> createState() => _BreedPageState();
}

class _BreedPageState extends State<BreedPage> {
  late final _fetch = PreviewFetcher(isMounted: () => mounted, setState: setState);

  /// 剛配好的那一對（S08-09）：照樣顯示成選好的、留著剛剛的機率，按鈕換成「已配種」，下面放新小牛。換選別的牛才清掉；
  /// 離開這一頁也就沒了（新小牛在牛舍清單看得到）。
  ({String sire, String dam, BreedPreview preview, Cow? calf})? _done;
  bool _breeding = false;

  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;
  final _scroll = ScrollController();
  final _calfKey = GlobalKey();

  @override
  void dispose() {
    _fetch.dispose();
    _toastTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 點選牛的卡片：選了就換成這頭，再點一次取消。剛配好的那一對就不再顯示成選好的。
  void _pick(GameModel m, Cow cow, {required bool on}) {
    setState(() => _done = null);
    final key = on ? null : cow.key;
    if (cow.bull) {
      m.setBreedSire(key);
    } else {
      m.setBreedDam(key);
    }
  }

  Future<void> _breed(Cow sire, Cow dam, BreedPreview p) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    setState(() => _breeding = true);
    final r = await m.breed(sire, dam);
    if (!mounted) return;
    final err = r.error;
    if (err != null) {
      // 伺服器說不能配（例：別的手機剛配過）：重抓機率，下面的提醒照最新的原因
      setState(() {
        _breeding = false;
        _fetch.invalidate();
      });
      if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
      _showToast(ToastKind.err, actionErrorTextWith(s, m, err));
      return;
    }
    final calf = r.value?.calf;
    setState(() {
      _breeding = false;
      _done = (sire: sire.key, dam: dam.key, preview: p, calf: calf);
    });
    if (calf != null) _showToast(ToastKind.ok, s.breedDone(cow: s.cowName(calf.breed, calf.number)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCalf());
  }

  /// 配好以後捲到新小牛的卡片：卡片的下緣在內容區下緣往上 18（設計稿 S08-09 的 scrollTo）。
  void _revealCalf() {
    final box = _calfKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !_scroll.hasClients) return;
    final p = _scroll.position;
    final target = (RenderAbstractViewport.of(box).getOffsetToReveal(box, 1).offset + 18).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      p.jumpTo(target);
    } else {
      p.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final seg = SegControl(
      labels: [s.subOwnBreed, s.subStud],
      selected: m.breedStud ? 1 : 0,
      onSelect: (i) => m.selectBreed(stud: i == 1),
    );
    // 借種（S18）：市場、我的公牛；按「借種紀錄」開紀錄頁（S18-11）
    if (m.breedStud) return m.studLogOpen ? const StudLogPage() : StudTab(seg: seg);

    final st = m.state!;
    final now = m.gameNow;
    final done = _done;
    Cow? byKey(String? key) => key == null ? null : st.cowById(key);
    var sire = byKey(done?.sire ?? m.breedSireKey);
    var dam = byKey(done?.dam ?? m.breedDamKey);
    // 選過、後來不能配了（配過種、下田、上架）的就當作沒選
    if (done == null && sire != null && !sire.canBreedAt(now)) sire = null;
    if (done == null && dam != null && !dam.canBreedAt(now)) dam = null;
    _fetch.ensure(
      m,
      sire == null || dam == null ? null : '${sire.key}|${dam.key}',
      () => m.breedPreview(sire!, dam!),
      hold: done != null,
    );

    final preview = done?.preview ?? _fetch.value;
    final outcome = _fetch.state(m, picked: sire != null && dam != null, shown: preview);
    // 剛配好（已配種）不放提醒：新小牛可能剛好把牛舍佔滿，成功下面跳「牛舍滿了」像是失敗（設計稿 S08-09 沒有；
    // ceo 2026-10-02）。換選別的、清掉剛配好的那一對以後照常提醒
    final notes = done != null
        ? const <String>[]
        : breedNotes(s, m, preview: outcome == OutcomeState.ok ? preview : null, pair: [?sire, ?dam]);
    final canBreed =
        done == null && outcome == OutcomeState.ok && preview!.canBreed && notes.isEmpty && m.canAct && !_breeding;
    final calf = done == null ? null : (byKey(done.calf?.key) ?? done.calf);
    final picked = {?done?.sire, ?done?.dam};

    Widget pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: child);
    Widget row(String prefix, bool bulls, Cow? selected, String title, String hint) {
      final herd = [
        for (final c in st.cows)
          if (c.bull == bulls) c,
      ];
      // 沒有成年的公牛（或母牛）才放空的框（S08-02）；有成年的就全部列出來，不能配的變灰加原因（S08-03）
      final empty = !herd.any((c) => c.isAdultAt(now));
      return PickSection(
        title: bulls ? s.pickSire : s.pickDam,
        child: empty
            ? PickEmpty(key: Key(bulls ? 'no-sire' : 'no-dam'), title: title, hint: hint)
            : PickRow(
                key: Key('$prefix-row'),
                children: [
                  for (final (c, off) in pickOrder(herd, now, keep: picked))
                    PickCard(
                      key: Key('$prefix-${c.key}'),
                      cow: c,
                      on: c.key == selected?.key,
                      off: off,
                      onTap: () => _pick(m, c, on: c.key == selected?.key),
                    ),
                ],
              ),
      );
    }

    final safe = MediaQuery.paddingOf(context);
    return AppFrame(
      tab: AppTab.breed,
      contentPadding: EdgeInsets.zero,
      content: ListView(
        key: const Key('breed'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        children: [
          pad(seg),
          const SizedBox(height: 12),
          pad(NoteLine(key: const Key('breed-rule'), icon: 'heart', text: s.s08Rule, kind: NoteKind.rule)),
          const SizedBox(height: 12),
          row('sire', true, sire, s.noSire, s.s08NoSireHint),
          const SizedBox(height: 12),
          row('dam', false, dam, s.noDam, s.s08NoDamHint),
          const SizedBox(height: 12),
          pad(OutcomeCard(state: outcome, preview: preview)),
          for (final (i, n) in notes.indexed) ...[
            const SizedBox(height: 12),
            pad(NoteLine(key: Key('breed-note-$i'), icon: 'warn', text: n, kind: NoteKind.warn)),
          ],
          const SizedBox(height: 12),
          pad(
            AppButton(
              done == null ? s.s08BreedBtnFree : s.s08BredBtn,
              key: const Key('breed-go'),
              kind: ButtonKind.pink,
              block: true,
              icon: 'heart',
              busy: _breeding,
              onPressed: canBreed ? () => _breed(sire!, dam!, preview) : null,
            ),
          ),
          if (calf != null) ...[const SizedBox(height: 12), pad(CalfCard(key: _calfKey, calf: calf))],
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
}

/// 機率預覽（S08 配種、S18 借種共用）：選好的那一對（[key]）換了就重抓；失敗了 [BreedPage.retryAfter] 後自動再試；
/// 斷線時不抓，連回來（模型通知、重畫）再抓。在 build 裡呼叫 [ensure]。
class PreviewFetcher {
  PreviewFetcher({required this.isMounted, required this.setState});

  final bool Function() isMounted;
  final void Function(VoidCallback) setState;

  String? key;
  BreedPreview? value;
  bool failed = false;
  bool _loading = false;
  Timer? _retry;

  void dispose() => _retry?.cancel();

  /// 下一次 [ensure] 重抓（例：配種、借種失敗後看最新的原因）。
  void invalidate() => key = null;

  /// [newKey] 是 null 代表還沒選好；[hold] 時不抓（例：剛配好，留著剛剛的機率）。
  void ensure(GameModel m, String? newKey, Future<BreedPreview?> Function() fetch, {bool hold = false}) {
    if (newKey != key) {
      key = newKey;
      value = null;
      failed = false;
      _loading = false;
      _retry?.cancel();
    }
    if (newKey == null || hold || value != null || _loading || failed || !m.online) return;
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isMounted() || key != newKey) return;
      final p = await fetch();
      if (!isMounted() || key != newKey) return;
      setState(() {
        _loading = false;
        value = p;
        failed = p == null;
      });
      if (p == null) {
        _retry?.cancel();
        _retry = Timer(BreedPage.retryAfter, () {
          if (isMounted() && key == newKey) setState(() => failed = false);
        });
      }
    });
  }

  /// 機率卡的狀態。[picked] 是兩邊都選好了；[shown] 是要顯示的機率（剛配好時是留著的那一份）。
  OutcomeState state(GameModel m, {required bool picked, BreedPreview? shown}) => !picked
      ? OutcomeState.none
      : (shown ?? value) != null
      ? OutcomeState.ok
      : !m.online
      ? OutcomeState.offline
      : failed
      ? OutcomeState.failed
      : OutcomeState.quoting;
}

/// 機率卡下面的橘字提醒（S08-07、S08-08）：伺服器的 blockers 一個一行，照協定的順序（設計稿缺口清單 3-1）；
/// 牛舍滿了另外看 state（還沒選好也提醒），跟 blockers 的 pen_full 只放一次。[pair] 是選好的公牛、母牛。
List<String> breedNotes(Strings s, GameModel m, {required BreedPreview? preview, required List<Cow> pair}) {
  final st = m.state!;
  final out = <String>[];
  var penFull = false;
  for (final b in preview?.blockers ?? const <Blocker>[]) {
    switch (b.code) {
      case 'pen_full':
        if (penFull) continue;
        penFull = true;
        out.add(s.s08PenFull);
      case 'already_bred':
        // {cow} 是 cow_id 那頭牛（公牛、母牛都可能）；找不到就用選好的那對裡配過種的
        final id = b.detail['cow_id'];
        final cow =
            (id == null ? null : st.cowById('$id')) ?? pair.where((c) => c.bred).firstOrNull ?? pair.firstOrNull;
        out.add(s.s08AlreadyBred(cow: cow == null ? '' : s.cowName(cow.breed, cow.number)));
      default:
        out.add(s.blockerText(b, gameNow: m.gameNow, timeScale: m.timeScale));
    }
  }
  if (st.pen.full && !penFull) out.add(s.s08PenFull);
  return out;
}

/// 不能配的原因（選牛卡的標籤）；排序也照這個順序（設計稿 s08.js 的 BULLS、DAMS：上架中、已配種、工作中、小牛）。
enum PickOff {
  listed,
  bred,
  working,
  calf,

  /// 伺服器說不能配、原因不在上面（沒有標籤，只變灰）。
  other,
}

/// 一頭牛為什麼不能選；能選是 null。配過種又在田裡的寫「已配種」（叫回來也不能配）。
PickOff? pickOff(Cow c, double now) {
  if (c.canBreedAt(now)) return null;
  if (!c.isAdultAt(now)) return PickOff.calf;
  if (c.bred) return PickOff.bred;
  if (c.listed) return PickOff.listed;
  if (c.working) return PickOff.working;
  return PickOff.other;
}

/// 選牛列的順序：能選的在前（照 state 的順序），不能選的照 [PickOff] 排在後面。[keep] 是剛配好的那一對，照樣當作能選的。
List<(Cow, PickOff?)> pickOrder(List<Cow> herd, double now, {Set<String> keep = const {}}) {
  final rows = [for (final c in herd) (c, keep.contains(c.key) ? null : pickOff(c, now))];
  return [
    for (final r in rows)
      if (r.$2 == null) r,
    for (final o in PickOff.values)
      for (final r in rows)
        if (r.$2 == o) r,
  ];
}

/// section：小標題（.sec-title，16 特粗、行高 22，左右縮 2）加下面的東西（往下 6）。整頁時左右不留邊（選牛列貼齊螢幕），
/// 小標題、空的框自己留內容區的 [side]（12）；放在已經留了邊的地方（局部狀態表）給 0。
class PickSection extends StatelessWidget {
  const PickSection({super.key, required this.title, required this.child, this.side = 12});

  final String title;
  final Widget child;
  final double side;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: side + 2),
        child: Text(title, style: AppText.style(16, weight: FontWeight.w900, lineHeight: 22)),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// .pick-row：選牛卡排一行，可以左右滑；左右貼齊螢幕（內距 12），上 2、下 6，超出的裁掉（勾勾會被裁掉上面一點，設計稿也是）。
/// 每張卡一樣高（flex 的 stretch：名字換兩行的卡片撐高，其他的跟著高）。
class PickRow extends StatelessWidget {
  const PickRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 8), c],
        ],
      ),
    ),
  );
}

/// .pick：選牛卡（寬 100、至少高 136）：正面小圖 84×76、名字、稀有度。選中（.on）淡黃底、外圈黃色、右上角勾勾；
/// 不能選（.off）灰底灰框，圖和名字變淡，下面換成原因的標籤。浮起的元件，按下往下 2（G-13）。
class PickCard extends StatelessWidget {
  const PickCard({super.key, required this.cow, required this.on, this.off, required this.onTap});

  final Cow cow;
  final bool on;
  final PickOff? off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final disabled = off != null;
    final line = disabled ? AppColors.disabledLine : AppColors.ink;
    final calf = cow.stage == CowStage.calf;
    final meta = switch (off) {
      null || PickOff.other => TierChip(breedInfo(cow.breed)?.tier ?? cow.tier),
      PickOff.listed => CowBadge(BadgeKind.listed, s.badgeListed),
      PickOff.bred => CowBadge(BadgeKind.bred, s.badgeBred),
      PickOff.working => CowBadge(BadgeKind.working, s.badgeWorking),
      PickOff.calf => CowBadge(BadgeKind.calf, s.stageCalf),
    };
    Widget faded(Widget child) => disabled ? Opacity(opacity: 0.45, child: child) : child;
    return Semantics(
      container: true,
      button: true,
      selected: on,
      enabled: !disabled,
      child: Pressable(
        lift: 3,
        onTap: disabled ? null : onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                constraints: const BoxConstraints(minHeight: 136),
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                decoration: BoxDecoration(
                  color: disabled
                      ? AppColors.disabledBg
                      : on
                      ? const Color(0xFFFFF1B8)
                      : Colors.white,
                  border: Border.all(color: line, width: AppSizes.border),
                  borderRadius: const BorderRadius.all(AppRadii.r16),
                  // 選中：外圈黃色（spread 3）在下面，可可色的下陰影蓋在上面
                  boxShadow: [
                    if (on) const BoxShadow(color: AppColors.yellow, spreadRadius: 3),
                    BoxShadow(color: line, offset: Offset(0, look.shadow)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    faded(
                      CowPicture(
                        breed: cow.breed,
                        bull: cow.bull,
                        calf: calf,
                        variant: cow.number,
                        width: 84,
                        height: 76,
                        pad: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 名字放不下（英文、泰文）可以換兩行，卡片跟著變高（screens.css 第 2 條）
                    faded(
                      Text(
                        s.cowName(cow.breed, cow.number),
                        textAlign: TextAlign.center,
                        style: AppText.style(13, weight: FontWeight.w900, lineHeight: 18),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 標籤不換行；比卡片裡面寬（英文的稀有度）就左右一樣多超出去（flex 的 align-items: center）
                    OverflowBox(maxWidth: double.infinity, fit: OverflowBoxFit.deferToChild, child: meta),
                  ],
                ),
              ),
              if (on) const Positioned(right: -6, top: -6, child: AppIcon('ok', size: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

/// .pick-empty：沒有成年的公牛（或母牛）時的虛線框：粗體一句加一行說明（S08-02）。
class PickEmpty extends StatelessWidget {
  const PickEmpty({super.key, required this.title, required this.hint, this.side = 12});

  final String title;
  final String hint;

  /// 左右留的邊（見 [PickSection.side]）。
  final double side;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: side),
    child: CustomPaint(
      foregroundPainter: const DashedBorder(color: AppColors.lineSoft, radius: 14),
      child: Container(
        padding: const EdgeInsets.all(2 + 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(AppRadii.r14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // <b> 是 bolder：一般字的 400 → 700；行高 normal（Noto Sans CJK 的 15px 是 17 + 4）
            Text(title, style: AppText.style(15, weight: FontWeight.w700, lineHeight: 21)),
            const SizedBox(height: 2),
            Text(hint, style: KitText.hint()),
          ],
        ),
      ),
    ),
  );
}

/// 2px 的虛線圓角框（CSS 的 border: 2px dashed）：每段 6、間隔約 6，照周長平均分配。
class DashedBorder extends CustomPainter {
  const DashedBorder({required this.color, required this.radius, this.width = 2});

  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(width / 2), Radius.circular(radius - width / 2));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * 3;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      final n = math.max(1, (metric.length / (dash * 2)).round());
      final step = metric.length / n;
      for (var i = 0; i < n; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder old) => old.color != color || old.radius != radius || old.width != width;
}

/// 機率卡的狀態：還沒選好、計算中（S08-04）、失敗（S08-05）、斷線（S08-11）、有結果（S08-06）。
enum OutcomeState { none, quoting, failed, offline, ok }

/// .outcome-card：「可能生出的小牛」。有結果時一個品種一列（還沒發現的畫剪影、寫「？？？」加「沒發現過」），
/// 下面左邊公牛機率、右邊小牛長大要多久。[fee] 是右上角的費用（自己配種免費；借種是借種費）。
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key = const Key('outcome'), required this.state, this.preview, this.fee, this.noneText});

  final OutcomeState state;
  final BreedPreview? preview;
  final String? fee;
  final String? noneText;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final empty = AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2);
    Widget center(List<Widget> children) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
    );
    final body = switch (state) {
      OutcomeState.none => center([
        const AppIcon('heart', size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Text(noneText ?? s.pickBoth, textAlign: TextAlign.center, style: empty),
        ),
      ]),
      OutcomeState.quoting => center([
        const Spinner(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(s.s08Calculating, textAlign: TextAlign.center, style: empty),
        ),
      ]),
      // .err-text 是一行字：圖示放在字的基線上，後面一個空白
      OutcomeState.failed => center([
        Flexible(
          child: Text.rich(
            TextSpan(
              style: KitText.err(),
              children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: AppIcon('err', size: 20),
                ),
                TextSpan(text: ' ${s.s08ProbFailedRetry(n: BreedPage.retryAfter.inSeconds)}'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
      OutcomeState.offline => center([
        const AppIcon('offline', size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(s.connecting, textAlign: TextAlign.center, style: empty),
        ),
      ]),
      OutcomeState.ok => _OutcomeRows(preview: preview!),
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CardTitle(s.s08OutcomeTitle, color: AppColors.pink, icon: 'heart', iconSize: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fee ?? s.breedFree,
                  key: const Key('outcome-fee'),
                  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                ),
              ),
            ],
          ),
          body,
        ],
      ),
    );
  }
}

/// 機率：不到 10% 寫兩位小數，其他一位，去掉後面的 0（s08.js：toFixed 再去尾 0）。
String outcomePct(double p) => '${(p * 100).toStringAsFixed(p < 0.1 ? 2 : 1).replaceFirst(RegExp(r'\.?0+$'), '')}%';

/// 「小牛長大 1–4 小時」的「1–4 小時」：可能生出的稀有度裡最短到最長（economy.calf_grow_h）。一樣長只寫一個（缺口清單 3-3）。
/// 時鐘倍率不是 1（試玩伺服器）就換成現實時間的倒數寫法。沒有資料回 null（不寫這一句）。
String? growRangeText(Strings s, BreedPreview p, List<double> growH, double timeScale) {
  final hs = [
    for (var t = 0; t < p.tierProbs.length && t < growH.length; t++)
      if (p.tierProbs[t] > 0) growH[t],
  ];
  if (hs.isEmpty) return null;
  final a = hs.reduce(math.min), b = hs.reduce(math.max);
  if (timeScale != 1 && timeScale > 0) {
    final ra = s.countdown(a * 3600 / timeScale), rb = s.countdown(b * 3600 / timeScale);
    return a == b ? ra : '$ra–$rb';
  }
  String h(double v) => fmt(v, v == v.roundToDouble() ? 0 : 1);
  return a == b ? s.hours(h: h(a)) : s.s08HoursRange(a: h(a), b: h(b));
}

class _OutcomeRows extends StatelessWidget {
  const _OutcomeRows({required this.preview});

  final BreedPreview preview;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.watch<GameModel>();
    final st = m.state;
    final found = st?.codex ?? const <String, double>{};
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final foot = AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2);
    final bold = AppText.number(14);
    final grow = growRangeText(s, preview, st?.economy?.calfGrowH ?? const [], m.timeScale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, r) in preview.byBreed.indexed) ...[
          SizedBox(height: i == 0 ? 8 : 6),
          _OutcomeRow(
            key: Key('oc-${r.breed}'),
            breed: r.breed,
            tier: r.tier,
            p: r.p,
            found: found.containsKey(r.breed),
            narrow: narrow,
          ),
        ],
        const SizedBox(height: 8),
        // .oc-foot：左右兩句，放不下就換到下一行
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (preview.bullProb case final b?)
              CssLine(
                TextSpan(
                  style: foot,
                  children: fillSpans(s.bullProbLine(v: '\u0000'), bold, pct(b)),
                ),
                wrap: true,
              ),
            if (grow != null)
              CssLine(
                TextSpan(
                  style: foot,
                  children: fillSpans(s.s08GrowRange(v: '\u0000'), bold, grow),
                ),
                wrap: true,
              ),
          ],
        ),
      ],
    );
  }
}

/// .oc-row：小牛的小圖（44，還沒發現的是剪影加「？」）、品種名（或「？？？」）、稀有度、「沒發現過」、機率（靠右）。
class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    super.key,
    required this.breed,
    required this.tier,
    required this.p,
    required this.found,
    required this.narrow,
  });

  final String breed;
  final int tier;
  final double p;
  final bool found;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.fromLTRB(4, 2, narrow ? 8 : 10, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r12),
      ),
      child: OutcomeRowLayout(
        gap: narrow ? 4 : 6,
        wrap: narrow,
        children: [
          if (found)
            CowPicture(breed: breed, calf: true, variant: 90 + tier, width: 44, height: 44, pad: 2)
          else
            CowSilhouette(breed: breed, calf: true, size: 44, pad: 2),
          Text(
            found ? s.breedName(breed) : s.gUnknownBreed,
            style: AppText.style(15, weight: FontWeight.w900, lineHeight: 21),
          ),
          TierChip(tier),
          if (!found) CowBadge(BadgeKind.newBreed, s.s08NotFound),
          Text(outcomePct(p), style: AppText.number(16, lineHeight: 24)),
        ],
      ),
    );
  }
}

/// .oc-row 的排法（flex，align-items: center）：第一個是圖、第二個是名字、最後一個是機率（margin-left: auto，靠右），
/// 中間的標籤不縮。名字可以縮（min-width: 0），縮了就換行。[wrap]（窄手機，screens.css 的 max-width: 339px）時照
/// flex-wrap 排：照順序放，放不下的換到下一行（名字整個留在第一行）；每一行裡的東西上下置中，機率一樣靠右。
class OutcomeRowLayout extends MultiChildRenderObjectWidget {
  const OutcomeRowLayout({super.key, required super.children, required this.gap, required this.wrap});

  final double gap;
  final bool wrap;

  @override
  RenderOutcomeRow createRenderObject(BuildContext context) => RenderOutcomeRow(gap, wrap);

  @override
  void updateRenderObject(BuildContext context, RenderOutcomeRow renderObject) {
    renderObject
      ..gap = gap
      ..wrap = wrap;
  }
}

class OutcomeRowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderOutcomeRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, OutcomeRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, OutcomeRowParentData> {
  RenderOutcomeRow(this._gap, this._wrap);

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  bool _wrap;
  bool get wrap => _wrap;
  set wrap(bool v) {
    if (v == _wrap) return;
    _wrap = v;
    markNeedsLayout();
  }

  /// 排好以後第幾個東西在第幾行（測試看窄手機有沒有換行）。
  List<int> lineOf = const [];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! OutcomeRowParentData) child.parentData = OutcomeRowParentData();
  }

  /// 照 CSS 排：回傳整列的大小；不是 [dry] 時真的排（給每個東西大小、位置）。
  Size _arrange(BoxConstraints c, {required bool dry}) {
    final kids = getChildrenAsList();
    if (kids.isEmpty) return c.smallest;
    final maxW = c.maxWidth;
    // 每個東西不縮、不換行時的寬（CSS 的 max-content）
    final want = [for (final k in kids) k.getMaxIntrinsicWidth(double.infinity)];
    const name = 1;
    final last = kids.length - 1;
    final lines = <List<int>>[];
    if (!wrap) {
      lines.add([for (var i = 0; i < kids.length; i++) i]);
    } else {
      var line = <int>[];
      var used = 0.0;
      for (var i = 0; i < kids.length; i++) {
        final add = (line.isEmpty ? 0 : gap) + want[i];
        if (line.isNotEmpty && used + add > maxW + 0.01) {
          lines.add(line);
          line = [i];
          used = want[i];
        } else {
          line.add(i);
          used += add;
        }
      }
      lines.add(line);
    }
    final sizes = List<Size>.filled(kids.length, Size.zero);
    final offsets = List<Offset>.filled(kids.length, Offset.zero);
    final lineIndex = List<int>.filled(kids.length, 0);
    var y = 0.0;
    for (final (li, line) in lines.indexed) {
      final fixed = [
        for (final i in line)
          if (i != name) want[i],
      ].fold(0.0, (a, b) => a + b);
      final gaps = gap * (line.length - 1);
      for (final i in line) {
        final BoxConstraints cc;
        if (i == name) {
          // 名字照它要的寬，放不下就縮（min-width: 0），字跟著換行
          final w = math.min(want[i], math.max(0.0, maxW - fixed - gaps));
          cc = BoxConstraints(maxWidth: w < want[i] ? w : w + 0.01);
        } else {
          cc = BoxConstraints(maxWidth: maxW);
        }
        sizes[i] = dry ? kids[i].getDryLayout(cc) : (kids[i]..layout(cc, parentUsesSize: true)).size;
        lineIndex[i] = li;
      }
      final h = line.map((i) => sizes[i].height).fold(0.0, math.max);
      var x = 0.0;
      for (final i in line) {
        if (i == last && line.length > 1) x = math.max(x, maxW - sizes[i].width); // margin-left: auto
        if (i == last && line.length == 1) x = maxW - sizes[i].width;
        offsets[i] = Offset(x, y + (h - sizes[i].height) / 2);
        x += sizes[i].width + gap;
      }
      y += h;
    }
    if (!dry) {
      for (final (i, k) in kids.indexed) {
        (k.parentData! as OutcomeRowParentData).offset = offsets[i];
      }
      lineOf = lineIndex;
    }
    return c.constrain(Size(maxW, y));
  }

  @override
  void performLayout() => size = _arrange(constraints, dry: false);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _arrange(constraints, dry: true);

  @override
  double computeMinIntrinsicWidth(double height) {
    var w = 0.0;
    var child = firstChild;
    while (child != null) {
      w = math.max(w, child.getMinIntrinsicWidth(height));
      child = childAfter(child);
    }
    return w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var w = 0.0;
    var n = 0;
    var child = firstChild;
    while (child != null) {
      w += child.getMaxIntrinsicWidth(height);
      n++;
      child = childAfter(child);
    }
    return w + gap * math.max(0, n - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

/// .calf-card：新小牛（S08-09）：正面小圖（84，米色底）、「新小牛 品種 #編號」、稀有度和「小牛」、長大還要多久、黃色進度條。
class CalfCard extends StatelessWidget {
  const CalfCard({super.key, required this.calf});

  final Cow calf;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.watch<GameModel>();
    final name = s.cowName(calf.breed, calf.number);
    return AppCard(
      child: Row(
        children: [
          // .calf-pic：84×84、框 2、圓角 18。裡面是 grid：84×84 的圖比框裡（80×80）大，格子跟著圖變成 84，
          // 從框裡的左上角開始放，右邊、下面各超出 4 被裁掉（place-items 在格子裡沒有作用）
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              border: Border.all(color: AppColors.ink, width: 2),
              borderRadius: const BorderRadius.all(AppRadii.r18),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(18 - 2)),
              child: OverflowBox(
                maxWidth: 84,
                maxHeight: 84,
                alignment: Alignment.topLeft,
                child: CowPicture(
                  breed: calf.breed,
                  bull: calf.bull,
                  calf: true,
                  variant: calf.number,
                  width: 84,
                  height: 84,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TickerBuilder(
              builder: (context) {
                final now = m.gameNow;
                final st = m.state;
                final left = math.max(0.0, (calf.adultAt ?? now) - now);
                // 進度：出生到現在 ÷ 出生到長大（age_h 是 state 那一刻的遊戲小時數）
                final age = (calf.ageH ?? 0) * 3600 + (st == null ? 0 : now - st.serverTime);
                final frac = age + left > 0 ? age / (age + left) : 1.0;
                final hint = KitText.hint();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.gNewCalf(cow: name),
                      style: AppText.style(16, weight: FontWeight.w700, lineHeight: 24),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TierChip(breedInfo(calf.breed)?.tier ?? calf.tier),
                          CowBadge(BadgeKind.calf, s.stageCalf),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: hint,
                        children: fillSpans(
                          s.growUp(v: '\u0000'),
                          AppText.number(13, color: AppColors.ink2, lineHeight: 19),
                          s.countdown(left / (m.timeScale > 0 ? m.timeScale : 1)),
                        ),
                      ),
                      key: const Key('calf-grow'),
                    ),
                    const SizedBox(height: 6),
                    MeterBar.yellow(fraction: frac),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
