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
  static const tabFields = '田地';
  static const tabBreed = '配種';
  static const tabShop = '商店';
  static const tabRecords = '紀錄';
  static const subOwnBreed = '自己配種';
  static const subStud = '借種';
  static const subCodex = '圖鑑';
  static const subRank = '排行榜';

  // ---- 牛 ----
  static const typeDairy = '乳牛';
  static const typeDual = '耕牛';
  static const typeBeef = '肉牛';
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
  static const rice = '稻米';
  static const unitMilk = '瓶';
  static const unitBeef = '公斤';
  static const unitRice = '公斤';
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

  // ---- v0.2：牛的狀態 ----
  static const badgeBred = '已配種';
  static const badgeWorking = '工作中';
  static const badgeListed = '上架中';
  static String workingIn(int field) => '在第 ${field + 1} 塊田工作';
  static String ricePerHour(String v) => '產稻米 $v 公斤／時';
  static String origin(String v) => '來源：$v';
  static String originName(String o) => switch (o) {
    'start' => '開局',
    'A' || 'B' || 'C' => '商店 $o 級',
    'breed' => '自己配種',
    'stud' => '借種',
    _ => o,
  };
  static const recallFirst = '在田裡工作，先叫回來才能出貨或配種';
  static const unlistFirst = '上架借種中，先下架才能出貨或配種';

  // ---- v0.2：倉庫 ----
  static String warehouseRice(String kg, int lots) => '稻米 $kg 公斤（$lots 批）';

  // ---- v0.2：出貨評級（S20）----
  static const shipGradeTitle = '出貨評級機率';
  static String gradeLine(String g, String pct, String value) => '$g 級 $pct　收入約 $value 幣';
  static String gradeProb(String g, String pct) => '$g 級 $pct';
  static String expectedValue(String v) => '期望收入 約 $v 幣';
  static const loadingPreview = '正在取得評級機率…';
  static String shipResultTitle(String g) => '評級：$g 級';
  static String shipResultBody(String kg, String value) => '$kg 公斤牛肉放進倉庫，現在全部賣掉約 $value 幣。';
  static const ok = '好';

  // ---- v0.2：商店等級抽牛（S19）----
  static const shopGradesTitle = '商店抽牛（只挑等級，用途、公母、稀有度隨機）';
  static String gradeButton(String g, String price) => '買 $g 級（$price 幣）';
  static const probType = '用途';
  static const probSex = '公母';
  static const probTier = '稀有度';
  static String pct(String name, String v) => '$name $v';
  static const loadingShop = '正在取得機率…';
  static String drawnTitle(String g) => '$g 級抽到的牛';
  static String drawnBody(String type, String sex, String tier, String id) => '$type・$sex・$tier（牛 #$id）';

  // ---- v0.2：田地（S17）----
  static const fieldsTitle = '田地';
  static String fieldName(int i) => '第 ${i + 1} 塊田';
  static const fieldEmpty = '空田';
  static String fieldOx(String id) => '耕牛 #$id 工作中';
  static String fieldRice(String now, String cap) => '稻米 $now / $cap 公斤';
  static String fieldRate(String v) => '每小時 $v 公斤';
  static const fieldFull = '長滿了，快收成！';
  static const assignOx = '派耕牛';
  static const recall = '叫回';
  static const noOx = '沒有能下田的成年耕牛';
  static const pickOx = '選一頭耕牛下田';
  static String harvestAll(String kg) => '收成（田裡約 $kg 公斤）';
  static String harvested(String kg) => '收成了 $kg 公斤稻米';
  static String riceStock(String kg) => '倉庫稻米 $kg 公斤';
  static String riceRate(String kg) => '全部田地每小時 $kg 公斤';
  static String expandField(String cost) => '開新田（$cost 幣）';
  static String fieldCount(int n, int max) => '田地 $n / $max 塊';
  static const assigned = '已派去田裡';
  static const recalled = '已叫回';
  static const fieldExpanded = '開了一塊新田';
  static const upFieldTitle = '開新田';

  // ---- v0.2：配種（一輩子一次）----
  static const breedFree = '費用 免費（自己的公母）';
  static const breedOnce = '每頭牛一輩子只能配種一次';
  static String typeProbLine(String v) => '小牛用途：$v';
  static String bullProbLine(String v) => '公牛機率 $v';

  // ---- v0.2：借種（S18）----
  static const studMineTitle = '我的公牛出借';
  static const studNoBull = '沒有能上架的公牛（要成年、沒配過、不在田裡）';
  static String studIncome(String v) => '借種收入累計 $v 幣';
  static String listedAt(String price) => '上架中：$price 幣';
  static const list = '上架';
  static const unlist = '下架';
  static const listedOk = '已上架';
  static const unlistedOk = '已下架';
  static const studMarketTitle = '借種市場';
  static const studEmpty = '目前沒有別人上架的公牛';
  static String studRow(String type, String tier, String price) => '$type・$tier・$price 幣';
  static String studOwner(String name) => '主人：$name';
  static const pickListing = '先選一頭要借的公牛';
  static const pickDamForStud = '選自己的母牛';
  static const noDamForStud = '沒有能配種的母牛（要成年、沒配過）';
  static String borrow(String price) => '借種（$price 幣）';
  static const borrowed = '借種成功！';
  static String studBorrowedNotice(String price) => '有人借了你的公牛，收到 $price 幣';
  static const reload = '重新整理';
}
