// 牧場的大便（v0.3 第 5 節；使用者 2026-10-03 選第 13 輪 04-A 霜淇淋捲）：場景裡的大便（設計稿 poop.js）、
// 右上角的大便數（s03.js 的 dirtyPill、screens.css 的 .dirty）。點一下清一坨（A-14）、手指劃過去清好幾坨（A-15），
// 現在是兩個動畫的減少動態版：清到的大便直接消失，數字直接變少。
import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';

/// 場景裡大便的位置（poop.js 的 POOP_SPOTS：場景座標，大便的底部中間；草地上、不擋到牛）。
/// 設計稿只畫了這 9 個（都在場景左半邊）；第 10 坨以後放哪裡還沒定（問 ceo 中），先不畫，右上角的數字照樣寫全部。
const kPoopSpots = <Offset>[
  Offset(236, 398),
  Offset(252, 452),
  Offset(38, 498),
  Offset(214, 482),
  Offset(284, 472),
  Offset(362, 448),
  Offset(204, 338),
  Offset(132, 412),
  Offset(332, 490),
];

/// 場景裡一坨的寬（poop.js 的 POOP_W：圖示 poop 的 20 放大成 19）。
const kPoopWidth = 19.0;

/// 圖示 poop.svg 的 viewBox（−12 −19 24 22）：原點是底部中間。
const _viewBox = Rect.fromLTWH(-12, -19, 24, 22);

/// 一坨大便在場景裡的範圍（場景座標）：底部中間對準 [spot]。
Rect poopRect(Offset spot) {
  const s = kPoopWidth / 20;
  return Rect.fromLTWH(
    spot.dx + _viewBox.left * s,
    spot.dy + _viewBox.top * s,
    _viewBox.width * s,
    _viewBox.height * s,
  );
}

/// 場景裡的一坨大便：畫在第 [spot] 個位置，是 [cow] 旁邊的（清的時候送這頭牛的編號，協定 2.6）。
class ScenePoop {
  const ScenePoop(this.spot, this.cow);
  final int spot;
  final Cow cow;
}

/// 哪一坨畫在哪個位置。跟牛的位置（HerdLayout）一樣記住：清掉一坨時其他的不會跳位；新的大便放進最前面的空位，
/// 剛打開時照牛的編號從第 0 個位置排起（設計稿 S03-26 的 4 坨是第 0–3 個位置）。
class PoopLayout {
  final _byCow = <String, List<int>>{};

  /// 這一坨清掉了（點到、劃過去）：那個位置空出來。
  void take(int spot) {
    for (final l in _byCow.values) {
      l.remove(spot);
    }
  }

  /// [cows] 每頭現在要畫幾坨（[count]，已經扣掉正在清的）。多出來的先拿掉最後放的，少的放進最前面的空位；
  /// 位置不夠就先不畫。
  List<ScenePoop> place(Iterable<Cow> cows, int Function(Cow) count) {
    final byKey = {for (final c in cows) c.key: c};
    _byCow.removeWhere((k, _) => !byKey.containsKey(k));
    for (final e in _byCow.entries) {
      final n = count(byKey[e.key]!);
      while (e.value.length > n) {
        e.value.removeLast();
      }
    }
    final used = {for (final l in _byCow.values) ...l};
    var free = 0;
    for (final c in [...byKey.values]..sort((a, b) => _compareId(a.id, b.id))) {
      final n = count(c);
      final l = _byCow.putIfAbsent(c.key, () => []);
      while (l.length < n) {
        while (free < kPoopSpots.length && used.contains(free)) {
          free++;
        }
        if (free == kPoopSpots.length) break;
        l.add(free);
        used.add(free);
      }
    }
    return [
      for (final e in _byCow.entries)
        for (final s in e.value) ScenePoop(s, byKey[e.key]!),
    ]..sort((a, b) => a.spot.compareTo(b.spot));
  }

  /// 換了牧場：新牧場的大便照編號重新排。
  void clear() => _byCow.clear();

  static int _compareId(Object a, Object b) => a is int && b is int ? a.compareTo(b) : '$a'.compareTo('$b');
}

/// .dirty：右上角的大便數（有大便才出現）。髒的程度超過會生病的門檻（[bad]）就變紅、加警告圖示和「會生病」；
/// 寬度小於 390 只留圖示（screens.css 的 @media (max-width: 389px)）。
class DirtPill extends StatelessWidget {
  const DirtPill({super.key, required this.count, required this.bad});

  final int count;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 390;
    const warn = Color(0xFFC2412F);
    return Container(
      key: const Key('dirt-pill'),
      height: 36,
      padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
      decoration: BoxDecoration(
        color: bad ? const Color(0xFFFFE1DC) : Colors.white,
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('poop', size: 22),
          const SizedBox(width: 4),
          // 「大便 9」：字 14 特粗、數字 16（.num），這一段行高 20
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${s.s03Poop} '),
                TextSpan(text: '$count', style: AppText.number(16, lineHeight: 20)),
              ],
            ),
            key: const Key('dirt-count'),
            softWrap: false,
            style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20),
          ),
          if (bad) ...[
            const SizedBox(width: 4 + 2),
            const AppIcon('warn', size: 16),
            if (!narrow) ...[
              const SizedBox(width: 2),
              Text(
                s.s03PoopDanger,
                softWrap: false,
                style: AppText.style(12, weight: FontWeight.w900, color: warn, lineHeight: 20),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
