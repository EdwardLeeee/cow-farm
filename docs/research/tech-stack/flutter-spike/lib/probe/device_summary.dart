/// 結果表上方顯示的裝置資訊。
class DeviceSummary {
  const DeviceSummary({required this.model, required this.os});

  /// 機型，例如 iOS 的 `iPhone15,3`（= iPhone 14 Pro Max）或 Android 的 `Google Pixel 8`。
  final String model;

  /// 作業系統與版本。
  final String os;

  Map<String, String> toJson() => <String, String>{'model': model, 'os': os};
}
