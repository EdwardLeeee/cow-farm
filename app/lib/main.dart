import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_game_api.dart';
import 'api/push.dart';
import 'app.dart';
import 'config.dart';
import 'state/game_model.dart';
import 'storage/token_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final base = resolveApiBase();
  final model = GameModel(
    api: HttpGameApi(base: base),
    push: WsPushClient(base: base),
    tokens: createTokenStore(),
  );
  runApp(CowFarmApp(model: model));
  model.start();
}
