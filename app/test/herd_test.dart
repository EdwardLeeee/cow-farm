// 牧場場景裡牛的位置（ceo 2026-10-02）：同一頭牛一直在同一個位置；多一頭牛拿第一個空位，少一頭牛空出位置，其他牛不動。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/ui/ranch/herd.dart';
import 'package:cowfarm/ui/ranch/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages/s03_cases.dart';

Cow _cow(int id, {int? field}) => Cow.fromJson(designCow(id, 'holstein', field: field));

Map<Object, HerdSlot> _slots(HerdLayout l, List<Cow> cows) => {for (final (c, s) in l.place(cows)) c.id: s};

void main() {
  test('設計稿的 8 頭牛落在設計稿的 8 個位置（依編號排）', () {
    final ids = [3, 5, 7, 8, 11, 12, 14, 15];
    final placed = _slots(HerdLayout(), [for (final id in ids) _cow(id)]);
    for (final (i, id) in ids.indexed) {
      expect(placed[id], same(kHerdSlots[i]), reason: '牛 #$id');
    }
    expect(kHerdSlots[0].x, 70, reason: '#3 在設計稿的 (70, 420)');
    expect(kHerdSlots[0].y, 420);
  });

  test('多一頭、少一頭時其他牛不動；新的牛拿第一個空位', () {
    final layout = HerdLayout();
    final herd = [
      for (final id in [3, 5, 7, 8, 11, 12, 14, 15]) _cow(id),
    ];
    final first = _slots(layout, herd);

    final more = _slots(layout, [...herd, _cow(99)]);
    for (final id in first.keys) {
      expect(more[id], same(first[id]), reason: '多一頭牛：#$id 不動');
    }
    expect(more[99], same(kHerdSlots[8]));

    // #3 出貨了：空出第 1 個位置，其他牛不動
    final fewer = _slots(layout, [...herd.where((c) => c.id != 3), _cow(99)]);
    expect(fewer.containsKey(3), isFalse);
    for (final id in first.keys.where((id) => id != 3)) {
      expect(fewer[id], same(first[id]), reason: '少一頭牛：#$id 不動');
    }
    // 下一頭新牛拿空出來的第 1 個位置，不是第 10 個
    final refill = _slots(layout, [...herd.where((c) => c.id != 3), _cow(99), _cow(100)]);
    expect(refill[100], same(kHerdSlots[0]));
    expect(refill[99], same(kHerdSlots[8]));
  });

  test('一直重算（每 5 秒校正一次）位置也不變', () {
    final layout = HerdLayout();
    final herd = [
      for (final id in [1, 2, 3, 4, 5]) _cow(id),
    ];
    final a = _slots(layout, herd);
    final b = _slots(layout, herd.reversed.toList());
    for (final id in a.keys) {
      expect(b[id], same(a[id]));
    }
  });

  test('去田裡工作的耕牛不在牧場（S03-10），也不佔位置', () {
    final placed = _slots(HerdLayout(), [_cow(1), _cow(2, field: 0), _cow(3)]);
    expect(placed.keys, [1, 3]);
    expect(placed[3], same(kHerdSlots[1]));
  });

  test('40 個位置都不一樣；畫的順序是後面（上面）的先畫', () {
    expect(kHerdSlots, hasLength(40));
    expect({for (final s in kHerdSlots) (s.x, s.y)}, hasLength(40));
    final herd = HerdLayout().place([for (var id = 1; id <= 40; id++) _cow(id)]);
    final order = RanchScene.paintOrder([for (final (c, s) in herd) SceneCow(c, s)]);
    for (var i = 1; i < order.length; i++) {
      final a = order[i - 1].slot, b = order[i].slot;
      expect(a.y < b.y || (a.y == b.y && a.x <= b.x), isTrue, reason: '第 $i 頭');
    }
    // 前大後小
    for (final s in kHerdSlots) {
      expect(s.scale, inInclusiveRange(0.8, 1.0));
    }
  });
}
