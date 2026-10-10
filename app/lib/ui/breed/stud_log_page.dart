// S18-11 借種紀錄（設計稿 s08.js 的 S18-11、S18-14、S18-15、logRow；screens.css 的 .log-row、.log-dir、.log-amt）：
// 借出、借入，新的在前，可以只看借出或借入；空的時候一張卡寫「還沒有…的紀錄」（S18-15）。資料是 GET /v1/stud/log（協定 4.6）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/page_head.dart';

class StudLogPage extends StatefulWidget {
  const StudLogPage({super.key});

  @override
  State<StudLogPage> createState() => _StudLogPageState();
}

class _StudLogPageState extends State<StudLogPage> {
  StudLog? _log;
  bool _loading = true;

  /// 0 全部、1 借出、2 借入。
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final log = await context.read<GameModel>().studLog();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _log = log ?? _log;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final log = _log;
    final entries = [
      for (final e in log?.entries ?? const <StudLogEntry>[])
        if (_filter == 0 || e.out == (_filter == 1)) e,
    ];
    final emptyStyle = AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2);
    Widget card(List<Widget> children, Key key) => AppCard(
      key: key,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    );
    return AppFrame(
      tab: AppTab.breed,
      content: ListView(
        key: const Key('stud-log'),
        padding: EdgeInsets.zero,
        children: [
          PageHead(
            title: s.s18LogTitle,
            sub: s.s18LogIncome(v: fmt(m.state?.stud.income ?? log?.incomeTotal ?? 0)),
            onBack: m.closeStudLog,
          ),
          const SizedBox(height: 12),
          FilterChips(
            labels: [s.gAll, s.s18Out, s.s18In],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 12),
          if (log == null && _loading)
            card([
              const Spinner(),
              const SizedBox(width: 8),
              Flexible(child: Text(s.gLoading, style: emptyStyle)),
            ], const Key('log-loading'))
          else if (log == null)
            card([
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
                      TextSpan(text: ' ${s.loadFailed}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(s.reload, key: const Key('log-reload'), small: true, icon: 'refresh', onPressed: _load),
            ], const Key('log-failed'))
          else if (entries.isEmpty)
            LogEmptyCard(filter: _filter)
          else
            Column(
              key: const Key('log-rows'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in entries.indexed) ...[if (i > 0) const SizedBox(height: 10), StudLogRow(entry: e)],
              ],
            ),
          const SizedBox(height: 12),
          Text(
            s.s18LogKeep(n: log?.keepDays ?? 30),
            key: const Key('log-keep'),
            textAlign: TextAlign.center,
            style: KitText.hint(),
          ),
        ],
      ),
    );
  }
}

/// 借種紀錄是空的（S18-15）：卡片裡一句，全部、借出、借入各一句（樣子跟 S18-05 的空狀態一樣）。[filter] 是 0 全部、1 借出、2 借入。
class LogEmptyCard extends StatelessWidget {
  const LogEmptyCard({super.key = const Key('log-empty'), required this.filter});

  final int filter;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Center(
          child: Text(
            switch (filter) {
              1 => s.s18LogEmptyOut,
              2 => s.s18LogEmptyIn,
              _ => s.s18LogEmpty,
            },
            textAlign: TextAlign.center,
            style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2),
          ),
        ),
      ),
    );
  }
}

/// 借種紀錄裡的牛：品種＋編號（借入的公牛沒有編號）。不加「公牛」（ceo 2026-10-02：紀錄裡的一定是公牛）。
/// 沒有品種（伺服器沒給）只寫 #編號。
String logCowText(Strings s, String breed, Object? id) {
  final n = id is int ? id : int.tryParse('${id ?? ''}');
  if (breed.isEmpty) return n == null ? '' : '#$n';
  return n == null ? s.breedName(breed) : s.cowName(breed, n);
}

/// 借入時生下的小牛：長大了寫品種＋編號；還沒長大（協定 4.6：calf.breed 是 null）寫牧場裡那頭牛現在的名字
/// （例「小乳牛 #15」），不在牧場了寫 #編號。沒有小牛是 null。
String? logCalfText(Strings s, GameModel m, StudLogEntry e) {
  if (e.calfBreed case final b? when b.isNotEmpty) return logCowText(s, b, e.calfId);
  if (e.calfId == null) return null;
  final c = m.state?.cowById('${e.calfId}');
  return c != null ? s.cowLabel(c) : '#${e.calfId}';
}

/// 紀錄裡的對方：已刪除的牧場、電腦「電腦 名字」、真人「名字 #編號」。
String logRanchText(Strings s, RanchRef? r) {
  if (r == null) return s.s18DeletedRanch;
  if (r.isBot) return s.ranchText(r);
  final tag = Strings.ranchTag(r);
  return tag == null ? s.ranchName(r) : '${s.ranchName(r)} $tag';
}

/// 遊戲時間 [t] 換成手機時區的日期時刻：今天、昨天，或「9 月 29 日 13:05」。
/// 現實時間用伺服器的：state 那一刻的 real_time，加上之後過了多久（遊戲時間 ÷ 倍率）；不看手機的時鐘。
String logWhen(Strings s, GameModel m, double t) {
  final now = m.realLocalTime(m.gameNow), at = m.realLocalTime(t);
  final days = calendarDaysBetween(now, at);
  return s.dateTime(today: days == 0, yesterday: days == 1, month: at.month, day: at.day, time: s.clock(at));
}

/// .card.log-row：左邊「借出／借入」，中間一句（誰借給誰）和日期（借入的加「生下 小牛」），右邊錢（借出綠字 +、借入 −）。
class StudLogRow extends StatelessWidget {
  const StudLogRow({super.key, required this.entry});

  final StudLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final m = context.watch<GameModel>();
    final e = entry;
    final cow = logCowText(s, e.bullBreed, e.out ? e.bullId : null);
    final ranch = logRanchText(s, e.ranch);
    final calf = logCalfText(s, m, e);
    final amt = e.out ? '+${fmt(e.price)}' : '−${fmt(e.price)}';
    // 每一列自己一個無障礙節點：不然同一個清單的幾列會併成一個，讀螢幕一口氣讀完（8790 走查看到）
    return Semantics(
      container: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // .log-dir：借出橘、借入粉紅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: e.out ? AppColors.orange : AppColors.pink,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: const BorderRadius.all(AppRadii.r10),
              ),
              child: Text(
                e.out ? s.s18Out : s.s18In,
                softWrap: false,
                style: AppText.style(12, weight: FontWeight.w900, lineHeight: 20),
              ),
            ),
            const SizedBox(width: 8),
            // .grow：名字很長、中間沒有空白時可以在任何字母之間換行（5-1）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // <b> 是外層 div（16px、行高 normal）裡的一行字：每行至少 24 高（div 的 strut），不是 b 自己的 20
                  Text(
                    e.out ? s.s18LentTo(cow: cow, ranch: ranch) : s.s18BorrowedFrom(cow: cow, ranch: ranch),
                    strutStyle: kDivStrut,
                    style: AppText.style(14, weight: FontWeight.w700, lineHeight: 20),
                  ),
                  Text(
                    calf == null
                        ? logWhen(s, m, e.time)
                        : '${logWhen(s, m, e.time)}${s.gSep}${s.s18CalfBorn(cow: calf)}',
                    style: KitText.hint(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // .log-amt：「+870 幣」，數字 16 特粗；借出的數字綠色
            Text.rich(
              TextSpan(
                style: AppText.style(12, weight: FontWeight.w700),
                children: fillSpans(
                  s.costCoins(v: '\u0000'),
                  AppText.number(16, color: e.out ? const Color(0xFF2C8A4B) : AppColors.ink),
                  amt,
                ),
              ),
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
