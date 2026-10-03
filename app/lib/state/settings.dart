import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// 手機上的偏好設定（語言、漲跌顏色、音效；牧場面板收起、提示看過了沒）。這些不是帳，伺服器不用知道。
/// 登入 token 不放這裡（T1：token 用 flutter_secure_storage，見 storage/token_store.dart）。
abstract class PrefsStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

/// 手機和網頁版：shared_preferences（iOS NSUserDefaults、Android SharedPreferences、網頁 localStorage）。
class SharedPrefsStore implements PrefsStore {
  SharedPrefsStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}

/// 測試用：存在記憶體。
class MemoryPrefsStore implements PrefsStore {
  MemoryPrefsStore([Map<String, String>? initial]) : values = {...?initial};
  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

/// 語言和漲跌顏色（S13 設定；D25）。
///
/// - 語言：還沒在設定選過時，每次打開都跟著手機語言（AppLang.forDevice）；選過以後固定用玩家選的（ceo 2026-10-02）。
/// - 漲跌顏色：還沒選過時跟著語言的預設（繁中漲紅跌綠、英文泰文綠漲紅跌）；選過以後固定。
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, {List<Locale> Function()? deviceLocales})
    : _deviceLocales = deviceLocales ?? (() => WidgetsBinding.instance.platformDispatcher.locales);

  final PrefsStore _store;
  final List<Locale> Function() _deviceLocales;

  static const langKey = 'cowfarm_lang';
  static const upColorKey = 'cowfarm_up_color';
  static const dockKey = 'cowfarm_dock_collapsed';
  static const swipeHintKey = 'cowfarm_swipe_hint_seen';
  static const bigNewsKey = 'cowfarm_big_news_seen';
  static const soundKey = 'cowfarm_sound';
  static const backupSeenKey = 'cowfarm_backup_seen';
  static const coachSeenKey = 'cowfarm_coach_seen';

  AppLang? _chosenLang;
  bool? _upIsRed;
  bool _dockCollapsed = false;
  bool _swipeHintSeen = false;
  List<String> _bigNewsSeen = [];
  bool _soundOn = true;
  bool _backupSeen = false;
  Set<String> _coachSeen = {};

  /// 打開 app 時讀一次（main.dart 在 runApp 之前呼叫，第一個畫面就是對的語言）。
  Future<void> load() async {
    _chosenLang = AppLang.fromCode(await _store.getString(langKey));
    final up = await _store.getString(upColorKey);
    _upIsRed = up == null ? null : up == 'red';
    _dockCollapsed = await _store.getString(dockKey) == '1';
    _swipeHintSeen = await _store.getString(swipeHintKey) == '1';
    final seen = await _store.getString(bigNewsKey);
    _bigNewsSeen = seen == null || seen.isEmpty ? [] : seen.split(',');
    _soundOn = await _store.getString(soundKey) != '0';
    _backupSeen = await _store.getString(backupSeenKey) == '1';
    final coach = await _store.getString(coachSeenKey);
    _coachSeen = coach == null || coach.isEmpty ? {} : coach.split(',').toSet();
    notifyListeners();
  }

  /// 現在用的語言。
  AppLang get lang => _chosenLang ?? AppLang.forDevice(_deviceLocales());

  /// 玩家在設定選過的語言；null 代表還沒選過、跟著手機。
  AppLang? get chosenLang => _chosenLang;

  Future<void> chooseLang(AppLang lang) async {
    _chosenLang = lang;
    await _store.setString(langKey, lang.code);
    notifyListeners();
  }

  /// 漲是紅色（跌是綠色）；false 是綠漲紅跌。
  bool get upIsRed => _upIsRed ?? lang.upIsRedByDefault;

  Future<void> chooseUpIsRed(bool red) async {
    _upIsRed = red;
    await _store.setString(upColorKey, red ? 'red' : 'green');
    notifyListeners();
  }

  /// 音效開著（S13-01 的開關；預設開）。app 現在還沒有音效，之後加音效時照這個決定要不要播。
  bool get soundOn => _soundOn;

  Future<void> setSoundOn(bool on) async {
    _soundOn = on;
    notifyListeners();
    await _store.setString(soundKey, on ? '1' : '0');
  }

  /// 牧場頁的面板收起來了（S03-11）。第一次打開是展開的，之後記住玩家上次的選擇（m3-backlog D27）。
  bool get dockCollapsed => _dockCollapsed;

  Future<void> setDockCollapsed(bool collapsed) async {
    _dockCollapsed = collapsed;
    notifyListeners();
    await _store.setString(dockKey, collapsed ? '1' : '0');
  }

  /// 打開過「備份牧場」頁（S13-02）：頂列齒輪的小點（G-10）就不再出現，沒備份也一樣。
  bool get backupSeen => _backupSeen;

  Future<void> markBackupSeen() async {
    if (_backupSeen) return;
    _backupSeen = true;
    notifyListeners();
    await _store.setString(backupSeenKey, '1');
  }

  /// 第一次進牧場的「左右滑動」提示看過了（S03-14，只出現一次）。
  bool get swipeHintSeen => _swipeHintSeen;

  Future<void> markSwipeHintSeen() async {
    _swipeHintSeen = true;
    notifyListeners();
    await _store.setString(swipeHintKey, '1');
  }

  /// 新手引導卡（S11-03）每張只出現一次：記在手機上，照牧場分開（刪掉牧場、開新牧場會再出一次）。
  /// [card] 是 pen（牛舍可以擴建了）或 bull（小公牛長大了）。
  bool coachSeen(String card, int? playerId) => _coachSeen.contains('$card@${playerId ?? 0}');

  Future<void> markCoachSeen(String card, int? playerId) async {
    if (!_coachSeen.add('$card@${playerId ?? 0}')) return;
    notifyListeners();
    await _store.setString(coachSeenKey, _coachSeen.join(','));
  }

  /// 大新聞提示（S03-15）每則只跳出一次：記住最近 50 則看過的新聞 id。
  bool bigNewsSeen(String id) => _bigNewsSeen.contains(id);

  Future<void> markBigNewsSeen(String id) async {
    if (_bigNewsSeen.contains(id)) return;
    _bigNewsSeen = [..._bigNewsSeen, id];
    if (_bigNewsSeen.length > 50) _bigNewsSeen = _bigNewsSeen.sublist(_bigNewsSeen.length - 50);
    notifyListeners();
    await _store.setString(bigNewsKey, _bigNewsSeen.join(','));
  }

  /// 手機的語言改了（app.dart 的 didChangeLocales 呼叫）：還沒選過語言的玩家要跟著換。
  void deviceLocalesChanged() {
    if (_chosenLang == null) notifyListeners();
  }
}
