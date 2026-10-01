# M2 設計稿量測摘要（英文）

- 工具：`design/m2/harness/capture.mjs`（Chromium，行動裝置模式）。每個狀態在四種寬度各量一次。
- 430、390 是送核准的尺寸；360、320 只量測，問題列在下面，實作時處理。
- 量的項目：最小字級、文字被切掉、文字超出所屬的框、不該換行卻換行、文字互相重疊或被按鈕蓋住、按鈕小於 44×44、進到狀態列或 Home 指示條、橫向捲動、頁面錯誤。
- 不算問題、另外記的：跑馬燈和橫向捲動列本來就會切到；太長的名字刻意截成「…」；內容區要往下捲才看得到的部分。

## 總表

| 寬度 | 狀態數 | 最小字級 | 有問題的狀態 | 橫向捲動 | 刻意截成「…」 | 要往下捲的狀態 |
|---|---|---|---|---|---|---|
| 430×932 | 166 | 12 px | 14 | 0 | 0 | 36 |
| 390×844 | 166 | 12 px | 16 | 0 | 2 | 47 |
| 360×800 | 166 | 12 px | 40 | 0 | 4 | 52 |
| 320×568 | 166 | 12 px | 52 | 0 | 110 | 73 |

## 430×932

- **S08-01 一般：還沒選**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-03 有牛不能選：變灰加原因**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-04 機率計算中**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-05 機率計算失敗（3 秒後自動再試）**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-06 可能生出的小牛與機率（沒發現過的顯示「？」）**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-09 配種成功：小牛倒數**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-11 斷線：機率卡顯示「連線中…」**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S09-01 列表：24 格（長頁）**：文字超出框 2（例：Strawberry Cow；Taiwan Yellow Ox）
- **S09-02 全部發現**：文字超出框 4（例：Glossy Black Dairy；Black Velvet Dairy；Strawberry Cow）
- **S15-03 帳號失效**：文字被切掉 1（例：Ranch data on this phone）
- **S18-06 選了公牛和母牛：機率、費用、借種**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-09 借種成功：小牛倒數**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-10 借種失敗：公牛已經被借走**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-12 借種費變了：公牛長大，價格跟剛剛看的不一樣**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）

## 390×844

- **S02-02 取好名字：歡迎卡與開局的牛**：文字超出框 1（例：Taiwan Yellow Ox #2）
- **S08-01 一般：還沒選**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-03 有牛不能選：變灰加原因**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-04 機率計算中**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-05 機率計算失敗（3 秒後自動再試）**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-06 可能生出的小牛與機率（沒發現過的顯示「？」）**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-09 配種成功：小牛倒數**：文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-11 斷線：機率卡顯示「連線中…」**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S09-01 列表：24 格（長頁）**：文字超出框 5（例：Fluffy Holstein；Chocolate Cow；Strawberry Cow）
- **S09-02 全部發現**：文字被切掉 1（例：Glossy Black Dairy）、文字超出框 7（例：Fluffy Holstein；Glossy Black Dairy；Black Velvet Dairy）、文字互相重疊或被按鈕蓋住 5（例：Cotton Cream／Black Velve；Black Velvet Dairy／Choco；Glossy Black Dairy／按鈕:Je）
- **S14-05 舊手機：牧場已經在另一支手機登入**：文字被切掉 1（例：Your ranch is signed in ）
- **S15-03 帳號失效**：文字被切掉 1（例：Ranch data on this phone）
- **S18-06 選了公牛和母牛：機率、費用、借種**：文字超出框 1（例：6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-09 借種成功：小牛倒數**：文字超出框 1（例：6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-10 借種失敗：公牛已經被借走**：文字超出框 1（例：6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-12 借種費變了：公牛長大，價格跟剛剛看的不一樣**：文字超出框 1（例：6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）

## 360×800

- **S02-02 取好名字：歡迎卡與開局的牛**：文字超出框 2（例：Taiwan Yellow Ox #2；Bull · Grows up in 20m）
- **S03-01 一般**：文字超出框 1（例：Milk 58% full）
- **S03-02 奶桶滿了**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：100%／按鈕:Collect mi）
- **S03-03 收奶成功**：文字超出框 1（例：Milk 74% full）
- **S03-05 奶桶是 0：收奶鈕停用**：文字超出框 1（例：Milk 58% full）
- **S03-06 點一頭牛：轉正面、跳出小名片**：文字超出框 1（例：Milk 58% full）
- **S03-08 一頭牛都沒有**：文字超出框 1（例：Milk 58% full）
- **S03-09 數字最大、牛舍滿（量測用）**：文字互相重疊或被按鈕蓋住 1（例：100%／按鈕:Collect mi）
- **S03-13 往右滑：牧場的另一邊（池塘、大樹）**：文字超出框 1（例：Milk 58% full）
- **S03-14 第一次打開牧場：提示可以左右滑動（只出現一次）**：文字超出框 1（例：Milk 58% full）
- **S03-15 大新聞提示：收購價大漲（只跳出一次）**：文字超出框 1（例：Milk 58% full）
- **S04-13 耕牛：沒有空田，派不出去**：文字互相重疊或被按鈕蓋住 6（例：A／按鈕:Send to fi；41.6%／按鈕:Send to fi；B／按鈕:Send to fi）
- **S05-01 牧場頁的倉庫小卡**：文字超出框 1（例：Milk 58% full）
- **S05-02 倉庫詳細：每一批（長頁）**：文字超出框 2（例：Uncommon milk ×1.3；Legendary milk ×2.5）
- **S05-04 倉庫滿了（牛奶）**：文字超出框 2（例：Uncommon milk ×1.3；Legendary milk ×2.5）
- **S05-05 有一批牛奶快壞了（新鮮度低於 30%）**：文字超出框 2（例：Uncommon milk ×1.3；Legendary milk ×2.5）
- **S08-01 一般：還沒選**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-03 有牛不能選：變灰加原因**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-04 機率計算中**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-05 機率計算失敗（3 秒後自動再試）**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-06 可能生出的小牛與機率（沒發現過的顯示「？」）**：文字超出框 1（例：12.5%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S08-07 伺服器說不能配：原因、按鈕停用**：文字超出框 1（例：12.5%）
- **S08-09 配種成功：小牛倒數**：文字超出框 1（例：12.5%）
- **S08-11 斷線：機率卡顯示「連線中…」**：文字互相重疊或被按鈕蓋住 3（例：Taiwan Yellow Ox #2／按鈕:H；Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S09-01 列表：24 格（長頁）**：文字超出框 5（例：Fluffy Holstein；Chocolate Cow；Strawberry Cow）、文字互相重疊或被按鈕蓋住 3（例：Chocolate Cow／Strawberry；Strawberry Cow／按鈕:Chocol；Taiwan Yellow Ox／按鈕:High）
- **S09-02 全部發現**：文字被切掉 2（例：Glossy Black Dairy；Taiwan Yellow Ox）、文字超出框 8（例：Fluffy Holstein；Glossy Black Dairy；Cotton Cream）、文字互相重疊或被按鈕蓋住 8（例：Cotton Cream／Black Velve；Black Velvet Dairy／Choco；Chocolate Cow／Strawberry）
- **S10-01 升級列表**：文字互相重疊或被按鈕蓋住 1（例：Upgrade storage／按鈕:480 c）
- **S10-05 升級成功**：文字互相重疊或被按鈕蓋住 1（例：Upgrade storage／按鈕:480 c）
- **S11-01 場主升級慶祝**：文字超出框 1（例：Milk 58% full）
- **S11-05 升到 Lv2 之後：提醒備份牧場（只出現一次）**：文字超出框 1（例：Milk 12% full）
- **S14-05 舊手機：牧場已經在另一支手機登入**：文字被切掉 1（例：Your ranch is signed in ）
- **S15-01 斷線、重連中：保留畫面、按鈕停用**：文字超出框 1（例：Milk 58% full）
- **S15-02 重新連上**：文字超出框 1（例：Milk 58% full）
- **S15-03 帳號失效**：文字被切掉 1（例：Ranch data on this phone）
- **S15-04 斷線超過 60 秒：請檢查網路**：文字超出框 1（例：Milk 58% full）
- **S16-02 操作時伺服器錯誤（500）**：文字超出框 1（例：Milk 58% full）
- **S18-06 選了公牛和母牛：機率、費用、借種**：文字被切掉 1（例：6.25%）、文字超出框 2（例：6.25%；6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-09 借種成功：小牛倒數**：文字被切掉 1（例：6.25%）、文字超出框 2（例：6.25%；6.25%）
- **S18-10 借種失敗：公牛已經被借走**：文字被切掉 1（例：6.25%）、文字超出框 2（例：6.25%；6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）
- **S18-12 借種費變了：公牛長大，價格跟剛剛看的不一樣**：文字被切掉 1（例：6.25%）、文字超出框 2（例：6.25%；6.25%）、文字互相重疊或被按鈕蓋住 2（例：Strawberry Cow #12／按鈕:Je；Strawberry Cow #12／按鈕:Wa）

## 320×568

- **S02-02 取好名字：歡迎卡與開局的牛**：文字超出框 2（例：Taiwan Yellow Ox #2；Bull · Grows up in 20m）
- **S03-01 一般**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S03-02 奶桶滿了**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：100%／按鈕:Collect mi）
- **S03-03 收奶成功**：文字超出框 1（例：Milk 74% full）、文字互相重疊或被按鈕蓋住 1（例：0%／按鈕:Collect mi）
- **S03-04 倉庫滿了只收一部分**：文字互相重疊或被按鈕蓋住 1（例：30%／按鈕:Collect mi）
- **S03-05 奶桶是 0：收奶鈕停用**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：0%／按鈕:Collect mi）
- **S03-06 點一頭牛：轉正面、跳出小名片**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S03-07 牛舍清單（長頁）**：文字超出框 1（例：Weight 612 kg · Value ~1）
- **S03-08 一頭牛都沒有**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 11（例：Draw a cow in the Shop, ；Go to Shop／Collect milk；Draw a cow in the Shop, ）
- **S03-09 數字最大、牛舍滿（量測用）**：文字超出框 2（例：Milk43.8Kbtl99%；99%）
- **S03-12 收起來的那一條：奶桶滿了、奶桶是 0**：文字互相重疊或被按鈕蓋住 3（例：Full／Collect milk；100%／按鈕:Collect mi；Full／按鈕:Collect mi）
- **S03-13 往右滑：牧場的另一邊（池塘、大樹）**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S03-14 第一次打開牧場：提示可以左右滑動（只出現一次）**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S03-15 大新聞提示：收購價大漲（只跳出一次）**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 2（例：87%／按鈕:Collect mi；BBQ season kicks off／按鈕:）
- **S04-08 小牛：長大倒數**：文字被切掉 1（例：Can't ship yet）
- **S04-13 耕牛：沒有空田，派不出去**：文字互相重疊或被按鈕蓋住 2（例：Age／按鈕:Send to fi；Plowing／按鈕:Send to fi）
- **S05-01 牧場頁的倉庫小卡**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S05-02 倉庫詳細：每一批（長頁）**：文字超出框 8（例：Common milk ×1.0；Uncommon milk ×1.3；Legendary milk ×2.5）、文字互相重疊或被按鈕蓋住 1（例：Storage／按鈕:Upgrade st）
- **S05-03 空倉庫**：文字互相重疊或被按鈕蓋住 1（例：Storage／按鈕:Upgrade st）
- **S05-04 倉庫滿了（牛奶）**：文字被切掉 2（例：Common milk ×1.0；Uncommon milk ×1.3）、文字超出框 4（例：Common milk ×1.0；Uncommon milk ×1.3；Common milk ×1.0）、文字互相重疊或被按鈕蓋住 1（例：Storage／按鈕:Upgrade st）
- **S05-05 有一批牛奶快壞了（新鮮度低於 30%）**：文字超出框 8（例：Common milk ×1.0；Uncommon milk ×1.3；Legendary milk ×2.5）、文字互相重疊或被按鈕蓋住 1（例：Storage／按鈕:Upgrade st）
- **S06-16 數字最長（量測用）**：文字被切掉 1（例：All）、文字超出框 1（例：All）
- **S07-02 確認：各等級機率與收入**：文字超出框 3（例：Earn ~2,968 coins；Earn ~2,374 coins；Earn ~1,781 coins）
- **S07-03 伺服器說現在不能出貨**：文字超出框 3（例：Earn ~2,968 coins；Earn ~2,374 coins；Earn ~1,781 coins）
- **S07-05 斷線：「確定出貨」停用**：文字超出框 3（例：Earn ~2,968 coins；Earn ~2,374 coins；Earn ~1,781 coins）、文字互相重疊或被按鈕蓋住 1（例：Connecting…／Holstein #3）
- **S08-01 一般：還沒選**：文字互相重疊或被按鈕蓋住 1（例：Taiwan Yellow Ox #2／按鈕:H）
- **S08-03 有牛不能選：變灰加原因**：文字互相重疊或被按鈕蓋住 1（例：Taiwan Yellow Ox #2／按鈕:H）
- **S08-04 機率計算中**：文字互相重疊或被按鈕蓋住 1（例：Taiwan Yellow Ox #2／按鈕:H）
- **S08-05 機率計算失敗（3 秒後自動再試）**：文字互相重疊或被按鈕蓋住 1（例：Taiwan Yellow Ox #2／按鈕:H）
- **S08-06 可能生出的小牛與機率（沒發現過的顯示「？」）**：文字被切掉 1（例：12.5%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S08-07 伺服器說不能配：原因、按鈕停用**：文字被切掉 1（例：12.5%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S08-09 配種成功：小牛倒數**：文字被切掉 1（例：12.5%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S08-11 斷線：機率卡顯示「連線中…」**：文字互相重疊或被按鈕蓋住 1（例：Taiwan Yellow Ox #2／按鈕:H）
- **S09-01 列表：24 格（長頁）**：文字超出框 5（例：Fluffy Holstein；Chocolate Cow；Strawberry Cow）、文字互相重疊或被按鈕蓋住 9（例：Chocolate Cow／Strawberry；Taiwan Yellow Ox／Highlan；Fluffy Holstein／按鈕:Holst）
- **S09-02 全部發現**：文字被切掉 1（例：Glossy Black Dairy）、文字超出框 2（例：Fluffy Holstein；Glossy Black Dairy）、文字互相重疊或被按鈕蓋住 3（例：Fluffy Holstein／按鈕:Holst；Fluffy Holstein／按鈕:Jerse；Glossy Black Dairy／按鈕:Je）
- **S10-01 升級列表**：文字互相重疊或被按鈕蓋住 4（例：Expand barn／按鈕:12,150 co；Expanded ×10／按鈕:12,150 c；Upgrade bucket／按鈕:310 co）
- **S10-04 第一次擴建還沒開放（開局第 15 分鐘）**：文字互相重疊或被按鈕蓋住 2（例：Expand barn／按鈕:Opens in ；Never expanded／按鈕:Opens ）
- **S10-05 升級成功**：文字互相重疊或被按鈕蓋住 4（例：Expand barn／按鈕:12,150 co；Expanded ×10／按鈕:12,150 c；Upgrade bucket／按鈕:481 co）
- **S11-01 場主升級慶祝**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S11-05 升到 Lv2 之後：提醒備份牧場（只出現一次）**：文字超出框 1（例：Milk 12% full）、文字互相重疊或被按鈕蓋住 1（例：35%／按鈕:Collect mi）
- **S13-09 換回前再確認：現在的牧場會刪除**：文字超出框 1（例：Switch and delete curren）
- **S14-03 這個帳號沒有備份過牧場**：文字被切掉 1（例：Start a new ranch）
- **S14-05 舊手機：牧場已經在另一支手機登入**：文字被切掉 1（例：Your ranch is signed in ）
- **S15-01 斷線、重連中：保留畫面、按鈕停用**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S15-02 重新連上**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S15-03 帳號失效**：文字被切掉 1（例：Ranch data on this phone）
- **S15-04 斷線超過 60 秒：請檢查網路**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S16-02 操作時伺服器錯誤（500）**：文字超出框 1（例：Milk 58% full）、文字互相重疊或被按鈕蓋住 1（例：87%／按鈕:Collect mi）
- **S18-06 選了公牛和母牛：機率、費用、借種**：文字被切掉 1（例：6.25%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S18-09 借種成功：小牛倒數**：文字被切掉 1（例：6.25%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S18-10 借種失敗：公牛已經被借走**：文字被切掉 1（例：6.25%）、文字超出框 4（例：12.5%；6.25%；12.5%）
- **S18-12 借種費變了：公牛長大，價格跟剛剛看的不一樣**：文字被切掉 2（例：6.25%；Borrow for 1,090 coins）、文字超出框 4（例：12.5%；6.25%；12.5%）

## 缺翻譯的 key（畫面用繁中顯示）

沒有缺。

