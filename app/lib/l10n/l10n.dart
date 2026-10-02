import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import 'format.dart' as f;
import 'gen/strings.g.dart';

/// app 支援的語言（D25：繁中、英文、泰文）。字串在 design/m2/i18n/，由 tool/gen_l10n.dart 產生成 Dart。
enum AppLang {
  zhHant('zh-Hant', Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')),
  en('en', Locale('en')),
  th('th', Locale('th'));

  const AppLang(this.code, this.locale);

  /// 字串表的語言代碼，也是設定裡存的值。
  final String code;
  final Locale locale;

  static AppLang? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// 還沒在設定選過語言時，跟著手機語言（D25）：中文 → 繁中、泰文 → 泰文、其他 → 英文。只看第一個偏好語言。
  static AppLang forDevice(List<Locale> deviceLocales) => switch (deviceLocales.firstOrNull?.languageCode) {
    'zh' => zhHant,
    'th' => th,
    _ => en,
  };

  /// 漲跌顏色的預設（D25）：繁中照台灣習慣漲紅跌綠；英文、泰文綠漲紅跌。設定裡可以換。
  bool get upIsRedByDefault => this == zhHant;
}

/// 把文字裡的 {名稱} 換成參數；沒給的參數留著原樣（跟設計稿 src/js/i18n.js 的 t() 一樣）。
String fillTemplate(String template, Map<String, Object> params) =>
    template.replaceAllMapped(_placeholder, (m) => params.containsKey(m[1]) ? '${params[m[1]]}' : m[0]!);

final _placeholder = RegExp(r'\{(\w+)\}');

/// 手機時區的兩個時刻差幾個日曆天（[at] 是 [now] 的前一天就是 1），決定寫「今天」「昨天」還是日期。
/// 只看年月日、用 UTC 相減：當地的兩個午夜相減，遇到夏令時間切換那天只有 23 小時，inDays 會是 0（昨天變成「今天」）。
int calendarDaysBetween(DateTime now, DateTime at) =>
    DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(at.year, at.month, at.day)).inDays;

/// 給畫面用的字串：`Strings.of(context).tabRanch`、`Strings.of(context).level(lv: 3)`。
///
/// 每個 key 一個成員（gen/strings.g.dart）；品種、特徵、星期、取名詞庫這些「依資料組 key」的字用下面的方法。
class Strings extends GeneratedStrings {
  Strings._(this.lang) : table = kStringTables[lang.code]!;

  /// 每種語言共用一個（字串表是常數，不用每次重建）。
  factory Strings.forLang(AppLang lang) => _cache.putIfAbsent(lang, () => Strings._(lang));
  static final _cache = <AppLang, Strings>{};

  final AppLang lang;

  @override
  final Map<String, String> table;

  /// 畫面上方的 Provider 提供（app.dart）。在按鈕的 onPressed 這類 build 以外的地方讀，要給 listen: false。
  static Strings of(BuildContext context, {bool listen = true}) => Provider.of<Strings>(context, listen: listen);

  @override
  String fill(String key, Map<String, Object> params) => fillTemplate(table[key]!, params);

  /// 依資料組出來的 key（例：`breed.$breed.name`）。key 不存在是程式錯誤，直接丟例外；測試會把每一組都查一遍。
  String byKey(String key, [Map<String, Object> params = const {}]) {
    final text = table[key];
    if (text == null) throw ArgumentError.value(key, 'key', '字串表沒有這個 key');
    return fillTemplate(text, params);
  }

  /// 品種名（協定的 breed 代號，跟 design/m2/src/cow/breeds.js 一樣）。
  String breedName(String breed) => byKey('breed.$breed.name');

  /// 品種的一句話介紹（圖鑑）。
  String breedIntro(String breed) => byKey('breed.$breed.intro');

  /// 「品種名 #編號」，例：荷斯坦 #12。
  String cowName(String breed, int id) => '${breedName(breed)} #$id';

  /// 特徵名：A 長毛、B 淡色、C 光澤。
  String traitName(String trait) => byKey('trait.$trait');

  /// 稀有度：0 一般、1 優良、2 稀有、3 傳說。
  String tierName(int tier) => byKey('tier$tier');

  /// 星期：0 是星期日（跟 JavaScript 的 getDay() 一樣），Dart 的 DateTime.weekday 7 也是星期日。
  String weekdayName(int day) => byKey('weekday.${day % 7}');

  /// 取名詞庫每組幾個詞（i18ncheck 檢查每種語言每組一樣多）。
  static const nameWordsPerGroup = 12;

  /// 用三組詞的編號組牧場名（「幫我想一個」、電腦牧場；協定 1.6 的 name_words），照這個語言的 namegen.pattern 接。
  String ranchNameFromWords(List<int> words) => fill('namegen.pattern', {
    'first': byKey('namegen.first.${words[0]}'),
    'second': byKey('namegen.second.${words[1]}'),
    'third': byKey('namegen.third.${words[2]}'),
  });

  /// 「幫我想一個」：三組各挑一個詞。
  String suggestRanchName(Random random) => ranchNameFromWords([
    random.nextInt(nameWordsPerGroup),
    random.nextInt(nameWordsPerGroup),
    random.nextInt(nameWordsPerGroup),
  ]);

  /// 時間長度，例：「2 天 5 小時」「2d 5h」（設計稿 i18n.js 的 dur）。0 的單位不寫；全部是 0 回傳空字串。
  String duration({int d = 0, int h = 0, int m = 0, int s = 0}) =>
      [if (d != 0) days(d: d), if (h != 0) hours(h: h), if (m != 0) minutes(m: m), if (s != 0) seconds(s: s)].join(' ');

  /// 多久以前（設計稿 i18n.js 的 ago）：給分鐘、小時或天其中一個；都沒給是「剛剛」。
  String timeAgo({int? min, int? h, int? d}) {
    if (min != null) return agoMin(n: min);
    if (h != null) return agoHour(n: h);
    if (d != null) return agoDay(n: d);
    return agoNow;
  }

  /// 日期（設計稿 i18n.js 的 dateText）：今天、昨天，或「9 月 29 日 13:05」。
  String dateTime({bool today = false, bool yesterday = false, int? month, int? day, required String time}) {
    if (today) return dateToday(time: time);
    if (yesterday) return dateYesterday(time: time);
    return dateMd(m: month!, d: day!, time: time);
  }

  /// 時刻（docs/i18n/glossary.md「格式」）：繁中 09:41、英文 9:41 AM、泰文 09:41 น.。[local] 是手機時區的時間。
  /// 時刻不在字串表裡，由 app 依語言組。數字跟 AM／PM、น. 之間用不換行空格（U+00A0），不會被拆到兩行。
  String clock(DateTime local) {
    final mm = local.minute.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    return switch (lang) {
      AppLang.zhHant => '$hh:$mm',
      AppLang.en => '${(local.hour + 11) % 12 + 1}:$mm\u00a0${local.hour < 12 ? 'AM' : 'PM'}',
      AppLang.th => '$hh:$mm\u00a0น.',
    };
  }

  /// S16-01「預計 {date} 恢復」：月、日、星期與時刻（[clock]）。[local] 是換成手機時區的時間。
  String maintenanceEta(DateTime local) => s16Eta(
    date: dateMdw(m: local.month, d: local.day, w: weekdayName(local.weekday), time: clock(local)),
  );

  /// 品種名和後面的「公／母」之間（ceo 2026-10-02）：英文、泰文加一個一般空白（Holstein Bull、โฮลสไตน์ ตัวผู้）；
  /// 繁中照設計稿不加（荷斯坦公）。兩段分開排（字級不同）的地方都用這個，不另外加字串。
  String get breedSexGap => lang == AppLang.zhHant ? '' : ' ';

  /// 用途名：乳牛、耕牛、肉牛。
  String useName(CowType type) => switch (type) {
    CowType.dairy => typeDairy,
    CowType.dual => typeDual,
    CowType.beef => typeBeef,
  };

  /// 牧場名（協定 1.6）：真人用自己取的名字；電腦用三組詞照這個語言的 namegen.pattern 組。
  /// 對方的牧場已經刪除（null）時是「已刪除的牧場」。電腦標記和 #編號由畫面另外放（設計稿把它們分開排版）。
  String ranchName(RanchRef? ranch) {
    if (ranch == null) return s18DeletedRanch;
    final words = ranch.nameWords;
    return ranch.name ?? (words != null ? ranchNameFromWords(words) : '');
  }

  /// 只有一行文字的地方（借種紀錄、通知）：電腦牧場前面加「電腦」，例「電腦 露珠溪谷牧野」。
  String ranchText(RanchRef? ranch) =>
      ranch != null && ranch.isBot ? '$botPrefix ${ranchName(ranch)}' : ranchName(ranch);

  /// #編號：player_id 補零到 4 位（#0031），超過 9999 照實顯示；公營種牛站（player_id null）沒有編號。
  static String? ranchTag(RanchRef? ranch) {
    final id = ranch?.playerId;
    return id == null ? null : '#${id.toString().padLeft(4, '0')}';
  }

  /// 商品名（牛奶、牛肉、稻米）。
  String commodity(Commodity c) => switch (c) {
    Commodity.milk => milk,
    Commodity.beef => beef,
    Commodity.rice => rice,
  };

  /// 商品的單位（瓶、公斤）。
  String unitOf(Commodity c) => switch (c) {
    Commodity.milk => unitMilk,
    Commodity.beef => unitBeef,
    Commodity.rice => unitRice,
  };

  /// 新聞的商品標籤：【牛奶】；全部商品一起漲跌的是【全部】（fixtures.js 的 newsTag）。
  String newsTag(NewsItem n) => n.commodity == null ? bothTag : commodityTag(name: commodity(n.commodity!));

  /// 新聞標題：伺服器送代碼，查字串表 `news.<code>`（協定 3.11）。字串表還沒有的新代碼回空字串，不讓畫面壞掉。
  String newsHeadline(NewsItem news) {
    final text = table['news.${news.code}'];
    return text == null ? '' : fillTemplate(text, {for (final e in news.params.entries) e.key: '${e.value}'});
  }

  /// 倒數的時間長度（現實時間的秒數，無條件進位）：不到 1 分鐘寫秒，不到 1 小時寫分，不到 1 天寫時分，其他寫天時。
  String countdown(double seconds) {
    final s = seconds.ceil().clamp(0, 1 << 31);
    if (s < 60) return duration(s: s);
    final m = (s / 60).ceil();
    if (m < 60) return duration(m: m);
    if (m < 24 * 60) return duration(h: m ~/ 60, m: m % 60);
    final h = (m / 60).ceil();
    return duration(d: h ~/ 24, h: h % 24);
  }

  /// 錯誤碼 → 給玩家看的字（協定 1.4 的「app 文案」欄）。不顯示伺服器的 message。
  /// [gameNow]、[timeScale] 用來把 not_yet_available 的 open_at 換成現實時間的倒數。
  /// unauthorized、signed_in_elsewhere、account_*、maintenance 是整頁狀態（S15-03、S14-05、S13、S14、S16-01），
  /// 這裡只給萬一變成提示條時的通用字。
  String errorText(String code, {Map<String, dynamic> detail = const {}, double? gameNow, double timeScale = 1}) {
    switch (code) {
      case 'invalid_name':
        return switch (detail['reason']) {
          'too_short' => s02ErrShort,
          'too_long' => s02ErrLong,
          'emoji' => s02ErrEmoji,
          'bad_char' => s02ErrChar,
          _ => unknownError,
        };
      case 'sign_in_failed':
        return s13ToastFailed;
      case 'not_enough_coins':
        final need = detail['need'], have = detail['have'];
        if (need is num && have is num) return notEnoughCoins(n: f.fmt(need - have > 0 ? need - have : 0));
        return unknownError;
      case 'not_yet_available':
        final openAt = detail['open_at'];
        if (openAt is num && gameNow != null) {
          return errNotYetAvailable(time: countdown((openAt - gameNow) / (timeScale > 0 ? timeScale : 1)));
        }
        return unknownError;
      case 'pen_full':
        return penFull;
      case 'listing_not_found' || 'listing_gone':
        return errListingGone;
      case 'price_changed':
        return s18FeeChangedTitle;
      default:
        final key = 'err.$code';
        return table.containsKey(key) ? byKey(key) : unknownError;
    }
  }

  /// 伺服器說「現在不能做」的原因（出貨、配種、借種預覽的 blockers[]）。
  String blockerText(Blocker blocker, {double? gameNow, double timeScale = 1}) =>
      errorText(blocker.code, detail: blocker.detail, gameNow: gameNow, timeScale: timeScale);

  /// 數字縮寫（頂列金幣等），見 format.dart 的 compact。
  String compact(num n, {int from = 10000}) => f.compact(n, lang, from: from);

  /// 排行榜的大數字，見 format.dart 的 compactBig。
  String compactBig(num n) => f.compactBig(n, lang);
}
