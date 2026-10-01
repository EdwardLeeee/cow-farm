import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// app 的主題：頁面底色、內建字型。各元件的樣子（按鈕、卡片、頂列…）照設計稿另外做，不靠 Material 的預設。
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.yellow, surface: AppColors.cream),
  scaffoldBackgroundColor: AppColors.cream,
  fontFamily: AppText.family,
  fontFamilyFallback: AppText.fallback,
);

/// 內建字型的授權（SIL Open Font License 1.1 條件 2：每一份都要附版權聲明和授權全文），放進 app 的第三方授權頁。
/// main.dart 啟動時呼叫一次。
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in _fontLicenses) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}

const _fontLicenses = [('Noto Sans TC', 'OFL-NotoSansTC.txt'), ('Noto Sans Thai', 'OFL-NotoSansThai.txt')];
