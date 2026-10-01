// 牛怎麼畫的實測腳本 5（Dart 這一邊）：讀 mathcheck.mjs 的輸出，用 Dart 算同樣的東西，數有幾筆跟 JavaScript 不一樣。
// 用法（在 spike/ 下）：dart run tool/mathcheck.dart <mathcheck.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

final _bd = ByteData(8);
double _fromHex(String h) {
  _bd.setUint64(0, int.parse(h.substring(0, 8), radix: 16) << 32 | int.parse(h.substring(8), radix: 16));
  return _bd.getFloat64(0);
}

String _hex(double v) {
  _bd.setFloat64(0, v);
  return (_bd.getUint32(0).toRadixString(16).padLeft(8, '0') + _bd.getUint32(4).toRadixString(16).padLeft(8, '0'));
}

/// JavaScript 的 Math.round：.5 一律往正無限大進位（Dart 的 round() 是遠離 0）。
double _jsRound(double v) => (v + 0.5).floorToDouble();

/// JavaScript 把數字轉字串的寫法：整數不帶 .0，-0 寫成 0。
String _jsNum(double v) {
  if (v == v.truncateToDouble() && v.abs() < 1e21) return v.toInt().toString();
  return v.toString();
}

String _f(double v) => _jsNum(_jsRound(v * 100) / 100);

void main(List<String> args) {
  final rows = (jsonDecode(File(args.first).readAsStringSync()) as List).cast<List>();
  final bad = <String, int>{'sin': 0, 'cos': 0, 'atan2': 0, 'hypot(sqrt)': 0, 'f(x)': 0, 'f(rot)': 0, 'f(rot) 差超過 0.01': 0};
  for (final row in rows) {
    final a = _fromHex(row[0] as String), x = _fromHex(row[1] as String), y = _fromHex(row[2] as String);
    if (_hex(math.sin(a)) != row[3]) bad['sin'] = bad['sin']! + 1;
    if (_hex(math.cos(a)) != row[4]) bad['cos'] = bad['cos']! + 1;
    if (_hex(math.atan2(y, x)) != row[5]) bad['atan2'] = bad['atan2']! + 1;
    if (_hex(math.sqrt(x * x + y * y)) != row[6]) bad['hypot(sqrt)'] = bad['hypot(sqrt)']! + 1;
    if (_f(x) != row[7]) bad['f(x)'] = bad['f(x)']! + 1;
    final rot = _f(x * math.cos(a) + y * math.sin(a));
    if (rot != row[8]) {
      bad['f(rot)'] = bad['f(rot)']! + 1;
      if ((double.parse(rot) - double.parse(row[8] as String)).abs() > 0.0100001) {
        bad['f(rot) 差超過 0.01'] = bad['f(rot) 差超過 0.01']! + 1;
      }
    }
  }
  stdout.writeln('筆數 ${rows.length}');
  bad.forEach((k, v) => stdout.writeln('$k 不一樣：$v（${(100 * v / rows.length).toStringAsFixed(4)}%）'));
}
