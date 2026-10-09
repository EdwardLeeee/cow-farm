// S04 牛的詳細資料（設計稿 s04.js 的 detailPage；screens.css 的 .hero、.origin-tag、.detail-actions；kit.css 的 .kv）、
// S04-04 上架借種（.sheet、.fee-box）、S07 出貨確認（s07.js；.ship-head、.grade-row、.ev-line）、
// S20 出貨評級結果（.result-card、.grade-big、.burst）。
// 能不能出貨、配種、下田看伺服器的 can_*；評級機率、各等級收入、借種費都是伺服器算的，手機不算帳。
import 'dart:async';
import 'dart:math' as math;

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
import '../kit/fly.dart';
import '../kit/frame.dart';
import '../kit/grade.dart';
import '../kit/kit.dart';
import '../kit/kv.dart';
import '../kit/meter.dart';
import '../kit/motion.dart';
import '../kit/note_line.dart';
import '../kit/page_head.dart';
import '../ship/truck_scene.dart';
import '../widgets/action_button.dart';
import '../widgets/ticker_builder.dart';

/// CSS 的 line-height 把多出來（或不夠）的行距上下平分；字比行高大的地方要照這樣排，字才不會偏上。
TextStyle _even(TextStyle s) => s.copyWith(leadingDistribution: TextLeadingDistribution.even);

/// 牛的詳細資料（S04）。這頭牛不在了（別的手機出貨了）是 S04-11。
class CowDetailPage extends StatefulWidget {
  const CowDetailPage({super.key, required this.cowKey});

  final String cowKey;

  @override
  State<CowDetailPage> createState() => _CowDetailPageState();
}

class _CowDetailPageState extends State<CowDetailPage> {
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  /// 上架借種的面板開著（S04-04）。
  bool _listing = false;

  /// 正在出貨：伺服器回來到關掉這頁之間，牛已經不在 state 裡，先照原本的畫，不要閃一下「找不到這頭牛」。
  Cow? _shipping;

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

  /// 動作的結果：失敗跳提示（維護、token 失效是整頁的狀態，不另外跳）。成功的話畫面本身就變了（標籤、按鈕），不跳提示。
  void _done(ActionResult<Object?> r) {
    final err = r.error;
    if (!mounted || err == null) return;
    if (err case ApiActionError(:final error) when error.maintenance || error.unauthorized) return;
    _showToast(
      actionErrorKind(err),
      actionErrorTextWith(Strings.of(context, listen: false), context.read<GameModel>(), err),
    );
  }

  Future<void> _ship(Cow cow) async {
    final m = context.read<GameModel>();
    final navigator = Navigator.of(context);
    final motion = AppMotion.read(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent, // 暗幕由 AppDialog 自己畫
      useSafeArea: false,
      builder: (context) => ShipConfirmDialog(cow: cow),
    );
    if (ok != true || !mounted) return;
    setState(() => _shipping = cow);
    final r = await m.ship(cow);
    if (mounted) setState(() => _shipping = null);
    final res = r.value;
    if (res == null) {
      _done(r);
      return;
    }
    // 出貨成功這頁就關了（牛不在了），用事先拿到的 Navigator 開結果頁（S20）
    if (!navigator.mounted) return;
    Route<void> result() => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => ShipResultPage(cow: cow, result: res),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    );
    if (!motion) {
      // 減少動態：不播卡車，直接顯示評級結果（A-03 的減少動態版）
      await navigator.push(result());
      return;
    }
    // A-03 出貨卡車：播完（或點一下跳過）換成結果頁，白光接著結果頁淡入
    await navigator.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => TruckScene(
          cow: cow,
          ranchName: m.ranchName,
          herd: m.state?.cows ?? const [],
          onDone: () => navigator.pushReplacement(result()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final cow = m.state?.cowById(widget.cowKey) ?? _shipping;
    if (cow == null) return _GonePage(cowKey: widget.cowKey);
    return AppFrame(
      tab: m.tab,
      contentPadding: EdgeInsets.zero,
      content: TickerBuilder(
        builder: (context) => Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _DetailList(cow: cow)),
                  // 提示放在按鈕區上面 14（G-04）
                  if (_toast case final t?)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Center(
                        child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
                      ),
                    ),
                ],
              ),
            ),
            _DetailActions(
              cow: cow,
              onShip: () => _ship(cow),
              onList: () => setState(() => _listing = true),
              onDone: _done,
            ),
          ],
        ),
      ),
      overlays: [
        if (_listing)
          Positioned.fill(
            child: ListSheet(
              cow: cow,
              onCancel: () => setState(() => _listing = false),
              onConfirm: () async {
                setState(() => _listing = false);
                _done(await m.studList(cow));
              },
            ),
          ),
      ],
    );
  }
}

/// 年齡（現實時間）：不到 1 小時寫分，不到 1 天寫時、分，其他寫天、時（設計稿：18 分、2 天 5 小時）。
String ageText(Strings s, double realSeconds) {
  final sec = realSeconds.floor().clamp(0, 1 << 31);
  if (sec < 3600) return s.duration(m: math.max(1, sec ~/ 60));
  if (sec < 24 * 3600) return s.duration(h: sec ~/ 3600, m: (sec % 3600) ~/ 60);
  return s.duration(d: sec ~/ (24 * 3600), h: (sec % (24 * 3600)) ~/ 3600);
}

/// 牛的來源（開局、商店 B 級、自己配種、借種）；伺服器沒給是空字串，不畫標籤。
String originText(Strings s, String? origin) => switch (origin) {
  'start' => s.s04OriginStart,
  'A' || 'B' || 'C' => s.s04OriginShop(g: origin!),
  'breed' => s.s04OriginBreed,
  'stud' => s.s04OriginStud,
  _ => '',
};

/// 公耕牛（成年、沒配過種的公耕牛）：可以下田，也可以上架借種，一共 4 個動作（D31，S04-14～16）。
bool isStudOx(Cow cow, double now) => cow.bull && cow.type == CowType.dual && cow.isAdultAt(now) && !cow.bred;

/// 自己上架的那一筆（state.stud.listings）。
StudListing? _listingOf(GameModel m, Cow cow) =>
    cow.listed ? m.state?.stud.listings.where((l) => '${l.cowId}' == cow.key).firstOrNull : null;

/// 上面捲動的內容：頁首（名字、標籤）、大圖（來源）、橘字提醒、四格資料、出貨評級機率。
class _DetailList extends StatelessWidget {
  const _DetailList({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final adult = cow.isAdultAt(m.gameNow);
    // 橘字提醒：在田裡（S04-07）、已配種（S04-09）。上架中的公牛不放（D31：看「上架中」標籤和停用的按鈕就知道）；
    // 老牛配過種不加（S04-10 的設計稿：大圖下面已經有老牛的說明，配過種看標籤和按鈕）
    final note = cow.fieldIndex != null
        ? (isStudOx(cow, m.gameNow) ? s.s04RecallFirstOx : s.recallFirst)(n: cow.fieldIndex! + 1)
        : cow.bred && adult && cow.stage != CowStage.old
        ? s.s04NoteBred
        : null;
    final probs = cow.gradeProbs;
    return SingleChildScrollView(
      key: const Key('cow-detail'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        key: const Key('detail-stack'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailHead(cow: cow),
          const SizedBox(height: 12),
          _Hero(cow: cow),
          if (note != null) ...[
            const SizedBox(height: 12),
            NoteLine(key: const Key('detail-note'), icon: 'warn', text: note, kind: NoteKind.warn),
          ],
          const SizedBox(height: 12),
          _Kv(cow: cow, adult: adult),
          if (adult && probs != null && probs.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              key: const Key('detail-grade-probs'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // .card-head：標題靠左、小字靠右；小字放不下就在剩下的寬度裡換行
                  Row(
                    children: [
                      CardTitle(s.shipGradeTitle),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            s.s04GradeHint,
                            style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GradeBar(probs: probs),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// .page-head：返回、「品種名 #編號」，下面一排標籤（用途、公母、稀有度、狀態）。
class _DetailHead extends StatelessWidget {
  const _DetailHead({required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final s = Strings.of(context);
    return Row(
      children: [
        CircleIconButton(icon: 'back', label: s.back, onTap: m.closeCow),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.cowName(cow.breed, cow.number),
                key: const Key('detail-name'),
                style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: cowChips(context, cow),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// .card.hero：天空草地的底、牛的正面大圖（200×150、置中），左上角「來源：開局」；老牛下面一行說明（S04-10）。
/// 來源標籤不能蓋到牛頭（scope.md S04；設計稿 kit.js 的 fitOriginTags）：牛頭最靠左的地方離牛圖左緣，
/// 一行標籤的高度內 42、兩行 38；標籤右緣要在那之前 6。一行放得下就一行；不然在「來源：」後面換兩行；
/// 還是放不下就放到圖的下面、靠左。
class _Hero extends StatelessWidget {
  const _Hero({required this.cow});

  final Cow cow;

  static const _headOne = 42.0, _headTwo = 38.0, _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final origin = originText(s, cow.origin);
    final full = origin.isEmpty ? null : s.origin(v: origin);
    final pre = s.origin(v: '\u0000').split('\u0000').first; // 「來源：」「From: 」「ที่มา: 」
    final tagStyle = AppText.style(12, weight: FontWeight.w900, lineHeight: 18);
    final scaler = MediaQuery.textScalerOf(context);
    double width(String t) {
      final p = TextPainter(
        text: TextSpan(text: t, style: tagStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    Widget tag(String text) => Container(
      key: const Key('origin-tag'),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.9),
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r10),
      ),
      child: Text(text, style: tagStyle),
    );

    return LayoutBuilder(
      builder: (context, c) {
        // 卡片的框 3；標籤在框內左 8（加自己的框 2、左右留白 7：字的寬 + 18）
        const border = AppSizes.border;
        final picLeft = border + (c.maxWidth - border * 2 - 200) / 2;
        String? onTop;
        var below = false;
        if (full != null) {
          final value = full.startsWith(pre) ? full.substring(pre.length) : '';
          if (border + 8 + width(full) + 18 <= picLeft + _headOne - _gap + 0.5) {
            onTop = full;
          } else if (value.isNotEmpty &&
              border + 8 + math.max(width(pre.trim()), width(value)) + 18 <= picLeft + _headTwo - _gap + 0.5) {
            onTop = '${pre.trim()}\n$value';
          } else {
            below = true;
          }
        }
        return Container(
          key: const Key('hero'),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: border),
            borderRadius: const BorderRadius.all(AppRadii.r18),
            boxShadow: AppShadows.solid(4),
          ),
          // 框裡面的圓角是 18 − 3（overflow: hidden 裁在框的內緣）
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(18 - border)),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(gradient: kHeroGradient)),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: CowPicture(
                          breed: cow.breed,
                          bull: cow.bull,
                          calf: cow.stage == CowStage.calf,
                          variant: cow.number,
                          width: 200,
                          height: 150,
                        ),
                      ),
                      if (below)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 8), child: tag(full!)),
                        ),
                      // .hero-note：老牛（過了壯年）
                      if (cow.stage == CowStage.old)
                        Container(
                          key: const Key('old-note'),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: Color.fromRGBO(255, 255, 255, 0.9),
                            borderRadius: BorderRadius.all(AppRadii.r10),
                          ),
                          child: Text(s.s04OldNote, style: KitText.hint()),
                        ),
                    ],
                  ),
                ),
                if (onTop != null) Positioned(left: 8, top: 8, child: tag(onTop)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// .kv：兩欄的小格子。成年：年齡、產奶／耕田／用途、體重、出貨估值；小牛：年齡、長大還要。
class _Kv extends StatelessWidget {
  const _Kv({required this.cow, required this.adult});

  final Cow cow;
  final bool adult;

  @override
  Widget build(BuildContext context) {
    final m = context.read<GameModel>();
    final s = Strings.of(context);
    final cells = <KvCell>[];
    // age_h 是拿到 state 那一刻的遊戲小時；加上之後走過的遊戲時間，再換成現實時間
    final ageH = cow.ageH, serverTime = m.state?.serverTime;
    if (ageH != null) {
      final gameS = ageH * 3600 + (serverTime == null ? 0 : m.gameNow - serverTime);
      cells.add((s.s04Age, ageText(s, gameS / m.timeScale), null));
    }
    final adultAt = cow.adultAt;
    if (!adult) {
      if (adultAt != null) cells.add((s.s04GrowIn, s.countdown((adultAt - m.gameNow) / m.timeScale), null));
    } else if (cow.milker) {
      cells.add((s.gMilk, rateText(cow.milkPerH), s.gPerHourMilk));
    } else if (cow.type == CowType.dual) {
      // 耕牛：下田的話每小時的稻米（沒下田也是這個值，協定 2.3 的 rice_per_h）
      cells.add((s.gPlow, rateText(cow.ricePerH), s.gPerHourRice));
    } else {
      cells.add((s.probType, cow.type == CowType.beef ? s.s04UseBeef : s.s04UseBreed, null));
    }
    if (adult) {
      cells.add((s.s04Weight, fmt(cow.weightKg), s.gKg));
      cells.add((s.s04Value, s.s04About(v: fmt(cow.shipValue ?? 0)), s.gCoin));
    }
    return KvGrid(key: const Key('kv'), cells: cells);
  }
}

/// .detail-actions：下面固定的按鈕區（米色底、上緣 2px 虛線）。依牛的狀態放：
/// 小牛一句說明；在田裡「叫回」；上架中「下架」；耕牛「派去田裡」（沒有空田停用、加一句說明）；沒配過種的公牛「上架」。
/// 下面一排「選這頭去配種」「出貨」。斷線時全部停用（S04-12）。
class _DetailActions extends StatelessWidget {
  const _DetailActions({required this.cow, required this.onShip, required this.onList, required this.onDone});

  final Cow cow;
  final VoidCallback onShip;
  final VoidCallback onList;
  final void Function(ActionResult<Object?>) onDone;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final now = m.gameNow;
    final adult = cow.isAdultAt(now);
    final act = m.canAct;
    final top = <Widget>[];
    var space = 12.0; // 上面那一塊和下面那排按鈕的間距
    // 派去田裡：要有空田（S04-13）
    final free = m.state?.fields.any((f) => f.empty) ?? false;
    final noField = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(s.s04NoField, key: const Key('no-field'), textAlign: TextAlign.center, style: KitText.warn()),
    );
    if (!adult) {
      top.add(Text(s.s04CalfHint, key: const Key('calf-hint'), textAlign: TextAlign.center, style: KitText.hint()));
      space = 8;
    } else if (isStudOx(cow, now)) {
      // 公耕牛（D31，S04-14～16）：第一排兩顆半寬。在田裡第一顆換成「叫回來」，上架中第二顆換成「下架」；
      // 放不下（窄手機的英文、泰文）就一顆一排（BtnRow），內容區跟著讓位
      final working = cow.fieldIndex != null;
      top.add(
        BtnRow(
          children: [
            if (working)
              AppButton(
                s.s04Recall,
                key: const Key('detail-recall'),
                icon: 'hand',
                onPressed: act ? () async => onDone(await m.fieldRecall(cow)) : null,
              )
            else
              AppButton(
                s.gAssign,
                key: const Key('detail-assign'),
                kind: ButtonKind.green,
                icon: 'sprout',
                onPressed: act && free && cow.canWorkAt(now) ? () async => onDone(await m.fieldAssign(cow)) : null,
              ),
            if (cow.listed)
              AppButton(
                s.unlist,
                key: const Key('detail-unlist'),
                icon: 'tag',
                onPressed: act ? () async => onDone(await m.studUnlist(_listingOf(m, cow)?.id ?? cow.listedId!)) : null,
              )
            else
              AppButton(
                s.s04ListStud,
                key: const Key('detail-list'),
                kind: ButtonKind.primary,
                icon: 'tag',
                onPressed: act && cow.canListAt(now) && cow.studFee != null ? onList : null,
              ),
          ],
        ),
      );
      // 沒有空田（設計稿只畫了一顆的樣子，S04-13）：說明放在第一排下面
      if (!working && !cow.listed && !free) {
        top.add(noField);
        space = 10;
      }
    } else if (cow.fieldIndex != null) {
      top.add(
        AppButton(
          s.s04Recall,
          key: const Key('detail-recall'),
          block: true,
          icon: 'hand',
          onPressed: act ? () async => onDone(await m.fieldRecall(cow)) : null,
        ),
      );
    } else if (cow.listed) {
      final id = _listingOf(m, cow)?.id ?? cow.listedId!;
      top.add(
        AppButton(
          s.unlist,
          key: const Key('detail-unlist'),
          block: true,
          icon: 'tag',
          onPressed: act ? () async => onDone(await m.studUnlist(id)) : null,
        ),
      );
    } else if (cow.type == CowType.dual) {
      top.add(
        AppButton(
          s.gAssign,
          key: const Key('detail-assign'),
          kind: ButtonKind.green,
          block: true,
          icon: 'sprout',
          onPressed: act && free && cow.canWorkAt(now) ? () async => onDone(await m.fieldAssign(cow)) : null,
        ),
      );
      if (!free) {
        top.add(noField);
        space = 10;
      }
    } else if (cow.bull && !cow.bred) {
      top.add(
        AppButton(
          s.s04ListStud,
          key: const Key('detail-list'),
          kind: ButtonKind.primary,
          block: true,
          icon: 'tag',
          onPressed: act && cow.canListAt(now) && cow.studFee != null ? onList : null,
        ),
      );
    }
    return Container(
      key: const Key('detail-actions'),
      width: double.infinity,
      color: AppColors.cream,
      child: CustomPaint(
        painter: const DashedTopLine(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2 + 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...top,
              if (top.isNotEmpty) SizedBox(height: space),
              BtnRow(
                children: [
                  AppButton(
                    !adult
                        ? s.s04CantBreedYet
                        : cow.bred
                        ? s.s04AlreadyBred
                        : s.pickForBreed,
                    key: const Key('detail-breed'),
                    kind: ButtonKind.pink,
                    icon: 'heart',
                    onPressed: act && cow.canBreedAt(now) ? () => m.selectForBreeding(cow) : null,
                  ),
                  AppButton(
                    adult ? s.ship : s.shipNotAdult,
                    key: const Key('detail-ship'),
                    kind: ButtonKind.danger,
                    icon: adult ? 'truck' : null,
                    onPressed: act && cow.canShipAt(now) ? onShip : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S04-11：這頭牛已經不在了（剛在別的手機出貨、或處理過）。
class _GonePage extends StatelessWidget {
  const _GonePage({required this.cowKey});

  final String cowKey;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    return AppFrame(
      tab: m.tab,
      content: ListView(
        key: const Key('cow-gone'),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              CircleIconButton(icon: 'back', label: s.back, onTap: m.closeCow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.cowTitle(id: cowKey),
                  style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            // .empty：圖、標題、說明、按鈕，間距 10
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Column(
                children: [
                  const CowSilhouette(breed: 'holstein', size: 120),
                  const SizedBox(height: 10),
                  Text(
                    s.s04GoneTitle,
                    textAlign: TextAlign.center,
                    style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.s04GoneBody,
                    textAlign: TextAlign.center,
                    style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    s.s04BackRanch,
                    key: const Key('gone-back'),
                    kind: ButtonKind.primary,
                    onPressed: m.closeCow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// S04-04 上架借種：借種費是伺服器算的（公牛現在的體重 × 每公斤價格，D26），主人只決定要不要上架。
class ListSheet extends StatelessWidget {
  const ListSheet({super.key, required this.cow, required this.onCancel, required this.onConfirm});

  final Cow cow;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.watch<GameModel>();
    final fee = cow.studFee;
    final price = fee == null ? '–' : fmt(fee.price);
    final label = AppText.style(14, weight: FontWeight.w900, lineHeight: 20);
    return AppSheet(
      title: s.s04ListTitle(cow: s.cowName(cow.breed, cow.number)),
      onClose: onCancel,
      children: [
        // .fee-box：借種費（大字），下面一行算法
        Container(
          key: const Key('fee-box'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.lineSoft, width: 2),
            borderRadius: const BorderRadius.all(AppRadii.r16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                // 對齊基線：大字的上面 30、「借種費」「幣」的下面 5，這一列在 Chrome 是 35 高
                children: [
                  CssLine(TextSpan(text: s.s04StudFee, style: label)),
                  const SizedBox(width: 6),
                  const Spacer(),
                  CssLine(
                    TextSpan(text: price, style: AppText.number(30, lineHeight: 34)),
                    textKey: const Key('fee'),
                  ),
                  const SizedBox(width: 6),
                  CssLine(TextSpan(text: s.gCoin, style: label)),
                ],
              ),
              if (fee != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    (fee.atMax ? s.s04FeeHowMax : s.s04FeeHowGrow)(
                      tier: s.tierName(cow.tier.clamp(0, 3)),
                      rate: priceText(fee.perKg),
                      kg: fmt(fee.kg),
                    ),
                    style: AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 19),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(s.s04ListHint, style: KitText.hint()),
        const SizedBox(height: 14),
        BtnRow(
          children: [
            AppButton(s.cancel, key: const Key('list-cancel'), onPressed: onCancel),
            AppButton(
              s.s04ListConfirm(price: price),
              key: const Key('list-confirm'),
              kind: ButtonKind.primary,
              onPressed: m.canAct && fee != null ? onConfirm : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// S07 出貨確認：先問伺服器這頭牛現在的評級機率和各等級的收入（GET /v1/ship/preview），按「確定出貨」才出貨。
/// 機率、收入、能不能出貨都照伺服器給的；拿不到就不能按（S07-04）。
class ShipConfirmDialog extends StatefulWidget {
  const ShipConfirmDialog({super.key, required this.cow});

  final Cow cow;

  @override
  State<ShipConfirmDialog> createState() => _ShipConfirmDialogState();
}

class _ShipConfirmDialogState extends State<ShipConfirmDialog> {
  ShipPreview? _preview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final p = await context.read<GameModel>().shipPreview(widget.cow);
    if (!mounted) return;
    setState(() {
      _preview = p;
      _loading = false;
    });
  }

  void _retry() {
    setState(() => _loading = true);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final cow = widget.cow;
    final p = _preview;
    final price = m.market?.quotes[Commodity.beef]?.price;
    final canConfirm = m.canAct && !_loading && p != null && p.canShip && p.blockers.isEmpty;
    final hint = KitText.hint();
    // .ship-head：牛的小圖（76；矮手機 60，整張圖照比例縮，#172）、名字、約多少公斤牛肉、牛肉現價
    final pic = isShortScreen(context) ? 60.0 : 76.0;
    final head = Container(
      key: const Key('ship-head'),
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
      ),
      child: Row(
        children: [
          CowPicture(breed: cow.breed, bull: cow.bull, variant: cow.number, width: pic, height: pic, pad: 3 * pic / 76),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // <b class="ship-name"> 放在對話框 14px、行高 21 的字裡：這一行在 Chrome 是 23 高
                CssLine(
                  TextSpan(
                    style: AppText.style(14, weight: FontWeight.w700, lineHeight: 21),
                    children: [
                      TextSpan(
                        text: s.cowName(cow.breed, cow.number),
                        style: AppText.style(16, weight: FontWeight.w700, lineHeight: 21),
                      ),
                    ],
                  ),
                  wrap: true,
                ),
                Text(s.s07KgBeef(kg: fmt(p?.weightKg ?? cow.weightKg)), style: hint),
                if (price != null) Text(s.s07BeefPrice(price: priceText(price)), style: hint),
              ],
            ),
          ),
        ],
      ),
    );
    final Widget body;
    if (_loading) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(0, 26, 0, 18),
        child: Row(
          key: const Key('preview-loading'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spinner(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(s.loadingPreview, style: AppText.style(16, weight: FontWeight.w900, lineHeight: 21)),
            ),
          ],
        ),
      );
    } else if (p == null) {
      // .empty（padding 14 0 4）：錯誤圖示、一句話、重試
      body = Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
        child: Column(
          children: [
            const AppIcon('err', size: 30),
            const SizedBox(height: 10),
            Text(
              s.s07ProbFailed,
              textAlign: TextAlign.center,
              style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
            ),
            const SizedBox(height: 10),
            AppButton(s.retry, key: const Key('preview-retry'), small: true, icon: 'refresh', onPressed: _retry),
          ],
        ),
      );
    } else {
      final blockers = p.blockers;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          for (final (i, g) in kGrades.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            _GradeRow(grade: g, prob: p.gradeProbs[g] ?? 0, value: p.valueByGrade[g]),
          ],
          if (p.expectedValue case final ev?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(
                  style: _even(AppText.style(14, weight: FontWeight.w700, lineHeight: 21)),
                  children: fillSpans(s.expectedValue(v: '\u0000'), _even(AppText.number(18, lineHeight: 21)), fmt(ev)),
                ),
                key: const Key('ship-ev'),
                textAlign: TextAlign.right,
              ),
            ),
          // 伺服器說現在不能出貨（S07-03）：橘字原因；不然一句說明
          if (blockers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: NoteLine(
                key: const Key('ship-blocker'),
                icon: 'warn',
                text: [
                  for (final b in blockers)
                    b.code == 'cow_in_field'
                        ? s.s07BlockWorking
                        : s.blockerText(b, gameNow: m.gameNow, timeScale: m.timeScale),
                ].join('\n'),
                kind: NoteKind.warn,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.s07Note, style: hint),
            ),
        ],
      );
    }
    return AppDialog(
      key: const Key('ship-confirm-dialog'),
      title: s.shipConfirmTitle,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, body]),
      buttons: [
        AppButton(s.cancel, key: const Key('ship-cancel'), onPressed: () => Navigator.of(context).pop(false)),
        AppButton(
          s.s07Confirm,
          key: const Key('ship-confirm'),
          kind: ButtonKind.danger,
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}

/// .grade-row：評級色塊、「A 級」、機率，右邊「收入約 2,968 幣」。放不下時收入換到下一行、靠右（screens.css 第 9 條）。
class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade, required this.prob, required this.value});

  final String grade;
  final double prob;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final nameSpan = TextSpan(
      text: s.gGrade(g: grade),
      style: AppText.style(14, weight: FontWeight.w900, lineHeight: 21),
    );
    final pctSpan = TextSpan(text: pct(prob), style: AppText.number(16, lineHeight: 21));
    final income = TextSpan(
      style: _even(AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21)),
      children: fillSpans(
        s.s07Income(v: '\u0000'),
        _even(AppText.number(15, lineHeight: 21)),
        value == null ? '–' : fmt(value!),
      ),
    );
    final scaler = MediaQuery.textScalerOf(context);
    double width(InlineSpan t) {
      final p = TextPainter(text: t, textDirection: TextDirection.ltr, textScaler: scaler)..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GradeChip(grade),
        const SizedBox(width: 8),
        Text.rich(nameSpan, softWrap: false),
        const SizedBox(width: 8),
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 52), child: Text.rich(pctSpan, softWrap: false)),
      ],
    );
    final incomeText = Text.rich(income, key: Key('ship-income-$grade'), softWrap: false);
    return Container(
      key: Key('ship-grade-$grade'),
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r12),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final leftW = 26 + 8 + width(nameSpan) + 8 + math.max(52.0, width(pctSpan));
          if (leftW + 8 + width(income) <= c.maxWidth + 0.5) {
            return Row(children: [left, const Spacer(), incomeText]);
          }
          // 換行：第一行色塊那一排（高 26），間距 8，第二行收入靠右
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 26,
                child: Align(alignment: AlignmentDirectional.centerStart, child: left),
              ),
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: incomeText),
            ],
          );
        },
      ),
    );
  }
}

/// S20 出貨評級結果（整頁，沒有頂列和分頁列）：放射光、大字評級、三箱牛肉、放進倉庫多少、現在全部賣掉約多少。
/// 開著動畫時先播 A-10 評級揭曉（設計稿 anims.js 的 A10，1.5 秒，頁面淡入以後才開始）：A、B、C 輪流越轉越慢，第 0.9 秒停在
/// 這次的評級、彈一下、光線放射，第 1.0 秒起三箱牛肉掉進來，1.2–1.45 秒字和按鈕淡入。點一下跳過（直接到最後一格）。
/// 減少動態（或沒開動畫）：直接是 S20。
class ShipResultPage extends StatefulWidget {
  const ShipResultPage({super.key, required this.cow, required this.result});

  final Cow cow;
  final ShipResult result;

  @override
  State<ShipResultPage> createState() => _ShipResultPageState();
}

class _ShipResultPageState extends State<ShipResultPage> with SingleTickerProviderStateMixin {
  /// A-10 的長度（秒）。
  static const _dur = 1.5;

  /// A-10 輪流到哪一格換下一個字（秒），第 0.9 秒停住。
  static const _ticks = [0, 0.08, 0.16, 0.25, 0.35, 0.47, 0.61, 0.76, 0.9];

  late final _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  /// 播 A-10（開著動畫）；null 是還沒決定。
  bool? _play;
  Animation<double>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_play != null) return;
    _play = AppMotion.read(context);
    if (_play != true) return;
    // 頁面淡入（卡車的白光接著結果頁淡入）以後才開始
    final route = ModalRoute.of(context)?.animation;
    if (route == null || route.isCompleted) {
      _reveal.forward();
    } else {
      _route = route..addStatusListener(_routeDone);
    }
  }

  void _routeDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _route?.removeStatusListener(_routeDone);
    _route = null;
    if (mounted) _reveal.forward();
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_routeDone);
    _reveal.dispose();
    super.dispose();
  }

  /// 點一下跳過：直接到最後一格。
  void _skip() {
    _reveal.stop();
    _reveal.value = 1;
  }

  @override
  Widget build(BuildContext context) => _play == true
      ? AnimatedBuilder(animation: _reveal, builder: (context, _) => _page(context, _reveal.value * _dur))
      : _page(context, null);

  /// 第 [t] 秒的樣子（A-10）；null 是 S20 的靜態樣子。
  Widget _page(BuildContext context, double? t) {
    final s = Strings.of(context);
    final m = context.read<GameModel>();
    final pad = MediaQuery.paddingOf(context);
    final cow = widget.cow, result = widget.result;
    final g = result.grade ?? 'B';
    // A-10：前 0.9 秒照 _ticks 輪流（順序是 A → B → C 循環，最後一格剛好是這次的評級），之後停在這次的評級
    const cycle = ['A', 'B', 'C'];
    final shown = t == null || t >= 0.9 ? g : cycle[(cycle.indexOf(g) + _ticks.where((x) => t >= x).length) % 3];
    final playing = t != null && t < _dur;
    // s20.gradeFormat：{grade} 前後的字用小字（繁中「A 級」，英文、泰文「Grade A」「เกรด A」）
    final parts = s.s20GradeFormat(grade: '\u0000').split('\u0000').map((p) => p.trim()).toList();
    final pre = parts.first, post = parts.length > 1 ? parts[1] : '';
    final tip = switch (g) {
      'A' => s.s20TipA,
      'B' => s.s20TipB,
      _ => s.s20TipC,
    };
    final line = _even(AppText.style(16, weight: FontWeight.w700, lineHeight: 24));
    final big = _even(AppText.number(20, lineHeight: 29));
    final small = _even(AppText.style(20, weight: FontWeight.w900, lineHeight: 29));
    // A-10：字和按鈕 1.2–1.45 秒淡入
    Widget later(Widget child) => t == null ? child : Opacity(opacity: animSeg(t, 1.2, 1.45), child: child);
    // 上下留一樣多（安全區比較大的那邊），卡片才會在整個畫面的正中間
    final v = math.max(pad.top, pad.bottom);
    final page = Material(
      key: const Key('ship-result'),
      color: AppColors.cream,
      child: Stack(
        children: [
          // .burst：A-10 第 0.9–1.05 秒淡入、0.9–1.3 秒從 0.4 倍放大到 1 倍，一直轉（每秒 20 度）
          Positioned.fill(
            child: t == null
                ? CustomPaint(painter: _Burst(g))
                : Opacity(
                    opacity: animSeg(t, 0.9, 1.05),
                    child: Transform.rotate(
                      angle: t * 20 * math.pi / 180,
                      child: Transform.scale(
                        scale: 0.4 + 0.6 * animOutCubic(animSeg(t, 0.9, 1.3)),
                        child: CustomPaint(painter: _Burst(g)),
                      ),
                    ),
                  ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, v, 20, v),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      s.s20Title(cow: s.cowName(cow.breed, cow.number)),
                      style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2, lineHeight: 20),
                    ),
                    const SizedBox(height: 8),
                    // .grade-big：116×116、框 4、圓角 32、下陰影 6、上面留 12；字母和前後的小字對齊基線。
                    // A-10：輪流時 0.92 倍，停住時彈一下（0.9–1.05 秒最大 1.18 倍）
                    Transform.scale(
                      scale: t == null ? 1 : (t < 0.9 ? 0.92 : 1 + 0.18 * math.sin(math.pi * animSeg(t, 0.9, 1.05))),
                      child: Container(
                        key: const Key('grade-big'),
                        width: 116,
                        height: 116,
                        padding: const EdgeInsets.only(top: 12),
                        alignment: Alignment.topCenter,
                        decoration: BoxDecoration(
                          color: kGradeColors[shown],
                          border: Border.all(color: AppColors.ink, width: 4),
                          borderRadius: const BorderRadius.all(Radius.circular(32)),
                          boxShadow: AppShadows.solid(6),
                        ),
                        // 英文「Grade B」比框寬：跟 CSS 一樣置中、左右超出（不裁、不縮）
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.topCenter,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              if (pre.isNotEmpty) ...[Text(pre, style: small), const SizedBox(width: 4)],
                              Text(
                                shown,
                                key: const Key('grade-letter'),
                                style: _even(AppText.number(72, lineHeight: 80)),
                              ),
                              if (post.isNotEmpty) ...[const SizedBox(width: 2), Text(post, style: small)],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // .boxes：三箱牛肉，左右兩箱各斜 6°。A-10：第 1.0 秒起一箱晚 0.08 秒從上面 80 掉下來（outBack）
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Builder(
                            builder: (context) {
                              final k = t == null ? 1.0 : animSeg(t, 1.0 + i * 0.08, 1.3 + i * 0.08);
                              return Opacity(
                                key: Key('gift-$i'),
                                opacity: k > 0 ? 1 : 0,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - animOutBack(k)) * -80),
                                  child: Transform.rotate(
                                    angle: (i - 1) * 6 * math.pi / 180,
                                    child: const AppIcon('beef', size: 56),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    later(
                      Text.rich(
                        TextSpan(
                          style: line,
                          children: fillSpans(s.s20KgIn(kg: '\u0000'), big, fmt(result.beefQty ?? 0)),
                        ),
                        key: const Key('ship-kg-in'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    later(
                      Text.rich(
                        TextSpan(
                          style: line,
                          children: fillSpans(s.s20SellAll(v: '\u0000'), big, fmt(result.valueEstimate ?? 0)),
                        ),
                        key: const Key('ship-sell-all'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    later(Text(tip, textAlign: TextAlign.center, style: KitText.hint())),
                    const SizedBox(height: 14),
                    later(
                      BtnRow(
                        children: [
                          AppButton(
                            s.s20GoMarket,
                            key: const Key('ship-go-market'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              m.selectMarket(Commodity.beef);
                              m.selectTab(AppTab.market);
                            },
                          ),
                          AppButton(
                            s.ok,
                            key: const Key('ship-result-ok'),
                            kind: ButtonKind.primary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 點一下跳過（分頁列上方 22，設計稿的 .skip-hint）；播完就拿掉（跟 S20 一樣）
          if (playing)
            Positioned(
              left: 0,
              right: 0,
              bottom: pad.bottom + FrameSizes.tab + 22,
              child: Center(child: SkipHint(s.animSkip, key: const Key('reveal-skip'))),
            ),
        ],
      ),
    );
    if (!playing) return page;
    // 播的時候點哪裡都是跳過（按鈕還看不到，不能按）
    return GestureDetector(
      key: const Key('reveal'),
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: IgnorePointer(child: page),
    );
  }
}

/// .burst：從畫面中間放射的光（直徑 900 的圓，從正上方順時針每 20° 一道 10° 寬的光）。A 金、B 藍、C 橘。
class _Burst extends CustomPainter {
  _Burst(this.grade);

  final String grade;

  @override
  void paint(Canvas canvas, Size size) {
    final color = switch (grade) {
      'A' => const Color.fromRGBO(255, 212, 94, 0.55),
      'B' => const Color.fromRGBO(169, 219, 255, 0.55),
      _ => const Color.fromRGBO(255, 201, 170, 0.5),
    };
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 450);
    final paint = Paint()..color = color;
    for (var a = 0; a < 360; a += 20) {
      canvas.drawArc(rect, (a - 90) * math.pi / 180, 10 * math.pi / 180, true, paint);
    }
  }

  @override
  bool shouldRepaint(_Burst oldDelegate) => oldDelegate.grade != grade;
}
