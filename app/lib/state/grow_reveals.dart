import 'dart:async';

import '../api/models.dart';
import 'settings.dart';

/// 小牛長大揭曉（v0.3 C1；協定 2.3「長大揭曉」、動畫 A-13、S03-25）：哪幾頭牛長大了、還沒在牧場頁揭曉。
///
/// 伺服器不推播（協定 2.3），app 從 state 看：玩家看過是小牛（state 裡 `stage` 是 calf）的牛，後來的 state 裡長大了，
/// 就排進來，在牧場頁一頭一頭揭曉；揭曉完（點一下、按「好」）才算看過。看過是小牛的牛記在手機上（照牧場分開）：
/// 沒開 app 的時候長大的，下次打開牧場頁時照樣揭曉（A-13：「不在 app 裡的話，下次打開牧場頁時一頭一頭播」）。
/// 揭曉的內容（品種、雜種牛）一律看伺服器的 state，不用手機的時間猜。
class GrowReveals {
  GrowReveals(this._store);

  /// 記在手機上的「看過是小牛、還沒揭曉」的牛：「牛的編號@牧場編號」用逗號連起來。
  static const key = 'cowfarm_calves_seen';

  final PrefsStore _store;
  Set<String> _seen = {};

  /// 長大了、還沒揭曉的牛（編號），照長大的時間排。
  final List<String> _queue = [];

  /// 讀手機上記的（第一次用到時讀一次）。收到 state 之前要等它讀完，才知道沒開 app 的時候誰長大了。
  late final Future<void> loaded = _load();

  Future<void> _load() async {
    try {
      final v = await _store.getString(key);
      _seen = {...?v?.split(',').where((e) => e.isNotEmpty), ..._seen};
    } catch (_) {
      // 讀不到就當作沒記過：只是少揭曉幾頭，不影響玩
    }
  }

  static String _tag(int? playerId) => '@${playerId ?? 0}';

  /// 收到新的 state：小牛記下來；看過是小牛、現在長大了的排進來；不在牧場裡的（出貨了）拿掉。
  void track(GameState s) {
    final tag = _tag(s.playerId);
    final cows = {for (final c in s.cows) '${c.id}': c};
    var changed = false;
    for (final k in _seen.where((k) => k.endsWith(tag)).toList()) {
      final id = k.substring(0, k.length - tag.length);
      final c = cows[id];
      if (c == null) {
        _seen.remove(k);
        _queue.remove(id);
        changed = true;
      } else if (c.stage != CowStage.calf && !_queue.contains(id)) {
        _queue.add(id);
      }
    }
    for (final c in s.cows) {
      if (c.stage == CowStage.calf && _seen.add('${c.id}$tag')) changed = true;
    }
    // 一起長大的照長大的時間、再照編號
    _queue.sort((a, b) {
      final x = cows[a]?.adultAt ?? 0, y = cows[b]?.adultAt ?? 0;
      return x != y ? x.compareTo(y) : (cows[a]?.number ?? 0).compareTo(cows[b]?.number ?? 0);
    });
    if (changed) _save();
  }

  /// 下一頭要揭曉的牛；沒有是 null。
  Cow? next(GameState? s) {
    if (s == null) return null;
    for (final id in _queue) {
      for (final c in s.cows) {
        if ('${c.id}' == id && c.stage != CowStage.calf) return c;
      }
    }
    return null;
  }

  /// 這頭揭曉完了（點一下、按「好」）：以後不再揭曉。
  void done(Object id, int? playerId) {
    _queue.remove('$id');
    if (_seen.remove('$id${_tag(playerId)}')) _save();
  }

  /// 換牧場：還沒揭曉的清掉（記在手機上的照牧場分開，新的牧場收到 state 時再排）。
  void clear() => _queue.clear();

  /// 牧場刪除了：手機上記的這個牧場的牛也不用留。
  void forget(int? playerId) {
    final tag = _tag(playerId);
    final before = _seen.length;
    _seen.removeWhere((k) => k.endsWith(tag));
    _queue.clear();
    if (_seen.length != before) _save();
  }

  void _save() => unawaited(_store.setString(key, _seen.join(',')).catchError((Object _) {}));
}
