import 'token_store_io.dart' if (dart.library.js_interop) 'token_store_web.dart' as platform;

/// 登入 token 與牧場名的存放處。
///
/// - 手機：`flutter_secure_storage`（iOS Keychain、Android Keystore 加密）。T1：不用 shared_preferences。
/// - 網頁版：瀏覽器的 localStorage。區網的 http 網址不是「安全環境」，瀏覽器不給 WebCrypto，
///   flutter_secure_storage 的網頁版會直接拋錯，所以網頁版不用它。網頁版只做內部試玩。
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  static const tokenKey = 'cowfarm_token';
  static const ranchKey = 'cowfarm_ranch_name';
}

/// 依平台選實作。
TokenStore createTokenStore() => platform.createPlatformTokenStore();

/// 測試用：存在記憶體。
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([Map<String, String>? initial]) : values = {...?initial};
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
