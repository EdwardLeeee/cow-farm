// 圖鑑的配種表（v0.3 第 13.2 節；使用者 2026-10-08 選第 15 輪 03-B「一對一列」、2026-10-09 選爸爸媽媽「分成兩列」；
// 設計稿 s09.js 的 pairTable、pairRow，screens.css 的 .bp-*）。品種詳細（S09-03）「怎麼配出來」下面一張卡，
// 一列是「爸爸的品種 ♂ × 媽媽的品種 ♀」：
// - 代表配法（協定 2.7 `GET /v1/codex/pairings`，每種 4 組）照順序列出。
// - 玩家用這一對品種配出這個品種（`state.pairings`，長大揭曉那一刻才算）那一列就亮起來：爸爸（公牛）、媽媽（母牛）的圖，
//   品種名，「配出過 n 次」。還沒配出過是兩頭牛的深色影子、名字「？？？」（S09-08）。
// - 用表上沒有的配法配出來的，加在最後面（淡黃底、「表上沒有的配法」）。
import 'package:flutter/material.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/meter.dart';

/// 配種表的一列（設計稿的 pairs）：[count] 是配出過幾次（0 是還沒），[extra] 是表上沒有的配法。
typedef PairRow = ({String sire, String dam, int count, bool extra});

/// [breed] 的配種表（協定 2.7「app 怎麼畫一個品種的表」）：代表配法 [table] 照順序列出，[done]（`state.pairings`）裡
/// 生出 [breed]、爸媽的品種一樣的那一筆就亮起來；生出 [breed] 但不在表上的加在最後面（照第一次配出來的先後）。
List<PairRow> pairRows(String breed, List<BreedPair> table, List<PairingRecord> done) {
  final got = <BreedPair, int>{};
  for (final p in done) {
    if (p.child != breed) continue;
    final k = (sire: p.sire, dam: p.dam);
    got[k] = (got[k] ?? 0) + p.count;
  }
  return [
    for (final t in table) (sire: t.sire, dam: t.dam, count: got[t] ?? 0, extra: false),
    for (final e in got.entries)
      if (!table.contains(e.key)) (sire: e.key.sire, dam: e.key.dam, count: e.value, extra: true),
  ];
}

/// .card.bp-table：標題「配種表」、右邊「解鎖 n / 幾列」、說明，下面一列一列（.bp-list 上面留 6）。
class PairTable extends StatelessWidget {
  const PairTable({super.key, required this.breed, required this.rows});

  final String breed;
  final List<PairRow> rows;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('pair-table'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .card-head：標題靠左、.card-sub 靠右，中間至少 8
          Row(
            children: [
              CardTitle(s.s09PairTitle, color: AppColors.pink, icon: 'heart', iconSize: 16),
              const SizedBox(width: 8),
              const Spacer(),
              // 一行的字照 Chrome 的基線（CssLine：12／16 比 Flutter 自己排高約 1）
              CssLine(
                TextSpan(
                  text: s.s09PairUnlocked(n: rows.where((r) => r.count > 0).length, total: rows.length),
                  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                ),
                textKey: const Key('pair-unlocked'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 相鄰的全形標點擠掉半格（「），」），跟設計稿（Chrome）一樣
          Text.rich(
            TextSpan(children: cjkTrimSpans(s.s09PairHint(breed: s.breedName(breed)))),
            key: const Key('pair-hint'),
            style: KitText.hint(),
          ),
          const SizedBox(height: 6),
          for (final (i, r) in rows.indexed) _PairRowView(r, index: i),
        ],
      ),
    );
  }
}

/// .bp-row：爸爸（公牛）× 媽媽（母牛）的圖（50×45），右邊兩行品種名（♂ 藍、♀ 粉紅）和配出過幾次；上下各留 6，
/// 第一列以外上面一條 2px 的淡色虛線。還沒配出過（.locked）：深色影子、名字「？？？」淡色。
/// 表上沒有的（.extra）：淡黃底、圓角 12、上面多留 4、左右留 4，沒有虛線。
class _PairRowView extends StatelessWidget {
  const _PairRowView(this.row, {required this.index});

  final PairRow row;
  final int index;

  static const _male = Color(0xFF3B82C4);
  static const _female = Color(0xFFE0567E);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final lock = row.count <= 0;
    // .bp-row b（inline-flex、間隔 2）：14、行高 19，粗細照瀏覽器預設 bold；♂ ♀（.sx）特粗。
    // 基線照 Chrome（CssLine：14／19 的基線在行頂下面 14，Flutter 自己排低約 1.6）。
    // 放不下的品種名換行（設計稿 320 寬英文的「Glossy Black Dairy」），♂ ♀ 在兩行的中間（align-items: center）
    Widget name(String sex, Color color, String breed) => Row(
      children: [
        CssLine(
          TextSpan(
            text: sex,
            style: AppText.style(14, weight: FontWeight.w900, color: color, lineHeight: 19),
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: CssLine(
            TextSpan(
              text: lock ? s.gUnknownBreed : s.breedName(breed),
              style: AppText.style(
                14,
                weight: FontWeight.w700,
                color: lock ? AppColors.ink3 : AppColors.ink,
                lineHeight: 19,
              ),
            ),
            wrap: true,
          ),
        ),
      ],
    );
    final hint = lock ? s.s09PairNone : s.s09PairCount(n: row.count) + (row.extra ? s.gSep + s.s09PairExtra : '');
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: row.extra ? 4 : 0),
      child: Row(
        children: [
          _ParentPic(breed: row.sire, bull: true, lock: lock),
          const SizedBox(width: 2),
          // .bp-x：16 特粗、行高 20、左右留 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              '×',
              style: AppText.style(16, weight: FontWeight.w900, color: AppColors.ink2, lineHeight: 20),
            ),
          ),
          const SizedBox(width: 2),
          _ParentPic(breed: row.dam, bull: false, lock: lock),
          // 間隔 2，加上 .grow 的 margin-left 6
          const SizedBox(width: 2 + 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name('♂', _male, row.sire),
                name('♀', _female, row.dam),
                Text(hint, style: KitText.hint()),
              ],
            ),
          ),
        ],
      ),
    );
    final key = Key('pair-row-$index');
    if (row.extra) {
      return Container(
        key: key,
        margin: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(color: Color(0xFFFFF6D6), borderRadius: BorderRadius.all(Radius.circular(12))),
        child: content,
      );
    }
    if (index == 0) return KeyedSubtree(key: key, child: content);
    return CustomPaint(
      key: key,
      painter: const DashedTopLine(),
      child: Padding(padding: const EdgeInsets.only(top: 2), child: content),
    );
  }
}

/// .bp-pic：爸爸或媽媽的正面（50×45、留邊 2）；還沒配出過是深色影子。雜種牛畫乳牛體型的雜種牛
/// （跟頭像一樣；紀錄只記「雜種牛」，不知道是哪種用途）。
class _ParentPic extends StatelessWidget {
  const _ParentPic({required this.breed, required this.bull, required this.lock});

  final String breed;
  final bool bull;
  final bool lock;

  @override
  Widget build(BuildContext context) {
    final look = lookOf(breed, CowType.dairy);
    return lock
        ? CowSilhouette.dark(breed: look, bull: bull, width: 50, height: 45, pad: 2)
        : CowPicture(breed: look, bull: bull, width: 50, height: 45, pad: 2);
  }
}
