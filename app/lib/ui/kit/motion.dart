// app 的動畫開不開：牧場的牛走動、轉身（A-11、A-07），出貨卡車（A-03）。
import 'package:flutter/widgets.dart';

/// app 的動畫開著（main.dart 打開）。沒有包這個的時候（測試）關著：牛站在原位、出貨不播卡車，跟靜態的設計稿一樣。
/// 手機設定了「減少動態」也一樣關著（設計稿每個動畫的減少動態版）。
class AppMotion extends InheritedWidget {
  const AppMotion({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<AppMotion>()?.enabled ?? false) &&
      !MediaQuery.disableAnimationsOf(context);

  /// 按鈕的處理函式裡讀（不登記依賴）。
  static bool read(BuildContext context) =>
      (context.getInheritedWidgetOfExactType<AppMotion>()?.enabled ?? false) &&
      !(context.getInheritedWidgetOfExactType<MediaQuery>()?.data.disableAnimations ?? false);

  @override
  bool updateShouldNotify(AppMotion oldWidget) => oldWidget.enabled != enabled;
}
