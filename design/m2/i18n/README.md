# 字串表（設計稿 M2）

- 日期：2026-10-01
- 負責：cow-ui（繁中）；ceo（英文、泰文，照 `docs/i18n/glossary.md`）
- 依據：D25（第一版有繁中、英文、泰文）、D27（M2 設計稿核准）

## 檔案

| 檔案 | 內容 |
|---|---|
| `zh-Hant.json` | 繁中，所有 key 的來源。一層「key → 文字」 |
| `en.json`、`th.json` | 英文、泰文，同一套 key（ceo 出） |

- key 的取法、不翻譯的字、怎麼在設計稿換語言：見上一層的 `README.md`「字串表與語言」。
- 檢查：`node design/m2/harness/i18ncheck.mjs`（牛名、新聞標題、取名詞庫跟來源一樣；程式用到的 key 都在；英文、泰文缺哪些、佔位符對不對）。

## 給 cow-app：strings.dart 要跟著改的

字串表沿用 `app/lib/l10n/strings.dart` 的 key 134 個。下面這些跟 strings.dart 不一樣，照設計稿改。

字不一樣（15 個）：

| key | strings.dart | 設計稿 |
|---|---|---|
| `networkError` | 網路不穩，稍後再試 | 網路不穩，請稍後再試 |
| `growUp` | 長大還要：{v} | 長大還要 {v} |
| `drawnTitle` | {g} 級抽到的牛 | {g} 級抽到了！ |
| `opensIn` | {v} 後開放 | {v}後開放 |
| `collected` | 收了 {v} 瓶牛奶 | 收了 {v} 瓶牛奶，放進倉庫了 |
| `noCows` | 牛舍裡還沒有牛。 | 牛舍裡還沒有牛 |
| `tooMuch` | 一次賣太多，均價會變差 | 一次賣太多，均價會變差，要不要分批？ |
| `noNews` | 目前沒有新聞 | 目前沒有新聞。 |
| `noSire` | 沒有成年公牛 | 沒有能配種的成年公牛 |
| `noDam` | 沒有成年母牛 | 沒有能配種的成年母牛 |
| `pickListing` | 先選一頭要借的公牛 | 先選一頭要借的公牛，再選自己的母牛 |
| `fieldFull` | 長滿了，快收成！ | 長滿了，快收成！收成後才會繼續長。 |
| `harvested` | 收成了 {kg} 公斤稻米 | 收成了 {kg} 公斤稻米，放進倉庫了 |
| `rankCollection` | 收藏 | 圖鑑 |
| `unknownError` | 發生錯誤，請稍後再試 | 操作失敗，請再試一次 |

參數不一樣（8 個，要改程式）：

| key | strings.dart | 設計稿 |
|---|---|---|
| `notEnoughCoins` | 金幣不夠 | 金幣不夠，還差 {n} 幣 |
| `unlistFirst` | 上架借種中，先下架才能出貨或配種 | 上架借種中（{price} 幣，跟著體重自動漲），先下架才能出貨或配種 |
| `recallFirst` | 在田裡工作，先叫回來才能出貨或配種 | 在第 {n} 塊田工作，先叫回來才能出貨或配種 |
| `breedDone` | 配種成功！ | 配種成功！{cow} 出生了 |
| `borrowed` | 借種成功！ | 借種成功！付給主人 {price} 幣 |
| `fieldName` | 第 {i} 塊田 | 第 {n} 塊田 |
| `pickOx` | 選一頭耕牛下田 | 派一頭耕牛到第 {n} 塊田 |
| `fieldExpanded` | 開了一塊新田 | 開了一塊新田（第 {n} 塊） |

- `fieldName`：strings.dart 的參數 `i` 從 0 算、字裡面 +1；字串表的 `{n}` 已經是第幾塊（從 1 算）。其他沿用的 key，佔位符名稱都跟 strings.dart 的參數一樣。

## 錯誤碼的文案

- 照錯誤文案總表（S16-03）：`err.<錯誤碼>`，例 `err.max_level`「已經是最高級了」、`err.not_yet_available`「還沒開放，{time}後再來」（ceo 2026-10-01：設計稿是規格）。
- `maxed`（已滿級）、`opensIn`（3 分後開放）留給按鈕上的字。
- 沿用的：`notEnoughCoins`、`penFull`、`networkError`（網路失敗）、`unknownError`（其他錯誤碼）。

## 「幫我想一個」的取名詞庫（ceo 2026-10-01）

- 放在字串表，app 在手機上自己組；伺服器只驗最後送出的名字。
- key：`namegen.first.0`–`namegen.first.11`、`namegen.second.0`–`11`、`namegen.third.0`–`11`，接法 `namegen.pattern`（繁中 `{first}{second}{third}`）。
- 繁中的詞照 `backend/server/data/ranch_words.json` 的順序（`i18ncheck` 會檢查）。英文、泰文由 ceo 選詞和接法：每組一樣 12 個，接出來的名字寬度不超過 16（`i18ncheck` 會算最長的組合）。
  - ceo 的接法：英文 `{first}{second} {third}`（例 Fernbrook Farm），泰文 `{third}{first}{second}`（例 ฟาร์มแสงเช้าริมน้ำ），跟 en.json、th.json 一起出。

## 名字的寬度（D23；ceo 2026-10-01 定的算法）

伺服器、app、`i18ncheck` 都用同一套，逐個 Unicode 字元算：
- 類別是 Mn、Me、Cf 的算 0：泰文的上下標記號（例 ั ี ่ ้ ์）屬於 Mn，玩家看到的是一個字。
- East Asian Width 是 W 或 F 的算 2：中文字和全形符號。
- 其他算 1：英文字母、數字、泰文的子音和母音。
- 名字總共 2–16。例：「ฟาร์ม」5 個字元，์ 算 0，寬度 4；「晨光河畔牧場」12；「MorningRiverFarm」16。

設計稿的寫法在 `src/js/namewidth.js`（取名頁的字數、頂列長名字縮小都用它）。W、F 的範圍由 Python 3.10 的 `unicodedata`（Unicode 13.0，跟伺服器一樣）產生，漢字區塊補到區塊結尾；跟 Python 逐字比對 143,924 個字元，只有 2 個罕用文字的記號（U+1734、U+1171E，新版 Unicode 改了類別）不一樣。

## 電腦牧場的名字（ceo 2026-10-01）

- 伺服器存三組詞的編號；app 用玩家當下的語言，照 `namegen.pattern` 組出名字，加上「電腦」標記（`botPrefix`）和 #編號。
- 這要改協定，由 cow-back 做。設計稿先維持現在的中文名字。

## 格式類的 key（不是字，照各語言的習慣寫）

- 分隔：`g.sep`（・）、`g.listSep`（、）、`s13.footer`（「　・　」）。
- 括號標籤：`commodityTag`、`bothTag`（【】）。
- 單位與價格：`priceUnit`、`g.pricePer`、`estAvgValue`（幣／瓶）、`g.hourUnit`、`s09.no`（No.01）。
- 時間日期：`days`、`hours`、`minutes`、`seconds`、`ago.*`、`date.*`、`weekday.*`。
- `s13.del.word`：刪除牧場時要輸入的字（繁中「刪除」），`s13.del.prompt` 會帶入它。
- 數字縮寫不用翻：繁中用「萬」「億」，英文、泰文用 K、M（`Intl.NumberFormat` 的 compact）。
