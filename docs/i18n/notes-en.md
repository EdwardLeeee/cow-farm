# 英文字串表的翻譯備註

- 日期：2026-10-02
- 對象：`design/m2/i18n/en.json`（ceo 交由子代理翻譯，ceo 審過並修改）
- ceo 審查後的修改：見 PR 說明。

- 翻譯途中繁中多了 37 個 `namegen.*`（#18、#19），現在共 648 個 key。詞和接法 `{first}{second} {third}` 原樣照抄同一個資料夾裡 ceo 的 `namegen-en.json`（跟 `i18n/README.md` 的例子 Fernbrook Farm 對得上）。1,728 種組合最寬 16。
  - `s02.placeholder`、`s02.sameName` 的例子改成詞庫組得出來的 `Dawnbrook Ranch`（＝晨光河畔牧場）。
- `unitMilk` = `bottles`：同一個 key 也接在斜線後面（`priceUnit`、`estAvgValue`、`g.pricePer`、`s03.bigNewsBody`），會變成「coins/bottles」。建議 app 另開單數的 key，或用 ICU 複數。`s06.baseLine` 直接寫 coins/bottle。
- 為了避開 n=1 的複數問題：`Lots: {n}`、`Expanded ×{n}`、`Bottles in bucket: {n}`、`Collected milk: {v}`、`Milk {v}/h`；`s12.kinds` = `found`（24 found）；`s14.head` = `head`（10 head）；`s18.logKeep` 用 `{n}-day`。金額照用詞表寫 `{v} coins`，實際不會是 1。
- 設計稿把字直接接起來的地方，字串裡補了空格：`s03.penFullSuffix`、`s06.lots`、`s12.pullHint` 開頭有空格。`s18.ownerLabel` 結尾是不換行空格（ ），因為它在沒有 gap 的 flex 裡，一般空格會被吃掉。
- `commodityTag` 照指定寫 `[{name}]`，但跑馬燈（S03）和最新新聞（S06）把它跟標題直接接起來，會變成「[Milk]Schools order…」，版面要加間距。
- `appTitle` = `Bull Market Ranch`：企劃書第 11 節的英文，是暫名，正式英文名在 M4 前定（D21、D25）。
- `s13.udNote`：「繁體中文、ไทย」改寫成 Traditional Chinese、Thai。check.py 不收中文字，英文句子裡這樣寫也比較自然。
- `s02.widthRule`、`s02.errShort`、`s02.errLong` 照原意保留「中文字算 2」。
- `s20.gradeSuffix` = `grade`，接在大字 A 後面讀成「A grade」。116 px 的框可能剛好塞滿，量測時要看。
- `s05.stored`（存放 {pct}%）→ `Value {pct}%`：寫 Storage 會被看成倉庫容量。公式裡的「存放折價」寫 `storage discount`。
- `probType`（用途）→ `Role`：S19 機率表和 S04「用途：配種／出貨牛肉最多」兩處都讀得通。`s04.useBeef` 縮成 `Most beef`，因為 kv 格是 17 px、不換行。
- `s08.notFound`（沒發現過）→ `New`，badge 樣式本來就是 new。`s04.originStud`（借種）→ `Borrowed bull`。`subOwnBreed`（自己配種）→ `My cows`。`s19.segDraw`（抽牛）→ `Draw cows`。
- 耕牛在句子裡寫 ox／oxen，跟 Ox 系列牛名一致；標籤照用詞表寫 Dairy／Draft／Beef。
- 分頁名當成地點時大寫：Go to Market、Shop › Facilities、the Fields tab。ranch 一律小寫。
- `{name} Account` 的 A 大寫，因為 Apple Account、Google Account 是官方名稱。
- 照用詞表寫、但 320 寬可能擠的：`collect`（Collect milk）、`s14.newRanch`（Start a new ranch，跟 Switch account 並排）、圖鑑 12 px 格子裡的長牛名（Cotton Candy Highland）。
  - `assignOx`（派耕牛）照用詞表寫 Send to field，但放在田的卡片上有點怪，改成 Send an ox 會比較順。
- `milk`／`beef`／`rice` 是大寫的標籤，帶進句子會變成「Sell Milk」「No Milk in storage to sell」。
- 新聞：`news.rice_down.1` 拿掉「中部」，避免真實地名；`news.rice_down.2` 的公糧寫 Government rice buying。
- 時刻（09:12）由程式產生；用詞表要的 9:41 AM 要在 app 的格式處理，不在字串表。
