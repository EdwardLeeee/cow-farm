import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

/// 斷線重連的等待時間：指數退避加隨機等待（full jitter），上限 [cap]（5 秒）。
///
/// 照 docs/protocol.md 第 4 節：第 n 次（從 0 起）等 random(0, min(5, 0.5 × 2^n)) 秒。
/// 隨機的部分讓很多手機不會在伺服器恢復的同一瞬間一起重連。最少等 [floor]，避免空轉。
class Backoff {
  Backoff({
    Random? random,
    this.base = const Duration(milliseconds: 500),
    this.cap = const Duration(seconds: 5),
    this.floor = const Duration(milliseconds: 50),
  }) : _random = random ?? Random();

  final Random _random;
  final Duration base;
  final Duration cap;
  final Duration floor;

  Duration delay(int attempt) {
    final expMs = min(cap.inMilliseconds, base.inMilliseconds * pow(2, min(attempt, 20)).toInt());
    final ms = max(floor.inMilliseconds, (_random.nextDouble() * expMs).round());
    return Duration(milliseconds: min(ms, cap.inMilliseconds));
  }
}

/// 伺服器用這個關閉碼表示 token 無效（protocol 第 4 節）。
const wsCloseUnauthorized = 4401;

/// 即時推播（行情、新聞）的介面：正式版用 [WsPushClient]，測試用假實作。
abstract class PushClient {
  /// 目前是否連著。
  ValueListenable<bool> get connected;
  Stream<PushMessage> get messages;
  void connect(String token);
  void close();
}

/// `WS /v1/ws?token=…`。伺服器每現實 1 秒推一次行情，超過 [staleAfter] 沒收到任何訊息就當作斷線重連。
class WsPushClient implements PushClient {
  WsPushClient({required this.base, Backoff? backoff, this.staleAfter = const Duration(seconds: 6)})
    : _backoff = backoff ?? Backoff();

  final Uri base;
  final Backoff _backoff;
  final Duration staleAfter;

  final _connected = ValueNotifier<bool>(false);
  final _messages = StreamController<PushMessage>.broadcast();
  WebSocketChannel? _channel;
  Timer? _watchdog;
  bool _closed = false;
  bool _running = false;
  String? _token;

  @override
  ValueListenable<bool> get connected => _connected;

  @override
  Stream<PushMessage> get messages => _messages.stream;

  Uri _wsUri(String token) {
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(scheme: scheme, path: '$basePath/v1/ws', queryParameters: {'token': token});
  }

  @override
  void connect(String token) {
    _token = token;
    _closed = false;
    if (_running) {
      _channel?.sink.close(); // 換 token：斷掉讓迴圈用新 token 重連
      return;
    }
    _running = true;
    unawaited(_loop());
  }

  Future<void> _loop() async {
    var attempt = 0;
    while (!_closed) {
      final token = _token!;
      try {
        final ch = WebSocketChannel.connect(_wsUri(token));
        _channel = ch;
        await ch.ready;
        _connected.value = true;
        attempt = 0;
        _kickWatchdog();
        await for (final raw in ch.stream) {
          _kickWatchdog();
          final msg = _parse(raw);
          if (msg != null) _messages.add(msg);
        }
        if (ch.closeCode == wsCloseUnauthorized) {
          // token 無效：不要重連，交給 app 建立新帳號（之後會用新 token 呼叫 connect）。
          _watchdog?.cancel();
          _connected.value = false;
          _running = false;
          _messages.add(PushAuthFailed(token));
          return;
        }
      } catch (e) {
        debugPrint('ws error: $e');
      }
      _watchdog?.cancel();
      _connected.value = false;
      if (_closed) break;
      await Future<void>.delayed(_backoff.delay(attempt));
      attempt++;
    }
    _running = false;
  }

  void _kickWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(staleAfter, () => _channel?.sink.close());
  }

  PushMessage? _parse(Object? raw) {
    try {
      final j = jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>));
      if (j is Map) return PushMessage.fromJson(j.cast<String, dynamic>());
    } catch (e) {
      debugPrint('ws bad message: $e');
    }
    return null;
  }

  @override
  void close() {
    _closed = true;
    _watchdog?.cancel();
    _channel?.sink.close();
    _connected.value = false;
  }
}
