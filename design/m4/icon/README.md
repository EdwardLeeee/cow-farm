# app 圖示（D32：A4 娟珊）

- 使用者 2026-10-02 選了「牛臉特寫」的娟珊版（M4-ICON-02 的 A4，決策 D32）。
- 草稿、兩輪的說明圖和產生程式在 `design/artboards/m4-icon/`。這個資料夾只放實作要用的檔案。
- 圖示上不放字（遊戲名稱還沒定，D21）。

## 哪個檔給哪個平台

| 檔案 | 用在哪裡 | 規格 |
|---|---|---|
| `ios-1024.png` | iOS 的 app 圖示（Xcode 的單一尺寸 1024）；App Store 也用這張 | 1024×1024，不透明（沒有 alpha）、方角。圓角由系統切 |
| `android-前景-432.png` | Android adaptive icon 的前景層 | 432×432（108dp × 4，xxxhdpi），透明底 |
| `android-背景-432.png` | Android adaptive icon 的背景層 | 432×432，不透明 |
| `play-512.png` | Google Play 商店頁的圖示 | 512×512，不透明 |
| `web-favicon-32.png` | 內部試玩用的 Flutter 網頁版：瀏覽器分頁的小圖示 | 32×32 |
| `web-192.png`、`web-512.png` | 網頁版 manifest 的一般圖示 | 不透明 |
| `web-maskable-192.png`、`web-maskable-512.png` | 網頁版 manifest 的 maskable 圖示（`"purpose": "maskable"`） | 跟 Android 一樣的 108dp 畫布，牛在中間 |

- 網頁版只在內部試玩時用，不公開（第一版只做 iOS、Android app）。
- Android 其他密度從 432 縮：mdpi 108、hdpi 162、xhdpi 216、xxhdpi 324。

## Android 前景要留的安全範圍

- 畫布 108dp（這裡 432 px，1dp = 4 px）。各家手機把它切成圓形、圓角方形等形狀，看得到的是中間 72dp（288 px）。
- 一定不會被切掉的是中間直徑 66dp（264 px）的圓：牛的臉在這個圓裡。
- 耳朵、身體的下半部在圓外，切成圓形時會切掉一點。三種切法的樣子見 `design/artboards/m4-icon/M4-ICON-02-app圖示-A4-娟珊.png` 的「Android adaptive icon」那一格。
- 畫布外圍（72dp 以外）有多畫一圈天空、草地和牛身，手機做視差效果時不會露出空白。

## 還沒做

- Android 13 的主題圖示（單色那一層）。
- iOS 18 的深色、染色版本。

## 重新產生

在 `design/artboards/m4-icon` 底下跑 `node harness/make.mjs export A4`，用 `design/m2` 的 Playwright。

照記憶體規則：`free -m` 可用 2 GB 以上，用 `systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0` 包起來。
