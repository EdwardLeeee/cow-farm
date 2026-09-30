// app 上所有給玩家看的文字都集中在這個檔案（繁體中文）。
// 之後加語言時，照 add-language 的流程把這裡換成對應的語言檔。
// 伺服器送來的文字（牧場名、新聞標題、錯誤訊息）不在這裡。

class S {
  S._();

  // ---- app ----
  static const appTitle = '牛市牧場';
  static const prototypeNote = '原型畫面：只用色塊和文字';

  // ---- 頂列 ----
  static const connecting = '連線中…';
  static String level(int lv) => 'Lv $lv';
  static String coins(String v) => '金幣 $v';
  static String gameClock(String t, String scale) => '遊戲時間 $t ・ 倍率 ×$scale';
  static const loadingFarm = '正在載入牧場…';
  static const retry = '重試';
  static const startFailed = '連不上伺服器，請確認網路後重試。';

  // ---- 分頁 ----
  static const tabRanch = '牧場';
  static const tabMarket = '市場';
  static const tabBreed = '配種';
  static const tabShop = '商店';
  static const tabCodex = '圖鑑';
  static const tabRank = '排行';

  // ---- 牛 ----
  static const typeDairy = '乳用';
  static const typeDual = '兼用';
  static const typeBeef = '肉用';
  static const bull = '公';
  static const cow = '母';
  static const tier0 = '一般';
  static const tier1 = '優良';
  static const tier2 = '稀有';
  static const tier3 = '傳說';
  static const stageCalf = '小牛';
  static const stageAdult = '成年';
  static const stageOld = '老牛';
  static String cowTitle(String id) => '牛 #$id';
  static String milkRate(String v) => '產奶 $v 瓶／時';
  static String weight(String v) => '體重 $v 公斤';
  static const noMilk = '不產奶';
  static String age(String v) => '年齡 $v';
  static const noCows = '牛舍裡還沒有牛。';

  // ---- 牧場 ----
  static const bucketTitle = '奶桶';
  static String bucketAmount(String amt, String cap) => '$amt / $cap 瓶';
  static String bucketRate(String v) => '每小時 $v 瓶';
  static const bucketFull = '奶桶滿了，快收奶！';
  static const collect = '收奶';
  static String collected(String v) => '收了 $v 瓶牛奶';
  static const warehouseTitle = '倉庫';
  static String warehouseMilk(String qty, String cap, int lots) => '牛奶 $qty / $cap 瓶（$lots 批）';
  static String warehouseFresh(String pct) => '最舊一批新鮮度 $pct';
  static String warehouseBeef(String kg, int lots) => '牛肉 $kg 公斤（$lots 批）';
  static String penSummary(int used, int slots) => '牛舍 $used / $slots 格';
  static const cowsTitle = '我的牛';

  // ---- 牛的詳細資料 ----
  static const back = '返回';
  static const ship = '出貨';
  static const shipNotAdult = '小牛還不能出貨';
  static String shipValue(String v) => '出貨估值 約 $v 幣';
  static const shipConfirmTitle = '確定出貨？';
  static String shipConfirmBody(String kg, String value) =>
      '這頭牛會變成約 $kg 公斤牛肉放進倉庫，以目前行情估值約 $value 幣。實際價格以賣出時的成交為準。';
  static const cancel = '取消';
  static const confirm = '確定';
  static String shipped(String id) => '牛 #$id 已出貨，牛肉放進倉庫了';
  static const pickForBreed = '選這頭去配種';
  static const breedReady = '可以配種';
  static String breedCooldown(String v) => '配種冷卻：$v';
  static String growUp(String v) => '長大還要：$v';
  static const bred = '已選好，請到配種頁';

  // ---- 市場 ----
  static const milk = '牛奶';
  static const beef = '牛肉';
  static const unitMilk = '瓶';
  static const unitBeef = '公斤';
  static String priceUnit(String unit) => '幣／$unit';
  static const price = '現價';
  static const change24h = '24 小時漲跌';
  static String ma24(String v) => '24 小時均價 $v';
  static const range1h = '1 小時';
  static const range1d = '1 天';
  static const range7d = '7 天';
  static const noChart = '還沒有走勢資料';
  static const newsTitle = '新聞';
  static const noNews = '目前沒有新聞';
  static const sellTitle = '賣出';
  static String sellQty(String qty, String unit) => '數量 $qty $unit';
  static String inventory(String qty, String unit) => '庫存 $qty $unit';
  static String nothingToSell(String name) => '倉庫裡沒有$name可以賣';
  static const estAvgPrice = '預估成交均價';
  static String estAvgValue(String avg, String unit) => '$avg 幣／$unit';
  static String estTotal(String v) => '預估總額 $v 幣';
  static String marketPriceNow(String v) => '市價 $v';
  static const quoting = '試算中…';
  static const tooMuch = '一次賣太多，均價會變差';
  static String sellConfirm(String qty, String unit) => '確認賣出 $qty $unit';
  static String sold(String qty, String unit, String avg, String total) =>
      '賣出 $qty $unit，均價 $avg，共 $total 幣';
  static String commodityTag(String name) => '【$name】';
  static const bothTag = '【全部】';
  static const upcomingTag = '【預告】';

  // ---- 配種 ----
  static const pickSire = '選公牛';
  static const pickDam = '選母牛';
  static const noSire = '沒有成年公牛';
  static const noDam = '沒有成年母牛';
  static const probTitle = '小牛稀有度機率';
  static String fee(String v) => '費用 $v 幣';
  static const feeFree = '費用 免費（第一次）';
  static const breed = '配種';
  static const penFull = '牛舍滿了，先擴建或出貨';
  static const notEnoughCoins = '金幣不夠';
  static const coolingDown = '冷卻中';
  static const breedDone = '配種成功！';
  static String newCalf(String id, String tier) => '新小牛 #$id（$tier）';
  static const pickBoth = '請選一頭公牛和一頭母牛';

  // ---- 商店／升級 ----
  static const buyCalfTitle = '買小牛';
  static String calfButton(String type, String sex) => '$type $sex';
  static String costCoins(String v) => '$v 幣';
  static String boughtCalf(String type, String sex) => '買了一頭$type$sex小牛';
  static const upgradesTitle = '升級';
  static const upPen = '擴建牛舍';
  static const upBucket = '加大奶桶';
  static const upWarehouse = '加大倉庫';
  static const upFresh = '冷藏設備';
  static const maxed = '已滿級';
  static String opensIn(String v) => '$v 後開放';
  static const upgraded = '升級完成';
  static String levelNow(int v) => '目前 $v 級';
  static String effectPen(String a, String b) => '$a → $b 格';
  static String effectCap(String a, String b) => '容量 $a → $b';
  static String effectFresh(String a, String b) => '保鮮 $a → $b 小時';

  // ---- 圖鑑 ----
  static const codexTitle = '圖鑑（用途 × 稀有度）';
  static const unknown = '？';
  static String codexCount(int found, int total) => '已發現 $found / $total';

  // ---- 排行榜 ----
  static const rankNetworth = '總資產';
  static const rankCollection = '收藏';
  static const rankWeekly = '本週收入';
  static const botPrefix = '電腦';
  static String myRank(String rank) => '我的名次：$rank';
  static const notRanked = '未上榜';
  static const loadFailed = '載入失敗';

  // ---- 時間 ----
  static String gameDuration(String v) => '遊戲 $v';
  static String realApprox(String v) => '現實約 $v';
  static const now = '現在';
  static String days(int d) => '$d 天';
  static String hours(int h) => '$h 小時';
  static String minutes(int m) => '$m 分';
  static String seconds(int s) => '$s 秒';

  // ---- 錯誤 ----
  static const networkError = '網路不穩，稍後再試';
  static const unknownError = '發生錯誤，請稍後再試';
}
