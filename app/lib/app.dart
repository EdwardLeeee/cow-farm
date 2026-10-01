import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'state/game_model.dart';
import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

/// app 根元件。GameModel、SettingsController 由外面傳入，測試可以換成假資料層。
class CowFarmApp extends StatefulWidget {
  CowFarmApp({super.key, required this.model, SettingsController? settings})
    : settings = settings ?? SettingsController(MemoryPrefsStore());
  final GameModel model;
  final SettingsController settings;

  @override
  State<CowFarmApp> createState() => _CowFarmAppState();
}

class _CowFarmAppState extends State<CowFarmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 手機的語言改了：還沒在設定選過語言的玩家跟著換（D25）。
  @override
  void didChangeLocales(List<Locale>? locales) => widget.settings.deviceLocalesChanged();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameModel>.value(value: widget.model),
        ChangeNotifierProvider<SettingsController>.value(value: widget.settings),
        ProxyProvider<SettingsController, Strings>(update: (_, settings, _) => Strings.forLang(settings.lang)),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          onGenerateTitle: (context) => Strings.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: settings.lang.locale,
          supportedLocales: [for (final l in AppLang.values) l.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: appTheme(),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
