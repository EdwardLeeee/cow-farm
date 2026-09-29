// cow-farm 效能測試 app（用完即丟）。打開就自動跑，約 87 秒後顯示結果表。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'benchmark_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 只支援直式（Info.plist 與 AndroidManifest 也限制了）。
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '牧場測試',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6B8E23)),
      home: const BenchmarkPage(),
    );
  }
}
