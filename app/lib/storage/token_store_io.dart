import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

TokenStore createPlatformTokenStore() => SecureTokenStore();

/// 手機：iOS Keychain、Android 加密存放（研究筆記 docs/research/2026-10-app-sign-in.md 1.4）。
/// - iOS：開機後解鎖過一次就讀得到（推播、背景也能用），不會隨 iCloud 備份搬到新手機（first_unlock_this_device）。
/// - Android：AndroidManifest 關掉備份和換機轉移。
/// 換手機用 Apple／Google 帳號找回牧場（S14），不靠搬 token。
class SecureTokenStore implements TokenStore {
  SecureTokenStore()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      );
  final FlutterSecureStorage _storage;

  /// 讀不出來（例如加密金鑰不見了、Android「Failed to unwrap key」）當成沒有存：不然開機會一直卡住。
  /// 這支手機就像第一次打開，備份過的牧場可以用帳號找回。
  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      try {
        await _storage.delete(key: key);
      } on PlatformException {
        // 刪不掉也一樣當成沒有
      }
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
