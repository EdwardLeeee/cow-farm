// 數字的寫法，照設計稿 design/m2/src/js/fixtures.js 的 fmt、compact、compactBig、pct。
// test/format_test.dart 拿 tool/gen_format_cases.mjs 用設計稿程式產生的對照表逐筆比。
import 'l10n.dart';

/// 千分位、固定小數位數：1234567 → 1,234,567；fmt(1.25, 1) → 1.3。三種語言都這樣寫（設計稿用 en-US 的 toLocaleString）。
String fmt(num n, [int digits = 0]) {
  final body = _roundShortest(n.toDouble().abs(), digits);
  final dot = body.indexOf('.');
  final intPart = dot < 0 ? body : body.substring(0, dot);
  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write(',');
    grouped.write(intPart[i]);
  }
  final text = '$grouped${dot < 0 ? '' : body.substring(dot)}';
  // 負數加負號；四捨五入後是 0 就不加（JavaScript 的 toLocaleString 也是）
  return n < 0 && RegExp('[1-9]').hasMatch(text) ? '-$text' : text;
}

/// 照 toLocaleString（ICU）的四捨五入：先取最短的十進位寫法（例 7.005，Dart 的 toString 也是最短寫法），
/// 再在第 [digits] 位四捨五入（.5 進位）。不能用 toStringAsFixed：它看的是二進位的真正值（7.00499…），會得到 7.00。
String _roundShortest(double v, int digits) {
  final s = v.toString();
  if (s.contains('e')) return v.toStringAsFixed(digits); // 1e21 以上或很小的數，畫面上用不到
  final dot = s.indexOf('.');
  var intPart = dot < 0 ? s : s.substring(0, dot);
  var frac = dot < 0 ? '' : s.substring(dot + 1);
  if (frac.length <= digits) {
    frac = frac.padRight(digits, '0');
  } else {
    final roundUp = frac.codeUnitAt(digits) >= 0x35; // 被捨去的第一位是 5–9
    frac = frac.substring(0, digits);
    if (roundUp) {
      final all = '$intPart$frac'.split('').map(int.parse).toList();
      var i = all.length - 1;
      for (; i >= 0 && all[i] == 9; i--) {
        all[i] = 0;
      }
      if (i >= 0) all[i]++;
      final joined = '${i < 0 ? '1' : ''}${all.join()}';
      intPart = joined.substring(0, joined.length - digits);
      frac = joined.substring(joined.length - digits);
    }
  }
  return digits == 0 ? intPart : '$intPart.$frac';
}

/// 數字縮寫（頂列金幣、牧場頁的小卡）：n 到 [from] 以上才縮寫，否則照 [fmt]。
/// - 繁中：「萬」，小數一位、無條件捨去，例 1234567 → 123.4萬。
/// - 英文、泰文：K／M／B，小數最多一位、四捨五入，例 1234567 → 1.2M（設計稿用 Intl 的 compact）。
String compact(num n, AppLang lang, {int from = 10000}) {
  if (n < from) return fmt(n);
  if (lang != AppLang.zhHant) return _compactLatin(n);
  final tenths = (n ~/ 1000) / 10;
  return '${_stripZero(tenths.toStringAsFixed(1))}萬';
}

/// 排行榜的大數字：
/// - 繁中：一億以上寫「億」（小數一位）、一百萬以上寫「萬」（四捨五入到整數萬），其他照 [fmt]。
/// - 英文、泰文：一百萬以上用 K／M／B，其他照 [fmt]。
String compactBig(num n, AppLang lang) {
  if (lang != AppLang.zhHant) return n >= 1e6 ? _compactLatin(n) : fmt(n);
  if (n >= 1e8) return '${(n / 1e8).toStringAsFixed(1)}億';
  if (n >= 1e6) return '${fmt((n / 1e4 + 0.5).floor())}萬';
  return fmt(n);
}

/// 百分比：0.123 → 12.3%；整數不寫 .0（設計稿 pct：toFixed 之後去掉結尾的 .0）。
String pct(num v, [int digits = 1]) => '${_stripZero((v * 100).toDouble().toStringAsFixed(digits))}%';

String _stripZero(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

/// 英文、泰文的縮寫（Intl compact、小數最多一位、四捨五入）：用整數算，避免 999,950 這種剛好在進位邊界的數字算錯。
String _compactLatin(num n) {
  const units = [(1000000000000, 'T'), (1000000000, 'B'), (1000000, 'M'), (1000, 'K')];
  final value = n.round();
  for (var i = 0; i < units.length; i++) {
    final (size, suffix) = units[i];
    if (value < size) continue;
    final tenths = (value * 10 + size ~/ 2) ~/ size; // 四捨五入到小數一位
    if (tenths >= 10000 && i > 0) {
      // 例 999,950 → 1000.0K，進位成 1M
      final (bigger, biggerSuffix) = units[i - 1];
      return '${_tenthsText((value * 10 + bigger ~/ 2) ~/ bigger)}$biggerSuffix';
    }
    return '${_tenthsText(tenths)}$suffix';
  }
  return fmt(value);
}

String _tenthsText(int tenths) => tenths % 10 == 0 ? '${tenths ~/ 10}' : '${tenths ~/ 10}.${tenths % 10}';

/// 收購價：10 幣以上寫 1 位小數、以下寫 2 位，後面的 0 不寫（設計稿：13.4、5.35、15）。
String priceText(double p) {
  final t = fmt(p, p.abs() < 10 ? 2 : 1);
  return t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
}
