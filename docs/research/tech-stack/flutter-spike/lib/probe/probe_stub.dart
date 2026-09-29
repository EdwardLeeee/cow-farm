import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'device_summary.dart';

/// 網頁版讀不到行程記憶體。
int? currentRssBytes() => null;

/// 網頁版只知道瀏覽器回報的平台。
DeviceSummary readDeviceSummary() =>
    DeviceSummary(model: 'Web', os: '瀏覽器（${defaultTargetPlatform.name}）');
