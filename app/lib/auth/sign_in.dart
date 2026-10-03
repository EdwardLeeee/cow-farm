// 用 Apple／Google 帳號備份、找回牧場（D22；協定第 5 節）的登入：叫出 Apple／Google 的登入畫面，拿到登入憑證。
// 憑證交給伺服器驗（協定 5.0），app 不讀裡面的資料。研究筆記：docs/research/2026-10-app-sign-in.md。
//
// 登入只在設好 client ID 的建置出現（ceo 2026-10-03）：哪種手機、能不能登入由 main.dart 用 config.dart 的
// resolveSignInPlatform() 決定，網頁版、沒填 client ID 的建置是 [SignInPlatform.none]，畫面上沒有任何登入的入口。
// 真的實作在 plugin_sign_in.dart；測試用 test/ 裡的假實作（app 本身沒有假的登入）。

/// 哪一家的帳號（協定的 `provider`）。
enum SignInProvider {
  apple('apple', 'Apple'),
  google('google', 'Google');

  const SignInProvider(this.wire, this.label);

  /// 協定的值。
  final String wire;

  /// 畫面上的名字（「使用 {name} 登入」「{name} 帳號」），不翻譯。
  final String label;

  static SignInProvider? fromWire(String v) => switch (v) {
    'apple' => SignInProvider.apple,
    'google' => SignInProvider.google,
    _ => null,
  };
}

/// 這個建置能不能登入、是哪種手機（決定有哪幾顆登入按鈕，設計稿 S13-02、S13-11）。
enum SignInPlatform {
  /// 網頁版、沒設 client ID：沒有登入（不顯示「備份牧場」、S15-03 和 S14 的「找回我的牧場」）。
  none,

  /// iPhone：Apple、Google 兩顆，Apple 在上。
  iphone,

  /// Android：只有 Google（Apple 登入在 Android 要另外設網頁登入，設計稿沒有）。
  android;

  bool get enabled => this != none;

  /// 這種手機可以用哪些帳號登入（照設計稿的順序）。
  List<SignInProvider> get providers => switch (this) {
    none => const [],
    iphone => const [SignInProvider.apple, SignInProvider.google],
    android => const [SignInProvider.google],
  };
}

/// 登入的結果。
sealed class SignInResult {
  const SignInResult();
}

/// 拿到登入憑證：原樣交給伺服器（協定 5.2、5.5）。
class SignInCredential extends SignInResult {
  const SignInCredential({required this.idToken, required this.nonce, this.authorizationCode});

  /// Apple 的 identity token、Google 的 ID token（JWT）。
  final String idToken;

  /// 這次登入用的 nonce（伺服器發的原值）。
  final String nonce;

  /// Apple 才有：伺服器拿它換 refresh token，刪除牧場、解除綁定時撤銷 Apple 登入（協定 5.2）。
  final String? authorizationCode;
}

/// 玩家自己關掉登入畫面：顯示「已取消登入」（S13-12、S14-08），不打伺服器。
class SignInCancelled extends SignInResult {
  const SignInCancelled();
}

/// 登入畫面那邊失敗（沒網路、設定不對、手機不支援）：顯示「登入失敗，請再試一次」。
class SignInFailed extends SignInResult {
  const SignInFailed();
}

/// 叫出 Apple／Google 的登入畫面。
abstract class SignInService {
  /// [nonce] 是伺服器剛發的（協定 5.1），每次登入一個，交給 Apple／Google 寫進憑證。
  Future<SignInResult> signIn(SignInProvider provider, {required String nonce});
}
