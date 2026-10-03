// 真的登入：Apple 用 sign_in_with_apple，Google 用 google_sign_in 的 Android／iOS 實作（研究筆記
// docs/research/2026-10-app-sign-in.md）。只在 [SignInPlatform] 不是 none 的建置、玩家按下登入按鈕時才用到。
//
// Google 不直接依賴 google_sign_in（app 用的那一層）：它的網頁實作一註冊就去載 accounts.google.com 的腳本，
// 網頁試玩版沒有登入也會每次連 Google。改依賴 Android、iOS 的實作和共用介面，網頁版就沒有 Google 的實作；
// 呼叫的是 google_sign_in 7.2.0 內部同一組 init、authenticate、signOut。
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'sign_in.dart';

class PluginSignInService implements SignInService {
  PluginSignInService({required this.googleServerClientId, this.googleIosClientId});

  /// 伺服器（Web）的 client ID：Google 的 ID token 要用它要（協定 5）。
  final String googleServerClientId;

  /// iOS 的 client ID（Android 不用）。
  final String? googleIosClientId;

  @override
  Future<SignInResult> signIn(SignInProvider provider, {required String nonce}) async {
    try {
      return switch (provider) {
        SignInProvider.apple => await _apple(nonce),
        SignInProvider.google => await _google(nonce),
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      return e.code == AuthorizationErrorCode.canceled ? const SignInCancelled() : const SignInFailed();
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled ? const SignInCancelled() : const SignInFailed();
    } on Exception {
      // 手機不支援（iOS 13 以下）、設定不對、平台錯誤：都當成登入失敗
      return const SignInFailed();
    }
  }

  /// Apple：每次登入各給一個 nonce，原樣寫進 identity token；scopes 空的，不要 email 和姓名。
  Future<SignInResult> _apple(String nonce) async {
    final c = await SignInWithApple.getAppleIDCredential(scopes: const [], nonce: nonce);
    final token = c.identityToken;
    if (token == null) return const SignInFailed();
    return SignInCredential(idToken: token, nonce: nonce, authorizationCode: c.authorizationCode);
  }

  /// Google：nonce 只能在 init 給，所以每次登入前用這次的 nonce 重新 init（研究筆記第 4 節方案 A）。
  /// 文件說 init 叫兩次是「未定義行為」；Android、iOS 的實作是把 nonce 換掉（讀程式推的，沒有實測），
  /// M4 實機一定要測「失敗後再按一次」「解除後再綁」，不行就找 cow-back 改方案 B。
  Future<SignInResult> _google(String nonce) async {
    final google = GoogleSignInPlatform.instance;
    await google.init(InitParameters(clientId: googleIosClientId, serverClientId: googleServerClientId, nonce: nonce));
    final result = await google.authenticate(const AuthenticateParameters());
    final token = result.authenticationTokens.idToken;
    // app 不留 Google 的登入狀態：憑證拿到就登出，下次按會重新選帳號（S14-03「換一個帳號」）
    try {
      await google.signOut(const SignOutParams());
    } on Exception {
      // 登出失敗不影響這次拿到的憑證
    }
    if (token == null) return const SignInFailed();
    return SignInCredential(idToken: token, nonce: nonce);
  }
}
