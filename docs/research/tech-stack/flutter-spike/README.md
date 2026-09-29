# cowfarm_spike（用完即丟的效能測試 app）

Flame 畫 N 頭牛＋Flutter 折線圖，打開後自動跑約 87 秒，結果表直接顯示在畫面上。
設計、結果與使用者要做的事見 [`../flutter-findings.md`](../flutter-findings.md)。

本機指令（Flutter 3.47.5 裝在 `~/development/flutter`，不在 PATH 上）：

```bash
F=~/development/flutter/bin/flutter
$F pub get
$F analyze
$F test
$F build web --release --no-wasm-dry-run   # 這台筆電記憶體吃緊時，wasm 試編譯會卡住
```

- iPhone：`.github/workflows/spike-ios.yml`（手動執行，上傳 TestFlight）。
- Android：`.github/workflows/spike-android.yml`（手動執行，APK 在 run 的 artifact）。
- 只在本機快速看流程時可縮短時間：`--dart-define=SPIKE_WARMUP_SECONDS=2 --dart-define=SPIKE_PHASE_SECONDS=5`。
  正式量測一律用預設值（熱身 5 秒、每段 20 秒）。
