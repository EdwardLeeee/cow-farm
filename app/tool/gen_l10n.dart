// 從 design/m2/i18n/ 的字串表（zh-Hant.json、en.json、th.json）產生 lib/l10n/gen/strings.g.dart。
// 用法（在 app/ 下）：dart run tool/gen_l10n.dart
// test/l10n_test.dart 會用同一個 generate() 再產生一次，跟 commit 進來的檔比；字串表改了卻沒重新產生，CI 會紅。
import 'dart:convert';
import 'dart:io';

/// 語言代碼 → 字串表的檔名。順序就是產生的順序；第一個（繁中）是所有 key 的來源。
const langFiles = {'zh-Hant': 'zh-Hant.json', 'en': 'en.json', 'th': 'th.json'};

/// 字串表放在設計稿（cow-ui、ceo 維護），app 不另外複製一份。
const defaultI18nDir = '../design/m2/i18n';
const outPath = 'lib/l10n/gen/strings.g.dart';

final _placeholder = RegExp(r'\{(\w+)\}');

/// 讀三種語言的字串表：語言代碼 → key → 文字。保留原本的順序和前後空白。
Map<String, Map<String, String>> loadTables([String dir = defaultI18nDir]) => {
  for (final e in langFiles.entries)
    e.key: (jsonDecode(File('$dir/${e.value}').readAsStringSync()) as Map<String, dynamic>).cast<String, String>(),
};

/// 一段文字裡的佔位符名稱（排序、不重複）。
List<String> placeholdersOf(String text) =>
    {for (final m in _placeholder.allMatches(text)) m.group(1)!}.toList()..sort();

/// 檢查三種語言的 key 集合、佔位符都一樣，產生出來的名字也不撞。回傳問題清單；空的就是沒問題。
List<String> check(Map<String, Map<String, String>> tables) {
  final problems = <String>[];
  final base = tables[langFiles.keys.first]!;
  for (final lang in langFiles.keys.skip(1)) {
    final t = tables[lang]!;
    for (final k in base.keys.where((k) => !t.containsKey(k))) {
      problems.add('$lang 少了 key：$k');
    }
    for (final k in t.keys.where((k) => !base.containsKey(k))) {
      problems.add('$lang 多了 key（繁中沒有）：$k');
    }
    for (final k in base.keys.where(t.containsKey)) {
      final a = placeholdersOf(base[k]!), b = placeholdersOf(t[k]!);
      if (a.join(',') != b.join(',')) problems.add('$lang 的 $k 佔位符跟繁中不一樣：$b，繁中是 $a');
    }
  }
  final names = <String, String>{};
  for (final k in base.keys) {
    final name = memberName(k);
    final other = names[name];
    if (other != null) problems.add('key $k 跟 $other 產生同一個名字 $name');
    names[name] = k;
    for (final p in placeholdersOf(base[k]!)) {
      if (_reserved.contains(p)) problems.add('$k 的佔位符 {$p} 是 Dart 的保留字');
    }
  }
  return problems;
}

/// key → 成員名稱：用 . 和 _ 切開，第一段照舊、後面每段開頭大寫。例：s02.suggest → s02Suggest，
/// err.not_enough_coins → errNotEnoughCoins，news.milk_up.0 → newsMilkUp0。撞到保留字或 Object 的成員就加 $。
String memberName(String key) {
  final parts = key.split(RegExp(r'[._-]')).where((p) => p.isNotEmpty).toList();
  final name = parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  return _reserved.contains(name) ? '$name\$' : name;
}

/// Dart 的保留字，以及產生的類別本身和 Object 已經用掉的名字。
const _reserved = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extends', //
  'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', //
  'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with', 'hashCode', 'runtimeType', 'toString', //
  'noSuchMethod', 'table', 'fill', 'lang',
};

/// Dart 的單引號字串：跳脫反斜線、單引號、錢字號和控制字元；其他字（中文、泰文、前後空白）照原樣。
String dartString(String s) {
  final b = StringBuffer("'");
  for (final r in s.runes) {
    switch (r) {
      case 0x5C:
        b.write(r'\\');
      case 0x27:
        b.write(r"\'");
      case 0x24:
        b.write(r'\$');
      case 0x0A:
        b.write(r'\n');
      case 0x0D:
        b.write(r'\r');
      case 0x09:
        b.write(r'\t');
      default:
        if (r < 0x20 || r == 0x7F || (r >= 0x80 && r < 0xA0)) {
          b.write('\\u{${r.toRadixString(16)}}');
        } else {
          b.writeCharCode(r);
        }
    }
  }
  b.write("'");
  return b.toString();
}

/// 把字串表產生成 Dart 程式碼。
String generate(Map<String, Map<String, String>> tables) {
  final base = tables[langFiles.keys.first]!;
  final o = StringBuffer()
    ..writeln('// dart format off')
    ..writeln('// 由 tool/gen_l10n.dart 從 design/m2/i18n/ 的 ${langFiles.values.join('、')} 產生，不要手改。')
    ..writeln('// 字串表改了以後，在 app/ 跑 `dart run tool/gen_l10n.dart`（test/l10n_test.dart 會檢查有沒有同步）。')
    ..writeln()
    ..writeln('/// 字串表：語言代碼 → key → 文字。')
    ..writeln('const Map<String, Map<String, String>> kStringTables = {');
  for (final lang in langFiles.keys) {
    o.writeln('  ${dartString(lang)}: ${_tableName(lang)},');
  }
  o
    ..writeln('};')
    ..writeln()
    ..writeln('/// 有佔位符的 key → 佔位符名稱（三種語言一樣）。')
    ..writeln('const Map<String, List<String>> kPlaceholders = {');
  for (final k in base.keys) {
    final ps = placeholdersOf(base[k]!);
    if (ps.isNotEmpty) o.writeln('  ${dartString(k)}: [${ps.map(dartString).join(', ')}],');
  }
  o.writeln('};');
  for (final lang in langFiles.keys) {
    o
      ..writeln()
      ..writeln('const Map<String, String> ${_tableName(lang)} = {');
    for (final e in tables[lang]!.entries) {
      o.writeln('  ${dartString(e.key)}: ${dartString(e.value)},');
    }
    o.writeln('};');
  }
  o
    ..writeln()
    ..writeln('/// 每個 key 一個成員：沒有佔位符的是 getter，有佔位符的是方法、佔位符是具名參數。')
    ..writeln('/// 說明文字是繁中的字。')
    ..writeln('abstract class GeneratedStrings {')
    ..writeln('  const GeneratedStrings();')
    ..writeln()
    ..writeln('  /// 這個語言的字串表。')
    ..writeln('  Map<String, String> get table;')
    ..writeln()
    ..writeln('  /// 把 key 的文字裡的 {名稱} 換成參數。')
    ..writeln('  String fill(String key, Map<String, Object> params);');
  for (final k in base.keys) {
    final ps = placeholdersOf(base[k]!);
    final doc = base[k]!.replaceAll('\n', r'\n');
    o
      ..writeln()
      ..writeln('  /// `$k`：$doc');
    if (ps.isEmpty) {
      o.writeln('  String get ${memberName(k)} => table[${dartString(k)}]!;');
    } else {
      final args = ps.map((p) => 'required Object $p').join(', ');
      final map = ps.map((p) => '${dartString(p)}: $p').join(', ');
      o.writeln('  String ${memberName(k)}({$args}) => fill(${dartString(k)}, {$map});');
    }
  }
  o.writeln('}');
  return o.toString();
}

String _tableName(String lang) => '_${memberName(lang.replaceAll('-', '_'))}';

void main(List<String> args) {
  final tables = loadTables(args.isEmpty ? defaultI18nDir : args.first);
  final problems = check(tables);
  if (problems.isNotEmpty) {
    stderr.writeln('字串表有 ${problems.length} 個問題，沒有產生：');
    for (final p in problems) {
      stderr.writeln('- $p');
    }
    exit(1);
  }
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generate(tables));
  stdout.writeln('產生 $outPath：${tables[langFiles.keys.first]!.length} 個 key × ${langFiles.length} 種語言');
}
