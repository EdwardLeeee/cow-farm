import 'package:web/web.dart' as web;

import 'token_store.dart';

TokenStore createPlatformTokenStore() => LocalStorageTokenStore();

/// 網頁版（內部試玩）：存在瀏覽器 localStorage。
class LocalStorageTokenStore implements TokenStore {
  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem(key);

  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem(key, value);

  @override
  Future<void> delete(String key) async => web.window.localStorage.removeItem(key);
}
