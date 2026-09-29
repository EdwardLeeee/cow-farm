// 手機版：記憶體用 ProcessInfo.currentRss，機型用 dart:ffi 直接呼叫系統的 C 函式。
//
// 不用 device_info_plus 外掛：它的 iOS 程式讀磁碟空間（NSFileSystemFreeSize，Apple 列為
// required reason API），隱私清單卻沒有宣告，上傳 App Store Connect 可能被拒。
// 這裡呼叫的 uname 與 __system_property_get 都不在 required reason API 清單裡。
// 任何一步失敗都只會少顯示機型，不影響測試。
import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io' show Platform, ProcessInfo;

import 'device_summary.dart';

typedef _MallocC = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeC = Void Function(Pointer<Void> pointer);
typedef _FreeDart = void Function(Pointer<Void> pointer);
typedef _UnameC = Int32 Function(Pointer<Uint8> buffer);
typedef _UnameDart = int Function(Pointer<Uint8> buffer);
typedef _PropGetC = Int32 Function(Pointer<Uint8> name, Pointer<Uint8> value);
typedef _PropGetDart = int Function(Pointer<Uint8> name, Pointer<Uint8> value);

/// 行程目前的常駐記憶體（RSS，位元組）。讀不到時回傳 null。
int? currentRssBytes() {
  try {
    final int rss = ProcessInfo.currentRss;
    return rss > 0 ? rss : null;
  } catch (_) {
    return null;
  }
}

DeviceSummary readDeviceSummary() {
  try {
    if (Platform.isIOS) return _readIos();
    if (Platform.isAndroid) return _readAndroid();
  } catch (_) {
    // 讀不到機型不影響測試，退回下面的通用資訊。
  }
  return DeviceSummary(model: Platform.operatingSystem, os: Platform.operatingSystemVersion);
}

/// iOS：uname() 的 machine 欄位是機型代號，例如 iPhone 14 Pro Max 是 `iPhone15,3`。
DeviceSummary _readIos() {
  final _Libc libc = _Libc(DynamicLibrary.process());
  final _UnameDart uname = libc.lib.lookupFunction<_UnameC, _UnameDart>('uname');
  // Darwin 的 struct utsname 有 5 個欄位，每個 256 bytes（_SYS_NAMELEN），machine 是第 5 個。
  const int fieldLength = 256;
  final String? machine = libc.withBuffer(fieldLength * 5, (Pointer<Uint8> buffer) {
    if (uname(buffer) != 0) return null;
    return _readCString(buffer, fieldLength * 4, fieldLength);
  });
  return DeviceSummary(
    model: machine ?? 'iPhone',
    os: 'iOS ${Platform.operatingSystemVersion}',
  );
}

/// Android：讀系統屬性 ro.product.model 等（bionic libc 的 __system_property_get）。
DeviceSummary _readAndroid() {
  final _Libc libc = _Libc(DynamicLibrary.open('libc.so'));
  final _PropGetDart get = libc.lib.lookupFunction<_PropGetC, _PropGetDart>(
    '__system_property_get',
  );
  // PROP_VALUE_MAX 是 92。
  const int valueLength = 92;
  String? prop(String name) {
    final List<int> nameBytes = utf8.encode(name);
    return libc.withBuffer(nameBytes.length + 1 + valueLength, (Pointer<Uint8> buffer) {
      for (int i = 0; i < nameBytes.length; i++) {
        buffer[i] = nameBytes[i];
      }
      buffer[nameBytes.length] = 0;
      final Pointer<Uint8> value = Pointer<Uint8>.fromAddress(
        buffer.address + nameBytes.length + 1,
      );
      value[0] = 0;
      final int length = get(buffer, value);
      if (length <= 0) return null;
      return _readCString(value, 0, valueLength);
    });
  }

  final String manufacturer = prop('ro.product.manufacturer') ?? '';
  final String model = prop('ro.product.model') ?? 'Android';
  final String release = prop('ro.build.version.release') ?? '?';
  final String sdk = prop('ro.build.version.sdk') ?? '?';
  return DeviceSummary(
    model: manufacturer.isEmpty ? model : '$manufacturer $model',
    os: 'Android $release（API $sdk）',
  );
}

class _Libc {
  _Libc(this.lib)
    : _malloc = lib.lookupFunction<_MallocC, _MallocDart>('malloc'),
      _free = lib.lookupFunction<_FreeC, _FreeDart>('free');

  final DynamicLibrary lib;
  final _MallocDart _malloc;
  final _FreeDart _free;

  T? withBuffer<T>(int size, T? Function(Pointer<Uint8> buffer) body) {
    final Pointer<Void> raw = _malloc(size);
    if (raw.address == 0) return null;
    try {
      return body(raw.cast<Uint8>());
    } finally {
      _free(raw);
    }
  }
}

String? _readCString(Pointer<Uint8> base, int offset, int maxLength) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < maxLength; i++) {
    final int b = base[offset + i];
    if (b == 0) break;
    bytes.add(b);
  }
  if (bytes.isEmpty) return null;
  return utf8.decode(bytes, allowMalformed: true);
}
