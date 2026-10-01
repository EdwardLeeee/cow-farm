import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// 手機上的偏好設定（語言、漲跌顏色；之後還有牧場面板收起、提示看過了沒）。這些不是帳，伺服器不用知道。
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

  AppLang? _chosenLang;
  bool? _upIsRed;

  /// 打開 app 時讀一次（main.dart 在 runApp 之前呼叫，第一個畫面就是對的語言）。
  Future<void> load() async {
    _chosenLang = AppLang.fromCode(await _store.getString(langKey));
    final up = await _store.getString(upColorKey);
    _upIsRed = up == null ? null : up == 'red';
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

  /// 手機的語言改了（app.dart 的 didChangeLocales 呼叫）：還沒選過語言的玩家要跟著換。
  void deviceLocalesChanged() {
    if (_chosenLang == null) notifyListeners();
  }
}
