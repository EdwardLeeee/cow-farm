import 'package:flutter/foundation.dart';

/// 伺服器網址：`--dart-define=API_BASE=http://192.168.1.10:8787`。
/// 沒給的話，網頁版用目前網頁的同一個網域（網頁由伺服器在 `/` 提供），手機用本機 8787 埠。
const _apiBaseDefine = String.fromEnvironment('API_BASE');

Uri resolveApiBase() {
  if (_apiBaseDefine.isNotEmpty) return Uri.parse(_apiBaseDefine);
  if (kIsWeb) return Uri.parse(Uri.base.origin);
  return Uri.parse('http://127.0.0.1:8787');
}
