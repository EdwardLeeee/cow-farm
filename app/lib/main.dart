import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_game_api.dart';
import 'api/push.dart';
import 'app.dart';
import 'auth/plugin_sign_in.dart';
import 'config.dart';
import 'state/game_model.dart';
import 'state/settings.dart';
import 'storage/token_store.dart';
import 'theme/app_theme.dart';
import 'ui/kit/cow_art.dart';
import 'ui/kit/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  registerFontLicenses();
  // 先讀語言設定，第一個畫面就用對的語言。
  final prefs = SharedPrefsStore();
  final settings = SettingsController(prefs);
  await settings.load();
  await CowArt.load(); // 牛的圖的量測（cows.json），畫第一頭牛之前要有
  final base = resolveApiBase();
  // Apple／Google 登入只在設好 client ID 的手機建置有（config.dart；網頁版、沒設的建置是 none）
  final signInPlatform = resolveSignInPlatform();
  final model = GameModel(
    // 小牛長大揭曉：看過是小牛的牛記在手機上（A-13：沒開 app 的時候長大的，下次打開牧場頁時揭曉）
    prefs: prefs,
    api: HttpGameApi(base: base),
    push: WsPushClient(base: base),
    tokens: createTokenStore(),
    signInPlatform: signInPlatform,
    signIn: signInPlatform.enabled
        ? PluginSignInService(
            googleServerClientId: googleServerClientId,
            googleIosClientId: googleIosClientId.isEmpty ? null : googleIosClientId,
          )
        : null,
  );
  // app 的動畫：牧場的牛會走動、轉身（A-11、A-07），出貨播卡車（A-03）；測試裡沒有包這層
  runApp(
    AppMotion(
      enabled: true,
      child: CowFarmApp(model: model, settings: settings),
    ),
  );
  model.start();
}
