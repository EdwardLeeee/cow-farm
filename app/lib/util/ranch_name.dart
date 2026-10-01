// 牧場名的規則（D23；協定 2.2 節）：取名畫面（S02）的字數和「名字不能用」的提示照這裡算，跟伺服器一樣。
// 表格（name_tables.g.dart）由 tool/gen_name_tables.py 用伺服器的 backend/server/ranchname.py 逐字產生；
// 順序也照伺服器的 check()：去掉前後空白 → 逐字找第一個 emoji 或不能用的字 → 再看寬度。
import 'package:flutter/foundation.dart';

import 'name_tables.g.dart';

/// 名字不能用的原因；[code] 是協定 invalid_name 的 reason。
enum NameProblem {
  tooShort('too_short'),
  tooLong('too_long'),
  emoji('emoji'),
  badChar('bad_char');

  const NameProblem(this.code);
  final String code;
}

/// 檢查的結果。
class NameCheck {
  const NameCheck(this.name, this.width, this.problem, [this.badCodePoint]);

  /// 去掉前後空白之後的名字（送給伺服器的就是這個）。
  final String name;

  /// 顯示寬度（中文字 2、英文字母和泰文字 1、泰文上下標記號 0）；有不能用的字也照算。
  final int width;

  /// null 代表可以用。
  final NameProblem? problem;

  /// 第一個不能用的字元（emoji、bad_char 才有）。
  final int? badCodePoint;

  bool get ok => problem == null;
}

/// 一個字元的顯示寬度：0、1 或 2。
int charWidth(int codePoint) => inNameTable(kZeroWidth, codePoint)
    ? 0
    : inNameTable(kDoubleWidth, codePoint)
    ? 2
    : 1;

/// 名字的顯示寬度（不去掉空白）。
int nameWidth(String s) => _width(s.runes);

int _width(Iterable<int> codePoints) => codePoints.fold(0, (w, cp) => w + charWidth(cp));

/// 去掉前後的 Unicode White_Space，中間的保留；不做正規化。
String stripWhiteSpace(String s) {
  final cps = s.runes.toList();
  var a = 0, b = cps.length;
  while (a < b && kWhiteSpace.contains(cps[a])) {
    a++;
  }
  while (b > a && kWhiteSpace.contains(cps[b - 1])) {
    b--;
  }
  return String.fromCharCodes(cps, a, b);
}

/// 檢查玩家打的牧場名。
NameCheck checkRanchName(String raw) {
  final name = stripWhiteSpace(raw);
  final cps = name.runes.toList();
  if (cps.length > kNameMaxScan) {
    // 太長就不逐字檢查（伺服器也一樣），寬度只算前面這些字
    return NameCheck(name, _width(cps.take(kNameMaxScan)), NameProblem.tooLong);
  }
  for (final cp in cps) {
    final problem = inNameTable(kEmoji, cp)
        ? NameProblem.emoji
        : inNameTable(kBadChar, cp)
        ? NameProblem.badChar
        : null;
    if (problem != null) return NameCheck(name, _width(cps), problem, cp);
  }
  final width = _width(cps);
  if (width < kNameMinWidth) return NameCheck(name, width, NameProblem.tooShort);
  if (width > kNameMaxWidth) return NameCheck(name, width, NameProblem.tooLong);
  return NameCheck(name, width, null);
}

/// 區間表（兩個數字一組：起、迄，由小到大、不重疊）裡有沒有這個字元。二分搜尋。
@visibleForTesting
bool inNameTable(List<int> table, int codePoint) {
  var lo = 0, hi = table.length ~/ 2 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (codePoint < table[mid * 2]) {
      hi = mid - 1;
    } else if (codePoint > table[mid * 2 + 1]) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}
