// 讀裝置資訊與記憶體。手機版用 dart:io＋dart:ffi，網頁版沒有這兩個函式庫，改用 stub。
export 'device_summary.dart';
export 'probe_stub.dart' if (dart.library.ffi) 'probe_native.dart';
