import '../api/models.dart';
import '../l10n/strings.dart';

/// 整數加千分位：1234567 → 1,234,567。
String fmtInt(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return neg ? '-$b' : '$b';
}

String fmtNum(num v, [int digits = 1]) => v.toStringAsFixed(digits);

/// 數量：整數不帶小數（1,234），有小數時留 1 位（150.5）。
String fmtQty(num v) => (v - v.roundToDouble()).abs() < 0.05 ? fmtInt(v) : fmtNum(v);

String fmtSigned(num v, [int digits = 2]) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

String fmtPct(num ratio, [int digits = 1]) => '${ratio > 0 ? '+' : ''}${(ratio * 100).toStringAsFixed(digits)}%';

String fmtPlainPct(num ratio) => '${(ratio * 100).toStringAsFixed(0)}%';

/// 機率：0.1375 → "13.8%"。
String fmtPlainPct1(num ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

/// 倍率：144 → "144"，1.5 → "1.5"。
String fmtScale(double s) => s == s.roundToDouble() ? s.round().toString() : s.toStringAsFixed(1);

/// 遊戲時間（Unix 秒）→ 台灣時間 "9/30 14:05"。
String fmtGameClock(double unixSeconds) {
  final t = DateTime.fromMillisecondsSinceEpoch((unixSeconds * 1000).round(), isUtc: true).add(const Duration(hours: 8));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
}

/// 秒數 → "1 小時 5 分"、"35 秒"。
String fmtDuration(double seconds) {
  final s = seconds.ceil();
  if (s <= 0) return S.now;
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final parts = <String>[
    if (d > 0) S.days(d),
    if (h > 0) S.hours(h),
    if (m > 0 && d == 0) S.minutes(m),
    if (sec > 0 && d == 0 && h == 0) S.seconds(sec),
  ];
  return parts.join(' ');
}

/// 遊戲時間的倒數，附現實時間：「遊戲 1 小時（現實約 25 秒）」。
String fmtCountdown(double gameSecondsLeft, double timeScale) {
  if (gameSecondsLeft <= 0) return S.now;
  final real = gameSecondsLeft / (timeScale <= 0 ? 1 : timeScale);
  return '${S.gameDuration(fmtDuration(gameSecondsLeft))}（${S.realApprox(fmtDuration(real))}）';
}

String typeName(CowType t) => switch (t) {
  CowType.dairy => S.typeDairy,
  CowType.dual => S.typeDual,
  CowType.beef => S.typeBeef,
};

String tierName(int tier) => const [S.tier0, S.tier1, S.tier2, S.tier3][tier.clamp(0, 3)];

String sexName(bool bull) => bull ? S.bull : S.cow;

String stageName(CowStage s) => switch (s) {
  CowStage.calf => S.stageCalf,
  CowStage.adult => S.stageAdult,
  CowStage.old => S.stageOld,
};

String commodityName(Commodity c) => switch (c) {
  Commodity.milk => S.milk,
  Commodity.beef => S.beef,
  Commodity.rice => S.rice,
};

String unitName(Commodity c) => switch (c) {
  Commodity.milk => S.unitMilk,
  Commodity.beef => S.unitBeef,
  Commodity.rice => S.unitRice,
};

/// 牛的一行摘要：乳牛・母・稀有。
String cowSummary(Cow c) => '${typeName(c.type)}・${sexName(c.bull)}・${tierName(c.tier)}';
