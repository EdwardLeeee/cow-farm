// S12 排行榜（設計稿 s09.js 的 rankPage；screens.css 的 .rank-*、.medal、.my-rank）：紀錄分頁「排行榜」那一側。
// 上面兩排分段鈕（圖鑑／排行榜；總資產／圖鑑／本週收入）、一行說明、前 50 名的卡（前三名是獎牌，自己那一列淡黃底加
// 「我」，電腦牧場前面加「電腦」，圖鑑榜發現 24 種的分數前面加綠色「完成」），下面固定一條「我的名次」。
// 下拉可以重新整理。載入中（S12-05）、載入失敗加重試（S12-06）在卡片裡，「我的名次」那一條這時寫「—」。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/seg.dart';

/// 圖鑑榜發現這麼多種就加「完成」（企劃書 4.6；D31）。
const kCodexComplete = 24;

/// 排行榜三種，照設計稿的順序。
const _kinds = [RankKind.networth, RankKind.collection, RankKind.weekly];

/// S12。[seg] 是上面的「圖鑑／排行榜」。
class RankPage extends StatefulWidget {
  const RankPage({super.key, required this.seg});

  final Widget seg;

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  final _boards = <RankKind, Leaderboard>{};
  final _loading = <RankKind>{};
  final _failed = <RankKind>{};

  Future<void> _load(RankKind kind) async {
    setState(() {
      _loading.add(kind);
      _failed.remove(kind);
    });
    final board = await context.read<GameModel>().leaderboard(kind);
    if (!mounted) return;
    setState(() {
      _loading.remove(kind);
      if (board == null) {
        _failed.add(kind);
      } else {
        _boards[kind] = board;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final kind = m.rankKind;
    final board = _boards[kind];
    final failed = board == null && _failed.contains(kind);
    // 還沒讀過這一種：畫完這一格就去讀
    if (board == null && !failed && !_loading.contains(kind)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading.contains(kind) && _boards[kind] == null) unawaited(_load(kind));
      });
    }
    final unit = kind == RankKind.collection ? s.s12Kinds : s.gCoin;
    final safe = MediaQuery.paddingOf(context);
    return AppFrame(
      tab: AppTab.records,
      // .content.has-myrank：內容的下緣停在「我的名次」那一條上面（分頁列上方 58）
      contentPadding: const EdgeInsets.only(bottom: 58),
      content: RefreshIndicator(
        onRefresh: () => _load(kind),
        child: ListView(
          key: const Key('rank'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            widget.seg,
            const SizedBox(height: 12),
            SegControl(
              labels: [s.rankNetworth, s.rankCollection, s.rankWeekly],
              selected: _kinds.indexOf(kind),
              onSelect: (i) => m.selectRankKind(_kinds[i]),
              small: true,
              keyPrefix: 'rank-kind',
            ),
            const SizedBox(height: 12),
            Text(_hint(s, kind, board), key: const Key('rank-hint'), style: KitText.hint()),
            const SizedBox(height: 12),
            // .rank-card 的 padding 4 10：左右的 10 由每一列自己留，自己那一列的淡黃底才能撐滿（CSS 用 margin 0 −10）
            AppCard(
              key: const Key('rank-card'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: board != null
                  ? _RankList(board: board, unit: unit, done: kind == RankKind.collection)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: failed ? _RankEmpty.failed(onRetry: () => _load(kind)) : const _RankEmpty.loading(),
                    ),
            ),
          ],
        ),
      ),
      body: [
        Positioned(
          left: 12,
          right: 12,
          bottom: safe.bottom + FrameSizes.tab + 8,
          child: _MyRank(me: board?.me, ready: board != null, unit: unit, done: kind == RankKind.collection),
        ),
      ],
    );
  }

  /// 說明：總資產、圖鑑各一句；本週收入寫每週幾點重算（手機當地時間）。後面接「下拉可以重新整理。」
  static String _hint(Strings s, RankKind kind, Leaderboard? board) {
    final first = switch (kind) {
      RankKind.networth => s.s12NetworthHint,
      RankKind.collection => s.s12CollectionHint(n: kCodexComplete),
      RankKind.weekly => () {
        final at = weeklyResetClock(board?.nextResetAtReal);
        final hh = at.hour.toString().padLeft(2, '0'), mm = at.minute.toString().padLeft(2, '0');
        return s.s12WeeklyHint(w: s.weekdayFullName(at.weekday), time: '$hh:$mm');
      }(),
    };
    return '$first${s.s12PullHint}';
  }
}

/// 測試、截圖用：當作手機在這個時區（設計稿的假資料：繁中在台灣 +8、泰文 +7、英文 −7）。null 是手機自己的時區。
@visibleForTesting
Duration? debugRankUtcOffset;

/// 本週收入下次重算是手機時區的星期幾（0 是星期日）、幾點幾分（ceo 2026-10-02）：伺服器給的 next_reset_at_real
/// （現實時間）；還沒有（舊的伺服器、還沒讀到）就照 D25 的規則：台灣時間週一 00:00。
({int weekday, int hour, int minute}) weeklyResetClock(double? nextResetAtReal) {
  final at = nextResetAtReal != null
      ? DateTime.fromMillisecondsSinceEpoch((nextResetAtReal * 1000).round(), isUtc: true)
      : _nextTaipeiMonday();
  final wall = at.add(debugRankUtcOffset ?? at.toLocal().timeZoneOffset);
  return (weekday: wall.weekday % 7, hour: wall.hour, minute: wall.minute);
}

/// 下一個台灣時間週一 00:00（＝ UTC 週日 16:00）。
DateTime _nextTaipeiMonday() {
  final now = DateTime.now().toUtc();
  var at = DateTime.utc(now.year, now.month, now.day, 16).add(Duration(days: (DateTime.sunday - now.weekday) % 7));
  if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
  return at;
}

/// 前 50 名。
class _RankList extends StatelessWidget {
  const _RankList({required this.board, required this.unit, required this.done});

  final Leaderboard board;
  final String unit;
  final bool done;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final (i, e) in board.entries.indexed) RankRow(entry: e, unit: unit, done: done, first: i == 0)],
  );
}

/// .rank-row：名次（前三名是獎牌）、牧場名和 #編號、等級（自己的加「我」）、分數。
class RankRow extends StatelessWidget {
  const RankRow({super.key, required this.entry, required this.unit, required this.done, this.first = false});

  final RankEntry entry;
  final String unit;

  /// 圖鑑榜：發現 24 種的加「完成」。
  final bool done;

  /// 第一列上面沒有虛線。
  final bool first;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final e = entry, ranch = e.ranch, me = e.isMe;
    final tag = Strings.ranchTag(ranch);
    final row = Container(
      key: Key('rank-row-${e.rank}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          _Medal(e.rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // .rn：（電腦）名字（放不下用「…」）#編號，基線對齊
                _NameLine(ranch: ranch, rank: e.rank, tag: tag),
                const SizedBox(height: 2),
                // .rl：等級、自己的加「我」（很窄的手機放不下時「我」換到下一行，設計稿沒畫到）
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    if (ranch?.level case final lv?) LvChip(lv),
                    if (me) CowBadge(BadgeKind.newBreed, s.s12Me),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (done && e.score >= kCodexComplete) ...[const DoneBadge(), const SizedBox(width: 10)],
          _Score(score: e.score, unit: unit),
        ],
      ),
    );
    // .rank-row.me：淡黃底、圓角 12，撐滿卡片寬（虛線是透明的）
    if (me) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFFFF1B8), borderRadius: BorderRadius.all(Radius.circular(12))),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: row),
      );
    }
    // 跟上一列之間 2 的淡色虛線（第一列沒有），畫在左右的 10 裡面
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: first ? row : CustomPaint(painter: const DashedTopLine(), child: row),
    );
  }
}

/// .rn：（電腦）名字（放不下用「…」）#編號。名字縮到沒有還放不下時（很窄的手機、很長的編號），超出去的部分裁掉，
/// 不擠壞（CSS 的 .rn 是超出去）。
class _NameLine extends StatelessWidget {
  const _NameLine({required this.ranch, required this.rank, required this.tag});

  final RanchRef? ranch;
  final int rank;
  final String? tag;

  static final _tagStyle = AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 20);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final bot = ranch?.isBot ?? false;
    final tag = this.tag;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (bot) ...[_BotTag(s.botPrefix), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            s.ranchName(ranch),
            key: Key('rank-name-$rank'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AppText.style(15, weight: FontWeight.w900, lineHeight: 20),
          ),
        ),
        if (tag != null) ...[const SizedBox(width: 4), Text(tag, softWrap: false, style: _tagStyle)],
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        final fixed =
            (bot ? _textWidth(s.botPrefix, _BotTag.style) + 8 + 4 : 0.0) +
            (tag != null ? 4 + _textWidth(tag, _tagStyle) : 0.0);
        if (fixed <= c.maxWidth) return row;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: fixed,
            maxWidth: fixed,
            fit: OverflowBoxFit.deferToChild,
            child: row,
          ),
        );
      },
    );
  }
}

double _textWidth(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// .medal（前三名，30 的圓、2 的框）或 .rk（第 4 名起，灰色數字）。
class _Medal extends StatelessWidget {
  const _Medal(this.rank);

  final int rank;

  static const _colors = [Color(0xFFFFD45E), Color(0xFFE3E7EE), Color(0xFFF2C29B)];

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return SizedBox(
        width: 30,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: AppText.number(16, color: AppColors.ink2),
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colors[rank - 1],
        shape: BoxShape.circle,
        // CSS 寫 2.5px，Chrome 畫成 2px（跟其他 2.5px 的框一樣照 boards）
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text('$rank', style: AppText.style(15, weight: FontWeight.w900, lineHeight: 20)),
    );
  }
}

/// .rn .bot：電腦牧場名前面的「電腦」（咖啡色底白字）。
class _BotTag extends StatelessWidget {
  const _BotTag(this.text);

  final String text;

  static final style = AppText.style(12, weight: FontWeight.w900, color: Colors.white, lineHeight: 16);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: const BoxDecoration(color: Color(0xFF8A6F60), borderRadius: BorderRadius.all(Radius.circular(6))),
    child: Text(
      text,
      softWrap: false,
      style: AppText.style(12, weight: FontWeight.w900, color: Colors.white, lineHeight: 16),
    ),
  );
}

/// .rv：分數（大的數字縮寫，compactBig）加單位。
class _Score extends StatelessWidget {
  const _Score({required this.score, required this.unit});

  final double score;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final lang = Strings.of(context).lang;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: compactBig(score, lang), style: AppText.number(16)),
          const WidgetSpan(child: SizedBox(width: 2)),
          TextSpan(
            text: unit,
            style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ],
      ),
      softWrap: false,
    );
  }
}

/// .lv：等級的小膠囊（黃底、2 的框、圓角 8）。
class LvChip extends StatelessWidget {
  const LvChip(this.level, {super.key});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: AppColors.yellow,
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    child: Text(Strings.of(context).level(lv: level), softWrap: false, style: AppText.number(12, lineHeight: 14)),
  );
}

/// .badge.done：綠底、打勾、「完成」（D31）。[tight] 時只留打勾（「我的名次」那一條放不下時，設計稿的 fitMyRank）。
class DoneBadge extends StatelessWidget {
  const DoneBadge({super.key, this.tight = false});

  final bool tight;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('done-badge'),
    height: 22,
    padding: tight ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.only(left: 5, right: 7),
    decoration: BoxDecoration(
      color: AppColors.green,
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(11)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon('ok', size: 12),
        if (!tight) ...[
          const SizedBox(width: 2),
          Text(
            Strings.of(context).s12Complete,
            softWrap: false,
            style: AppText.style(12, weight: FontWeight.w900, lineHeight: 18),
          ),
        ],
      ],
    ),
  );
}

/// 卡片裡的載入中（S12-05）、載入失敗加重試（S12-06）：.oc-empty，最矮 160。
class _RankEmpty extends StatelessWidget {
  const _RankEmpty.loading() : onRetry = null;
  const _RankEmpty.failed({required VoidCallback this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final retry = onRetry;
    return ConstrainedBox(
      key: Key(retry == null ? 'rank-loading' : 'rank-failed'),
      constraints: const BoxConstraints(minHeight: 160),
      child: retry == null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spinner(),
                const SizedBox(width: 8),
                Text(
                  s.gLoading,
                  style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    style: KitText.err(),
                    children: [
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AppIcon('err', size: 20),
                      ),
                      TextSpan(text: ' ${s.loadFailed}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(s.retry, key: const Key('rank-retry'), small: true, icon: 'refresh', onPressed: retry),
              ],
            ),
    );
  }
}

/// .my-rank：「我的名次 第 8 名」，右邊是自己的分數（圖鑑榜發現 24 種的加「完成」）。還在讀、讀不到時寫「—」。
/// 放不下時「完成」只留打勾（設計稿的 fitMyRank：泰文的窄手機）。
class _MyRank extends StatelessWidget {
  const _MyRank({required this.me, required this.ready, required this.unit, required this.done});

  final RankEntry? me;
  final bool ready;
  final String unit;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final me = this.me;
    final rankText = !ready ? '—' : (me != null && me.rank > 0 ? s.s12RankN(n: me.rank) : s.notRanked);
    final showScore = ready && me != null;
    final complete = showScore && done && me.score >= kCodexComplete;
    final label = AppText.style(13, weight: FontWeight.w700, color: AppColors.ink2);
    final big = AppText.number(17);
    final small = AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2);
    final score = showScore ? compactBig(me.score, s.lang) : '';
    Widget bar(bool tight) => Row(
      children: [
        Text(s.s12MyRank, softWrap: false, style: label),
        const SizedBox(width: 8),
        Text(rankText, key: const Key('my-rank'), softWrap: false, style: big),
        // 中間撐開的空白（.grow）兩邊也各有 gap 8
        const SizedBox(width: 8),
        const Spacer(),
        const SizedBox(width: 8),
        if (showScore) ...[
          if (complete) ...[DoneBadge(tight: tight), const SizedBox(width: 8)],
          Text(score, softWrap: false, style: big),
          const SizedBox(width: 8),
          Text(unit, softWrap: false, style: small),
        ],
      ],
    );
    return Container(
      key: const Key('my-rank-bar'),
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1B8),
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: AppShadows.solid(3),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // 要多寬：我的名次、名次、（撐開的空白兩邊各 8）、完成、分數、單位，中間都隔 8
          var need = _textWidth(s.s12MyRank, label) + 8 + _textWidth(rankText, big) + 16;
          if (showScore) need += _textWidth(score, big) + 8 + _textWidth(unit, small);
          // 完成：框 2 + 左 5 + 打勾 12 + 2 + 字 + 右 7 + 框 2；只留打勾時是框 2 + 4 + 打勾 12 + 4 + 框 2
          final full = 2 + 5 + 12 + 2 + _textWidth(s.s12Complete, AppText.style(12, weight: FontWeight.w900)) + 7 + 2;
          const tightBadge = 2 + 4 + 12 + 4 + 2;
          // 放不下時「完成」只留打勾（設計稿的 fitMyRank）
          final tight = complete && need + full + 8 > c.maxWidth + 0.5;
          if (complete) need += (tight ? tightBadge : full) + 8;
          if (need <= c.maxWidth + 0.5) return bar(tight);
          // 還是放不下（泰文的窄手機：app 內建的 Noto Sans Thai 可變字型畫得出 900 的粗字，比設計稿的 Chrome 用的 Bold 寬）：
          // 整條等比例縮小一點，間距照設計稿，不擠在一起也不超出去
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(width: need, child: bar(tight)),
          );
        },
      ),
    );
  }
}
