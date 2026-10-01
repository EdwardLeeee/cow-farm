// 設計參數，照 M2 設計稿（使用者 2026-10-01 核准，D27）：
// design/m2/src/css/base.css 的 :root 和 kit.css。R1-A「圓潤Q版」：3px 可可色粗描邊、扁平粉彩、貼紙般的實心下陰影。
// test/theme_test.dart 會讀 base.css，顏色跟這裡不一樣就紅。

import 'package:flutter/painting.dart';

/// 顏色（base.css :root）。
abstract final class AppColors {
  static const ink = Color(0xFF4B3326); // 描邊、主要文字
  static const ink2 = Color(0xFF8A6F60); // 次要文字
  static const ink3 = Color(0xFFB29C8E); // 停用文字
  static const paper = Color(0xFFFFFBF3); // 卡片底
  static const cream = Color(0xFFFFF3DC); // 頁面底
  static const lineSoft = Color(0xFFEADCC8); // 卡片內分隔線
  static const yellow = Color(0xFFFFD45E); // 主要按鈕、等級、金幣
  static const blue = Color(0xFFA9DBFF); // 牛奶、奶桶
  static const blue2 = Color(0xFF6FBDF0);
  static const green = Color(0xFFBDE8A6); // 田地、稻米、成功
  static const green2 = Color(0xFF7CC76A);
  static const pink = Color(0xFFFFD0DE); // 配種
  static const coral = Color(0xFFFF9784); // 牧場、提醒
  static const orange = Color(0xFFFFC98A); // 上架、警告
  static const redSoft = Color(0xFFFFB4AC); // 錯誤、刪除
  static const red = Color(0xFFE5484D); // base.css 的 --up（台灣慣例漲紅）
  static const deepGreen = Color(0xFF1E9A5A); // base.css 的 --down
  static const disabledBg = Color(0xFFEFE8DF);
  static const disabledLine = Color(0xFFCDBFB3);
  static const backdrop = Color.fromRGBO(46, 29, 20, 0.46); // 對話框後面的暗幕

  /// 漲跌顏色：繁中預設漲紅跌綠，英文、泰文預設綠漲紅跌（D25），設定可以換（SettingsController.upIsRed）。
  static Color up({required bool upIsRed}) => upIsRed ? red : deepGreen;
  static Color down({required bool upIsRed}) => upIsRed ? deepGreen : red;
}

/// 尺寸（base.css、kit.css）。
abstract final class AppSizes {
  static const hudHeight = 52.0; // 頂列
  static const tabBarHeight = 62.0; // 底部分頁列
  static const border = 3.0; // 粗描邊（kit.css 的 3px solid var(--ink)）
  static const pagePadding = 12.0; // 內容區左右留白
  static const gap = 12.0; // 卡片之間（.stack > * + *）
  static const minTouch = 44.0; // 按鈕最小 44×44（量測規則）
}

/// 圓角（kit.css 常用的幾種）。
abstract final class AppRadii {
  static const r6 = Radius.circular(6);
  static const r10 = Radius.circular(10);
  static const r12 = Radius.circular(12);
  static const r14 = Radius.circular(14);
  static const r16 = Radius.circular(16);
  static const r18 = Radius.circular(18);
  static const r22 = Radius.circular(22);
}

/// 貼紙般的實心下陰影（kit.css：box-shadow: 0 3px 0 var(--ink)），不模糊。
abstract final class AppShadows {
  static List<BoxShadow> solid([double dy = 3]) => [BoxShadow(color: AppColors.ink, offset: Offset(0, dy))];
}

/// 文字：Noto Sans TC 可變字型完整版，泰文接在後面用 Noto Sans Thai（英文字母、數字跟繁中一樣，設計稿 README）。
/// 粗細同時設 fontWeight 和 FontVariation.weight：Flutter 3.47.5 在 Linux 只設 fontWeight 也會帶動可變字型，
/// 但 iPhone 沒驗過；兩個都設實測不會粗上加粗（docs/research/2026-10-cow-rendering.md 第 3 節）。
abstract final class AppText {
  static const family = 'NotoSansTC';
  static const fallback = ['NotoSansThai'];

  /// 一般文字。[lineHeight] 是 CSS 的 line-height（px），沒給就用字型預設。
  static TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double? lineHeight,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    color: color,
    height: lineHeight == null ? null : lineHeight / size,
    letterSpacing: letterSpacing,
  );

  /// 數字（base.css 的 .num）：特粗 900、等寬數字、字距 0.2。
  static TextStyle number(double size, {Color color = AppColors.ink, double? lineHeight}) => style(
    size,
    weight: FontWeight.w900,
    color: color,
    lineHeight: lineHeight,
    letterSpacing: 0.2,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
