import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_game_api.dart';
import 'api/push.dart';
import 'app.dart';
import 'config.dart';
import 'state/game_model.dart';
import 'state/settings.dart';
import 'storage/token_store.dart';
import 'theme/app_theme.dart';
import 'ui/kit/cow_art.dart';
import 'ui/ranch/scene.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  registerFontLicenses();
  // 先讀語言設定，第一個畫面就用對的語言。
  final settings = SettingsController(SharedPrefsStore());
  await settings.load();
  await CowArt.load(); // 牛的圖的量測（cows.json），畫第一頭牛之前要有
  final base = resolveApiBase();
  final model = GameModel(
    api: HttpGameApi(base: base),
    push: WsPushClient(base: base),
    tokens: createTokenStore(),
  );
  // 牧場的牛會走動、轉身（A-11、A-07）；測試裡沒有包這層，牛站在原位
  runApp(
    HerdMotion(
      enabled: true,
      child: CowFarmApp(model: model, settings: settings),
    ),
  );
  model.start();
}
