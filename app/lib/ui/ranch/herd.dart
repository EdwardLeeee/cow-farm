// 牧場靜態場景裡每頭牛的位置（第 5 步牛會走動時再重新設計，ceo 2026-10-02）。
// 規則（ceo 2026-10-02）：
// - 位置穩定：這次打開 app 期間，同一頭牛一直在同一個位置；多一頭牛拿第一個空位，少一頭牛（出貨）空出位置，其他牛不動。
//   每 5 秒校正一次 state，牛也不會跳來跳去。重新打開 app 時依牛的編號由小到大重新排。
// - 前 8 個位置就是設計稿 design/m2/src/js/scene.js 的 HERD（依設計稿的牛編號排序），設計稿那 8 頭牛會落在設計稿的位置；
//   之後的 32 個用「離已經有的位置最遠」的方式在兩個螢幕寬的草地上補（產生的腳本寫在 PR 說明），避開池塘、水槽、乾草捆。
// - 後面（上面）的牛小（0.8 倍），前面（下面）的牛大（1.0 倍），照設計稿的三排；畫的時候後面的先畫。
import '../../api/models.dart';

/// 一個位置：腳底在場景座標 (x, y)（一個螢幕 390×844，牧場兩個螢幕寬 780），朝哪邊、大小倍率（設計稿的 SCALE）。
class HerdSlot {
  const HerdSlot(this.x, this.y, {required this.right, required this.scale});
  final double x;
  final double y;
  final bool right;
  final double scale;
}

/// 牛舍最多 40 頭（pen.max_slots），位置也是 40 個。
const kHerdSlots = <HerdSlot>[
  HerdSlot(70, 420, right: true, scale: 0.9), // 設計稿 HERD
  HerdSlot(410, 334, right: true, scale: 0.8), // 設計稿 HERD
  HerdSlot(310, 422, right: false, scale: 0.9), // 設計稿 HERD
  HerdSlot(318, 338, right: false, scale: 0.8), // 設計稿 HERD
  HerdSlot(724, 552, right: false, scale: 1.0), // 設計稿 HERD
  HerdSlot(122, 522, right: true, scale: 1.0), // 設計稿 HERD
  HerdSlot(104, 344, right: true, scale: 0.8), // 設計稿 HERD
  HerdSlot(186, 424, right: true, scale: 0.9), // 設計稿 HERD
  HerdSlot(730, 336, right: false, scale: 0.8),
  HerdSlot(431, 550, right: true, scale: 1.0),
  HerdSlot(569, 380, right: true, scale: 0.841),
  HerdSlot(730, 424, right: false, scale: 0.882),
  HerdSlot(270, 512, right: false, scale: 0.964),
  HerdSlot(454, 424, right: true, scale: 0.882),
  HerdSlot(569, 550, right: true, scale: 1.0),
  HerdSlot(385, 468, right: false, scale: 0.923),
  HerdSlot(247, 380, right: false, scale: 0.841),
  HerdSlot(109, 468, right: true, scale: 0.923),
  HerdSlot(201, 550, right: false, scale: 1.0),
  HerdSlot(661, 380, right: false, scale: 0.841),
  HerdSlot(500, 336, right: true, scale: 0.8),
  HerdSlot(385, 380, right: false, scale: 0.841),
  HerdSlot(40, 512, right: true, scale: 0.964),
  HerdSlot(224, 336, right: false, scale: 0.8),
  HerdSlot(477, 380, right: true, scale: 0.841),
  HerdSlot(247, 468, right: false, scale: 0.923),
  HerdSlot(155, 380, right: true, scale: 0.841),
  HerdSlot(684, 512, right: false, scale: 0.964),
  HerdSlot(63, 380, right: true, scale: 0.841),
  HerdSlot(408, 512, right: true, scale: 0.964),
  HerdSlot(63, 550, right: true, scale: 1.0),
  HerdSlot(293, 550, right: false, scale: 1.0),
  HerdSlot(40, 336, right: true, scale: 0.8),
  HerdSlot(661, 550, right: false, scale: 1.0),
  HerdSlot(178, 512, right: true, scale: 0.964),
  HerdSlot(132, 424, right: true, scale: 0.882),
  HerdSlot(362, 424, right: false, scale: 0.882),
  HerdSlot(178, 336, right: true, scale: 0.8),
  HerdSlot(270, 336, right: false, scale: 0.8),
  HerdSlot(546, 336, right: true, scale: 0.8),
];

/// 牛 → 位置。放在 GameModel 裡，整個 app 打開期間都記得。
class HerdLayout {
  final _slotOf = <Object, int>{};

  /// 場景裡要畫的牛和它們的位置。去田裡工作的耕牛不在牧場（S03-10）。
  List<(Cow, HerdSlot)> place(Iterable<Cow> cows) {
    final here = [
      for (final c in cows)
        if (c.fieldIndex == null) c,
    ];
    final ids = {for (final c in here) c.id};
    _slotOf.removeWhere((id, _) => !ids.contains(id));
    final used = _slotOf.values.toSet();
    for (final c in [...here]..sort((a, b) => _compareId(a.id, b.id))) {
      if (_slotOf.containsKey(c.id)) continue;
      var free = 0;
      while (free < kHerdSlots.length && used.contains(free)) {
        free++;
      }
      if (free == kHerdSlots.length) break; // 位置滿了（不會發生：牛舍最多 40 頭）
      _slotOf[c.id] = free;
      used.add(free);
    }
    return [
      for (final c in here)
        if (_slotOf[c.id] case final i?) (c, kHerdSlots[i]),
    ];
  }

  static int _compareId(Object a, Object b) => a is int && b is int ? a.compareTo(b) : '$a'.compareTo('$b');
}
