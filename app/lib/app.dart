import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'state/game_model.dart';
import 'ui/home_shell.dart';

/// app 根元件。GameModel 由外面傳入，測試可以換成假資料層。
class CowFarmApp extends StatelessWidget {
  const CowFarmApp({super.key, required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameModel>.value(
      value: model,
      child: MaterialApp(
        title: S.appTitle,
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'TW'),
        theme: ThemeData(colorSchemeSeed: const Color(0xFF6D8B3A), useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}
