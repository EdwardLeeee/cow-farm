// 牧場名的規則跟伺服器一樣（D23；協定 2.2 節）：拿伺服器的測試向量逐筆比，再檢查區間表和查表本身。
import 'dart:convert';
import 'dart:io';

import 'package:cowfarm/util/name_tables.g.dart';
import 'package:cowfarm/util/ranch_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('伺服器的測試向量（backend/server/data/name_cases.json）每一筆都一樣', () {
    final data = jsonDecode(File('../backend/server/data/name_cases.json').readAsStringSync()) as Map<String, dynamic>;
    expect(data['unicode'], '13.0');
    final cases = (data['cases'] as List).cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final r = checkRanchName(c['name'] as String);
      final why = '${jsonEncode(c['name'])}（${c['note']}）';
      expect(r.ok, c['ok'], reason: why);
      expect(r.problem?.code, c['reason'], reason: why);
      expect(r.width, c['width'], reason: why);
    }
  });

  test('ceo 給的例子（namewidth.js 檔頭）', () {
    expect(nameWidth('ฟาร์ม'), 4);
    expect(nameWidth('晨光河畔牧場'), 12);
    expect(nameWidth('Fernbrook Farm'), 14);
    expect(nameWidth('ฟาร์มแสงเช้าริมน้ำ'), 14);
  });

  test('去掉前後空白、記下第一個不能用的字', () {
    final r = checkRanchName('　 小花牧場🐮 ');
    expect(r.name, '小花牧場🐮');
    expect(r.problem, NameProblem.emoji);
    expect(r.badCodePoint, 0x1F42E);
    expect(checkRanchName('牧‎場').problem, NameProblem.badChar, reason: '雙向控制字元');
    expect(checkRanchName('a b').problem, NameProblem.badChar, reason: '中間的換行');
    expect(checkRanchName(' ab ').ok, isTrue, reason: '前後的換行是空白，會去掉');
  });

  test('太長（超過 256 個字元）不逐字檢查，直接算太長', () {
    final long = '${'a' * 300}🐮';
    final r = checkRanchName(long);
    expect(r.problem, NameProblem.tooLong);
    expect(r.width, kNameMaxScan);
  });

  test('區間表：兩個一組、由小到大、不重疊也不相連（相連的會被合併）', () {
    for (final (name, table) in [
      ('kZeroWidth', kZeroWidth),
      ('kDoubleWidth', kDoubleWidth),
      ('kEmoji', kEmoji),
      ('kBadChar', kBadChar),
    ]) {
      expect(table.length.isEven, isTrue, reason: name);
      for (var i = 0; i < table.length; i += 2) {
        expect(table[i] <= table[i + 1], isTrue, reason: '$name 第 ${i ~/ 2} 段');
        if (i > 0) expect(table[i] > table[i - 1] + 1, isTrue, reason: '$name 第 ${i ~/ 2} 段');
      }
    }
  });

  test('查表：每一段的頭尾在裡面，前一個、後一個字元不在', () {
    for (final table in [kZeroWidth, kDoubleWidth, kEmoji, kBadChar]) {
      for (var i = 0; i < table.length; i += 2) {
        final a = table[i], b = table[i + 1];
        expect(inNameTable(table, a), isTrue);
        expect(inNameTable(table, b), isTrue);
        expect(inNameTable(table, (a + b) ~/ 2), isTrue);
        expect(inNameTable(table, a - 1), isFalse);
        expect(inNameTable(table, b + 1), isFalse);
      }
    }
  });

  test('emoji 表包含伺服器的 Extended_Pictographic 區間表', () {
    final data = jsonDecode(
      File('../backend/server/data/extended_pictographic.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final r in (data['ranges'] as List).cast<List>()) {
      final a = int.parse(r[0] as String, radix: 16), b = int.parse(r[1] as String, radix: 16);
      expect(inNameTable(kEmoji, a) && inNameTable(kEmoji, b), isTrue, reason: '${r[0]}–${r[1]}');
    }
  });
}
