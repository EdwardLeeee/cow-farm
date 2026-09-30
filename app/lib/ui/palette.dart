import 'package:flutter/material.dart';

import '../api/models.dart';

/// 原型的顏色（只有色塊，不是正式美術）。
class Palette {
  Palette._();

  /// 行情：漲紅跌綠（台灣習慣）。
  static const up = Color(0xFFD32F2F);
  static const down = Color(0xFF2E7D32);
  static const flat = Color(0xFF616161);

  static Color change(double v) => v > 0 ? up : (v < 0 ? down : flat);

  /// 用途色塊。
  static Color type(CowType t) => switch (t) {
    CowType.dairy => const Color(0xFF90CAF9),
    CowType.dual => const Color(0xFFFFE082),
    CowType.beef => const Color(0xFFBCAAA4),
  };

  /// 稀有度色塊。
  static const tiers = [Color(0xFFE0E0E0), Color(0xFF81D4FA), Color(0xFFCE93D8), Color(0xFFFFB74D)];

  static const offline = Color(0xFFFFA000);
  static const warn = Color(0xFFE65100);
  static const card = Color(0xFFF5F5F5);
  static const unknown = Color(0xFFBDBDBD);
  static const working = Color(0xFFC5E1A5); // 在田裡工作
  static const listed = Color(0xFFFFCC80); // 借種上架中
  static const rice = Color(0xFFE6EE9C); // 稻田

  /// 評級色塊（A／B／C）。
  static Color grade(String g) => switch (g) {
    'A' => const Color(0xFFFFD54F),
    'B' => const Color(0xFFB0BEC5),
    _ => const Color(0xFFBCAAA4),
  };
}
