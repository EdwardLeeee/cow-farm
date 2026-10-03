import 'package:flutter/foundation.dart';

import 'auth/sign_in.dart';

/// 伺服器網址：`--dart-define=API_BASE=http://192.168.1.10:8787`。
/// 沒給的話，網頁版用目前網頁的同一個網域（網頁由伺服器在 `/` 提供），手機用本機 8787 埠。
const _apiBaseDefine = String.fromEnvironment('API_BASE');

Uri resolveApiBase() {
  if (_apiBaseDefine.isNotEmpty) return Uri.parse(_apiBaseDefine);
  if (kIsWeb) return Uri.parse(Uri.base.origin);
  return Uri.parse('http://127.0.0.1:8787');
}

/// Apple／Google 登入（備份、找回牧場；D22）的 Google client ID，M4 建好以後在建置時填：
/// - `--dart-define=GOOGLE_SERVER_CLIENT_ID=…`：伺服器（Web）的 client ID，Google 的 ID token 用它要（協定 5）。
/// - `--dart-define=GOOGLE_IOS_CLIENT_ID=…`：iOS 的 client ID（iPhone 才要）。
/// Apple 在 iPhone 上不用 client ID（用 app 的 Sign in with Apple 權限），伺服器那邊的設定由 cow-back 管。
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// 這個建置能不能用 Apple／Google 登入、是哪種手機。唯一的開關：「備份牧場」、齒輪小點（G-10）、
/// S15-03 和 S14 的「找回我的牧場」都看它（ceo 2026-10-03：只在設好 client ID 的建置顯示）。
/// - 網頁版一律不能登入（網頁試玩版）。
/// - 手機要填好 Google 的 client ID（iPhone 兩個都要）；沒填就跟網頁版一樣，沒有登入。
SignInPlatform resolveSignInPlatform() {
  if (kIsWeb || googleServerClientId.isEmpty) return SignInPlatform.none;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => googleIosClientId.isEmpty ? SignInPlatform.none : SignInPlatform.iphone,
    TargetPlatform.android => SignInPlatform.android,
    _ => SignInPlatform.none,
  };
}
