// dart format off
// 由 tool/gen_l10n.dart 從 design/m2/i18n/ 的 zh-Hant.json、en.json、th.json 產生，不要手改。
// 字串表改了以後，在 app/ 跑 `dart run tool/gen_l10n.dart`（test/l10n_test.dart 會檢查有沒有同步）。

/// 字串表：語言代碼 → key → 文字。
const Map<String, Map<String, String>> kStringTables = {
  'zh-Hant': _zhHant,
  'en': _en,
  'th': _th,
};

/// 有佔位符的 key → 佔位符名稱（三種語言一樣）。
const Map<String, List<String>> kPlaceholders = {
  'level': ['lv'],
  'hud.xp': ['pct'],
  'days': ['d'],
  'hours': ['h'],
  'minutes': ['m'],
  'seconds': ['s'],
  'ago.min': ['n'],
  'ago.hour': ['n'],
  'ago.day': ['n'],
  'date.today': ['time'],
  'date.yesterday': ['time'],
  'date.md': ['d', 'm', 'time'],
  's01.version': ['v'],
  's01.failAuto': ['n'],
  's05.milkName': ['tier'],
  's05.collectedAgo': ['ago'],
  's05.spoilIn': ['h'],
  's05.stored': ['pct'],
  's05.shippedFrom': ['cow'],
  's05.lotsOldestFirst': ['n'],
  's05.capLine': ['amount', 'pct'],
  'g.levelN': ['n'],
  's02.welcome': ['name'],
  'costCoins': ['v'],
  's02.giftBucket': ['n'],
  's02.boost': ['h', 'x'],
  's07.kgBeef': ['kg'],
  's07.beefPrice': ['price'],
  'g.grade': ['g'],
  's07.income': ['v'],
  'expectedValue': ['v'],
  's20.title': ['cow'],
  's20.gradeFormat': ['grade'],
  's20.kgIn': ['kg'],
  's20.sellAll': ['v'],
  's10.upgraded': ['effect', 'what'],
  's10.effectBottles': ['a', 'b'],
  'notEnoughCoins': ['n'],
  'g.studNoticeBody': ['cow', 'price', 'ranch'],
  'effectFresh': ['a', 'b'],
  'g.newCalf': ['cow'],
  'growUp': ['v'],
  'g.breedSex': ['breed', 'sex'],
  's19.penFull': ['slots', 'used'],
  'drawnTitle': ['g'],
  's19.drawnDraft': ['time'],
  'effectPen': ['a', 'b'],
  's10.penTimes': ['n'],
  's10.effectFresh': ['a', 'b'],
  's10.levelOf': ['max', 'n'],
  'opensIn': ['v'],
  's10.freshMax': ['h'],
  's11.earned': ['v'],
  's11.coachPenBody': ['price'],
  's03.bucketCount': ['amount'],
  's03.fullIn': ['time'],
  's03.milkUsed': ['pct'],
  'commodityTag': ['name'],
  's03.metaField': ['n', 'rate'],
  's03.metaListed': ['price'],
  'milkRate': ['v'],
  'weight': ['v'],
  's03.metaValue': ['v'],
  'collected': ['v'],
  'collectedSpoiled': ['n', 'v'],
  's03.partial': ['left', 'n'],
  's03.popMilk': ['n', 'tier'],
  'penSummary': ['slots', 'used'],
  's03.bigNewsBody': ['chg', 'name', 'price', 'unit'],
  's03.bigNewsAll': ['chg'],
  's06.vsHigher': ['pct'],
  's06.vsLower': ['pct'],
  'priceUnit': ['unit'],
  's06.baseLine': ['beef', 'milk', 'rice'],
  's06.sellTitle': ['name'],
  'inventory': ['qty', 'unit'],
  'nothingToSell': ['name'],
  'estAvgValue': ['avg', 'unit'],
  'g.pricePer': ['price', 'unit'],
  's06.formula': ['mult'],
  's06.lots': ['n'],
  'sellConfirm': ['qty', 'unit'],
  's06.pinUp': ['name'],
  's06.pinDown': ['name'],
  's06.pinNow': ['price', 'unit'],
  'sold': ['avg', 'qty', 'total', 'unit'],
  's04.about': ['v'],
  's04.originShop': ['g'],
  'origin': ['v'],
  's04.feeHowGrow': ['kg', 'rate', 'tier'],
  's04.feeHowMax': ['kg', 'rate', 'tier'],
  's04.listTitle': ['cow'],
  's04.listConfirm': ['price'],
  'recallFirst': ['n'],
  'cowTitle': ['id'],
  's04.recallFirstOx': ['n'],
  's08.probFailedRetry': ['n'],
  'bullProbLine': ['v'],
  's08.growRange': ['v'],
  's08.hoursRange': ['a', 'b'],
  's08.alreadyBred': ['cow'],
  'breedDone': ['cow'],
  's18.feeLabel': ['price'],
  'studIncome': ['v'],
  's18.feeLine': ['price'],
  'borrow': ['price'],
  'borrowed': ['price'],
  's18.feeChangedBody': ['now', 'old'],
  's18.borrowNew': ['price'],
  's18.logIncome': ['v'],
  's18.lentTo': ['cow', 'ranch'],
  's18.borrowedFrom': ['cow', 'ranch'],
  's18.calfBorn': ['cow'],
  's18.logKeep': ['n'],
  'g.growsIn': ['time'],
  'fieldName': ['n'],
  's17.leftover': ['kg'],
  'fieldRate': ['v'],
  's17.fullIn': ['h', 'time'],
  's17.ofMax': ['max'],
  'harvestAll': ['kg'],
  'expandField': ['cost'],
  'pickOx': ['n'],
  's17.inField': ['n'],
  'harvested': ['kg'],
  's17.maxFields': ['n'],
  'fieldExpanded': ['n'],
  's09.allFound': ['n'],
  's09.useCount': ['n', 'use'],
  's09.howNoTrait': ['use'],
  's09.howTraits': ['traits', 'use'],
  's09.no': ['n'],
  's09.firstFound': ['date', 'n'],
  'date.mdOnly': ['d', 'm'],
  's09.unknownBody': ['tier', 'use'],
  's12.weeklyHint': ['time', 'w'],
  's12.collectionHint': ['n'],
  's12.rankN': ['n'],
  's13.footer': ['game'],
  's13.backup.account': ['name'],
  's13.backup.boundOn': ['date'],
  'date.ymd': ['d', 'm', 'y'],
  's13.del.item1': ['name'],
  's13.del.prompt': ['word'],
  's13.switch.warn': ['name'],
  's13.switch.after': ['name'],
  's13.toast.bound': ['name'],
  's13.toast.unbound': ['name'],
  's13.unbindTitle': ['name'],
  's14.elsewhereLead': ['name'],
  's15.longOffTitle': ['n'],
  'err.not_yet_available': ['time'],
  's16.eta': ['date'],
  'date.mdw': ['d', 'm', 'time', 'w'],
  'anim.dexCount': ['n', 'total'],
  'namegen.pattern': ['first', 'second', 'third'],
  's21.badgeCount': ['n', 'total'],
  's21.badgeDate': ['date'],
  's21.avatarCount': ['n', 'total'],
  's21.avatarLocked': ['name'],
  's21.renamePaid': ['price'],
  's21.renamedFirst': ['price'],
};

const Map<String, String> _zhHant = {
  'tabRanch': '牧場',
  'tabMarket': '市場',
  'tabFields': '田地',
  'tabBreed': '配種',
  'tabShop': '商店',
  'tabRecords': '紀錄',
  'level': 'Lv {lv}',
  'hud.xp': '經驗 {pct}%',
  'hud.settings': '設定',
  'hud.settingsNotBacked': '設定（還沒備份牧場）',
  'connecting': '連線中…',
  'typeDairy': '乳牛',
  'typeDual': '耕牛',
  'typeBeef': '肉牛',
  'bull': '公',
  'cow': '母',
  'tier0': '一般',
  'tier1': '優良',
  'tier2': '稀有',
  'tier3': '傳說',
  'days': '{d} 天',
  'hours': '{h} 小時',
  'minutes': '{m} 分',
  'seconds': '{s} 秒',
  'milk': '牛奶',
  'beef': '牛肉',
  'rice': '稻米',
  'unitMilk': '瓶',
  'unitBeef': '公斤',
  'unitRice': '公斤',
  'news.rice_up.1': '颱風過境，稻米收購價上漲',
  'ago.min': '{n} 分鐘前',
  'ago.hour': '{n} 小時前',
  'ago.day': '{n} 天前',
  'ago.now': '剛剛',
  'date.today': '今天 {time}',
  'date.yesterday': '昨天 {time}',
  'date.md': '{m} 月 {d} 日 {time}',
  'appTitle': '牛市牧場',
  's01.version': '版本 {v}',
  'loadingFarm': '正在載入牧場…',
  's01.creating': '正在幫你準備新牧場…',
  's01.firstTime': '第一次打開要幾秒鐘',
  's01.failTitle': '連不上伺服器',
  's01.failCheck': '請確認網路後重試。',
  's01.failAuto': '每 {n} 秒也會自動再試一次。',
  'retry': '重試',
  's05.milkName': '{tier}牛奶',
  's05.spoiling': '快壞了',
  's05.fresh': '新鮮度',
  's05.collectedAgo': '{ago}收',
  'g.sep': '・',
  's05.spoilIn': '大約 {h} 小時後壞掉，壞掉的會丟掉',
  's05.stored': '存放 {pct}%',
  's05.shippedFrom': '{cow} 出貨',
  's05.lotsOldestFirst': '{n} 批・從最舊的先賣',
  's05.milkCap': '牛奶容量',
  's05.capLine': '{amount} 瓶（{pct}%）',
  's05.full': '倉庫滿了：收奶只收得進一部分，奶桶滿了就會停止產奶。',
  's05.nearFull': '倉庫快滿了，記得去賣或加大倉庫。',
  's05.capNote': '牛肉、稻米不佔倉庫容量。',
  'back': '返回',
  'warehouseTitle': '倉庫',
  'g.levelN': '第 {n} 級',
  'upWarehouse': '加大倉庫',
  's05.emptyMilk': '倉庫裡沒有牛奶。到牧場收奶吧。',
  's05.emptyBeef': '還沒有牛肉。成年的牛可以出貨。',
  's05.emptyRice': '還沒有稻米。派耕牛到田裡種稻。',
  's05.goSell': '去市場賣',
  's05.priceNote': '成交價 ＝ 市價 × 倍數：牛奶乘稀有度和新鮮度，牛肉乘評級、稀有度和存放折價，稻米乘存放折價。',
  'breed.holstein.name': '荷斯坦',
  'breed.holstein.intro': '黑白花斑的招牌乳牛，個子高、產奶穩定。',
  'breed.fluffyHolstein.name': '蓬蓬荷斯坦',
  'breed.fluffyHolstein.intro': '荷斯坦多了一身蓬蓬長毛和瀏海，冬天最不怕冷。',
  'breed.jersey.name': '娟珊',
  'breed.jersey.intro': '淺褐色的小個子，臉短短、眼睛又大又亮。',
  'breed.glossBlack.name': '亮黑乳牛',
  'breed.glossBlack.intro': '黑亮的毛上點綴白斑，站在太陽底下會反光。',
  'breed.cottonCream.name': '奶油棉花牛',
  'breed.cottonCream.intro': '奶油色的蓬毛像一團棉花，看起來軟綿綿。',
  'breed.velvetBlack.name': '黑絨乳牛',
  'breed.velvetBlack.intro': '一身亮黑長毛，像穿了一件絨毛大衣。',
  'breed.chocolate.name': '巧克力牛',
  'breed.chocolate.intro': '咖啡色的毛配奶油色斑，頭頂一球奶油，看起來像一杯巧克力牛奶。',
  'breed.strawberry.name': '草莓牛',
  'breed.strawberry.intro': '奶油白底配草莓紅斑，頭頂一片綠葉，像一顆會走路的草莓。',
  'breed.yellow.name': '台灣黃牛',
  'breed.yellow.intro': '黃褐色、肩上一個圓圓的小肩峰，田裡最可靠的幫手。',
  'breed.highland.name': '高地牛',
  'breed.highland.intro': '薑黃色長毛蓋住眼睛，頭上一對長長的角。',
  'breed.milkTea.name': '奶茶黃牛',
  'breed.milkTea.intro': '淡淡的奶茶色，肩峰圓圓的，脾氣很溫和。',
  'breed.buffalo.name': '台灣水牛',
  'breed.buffalo.intro': '深灰色亮毛，一對往後彎的大角，力氣很大。',
  'breed.cottonCandy.name': '棉花糖高地牛',
  'breed.cottonCandy.intro': '淡米粉色的長毛蓬蓬的，像一球會走路的棉花糖。',
  'breed.shaggyBuffalo.name': '長毛水牛',
  'breed.shaggyBuffalo.intro': '水牛多了一身深灰長毛，角一樣又大又彎。',
  'breed.honey.name': '蜂蜜牛',
  'breed.honey.intro': '金黃色的亮毛，像淋了一層蜂蜜。',
  'breed.goldenEar.name': '金穗牛',
  'breed.goldenEar.intro': '金黃色的身上有稻穗紋，頭頂一小束稻穗，耕田的產量特別多。',
  'breed.angus.name': '安格斯',
  'breed.angus.intro': '炭灰黑的壯碩肉牛，沒有角。',
  'breed.galloway.name': '蓋洛威',
  'breed.galloway.intro': '炭灰黑的長捲毛又厚又暖，沒有角。',
  'breed.charolais.name': '夏洛來',
  'breed.charolais.intro': '奶油白的大個子，肌肉結實。',
  'breed.wagyu.name': '和牛',
  'breed.wagyu.intro': '黑亮的毛帶一道光澤，頭上一對短角。',
  'breed.whiteFleece.name': '白絨牛',
  'breed.whiteFleece.intro': '奶油白的長捲毛，遠看像一朵雲。',
  'breed.fluffyWagyu.name': '絨毛和牛',
  'breed.fluffyWagyu.intro': '和牛的長毛版本，毛又亮又蓬，一樣有短角。',
  'breed.whiteWagyu.name': '白和牛',
  'breed.whiteWagyu.intro': '奶油白的毛帶著光澤，頭上一對短角。',
  'breed.starry.name': '星空牛',
  'breed.starry.intro': '深藍色的毛上有白色星星，是最難遇到的肉牛。',
  'trait.A': '長毛',
  'trait.B': '淡色',
  'trait.C': '光澤',
  's02.title': '幫牧場取個名字',
  's02.sub': '取一個自己喜歡的名字吧！',
  's02.placeholder': '例如：晨光河畔牧場',
  's02.filled': '想好了！可以直接用，也可以再改。',
  's02.widthRule': '中文字算 2，英文字母和數字算 1',
  's02.suggest': '幫我想一個',
  's02.sameName': '跟別人同名也沒關係，會加上 #編號分辨，例如「晨光河畔牧場 #1234」。',
  's02.confirm': '就叫這個',
  's02.welcome': '歡迎來到\n{name}',
  's02.gifts': '先送你這些，開始經營吧！',
  's02.giftMilk': '會產奶',
  'costCoins': '{v} 幣',
  's02.giftBucket': '奶桶裡已經有 {n} 瓶',
  's02.boost': '開局 {h} 小時產奶 ×{x}，進去就能收奶、賣奶。',
  'g.enterRanch': '進牧場',
  's02.errShort': '名字至少要 1 個中文字，或 2 個英文字母',
  's02.errLong': '名字最多 8 個中文字（或 16 個英文字母）',
  's02.errEmoji': '名字不能用表情符號',
  's02.errChar': '名字裡有不能用的字',
  'pickForBreed': '選這頭去配種',
  'ship': '出貨',
  's07.kgBeef': '約 {kg} 公斤牛肉',
  's07.beefPrice': '牛肉現價 {price} 幣／公斤',
  'loadingPreview': '正在取得評級機率…',
  's07.probFailed': '評級機率載入失敗',
  'g.grade': '{g} 級',
  's07.income': '收入約 {v} 幣',
  'expectedValue': '期望收入 約 {v} 幣',
  's07.note': '出貨時才會隨機評級。牛肉立刻放進倉庫，要不要賣、什麼時候賣都可以自己決定。',
  'shipConfirmTitle': '確定出貨？',
  'cancel': '取消',
  's07.confirm': '確定出貨',
  's07.blockWorking': '這頭牛在田裡工作，先叫回來才能出貨',
  's20.tipA': '養得剛剛好！A 級賣價 ×1.25。',
  's20.tipB': '不錯！B 級照市價賣。',
  's20.tipC': 'C 級賣價 ×0.75。下次養到最佳體重再出貨，拿到 A 級的機會比較高。',
  's20.title': '{cow} 出貨評級',
  's20.gradeFormat': '{grade} 級',
  's20.kgIn': '{kg} 公斤牛肉放進倉庫了',
  's20.sellAll': '現在全部賣掉約 {v} 幣',
  's20.goMarket': '去市場',
  'ok': '好',
  's10.upgraded': '升級完成：{what} {effect}',
  'bucketTitle': '奶桶',
  's10.effectBottles': '{a} → {b} 瓶',
  'notEnoughCoins': '金幣不夠，還差 {n} 幣',
  'networkError': '網路不穩，請稍後再試',
  'g.studNoticeTitle': '有人借了你的公牛',
  'g.studNoticeBody': '{cow} 借給 {ranch}，收到 {price} 幣',
  'upgradesTitle': '升級',
  'g.busySub': '送出後等伺服器回覆',
  'upBucket': '加大奶桶',
  'g.busy': '處理中…',
  'upFresh': '冷藏設備',
  'effectFresh': '保鮮 {a} → {b} 小時',
  'stageCalf': '小牛',
  'stageOld': '老牛',
  'badgeWorking': '工作中',
  'badgeListed': '上架中',
  'badgeBred': '已配種',
  'g.newCalf': '新小牛 {cow}',
  'growUp': '長大還要 {v}',
  'g.refreshing': '重新整理中…',
  'g.breedSex': '{breed} {sex}',
  'loadingShop': '正在取得機率…',
  's19.probFailed': '機率載入失敗',
  'probType': '用途',
  'probSex': '公母',
  'probTier': '稀有度',
  's19.descA': '最容易抽到稀有的牛',
  's19.descB': '有機會抽到稀有的牛',
  's19.descC': '便宜，大多是一般的牛',
  's19.segDraw': '抽牛',
  's19.segFacility': '設施',
  's19.rule': '只挑等級；用途、公母、稀有度是隨機的，機率全部公開。抽到的是小牛。',
  's19.penFull': '牛舍滿了（{used} / {slots} 格），先擴建或出貨',
  'drawnTitle': '{g} 級抽到了！',
  's19.drawnDraft': '長大還要 {time}。長大後可以派去田裡種稻。',
  'upPen': '擴建牛舍',
  'effectPen': '{a} → {b} 格',
  's10.penTimes': '擴建過 {n} 次',
  's10.effectFresh': '新鮮 100% 的時間 {a} → {b} 小時',
  's10.levelOf': '第 {n} / {max} 級',
  'maxed': '已滿級',
  'opensIn': '{v}後開放',
  's10.maxLevel': '最高級',
  's10.freshMax': '新鮮 100% 的時間 {h} 小時',
  's10.maxedEffect': '已經最大了',
  's10.fieldsNote': '田地在「田地」分頁開新田。',
  's10.penNever': '還沒擴建過',
  's11.earned': '累積收入到 {v} 幣了！',
  's11.hint': '繼續賣牛奶、牛肉、稻米，或出借公牛，等級會往上升。',
  's11.ribbon': '場主升級',
  's11.lv': 'Lv',
  's11.coachPenTitle': '牛舍可以擴建了！',
  's11.coachPenBody': '多一格就能多養一頭牛。到「商店 › 設施」擴建牛舍（{price} 幣）。',
  's11.coachPenGo': '去擴建',
  's11.coachBullTitle': '小公牛長大了！',
  's11.coachBullBody': '可以跟母牛配種（自己的免費），也可以派去田裡種稻。',
  's11.coachBullGo': '去配種',
  's11.backupTitle': '把牧場備份起來',
  's11.backupBody': '換手機或手機壞了都找得回來。',
  's11.later': '之後再說',
  's11.backupNow': '現在備份',
  's03.normal': '平常',
  's03.panAria': '牧場的位置',
  's03.expandAria': '展開奶桶、倉庫、收購價',
  's03.collapseAria': '收起奶桶、倉庫、收購價',
  's03.expand': '展開',
  's03.collapse': '收起',
  'collect': '收奶',
  's03.full': '滿了',
  's03.bucketCount': '{amount} 瓶',
  's03.fullStopped': '滿了，停止產奶',
  's03.fullIn': '約 {time}後滿',
  's03.noMilkers': '沒有牛在產奶',
  's03.milkFull': '牛奶滿了',
  's03.milkUsed': '牛奶用了 {pct}%',
  's03.prices': '收購價',
  's03.vsNormal': '比平常',
  's03.bubbleFull': '奶桶滿了',
  'cowsTitle': '我的牛',
  'commodityTag': '【{name}】',
  'bothTag': '【全部】',
  's03.swipeHint': '左右滑動，看看整個牧場',
  's03.metaField': '在第 {n} 塊田・稻米 {rate} 公斤／時',
  's03.metaListed': '借種上架中：{price} 幣',
  'milkRate': '產奶 {v} 瓶／時',
  'weight': '體重 {v} 公斤',
  's03.metaValue': '估值約 {v} 幣',
  'collected': '收了 {v} 瓶牛奶，放進倉庫了',
  'collectedSpoiled': '收了 {v} 瓶牛奶，順便丟掉 {n} 瓶壞掉的牛奶',
  's03.partial': '倉庫滿了，收進 {n} 瓶，\n還有 {left} 瓶在奶桶裡',
  's03.popMilk': '產{tier}牛奶 {n} 瓶／時',
  's03.popDetail': '看詳細',
  'penSummary': '牛舍 {used} / {slots} 格',
  's03.penFullSuffix': '（滿了）',
  's03.expandPen': '擴建',
  'g.all': '全部',
  'noCows': '牛舍裡還沒有牛',
  's03.emptyHint': '到商店抽一頭牛，或等配種的小牛出生。',
  's03.goShop': '去商店',
  'g.close': '關閉',
  's06.bigNews': '大新聞',
  'news.beef_up.1': '烤肉季開跑',
  's03.bigNewsBody': '{name}收購價 {chg}，現在 {price} 幣／{unit}',
  's03.bigNewsAll': '全部商品的收購價 {chg}',
  's03.bigNewsGo': '去市場看看',
  's06.vsSame': '跟平常一樣',
  's06.vsHigher': '比平常高 {pct}',
  's06.vsLower': '比平常低 {pct}',
  's06.loading': '正在取得收購價…',
  's06.title': '現在的收購價',
  's06.tapToSell': '點一列就能賣',
  'priceUnit': '幣／{unit}',
  's06.baseLine': '平常（基本價）：牛奶 {milk} 幣／瓶、牛肉 {beef} 幣／公斤、稻米 {rice} 幣／公斤',
  's06.multMilk': '市價 × 稀有度 × 新鮮度',
  's06.multBeef': '市價 × 評級 × 稀有度 × 存放折價',
  's06.multRice': '市價 × 存放折價',
  's06.sellTitle': '賣出{name}',
  'inventory': '庫存 {qty} {unit}',
  'nothingToSell': '倉庫裡沒有{name}可以賣',
  'sellTitle': '賣出',
  'quoting': '試算中…',
  's06.quoteFailed': '試算失敗',
  'estAvgPrice': '預估成交均價',
  'estAvgValue': '{avg} 幣／{unit}',
  's06.estTotalLabel': '預估總額',
  's06.marketPrice': '市價',
  'g.pricePer': '{price} 幣／{unit}',
  's06.formula': '成交價 ＝ {mult}',
  's06.lots': '（{n} 批）',
  's06.qty': '數量',
  's06.oldestFirst': '從最舊的一批先賣。',
  'tooMuch': '一次賣太多，均價會變差，要不要分批？',
  'sellConfirm': '確認賣出 {qty} {unit}',
  'newsTitle': '新聞',
  's06.up': '利多',
  's06.down': '利空',
  's06.superTag': '超級大事件',
  's06.swanTag': '超級黑天鵝',
  's06.pinUp': '{name}收購價變兩倍',
  's06.pinDown': '{name}收購價只剩一成',
  's06.pinUpAll': '全部商品的收購價\n都變兩倍',
  's06.pinDownAll': '全部商品的收購價\n都只剩一成',
  's06.pinNow': '現在 {price} 幣／{unit}',
  'noNews': '目前沒有新聞。',
  'sold': '賣出 {qty} {unit}，均價 {avg}，共 {total} 幣',
  's04.age': '年齡',
  's04.growIn': '長大還要',
  'g.milk': '產奶',
  'g.perHourMilk': '瓶／時',
  'g.plow': '耕田',
  'g.perHourRice': '公斤稻米／時',
  's04.useBeef': '出貨牛肉最多',
  's04.useBreed': '配種',
  's04.weight': '體重',
  'g.kg': '公斤',
  's04.value': '出貨估值',
  's04.about': '約 {v}',
  'g.coin': '幣',
  's04.originStart': '開局',
  's04.originShop': '商店 {g} 級',
  's04.originBreed': '自己配種',
  's04.originStud': '借種',
  'origin': '來源：{v}',
  'shipGradeTitle': '出貨評級機率',
  's04.gradeHint': '養到最佳體重，A 級機會最高',
  's04.oldNote': '老牛：過了壯年，產出和肉質會慢慢下降',
  's04.listStud': '上架借種',
  's04.studFee': '借種費',
  's04.feeHowGrow': '{tier}（每公斤 {rate} 幣）× {kg} 公斤，長大後會再漲',
  's04.feeHowMax': '{tier}（每公斤 {rate} 幣）× {kg} 公斤，已經長到最壯',
  's04.listTitle': '{cow} 上架借種',
  's04.listHint': '別人付這個錢借你的公牛配種；錢給你，小牛歸對方。借出去就算這頭公牛這輩子的那一次配種。',
  's04.listConfirm': '上架（{price} 幣）',
  'unlist': '下架',
  'g.assign': '派去田裡',
  'recallFirst': '在第 {n} 塊田工作，先叫回來才能出貨或配種',
  's04.recall': '叫回來',
  's04.calfHint': '小牛長大以後才能配種、出貨。',
  's04.cantBreedYet': '還不能配種',
  'shipNotAdult': '小牛還不能出貨',
  's04.noteBred': '已配種：每頭牛一輩子只能配種一次',
  's04.alreadyBred': '已配過種',
  'cowTitle': '牛 #{id}',
  's04.goneTitle': '找不到這頭牛',
  's04.goneBody': '可能已經出貨了，或在另一支手機上處理過。',
  's04.backRanch': '回牧場',
  's04.noField': '沒有空田：先開新田，或叫回別的耕牛',
  's04.recallFirstOx': '在第 {n} 塊田工作，先叫回來才能出貨、配種或上架',
  'breedFree': '費用 免費（自己的公母）',
  's08.outcomeTitle': '可能生出的小牛',
  'pickBoth': '請選一頭公牛和一頭母牛',
  's08.calculating': '計算機率中…',
  's08.probFailedRetry': '機率載入失敗，{n} 秒後自動再試',
  's08.notFound': '沒發現過',
  'bullProbLine': '公牛機率 {v}',
  's08.growRange': '小牛長大 {v}',
  's08.hoursRange': '{a}–{b} 小時',
  'subOwnBreed': '自己配種',
  'subStud': '借種',
  's08.rule': '每頭牛一輩子只能配種一次・自己的公母配種免費',
  'pickSire': '選公牛',
  'pickDam': '選母牛',
  'noSire': '沒有能配種的成年公牛',
  'noDam': '沒有能配種的成年母牛',
  's08.noSireHint': '到商店抽牛，或等小公牛長大。也可以到「借種」借別人的公牛。',
  's08.noDamHint': '到商店抽牛，或等小母牛長大。',
  's08.breedBtnFree': '配種（免費）',
  's08.alreadyBred': '{cow} 已經配過種了（每頭牛一輩子只能配種一次）',
  's08.penFull': '牛舍滿了，先擴建或出貨，才有位子給小牛',
  's08.bredBtn': '已配種',
  'breedDone': '配種成功！{cow} 出生了',
  's18.ownerLabel': '主人：',
  'botPrefix': '電腦',
  's18.growing': '還在長',
  's18.noBullTitle': '沒有能上架的公牛',
  's18.noBullHint': '要成年、沒配過種、不在田裡工作。',
  's18.feeLabel': '借種費 {price} 幣',
  'list': '上架',
  's18.feeNote': '借種費由系統算：公牛的體重 × 稀有度的每公斤價格，長大會自動漲。',
  'studMineTitle': '我的公牛出借',
  'studIncome': '借種收入累計 {v} 幣',
  's18.logTitle': '借種紀錄',
  'g.loading': '載入中…',
  'loadFailed': '載入失敗',
  'reload': '重新整理',
  'studEmpty': '目前沒有別人上架的公牛',
  'pickDamForStud': '選自己的母牛',
  'studMarketTitle': '借種市場',
  's18.pullHint': '下拉重新整理',
  's18.marketHint': '付錢借別人的公牛：錢給主人，小牛歸你。',
  's18.feeLine': '費用 {price} 幣（付給主人）',
  'borrow': '借種（{price} 幣）',
  'pickListing': '先選一頭要借的公牛，再選自己的母牛',
  's18.borrowedBtn': '已借種',
  'borrowed': '借種成功！付給主人 {price} 幣',
  's18.goneTitle': '借不到了',
  's18.goneBody': '這頭公牛剛剛被別人借走，或主人下架了。\n錢沒有扣。',
  's18.reloadMarket': '重新整理市場',
  's18.feeChangedTitle': '借種費變了',
  's18.feeChangedBody': '這頭公牛長大了，借種費從 {old} 幣變成 {now} 幣。\n要用新的價格借嗎？',
  's18.borrowNew': '用新價格借（{price} 幣）',
  's18.logIncome': '借出收入累計 {v} 幣',
  's18.out': '借出',
  's18.in': '借入',
  's18.lentTo': '{cow} 借給 {ranch}',
  's18.borrowedFrom': '{cow} 借自 {ranch}',
  's18.calfBorn': '生下 {cow}',
  's18.logKeep': '只保留最近 {n} 天的紀錄。',
  's18.logEmpty': '還沒有借種紀錄',
  's18.logEmptyOut': '還沒有借出的紀錄',
  's18.logEmptyIn': '還沒有借入的紀錄',
  'g.growsIn': '{time}後長大',
  'fieldName': '第 {n} 塊田',
  's17.leftover': '牛叫回來了，田裡還有 {kg} 公斤稻米，收成時一起收。',
  's17.emptyHint': '空田：派一頭成年耕牛來種稻。',
  'fieldEmpty': '空田',
  'noOx': '沒有能下田的成年耕牛',
  'assignOx': '派耕牛',
  's17.full': '長滿了',
  'fieldRate': '每小時 {v} 公斤',
  'recall': '叫回',
  'fieldFull': '長滿了，快收成！收成後才會繼續長。',
  's17.fullIn': '約 {time}後長滿（最多存 {h} 小時的量）',
  'fieldsTitle': '田地',
  's17.ofMax': '/ {max} 塊',
  's17.stock': '倉庫稻米',
  's17.perHour': '每小時',
  'harvestAll': '收成（田裡約 {kg} 公斤）',
  's17.harvestNone': '收成（田裡沒有稻米）',
  'expandField': '開新田（{cost} 幣）',
  'pickOx': '派一頭耕牛到第 {n} 塊田',
  's17.inField': '在第 {n} 塊田',
  's17.noOxHint': '耕牛要成年、不在別的田裡、沒有上架借種。\n可以到商店抽牛，或用乳牛配肉牛生耕牛。',
  'g.gotIt': '知道了',
  'harvested': '收成了 {kg} 公斤稻米，放進倉庫了',
  's17.maxFields': '田地已經 {n} 塊（最多）',
  'fieldExpanded': '開了一塊新田（第 {n} 塊）',
  'g.unknownBreed': '？？？',
  'subCodex': '圖鑑',
  'subRank': '排行榜',
  's09.found': '已發現',
  's09.allFound': '{n} 種全部發現了！圖鑑榜上會顯示你完成了。',
  's09.hint': '小牛出生、抽到或借種生下新品種，就會記在這裡。',
  's09.useCount': '{use} {n} 種',
  's09.howDairy': '爸媽都是乳牛',
  's09.howBeef': '爸媽都是肉牛',
  's09.howDraft': '一邊乳牛、一邊肉牛（或兩頭耕牛）',
  's09.howNoTrait': '{use}，而且沒有顯現任何特徵。',
  's09.howTraits': '{use}，而且爸媽都要帶「{traits}」的基因（看起來沒有也可能帶著）。',
  'g.listSep': '、',
  's09.milkCow': '產奶（母牛）',
  's09.bestKg': '最佳體重',
  's09.mult': '賣價倍數',
  's09.multBeef': '（牛肉）',
  's09.calfGrow': '小牛長大',
  'g.hourUnit': '小時',
  's09.notFoundYet': '還沒發現',
  's09.no': 'No.{n}',
  's09.howTitle': '怎麼配出來',
  's09.firstFound': '第一次發現：{date}　・　目前有 {n} 頭',
  'date.mdOnly': '{m} 月 {d} 日',
  's09.unknownTitle': '還沒發現這個品種',
  's09.unknownBody': '{use}・{tier}。多試試不同的牛配種，或到商店抽抽看。',
  'rankNetworth': '總資產',
  'rankCollection': '圖鑑',
  'rankWeekly': '本週收入',
  's12.kinds': '種',
  's12.me': '我',
  's12.complete': '完成',
  's12.weeklyHint': '每週{w} {time} 重新計算。',
  's12.networthHint': '金幣＋庫存照市價估＋牛的估值。',
  's12.collectionHint': '發現的品種數，最多 {n} 種。',
  's12.pullHint': '下拉可以重新整理。',
  's12.myRank': '我的名次',
  's12.rankN': '第 {n} 名',
  'notRanked': '未上榜',
  's13.web': '網頁',
  's13.ssoApple': '使用 Apple 登入',
  's13.ssoGoogle': '使用 Google 登入',
  's13.privacy': '只用來找回牧場，不會留下你的 email 和姓名。',
  's13.ssoOffline': '連上網路以後才能登入',
  's13.notBacked': '還沒備份',
  's13.backed': '已備份',
  's13.title': '設定',
  's13.sound': '音效',
  's13.language': '語言',
  's13.updown': '漲跌顏色',
  's13.up': '漲',
  's13.down': '跌',
  's13.backup.title': '備份牧場',
  's13.backup.sub': '換手機或手機壞了都能找回',
  's13.delete': '刪除我的牧場',
  's13.privacyPolicy': '隱私權政策',
  's13.version': '版本',
  's13.footer': '{game}　・　所有帳都在伺服器計算',
  's13.backup.done': '牧場已經備份了。換手機或重裝後，用綁定的帳號登入就能找回。',
  's13.backup.lead': '備份以後，換手機或手機壞了，都能找回牧場。',
  's13.backup.warn': '沒有備份的牧場，手機壞了就找不回來。',
  's13.backup.account': '{name} 帳號',
  's13.backup.boundOn': '已綁定・{date}',
  'date.ymd': '{y}/{m}/{d}',
  's13.unbind': '解除',
  's13.backup.addGoogle': '以後可能換 Android 手機的話，再綁一個 Google 帳號。',
  's13.backup.addGoogleAndroid': '在 Android 手機找回牧場要用 Google 帳號，建議再綁一個 Google 帳號。',
  's13.binding': '綁定中…',
  's13.backup.before': '之前備份過？用同一個帳號登入，就能換回舊牧場。',
  's13.del.word': '刪除',
  's13.del.title': '刪除後不能復原',
  's13.del.item1': '牧場「{name}」、所有的牛、金幣、倉庫會全部刪掉。',
  's13.del.item2': '排行榜上的紀錄也會刪掉。',
  's13.del.item3': '綁定的 Apple／Google 帳號會解除，之後可以再綁新的牧場。',
  's13.del.item4': '這支手機會回到第一次打開的畫面。',
  's13.del.prompt': '請輸入「{word}」兩個字確認',
  's13.deleted': '牧場已經刪除了',
  's13.thanks': '謝謝你這段時間的照顧。',
  's14.newRanch': '開新牧場',
  's13.del.failed': '刪除失敗：網路不穩，請稍後再試',
  's13.other.title': '這個帳號已經備份了另一個牧場',
  's13.other.body': '一個帳號只能備份一個牧場。要換回那個牧場嗎？',
  's13.other.switch': '換回那個牧場',
  's13.switch.title': '確定要換回嗎？',
  's13.switch.warn': '這支手機現在的牧場「{name}」會刪除，不能復原。',
  's13.switch.after': '換回以後，這支手機會回到「{name}」。',
  's13.switch.confirm': '換回，並刪除現在的牧場',
  's13.toast.bound': '備份好了！已綁定 {name} 帳號',
  's13.toast.cancelled': '已取消登入',
  's13.toast.failed': '登入失敗，請再試一次',
  's13.toast.unbound': '已解除 {name} 帳號的綁定',
  's13.unbindTitle': '解除 {name} 帳號的綁定？',
  's13.unbindBody': '解除以後，就不能用這個帳號找回牧場。',
  's13.unbindLast': '這是唯一綁定的帳號，解除後這個牧場就沒有備份了。',
  's13.langHint': '第一次打開時跟著手機的語言。換語言以後，畫面上的字、牛的名字和新聞都會跟著換；牧場名不會變。',
  's13.redUp': '漲紅跌綠',
  's13.redUpHint': '台灣的習慣',
  's13.greenUp': '綠漲紅跌',
  's13.greenUpHint': '國際的習慣',
  's13.udNote': '繁體中文預設漲紅跌綠，English、ไทย 預設綠漲紅跌。',
  's14.recover': '找回我的牧場',
  's14.signingIn': '登入中…',
  's14.noneTitle': '這個帳號沒有備份過牧場',
  's14.noneBody': '可能是用另一個帳號備份的。\n沒有備份過的牧場找不回來，只能開新牧場。',
  's14.otherAccount': '換一個帳號',
  's14.androidHint': '之前用 iPhone、只綁了 Apple 帳號？請先在 iPhone 的設定裡再綁一個 Google 帳號。',
  's14.lead': '用之前備份牧場的帳號登入',
  's14.leadHint': '登入以後，牧場就會回到這支手機。',
  's14.welcome': '歡迎回來！',
  's14.level': '等級',
  's14.coins': '金幣',
  's14.cows': '牛',
  's14.head': '頭',
  's14.welcomeHint': '牧場已經回到這支手機，舊手機已經登出。',
  's14.elsewhereTitle': '牧場已經在另一支手機登入',
  's14.elsewhereLead': '「{name}」現在在另一支手機上',
  's14.elsewhereBody': '一個牧場同一時間只能在一支手機上玩。\n在這支手機再登入一次，就能拿回來。',
  's14.elsewhereSecurity': '如果不是你做的，請先檢查那個 Apple 或 Google 帳號的安全，再登入拿回牧場。',
  's15.reconnected': '已重新連線，資料更新了',
  's15.invalidTitle': '這支手機的牧場資料失效了',
  's15.invalidBody': '這支手機存的登入資料不能用了。\n備份過的牧場，用備份的帳號登入就能找回來。',
  's15.longOffTitle': '連不上伺服器，已經超過 {n} 分鐘',
  's15.longOffBody': '請檢查網路。連上以後會自動更新。',
  'err.not_enough_stock': '倉庫裡的數量不夠了，請重新選數量',
  'penFull': '牛舍滿了，先擴建或出貨',
  'err.cow_not_found': '找不到這頭牛，可能已經出貨了',
  'err.cow_not_adult': '小牛還沒長大',
  'err.already_bred': '這頭牛已經配過種了（每頭牛一輩子只能配種一次）',
  'err.cow_in_field': '這頭牛在田裡工作，先叫回來',
  'err.cow_listed': '這頭公牛在借種市場上架中，先下架',
  'err.cow_not_in_field': '這頭牛已經不在田裡了',
  'err.no_free_field': '沒有空田，先開新田或叫回別的耕牛',
  'err.field_occupied': '這塊田已經有牛了',
  'err.field_not_found': '找不到這塊田，請重新整理',
  'err.listing_gone': '這頭公牛已經被借走或下架了',
  'err.max_level': '已經是最高級了',
  'err.not_yet_available': '還沒開放，{time}後再來',
  'err.internal': '伺服器出了點問題，請稍後再試',
  'unknownError': '操作失敗，請再試一次',
  's16.title': '維護中',
  's16.lead': '伺服器正在維護',
  's16.eta': '預計 {date} 恢復',
  's16.late': '比預計的時間晚一點，請再等一下',
  'date.mdw': '{m} 月 {d} 日（{w}）{time}',
  'weekday.0': '日',
  'weekday.1': '一',
  'weekday.2': '二',
  'weekday.3': '三',
  'weekday.4': '四',
  'weekday.5': '五',
  'weekday.6': '六',
  'weekdayFull.0': '日',
  'weekdayFull.1': '一',
  'weekdayFull.2': '二',
  'weekdayFull.3': '三',
  'weekdayFull.4': '四',
  'weekdayFull.5': '五',
  'weekdayFull.6': '六',
  's16.body': '維護完成後就能繼續玩。牧場的資料都保存在伺服器上。',
  'anim.skip': '點一下跳過',
  'anim.beep': '嗶',
  'anim.thanks': '謝謝你的照顧！',
  'anim.newBreed': '發現新品種！',
  'anim.dexCount': '圖鑑 已發現 {n} / {total}',
  'news.milk_up.1': '學校午餐加訂鮮奶',
  'news.milk_up.2': '連日高溫，冰品店大量進貨',
  'news.milk_up.3': '烘焙展開幕，鮮奶需求大增',
  'news.milk_up.4': '鮮奶檢驗全數合格，買氣回溫',
  'news.milk_down.1': '鄰近牧場產量大增',
  'news.milk_down.2': '超市推出鮮奶特賣',
  'news.milk_down.3': '連日寒流，冰品銷量下滑',
  'news.milk_down.4': '物流塞車，乳品廠暫停收購',
  'news.beef_up.2': '餐廳推出牛排節',
  'news.beef_up.3': '年節備貨潮提前',
  'news.beef_up.4': '牛肉麵大賽熱鬧登場',
  'news.beef_down.1': '健康飲食風潮，肉品需求降溫',
  'news.beef_down.2': '進口牛肉到港量創新高',
  'news.beef_down.3': '冷凍倉庫滿載，肉商暫緩收購',
  'news.beef_down.4': '連假結束，餐廳訂單減少',
  'news.rice_up.2': '便當業者搶購新米',
  'news.rice_up.3': '米食文化節開幕',
  'news.rice_up.4': '外銷訂單增加，米價走揚',
  'news.rice_down.1': '中部豐收，新米大量上市',
  'news.rice_down.2': '公糧收購暫停',
  'news.rice_down.3': '連日好天氣，各地提早收割',
  'news.rice_down.4': '米倉滿載，糧商暫緩收購',
  'news.all_up.1': '觀光牧場人潮湧入',
  'news.all_up.2': '農產品博覽會開幕',
  'news.all_up.3': '連假出遊潮，餐飲需求旺',
  'news.all_down.1': '颱風過境，市場休市一日',
  'news.all_down.2': '物價調查公布，消費者縮減開支',
  'news.all_down.3': '港口罷工，出口受阻',
  'news.milk_super.1': '全國學校改喝鮮奶，訂單暴增',
  'news.milk_super.2': '國際冰淇淋大賽開幕，鮮奶搶光',
  'news.milk_super.3': '鮮奶拿鐵爆紅，咖啡店搶不到奶',
  'news.milk_swan.1': '乳品廠大停電，鮮奶全面停收',
  'news.milk_swan.2': '冷藏車大罷工，鮮奶運不出去',
  'news.milk_swan.3': '超級寒流來襲，冰品店全部休息',
  'news.beef_super.1': '世界牛排大賽在本地舉辦',
  'news.beef_super.2': '全國烤肉節提前開跑，肉商搶貨',
  'news.beef_super.3': '牛肉麵登上國際美食榜',
  'news.beef_swan.1': '冷凍物流大當機，肉商全面停收',
  'news.beef_swan.2': '便宜進口牛肉湧入，價格崩盤',
  'news.beef_swan.3': '全國蔬食週開跑，牛肉沒人買',
  'news.rice_super.1': '新米拿下國際金獎，米價翻倍',
  'news.rice_super.2': '海外飯糰大流行，外銷訂單爆量',
  'news.rice_super.3': '國宴指定在地新米，糧商搶貨',
  'news.rice_swan.1': '糧商全面停收，新米堆成山',
  'news.rice_swan.2': '百年一見大豐收，新米賣不出去',
  'news.rice_swan.3': '麵食大流行，米飯沒人吃',
  'news.all_super.1': '世界美食節在本地登場',
  'news.all_super.2': '觀光人潮創新高，餐廳天天客滿',
  'news.all_super.3': '超級連假來了，餐飲需求翻倍',
  'news.all_swan.1': '超級颱風來襲，市場全面停擺',
  'news.all_swan.2': '港口全面封閉，農產品出不了貨',
  'news.all_swan.3': '全國消費急凍，農產品沒人買',
  'namegen.first.0': '晨光',
  'namegen.first.1': '青草',
  'namegen.first.2': '白雲',
  'namegen.first.3': '星河',
  'namegen.first.4': '楓葉',
  'namegen.first.5': '暖陽',
  'namegen.first.6': '微風',
  'namegen.first.7': '山嵐',
  'namegen.first.8': '月牙',
  'namegen.first.9': '麥浪',
  'namegen.first.10': '彩虹',
  'namegen.first.11': '露珠',
  'namegen.second.0': '小丘',
  'namegen.second.1': '河畔',
  'namegen.second.2': '原野',
  'namegen.second.3': '松林',
  'namegen.second.4': '花田',
  'namegen.second.5': '湖邊',
  'namegen.second.6': '坡地',
  'namegen.second.7': '竹林',
  'namegen.second.8': '石橋',
  'namegen.second.9': '溪谷',
  'namegen.second.10': '谷地',
  'namegen.second.11': '森林',
  'namegen.third.0': '牧場',
  'namegen.third.1': '農莊',
  'namegen.third.2': '牧園',
  'namegen.third.3': '農場',
  'namegen.third.4': '乳坊',
  'namegen.third.5': '牛舍',
  'namegen.third.6': '莊園',
  'namegen.third.7': '牧舍',
  'namegen.third.8': '小屋',
  'namegen.third.9': '家園',
  'namegen.third.10': '田園',
  'namegen.third.11': '牧野',
  'namegen.pattern': '{first}{second}{third}',
  's18.deletedRanch': '已刪除的牧場',
  's21.title': '牧場資料',
  's21.badges': '成就徽章',
  's21.badgeCount': '已解鎖 {n} / {total}',
  's21.badgeDate': '{date} 解鎖',
  's21.badgeLocked': '還沒解鎖',
  's21.avatarTitle': '換頭像',
  's21.avatarUse': '用這個頭像',
  's21.avatarFoundOnly': '只有圖鑑裡發現過的能選',
  's21.avatarCount': '已發現 {n} / {total} 種；還沒發現的，發現以後就能用',
  's21.avatarLocked': '還沒發現「{name}」，在圖鑑發現以後就能用',
  's21.avatarDone': '頭像換好了！',
  's21.renameTitle': '改牧場名',
  's21.renameFree': '改名（免費）',
  's21.renamePaid': '改名（{price} 幣）',
  's21.renamedFirst': '牧場名改好了！下次改名要 {price} 幣',
  'ach.firstMilk.name': '第一桶奶',
  'ach.firstMilk.cond': '第一次收奶',
  'ach.firstSale.name': '開張大吉',
  'ach.firstSale.cond': '第一次在市場賣出東西',
  'ach.firstShip.name': '第一趟出貨',
  'ach.firstShip.cond': '第一次出貨',
  'ach.gradeA.name': 'A 級牧場',
  'ach.gradeA.cond': '出貨評到 A 級 10 次',
  'ach.newLife.name': '新生命',
  'ach.newLife.cond': '第一次配種生出小牛',
  'ach.borrow.name': '借將成功',
  'ach.borrow.cond': '第一次借到別人的公牛',
  'ach.popularBull.name': '搶手公牛',
  'ach.popularBull.cond': '自己的公牛被借走 10 次',
  'ach.rice.name': '稻香滿倉',
  'ach.rice.cond': '累計收成 1,000 公斤稻米',
  'ach.codex.name.1': '圖鑑新手',
  'ach.codex.cond.1': '發現 5 種牛',
  'ach.codex.name.2': '圖鑑達人',
  'ach.codex.cond.2': '發現 12 種牛',
  'ach.codex.name.3': '圖鑑大師',
  'ach.codex.cond.3': '發現全部 24 種牛',
  'ach.legend.name': '傳說誕生',
  'ach.legend.cond': '擁有一頭傳說牛',
  'ach.level.name.1': '牧場主 Lv 10',
  'ach.level.cond.1': '升到 Lv 10',
  'ach.level.name.2': '牧場主 Lv 20',
  'ach.level.cond.2': '升到 Lv 20',
  'ach.rich.name.1': '小富翁',
  'ach.rich.cond.1': '總資產到 100,000 幣',
  'ach.rich.name.2': '大富翁',
  'ach.rich.cond.2': '總資產到 1,000,000 幣',
  'ach.tailwind.name': '順風車',
  'ach.tailwind.cond': '在超級大事件期間賣出東西',
  'ach.weekChamp.name': '週冠軍',
  'ach.weekChamp.cond': '本週收入排行榜第 1 名',
  'ach.pureBreed.name': '純種飼育',
  'ach.pureBreed.cond': '照品種的飼料養大一頭稀有以上的小牛（沒變雜種）',
  'ach.healer.name': '妙手回春',
  'ach.healer.cond': '治好一頭病牛',
  'ach.clean.name': '乾淨牧場',
  'ach.clean.cond': '連續 7 天沒有牛生病',
  'ach.trucks.name': '卡車收藏家',
  'ach.trucks.cond': '擁有 3 種卡車造型',
};

const Map<String, String> _en = {
  'tabRanch': 'Ranch',
  'tabMarket': 'Market',
  'tabFields': 'Fields',
  'tabBreed': 'Breed',
  'tabShop': 'Shop',
  'tabRecords': 'Records',
  'level': 'Lv {lv}',
  'hud.xp': 'XP {pct}%',
  'hud.settings': 'Settings',
  'hud.settingsNotBacked': 'Settings (ranch not backed up)',
  'connecting': 'Connecting…',
  'typeDairy': 'Dairy',
  'typeDual': 'Draft',
  'typeBeef': 'Beef',
  'bull': 'Bull',
  'cow': 'Cow',
  'tier0': 'Common',
  'tier1': 'Uncommon',
  'tier2': 'Rare',
  'tier3': 'Legendary',
  'days': '{d}d',
  'hours': '{h}h',
  'minutes': '{m}m',
  'seconds': '{s}s',
  'milk': 'Milk',
  'beef': 'Beef',
  'rice': 'Rice',
  'unitMilk': 'btl',
  'unitBeef': 'kg',
  'unitRice': 'kg',
  'news.rice_up.1': 'Typhoon passes; rice prices rise',
  'ago.min': '{n}m ago',
  'ago.hour': '{n}h ago',
  'ago.day': '{n}d ago',
  'ago.now': 'Just now',
  'date.today': 'Today {time}',
  'date.yesterday': 'Yesterday {time}',
  'date.md': '{m}/{d} {time}',
  'appTitle': 'Bull Market Ranch',
  's01.version': 'Version {v}',
  'loadingFarm': 'Loading your ranch…',
  's01.creating': 'Setting up your new ranch…',
  's01.firstTime': 'The first launch takes a few seconds',
  's01.failTitle': 'Can\'t reach the server',
  's01.failCheck': 'Check your connection and try again.',
  's01.failAuto': 'We\'ll also retry automatically every {n}s.',
  'retry': 'Retry',
  's05.milkName': '{tier} milk',
  's05.spoiling': 'Spoiling soon',
  's05.fresh': 'Freshness',
  's05.collectedAgo': 'Collected {ago}',
  'g.sep': ' · ',
  's05.spoilIn': 'Spoils in ~{h}h, then it\'s thrown out',
  's05.stored': 'Value {pct}%',
  's05.shippedFrom': 'From {cow}',
  's05.lotsOldestFirst': 'Lots: {n} · Oldest sell first',
  's05.milkCap': 'Milk capacity',
  's05.capLine': '{amount} btl ({pct}%)',
  's05.full': 'Storage is full: only part of your milk can be collected, and cows stop making milk once the bucket is full.',
  's05.nearFull': 'Storage is almost full. Sell some or upgrade storage.',
  's05.capNote': 'Beef and rice don\'t take up storage space.',
  'back': 'Back',
  'warehouseTitle': 'Storage',
  'g.levelN': 'Level {n}',
  'upWarehouse': 'Upgrade storage',
  's05.emptyMilk': 'No milk in storage. Collect some on your ranch!',
  's05.emptyBeef': 'No beef yet. Adult cows can be shipped.',
  's05.emptyRice': 'No rice yet. Send oxen to the fields to grow some.',
  's05.goSell': 'Sell at Market',
  's05.priceNote': 'Sale price = market price × multipliers. Milk: rarity and freshness. Beef: grade, rarity, and storage discount. Rice: storage discount.',
  'breed.holstein.name': 'Holstein',
  'breed.holstein.intro': 'The classic black-and-white dairy cow. Tall and a steady milker.',
  'breed.fluffyHolstein.name': 'Fluffy Holstein',
  'breed.fluffyHolstein.intro': 'A Holstein with a fluffy long coat and bangs. Cold winters are no problem!',
  'breed.jersey.name': 'Jersey',
  'breed.jersey.intro': 'Small and light brown, with a short face and big, bright eyes.',
  'breed.glossBlack.name': 'Glossy Black Dairy',
  'breed.glossBlack.intro': 'A shiny black coat dotted with white spots. It gleams in the sun.',
  'breed.cottonCream.name': 'Cotton Cream',
  'breed.cottonCream.intro': 'Fluffy cream-colored fur, like a ball of cotton. So soft!',
  'breed.velvetBlack.name': 'Black Velvet Dairy',
  'breed.velvetBlack.intro': 'Long, shiny black fur, like wearing a velvet coat.',
  'breed.chocolate.name': 'Chocolate Cow',
  'breed.chocolate.intro': 'Brown fur with cream spots and a dollop of cream on top, like a cup of chocolate milk.',
  'breed.strawberry.name': 'Strawberry Cow',
  'breed.strawberry.intro': 'Creamy white with strawberry-red spots and a green leaf on top, like a walking strawberry.',
  'breed.yellow.name': 'Taiwan Yellow Ox',
  'breed.yellow.intro': 'Tawny, with a small round hump on its shoulders. The most reliable helper in the fields.',
  'breed.highland.name': 'Highland',
  'breed.highland.intro': 'Long ginger hair covers its eyes, and it has a pair of long horns.',
  'breed.milkTea.name': 'Milk Tea Ox',
  'breed.milkTea.intro': 'A soft milk-tea color and a round hump. Very gentle.',
  'breed.buffalo.name': 'Taiwan Buffalo',
  'breed.buffalo.intro': 'A shiny dark gray coat and big horns that curve back. Very strong.',
  'breed.cottonCandy.name': 'Cotton Candy Highland',
  'breed.cottonCandy.intro': 'Fluffy, pale pink long hair, like a walking ball of cotton candy.',
  'breed.shaggyBuffalo.name': 'Shaggy Buffalo',
  'breed.shaggyBuffalo.intro': 'A buffalo with long dark gray hair and the same big, curved horns.',
  'breed.honey.name': 'Honey Ox',
  'breed.honey.intro': 'A shiny golden coat, like it\'s drizzled with honey.',
  'breed.goldenEar.name': 'Golden Rice Ox',
  'breed.goldenEar.intro': 'A golden body with rice-ear markings and a little tuft of rice on its head. Its fields yield extra rice.',
  'breed.angus.name': 'Angus',
  'breed.angus.intro': 'A sturdy, charcoal-black beef breed with no horns.',
  'breed.galloway.name': 'Galloway',
  'breed.galloway.intro': 'Thick, warm, curly charcoal-black hair, and no horns.',
  'breed.charolais.name': 'Charolais',
  'breed.charolais.intro': 'A big cream-white cow with firm muscles.',
  'breed.wagyu.name': 'Wagyu',
  'breed.wagyu.intro': 'A shiny black coat with a glossy sheen and a pair of short horns.',
  'breed.whiteFleece.name': 'White Fleece',
  'breed.whiteFleece.intro': 'Long, curly cream-white hair. From afar, it looks like a cloud.',
  'breed.fluffyWagyu.name': 'Fluffy Wagyu',
  'breed.fluffyWagyu.intro': 'A long-haired Wagyu: shiny, fluffy fur and the same short horns.',
  'breed.whiteWagyu.name': 'White Wagyu',
  'breed.whiteWagyu.intro': 'A glossy cream-white coat and a pair of short horns.',
  'breed.starry.name': 'Starry Cow',
  'breed.starry.intro': 'Deep blue fur with white stars. The hardest beef breed to find.',
  'trait.A': 'Long hair',
  'trait.B': 'Pale coat',
  'trait.C': 'Glossy coat',
  's02.title': 'Name your ranch',
  's02.sub': 'Pick a name you love!',
  's02.placeholder': 'e.g. Dawnbrook Ranch',
  's02.filled': 'Here\'s one! Use it as is, or edit it.',
  's02.widthRule': 'Letters and numbers count as 1, Chinese characters as 2',
  's02.suggest': 'Suggest a name',
  's02.sameName': 'It\'s OK if someone else has the same name. A #number is added to tell you apart, like "Dawnbrook Ranch #1234".',
  's02.confirm': 'Use this name',
  's02.welcome': 'Welcome to\n{name}',
  's02.gifts': 'Here are some gifts to get you started!',
  's02.giftMilk': 'Makes milk',
  'costCoins': '{v} coins',
  's02.giftBucket': 'Milk in bucket: {n} btl',
  's02.boost': 'Milk ×{x} for your first {h}h. Go in and start collecting and selling!',
  'g.enterRanch': 'Enter ranch',
  's02.errShort': 'Names need at least 2 letters or 1 Chinese character',
  's02.errLong': 'Names can have up to 16 letters or 8 Chinese characters',
  's02.errEmoji': 'Names can\'t include emoji',
  's02.errChar': 'Some characters can\'t be used',
  'pickForBreed': 'Breed this one',
  'ship': 'Ship',
  's07.kgBeef': '~{kg} kg of beef',
  's07.beefPrice': 'Beef now {price} coins/⁠kg',
  'loadingPreview': 'Getting grade odds…',
  's07.probFailed': 'Couldn\'t load grade odds',
  'g.grade': 'Grade {g}',
  's07.income': 'Earn ~{v} coins',
  'expectedValue': 'Expected: ~{v} coins',
  's07.note': 'The grade is random when you ship. Beef goes straight to storage, and you decide if and when to sell it.',
  'shipConfirmTitle': 'Ship this cow?',
  'cancel': 'Cancel',
  's07.confirm': 'Ship',
  's07.blockWorking': 'This cow is working in a field. Call it back before shipping.',
  's20.tipA': 'Raised just right! Grade A sells at ×1.25.',
  's20.tipB': 'Nice! Grade B sells at market price.',
  's20.tipC': 'Grade C sells at ×0.75. Ship at ideal weight next time for a better shot at A.',
  's20.title': 'Ship grade for {cow}',
  's20.gradeFormat': 'Grade {grade}',
  's20.kgIn': '{kg} kg of beef added to storage',
  's20.sellAll': 'Sell it all now for ~{v} coins',
  's20.goMarket': 'Go to Market',
  'ok': 'OK',
  's10.upgraded': 'Upgraded: {what} {effect}',
  'bucketTitle': 'Milk bucket',
  's10.effectBottles': '{a} → {b} btl',
  'notEnoughCoins': 'Not enough coins. You need {n} more.',
  'networkError': 'Connection problem. Please try again later.',
  'g.studNoticeTitle': 'Someone borrowed your bull',
  'g.studNoticeBody': '{cow} lent to {ranch}. You earned {price} coins.',
  'upgradesTitle': 'Upgrades',
  'g.busySub': 'Sent, waiting for the server',
  'upBucket': 'Upgrade bucket',
  'g.busy': 'Processing…',
  'upFresh': 'Cooler',
  'effectFresh': 'Stays fresh {a} → {b}h',
  'stageCalf': 'Calf',
  'stageOld': 'Senior',
  'badgeWorking': 'Working',
  'badgeListed': 'Listed',
  'badgeBred': 'Bred',
  'g.newCalf': 'New calf: {cow}',
  'growUp': 'Grows up in {v}',
  'g.refreshing': 'Refreshing…',
  'g.breedSex': '{breed} ({sex})',
  'loadingShop': 'Getting odds…',
  's19.probFailed': 'Couldn\'t load odds',
  'probType': 'Role',
  'probSex': 'Sex',
  'probTier': 'Rarity',
  's19.descA': 'Best chance of rare cows',
  's19.descB': 'Some chance of rare cows',
  's19.descC': 'Cheap, mostly Common cows',
  's19.segDraw': 'Draw cows',
  's19.segFacility': 'Facilities',
  's19.rule': 'You pick the grade; role, sex, and rarity are random, and all odds are shown. You\'ll get a calf.',
  's19.penFull': 'Barn full ({used} / {slots}). Expand it or ship a cow first.',
  'drawnTitle': 'Grade {g} draw!',
  's19.drawnDraft': 'Grows up in {time}. Once grown, send it to the fields to grow rice.',
  'upPen': 'Expand barn',
  'effectPen': '{a} → {b} slots',
  's10.penTimes': 'Expanded ×{n}',
  's10.effectFresh': '100% fresh for {a} → {b}h',
  's10.levelOf': 'Level {n} / {max}',
  'maxed': 'Maxed',
  'opensIn': 'Opens in {v}',
  's10.maxLevel': 'Max level',
  's10.freshMax': '100% fresh for {h}h',
  's10.maxedEffect': 'Already at max',
  's10.fieldsNote': 'Open new fields in the Fields tab.',
  's10.penNever': 'Never expanded',
  's11.earned': 'Total earnings hit {v} coins!',
  's11.hint': 'Keep selling milk, beef, and rice, or lend your bulls, to level up.',
  's11.ribbon': 'Level up!',
  's11.lv': 'Lv',
  's11.coachPenTitle': 'You can expand your barn!',
  's11.coachPenBody': 'One more slot means room for one more cow. Expand it in Shop › Facilities ({price} coins).',
  's11.coachPenGo': 'Expand',
  's11.coachBullTitle': 'Your young bull is all grown!',
  's11.coachBullBody': 'Breed him with a cow (free with your own), or send him to the fields to grow rice.',
  's11.coachBullGo': 'Breed',
  's11.backupTitle': 'Back up your ranch',
  's11.backupBody': 'Get it back if you switch phones or yours breaks.',
  's11.later': 'Later',
  's11.backupNow': 'Back up now',
  's03.normal': 'Usual',
  's03.panAria': 'Ranch view position',
  's03.expandAria': 'Show bucket, storage, and prices',
  's03.collapseAria': 'Hide bucket, storage, and prices',
  's03.expand': 'Show',
  's03.collapse': 'Hide',
  'collect': 'Collect',
  's03.full': 'Full',
  's03.bucketCount': '{amount} btl',
  's03.fullStopped': 'Full, no new milk',
  's03.fullIn': 'Full in ~{time}',
  's03.noMilkers': 'No cows making milk',
  's03.milkFull': 'Milk full',
  's03.milkUsed': '{pct}% full',
  's03.prices': 'Prices',
  's03.vsNormal': 'vs usual',
  's03.bubbleFull': 'Bucket full!',
  'cowsTitle': 'My cows',
  'commodityTag': '[{name}] ',
  'bothTag': '[All] ',
  's03.swipeHint': 'Swipe sideways to see the whole ranch',
  's03.metaField': 'Field {n} · Rice {rate} kg/⁠h',
  's03.metaListed': 'Listed for stud: {price} coins',
  'milkRate': 'Milk {v} btl/⁠h',
  'weight': 'Weight {v} kg',
  's03.metaValue': 'Value ~{v} coins',
  'collected': 'Collected {v} btl of milk, now in storage',
  'collectedSpoiled': 'Collected {v} btl of milk, tossed {n} btl that spoiled',
  's03.partial': 'Storage full! Collected {n} btl.\n{left} btl still in the bucket',
  's03.popMilk': '{tier} milk {n} btl/⁠h',
  's03.popDetail': 'Details',
  'penSummary': 'Barn {used} / {slots}',
  's03.penFullSuffix': ' (full)',
  's03.expandPen': 'Expand',
  'g.all': 'All',
  'noCows': 'No cows in your barn yet',
  's03.emptyHint': 'Draw a cow in the Shop, or wait for a bred calf to be born.',
  's03.goShop': 'Go to Shop',
  'g.close': 'Close',
  's06.bigNews': 'Big news',
  'news.beef_up.1': 'BBQ season kicks off',
  's03.bigNewsBody': '{name} price {chg}, now {price} coins/⁠{unit}',
  's03.bigNewsAll': 'All prices {chg}',
  's03.bigNewsGo': 'Go to Market',
  's06.vsSame': 'Same as usual',
  's06.vsHigher': '{pct} above usual',
  's06.vsLower': '{pct} below usual',
  's06.loading': 'Getting prices…',
  's06.title': 'Current prices',
  's06.tapToSell': 'Tap a row to sell',
  'priceUnit': 'coins/⁠{unit}',
  's06.baseLine': 'Usual (base) prices: milk {milk} coins/⁠btl, beef {beef} coins/⁠kg, rice {rice} coins/⁠kg',
  's06.multMilk': 'market price × rarity × freshness',
  's06.multBeef': 'market price × grade × rarity × storage discount',
  's06.multRice': 'market price × storage discount',
  's06.sellTitle': 'Sell {name}',
  'inventory': 'Stock: {qty} {unit}',
  'nothingToSell': 'No {name} in storage to sell',
  'sellTitle': 'Sell',
  'quoting': 'Estimating…',
  's06.quoteFailed': 'Estimate failed',
  'estAvgPrice': 'Est. average price',
  'estAvgValue': '{avg} coins/⁠{unit}',
  's06.estTotalLabel': 'Est. total',
  's06.marketPrice': 'Market price',
  'g.pricePer': '{price} coins/⁠{unit}',
  's06.formula': 'Sale price = {mult}',
  's06.lots': ' (lots: {n})',
  's06.qty': 'Amount',
  's06.oldestFirst': 'Oldest lots sell first.',
  'tooMuch': 'Selling a lot at once lowers the average price. Split it up?',
  'sellConfirm': 'Sell {qty} {unit}',
  'newsTitle': 'News',
  's06.up': 'Bullish',
  's06.down': 'Bearish',
  's06.superTag': 'Super boom',
  's06.swanTag': 'Black swan',
  's06.pinUp': '{name} price doubles',
  's06.pinDown': '{name} price drops to a tenth',
  's06.pinUpAll': 'All prices\ndouble',
  's06.pinDownAll': 'All prices drop\nto a tenth',
  's06.pinNow': 'Now {price} coins/⁠{unit}',
  'noNews': 'No news right now.',
  'sold': 'Sold {qty} {unit}, avg {avg}, total {total} coins',
  's04.age': 'Age',
  's04.growIn': 'Grows up in',
  'g.milk': 'Milk',
  'g.perHourMilk': 'btl/⁠h',
  'g.plow': 'Plowing',
  'g.perHourRice': 'kg rice/⁠h',
  's04.useBeef': 'Most beef',
  's04.useBreed': 'Breeding',
  's04.weight': 'Weight',
  'g.kg': 'kg',
  's04.value': 'Ship value',
  's04.about': '~{v}',
  'g.coin': 'coins',
  's04.originStart': 'Starter gift',
  's04.originShop': 'Shop, Grade {g}',
  's04.originBreed': 'Own breeding',
  's04.originStud': 'Borrowed bull',
  'origin': 'From: {v}',
  'shipGradeTitle': 'Ship grade odds',
  's04.gradeHint': 'Best odds of A at ideal weight',
  's04.oldNote': 'Senior: past its prime, its output and beef quality slowly drop',
  's04.listStud': 'List for stud',
  's04.studFee': 'Stud fee',
  's04.feeHowGrow': '{tier} ({rate} coins/⁠kg) × {kg} kg. Rises as it grows.',
  's04.feeHowMax': '{tier} ({rate} coins/⁠kg) × {kg} kg. Fully grown.',
  's04.listTitle': 'List {cow} for stud',
  's04.listHint': 'Others pay this fee to breed with your bull. You get the coins; they get the calf. Lending counts as this bull\'s one breeding.',
  's04.listConfirm': 'List ({price} coins)',
  'unlist': 'Unlist',
  'g.assign': 'Send to field',
  'recallFirst': 'Working in Field {n}. Call it back to ship or breed.',
  's04.recall': 'Call back',
  's04.calfHint': 'Calves can breed or be shipped once grown up.',
  's04.cantBreedYet': 'Can\'t breed yet',
  'shipNotAdult': 'Can\'t ship yet',
  's04.noteBred': 'Bred: each cow can breed only once in its life',
  's04.alreadyBred': 'Already bred',
  'cowTitle': 'Cow #{id}',
  's04.goneTitle': 'Can\'t find this cow',
  's04.goneBody': 'It may have been shipped, or handled on another phone.',
  's04.backRanch': 'Back to ranch',
  's04.noField': 'No free field: open a new one or call back another ox',
  's04.recallFirstOx': 'Working in Field {n}. Call it back to ship, breed, or list it.',
  'breedFree': 'Fee: free (your own cows)',
  's08.outcomeTitle': 'Possible calves',
  'pickBoth': 'Pick a bull and a cow',
  's08.calculating': 'Calculating odds…',
  's08.probFailedRetry': 'Couldn\'t load odds. Retrying in {n}s',
  's08.notFound': 'New',
  'bullProbLine': 'Bull chance {v}',
  's08.growRange': 'Grows up in {v}',
  's08.hoursRange': '{a}–{b}h',
  'subOwnBreed': 'My cows',
  'subStud': 'Borrow a bull',
  's08.rule': 'Each cow can breed once in its life · Free with your own cows',
  'pickSire': 'Pick a bull',
  'pickDam': 'Pick a cow',
  'noSire': 'No adult bulls ready to breed',
  'noDam': 'No adult cows ready to breed',
  's08.noSireHint': 'Draw one in the Shop, or wait for a young bull to grow up. You can also try "Borrow a bull".',
  's08.noDamHint': 'Draw one in the Shop, or wait for a young cow to grow up.',
  's08.breedBtnFree': 'Breed (free)',
  's08.alreadyBred': '{cow} has already bred (each cow can breed only once)',
  's08.penFull': 'Barn is full. Expand it or ship a cow to make room for the calf.',
  's08.bredBtn': 'Bred',
  'breedDone': 'Success! {cow} was born',
  's18.ownerLabel': 'Owner: ',
  'botPrefix': 'Bot',
  's18.growing': 'Growing',
  's18.noBullTitle': 'No bulls to list',
  's18.noBullHint': 'Bulls must be adult, never bred, and not working in a field.',
  's18.feeLabel': 'Stud fee: {price} coins',
  'list': 'List',
  's18.feeNote': 'The stud fee is set for you: the bull\'s weight × a per-kg price by rarity. It rises as the bull grows.',
  'studMineTitle': 'Lend my bulls',
  'studIncome': 'Earned: {v} coins',
  's18.logTitle': 'Stud history',
  'g.loading': 'Loading…',
  'loadFailed': 'Couldn\'t load',
  'reload': 'Refresh',
  'studEmpty': 'No one else has listed a bull right now',
  'pickDamForStud': 'Pick your cow',
  'studMarketTitle': 'Stud market',
  's18.pullHint': 'Pull to refresh',
  's18.marketHint': 'Pay to borrow someone\'s bull: the coins go to the owner, and the calf is yours.',
  's18.feeLine': 'Fee: {price} coins (to owner)',
  'borrow': 'Borrow ({price} coins)',
  'pickListing': 'Pick a bull to borrow, then pick your cow',
  's18.borrowedBtn': 'Borrowed',
  'borrowed': 'Bull borrowed! Paid {price} coins to the owner',
  's18.goneTitle': 'No longer available',
  's18.goneBody': 'Someone just borrowed this bull, or the owner unlisted it.\nYou weren\'t charged.',
  's18.reloadMarket': 'Refresh market',
  's18.feeChangedTitle': 'Stud fee changed',
  's18.feeChangedBody': 'This bull has grown, so the fee went from {old} to {now} coins.\nBorrow at the new price?',
  's18.borrowNew': 'Borrow for {price} coins',
  's18.logIncome': 'Earned from lending: {v} coins',
  's18.out': 'Lent',
  's18.in': 'Borrowed',
  's18.lentTo': '{cow} lent to {ranch}',
  's18.borrowedFrom': '{cow} borrowed from {ranch}',
  's18.calfBorn': 'Born: {cow}',
  's18.logKeep': 'Keeps a {n}-day history.',
  's18.logEmpty': 'No stud history yet',
  's18.logEmptyOut': 'Nothing lent yet',
  's18.logEmptyIn': 'Nothing borrowed yet',
  's18.deletedRanch': 'Deleted ranch',
  'g.growsIn': 'Grows up in {time}',
  'fieldName': 'Field {n}',
  's17.leftover': 'Ox called back. {kg} kg of rice is still in the field and will be collected at harvest.',
  's17.emptyHint': 'Empty field: send an adult ox here to grow rice.',
  'fieldEmpty': 'Empty',
  'noOx': 'No adult oxen available',
  'assignOx': 'Send an ox',
  's17.full': 'Full',
  'fieldRate': '{v} kg/⁠h',
  'recall': 'Call back',
  'fieldFull': 'Full! Harvest now. It won\'t grow more until you do.',
  's17.fullIn': 'Full in ~{time} (holds up to {h}h of rice)',
  'fieldsTitle': 'Fields',
  's17.ofMax': '/ {max}',
  's17.stock': 'Stored rice',
  's17.perHour': 'Per hour',
  'harvestAll': 'Harvest (~{kg} kg in fields)',
  's17.harvestNone': 'Harvest (no rice yet)',
  'expandField': 'New field ({cost} coins)',
  'pickOx': 'Send an ox to Field {n}',
  's17.inField': 'In Field {n}',
  's17.noOxHint': 'Oxen must be adult, not in another field, and not listed for stud.\nDraw one in the Shop, or breed Dairy × Beef for a Draft calf.',
  'g.gotIt': 'Got it',
  'harvested': 'Harvested {kg} kg of rice into storage',
  's17.maxFields': 'Fields: {n} (max)',
  'fieldExpanded': 'New field opened (Field {n})',
  'g.unknownBreed': '???',
  'subCodex': 'Collection',
  'subRank': 'Rankings',
  's09.found': 'Found',
  's09.allFound': 'All {n} found! Your Collection ranking will show it\'s complete.',
  's09.hint': 'New breeds you get from births, draws, or borrowed bulls are recorded here.',
  's09.useCount': '{use} breeds: {n}',
  's09.howDairy': 'Both parents are Dairy',
  's09.howBeef': 'Both parents are Beef',
  's09.howDraft': 'One Dairy and one Beef parent (or two Draft)',
  's09.howNoTrait': '{use}, with no traits showing.',
  's09.howTraits': '{use}, and both must carry the "{traits}" genes (a cow can carry them without showing them).',
  'g.listSep': ', ',
  's09.milkCow': 'Milk (cows)',
  's09.bestKg': 'Ideal weight',
  's09.mult': 'Price multiplier',
  's09.multBeef': '(beef)',
  's09.calfGrow': 'Calf growth',
  'g.hourUnit': 'h',
  's09.notFoundYet': 'Not found yet',
  's09.no': 'No.{n}',
  's09.howTitle': 'How to breed it',
  's09.firstFound': 'First found: {date} · Owned: {n}',
  'date.mdOnly': '{m}/{d}',
  's09.unknownTitle': 'Breed not found yet',
  's09.unknownBody': '{use} · {tier}. Try breeding different cows, or try a draw in the Shop.',
  'rankNetworth': 'Net worth',
  'rankCollection': 'Collection',
  'rankWeekly': 'This week',
  's12.kinds': 'found',
  's12.me': 'You',
  's12.complete': 'Complete',
  's12.weeklyHint': 'Resets every {w} at {time}.',
  's12.networthHint': 'Coins + stock at market price + cow value.',
  's12.collectionHint': 'Breeds found, out of {n}.',
  's12.pullHint': ' Pull down to refresh.',
  's12.myRank': 'My rank',
  's12.rankN': '#{n}',
  'notRanked': 'Unranked',
  's13.web': 'Web',
  's13.ssoApple': 'Sign in with Apple',
  's13.ssoGoogle': 'Sign in with Google',
  's13.privacy': 'Only used to recover your ranch. We don\'t keep your email or name.',
  's13.ssoOffline': 'Connect to the internet to sign in',
  's13.notBacked': 'Not backed up',
  's13.backed': 'Backed up',
  's13.title': 'Settings',
  's13.sound': 'Sound',
  's13.language': 'Language',
  's13.updown': 'Price colors',
  's13.up': 'Up',
  's13.down': 'Down',
  's13.backup.title': 'Back up ranch',
  's13.backup.sub': 'Get it back if you switch phones or yours breaks',
  's13.delete': 'Delete my ranch',
  's13.privacyPolicy': 'Privacy policy',
  's13.version': 'Version',
  's13.footer': '{game} · Everything runs on the server',
  's13.backup.done': 'Your ranch is backed up. After switching phones or reinstalling, sign in with a linked account to get it back.',
  's13.backup.lead': 'Once backed up, you can get your ranch back if you switch phones or yours breaks.',
  's13.backup.warn': 'Without a backup, your ranch can\'t be recovered if your phone breaks.',
  's13.backup.account': '{name} Account',
  's13.backup.boundOn': 'Linked · {date}',
  'date.ymd': '{m}/{d}/{y}',
  's13.unbind': 'Unlink',
  's13.backup.addGoogle': 'If you might switch to Android later, link a Google Account too.',
  's13.backup.addGoogleAndroid': 'On Android, you recover your ranch with a Google Account, so link one too.',
  's13.binding': 'Linking…',
  's13.backup.before': 'Backed up before? Sign in with the same account to switch back to your old ranch.',
  's13.del.word': 'DELETE',
  's13.del.title': 'This can\'t be undone',
  's13.del.item1': 'Your ranch "{name}", all your cows, coins, and storage will be deleted.',
  's13.del.item2': 'Your spots in the rankings will be removed too.',
  's13.del.item3': 'Your linked Apple or Google Account will be unlinked. You can link it to a new ranch later.',
  's13.del.item4': 'This phone will go back to the first-launch screen.',
  's13.del.prompt': 'Type "{word}" to confirm',
  's13.deleted': 'Your ranch has been deleted',
  's13.thanks': 'Thanks for taking care of us all this time.',
  's14.newRanch': 'Start a new ranch',
  's13.del.failed': 'Couldn\'t delete: connection problem. Please try again later.',
  's13.other.title': 'This account already backs up another ranch',
  's13.other.body': 'Each account can back up only one ranch. Switch back to that ranch?',
  's13.other.switch': 'Switch to that ranch',
  's13.switch.title': 'Switch back?',
  's13.switch.warn': 'The ranch on this phone now, "{name}", will be deleted. This can\'t be undone.',
  's13.switch.after': 'After switching, this phone will go back to "{name}".',
  's13.switch.confirm': 'Switch and delete current ranch',
  's13.toast.bound': 'Backed up! {name} Account linked',
  's13.toast.cancelled': 'Sign-in canceled',
  's13.toast.failed': 'Sign-in failed. Please try again.',
  's13.toast.unbound': '{name} Account unlinked',
  's13.unbindTitle': 'Unlink your {name} Account?',
  's13.unbindBody': 'After unlinking, you can\'t use this account to recover your ranch.',
  's13.unbindLast': 'This is your only linked account. If you unlink it, this ranch will no longer be backed up.',
  's13.langHint': 'At first launch, the game follows your phone\'s language. Changing it updates all text, cow names, and news; ranch names stay the same.',
  's13.redUp': 'Red = up',
  's13.redUpHint': 'Taiwan style',
  's13.greenUp': 'Green = up',
  's13.greenUpHint': 'International style',
  's13.udNote': 'Traditional Chinese defaults to Red = up; English and Thai default to Green = up.',
  's14.recover': 'Recover my ranch',
  's14.signingIn': 'Signing in…',
  's14.noneTitle': 'This account has no backed-up ranch',
  's14.noneBody': 'It may have been backed up with a different account.\nA ranch that was never backed up can\'t be recovered; you\'ll need to start a new one.',
  's14.otherAccount': 'Switch account',
  's14.androidHint': 'Used an iPhone and only linked an Apple Account? First link a Google Account in Settings on that iPhone.',
  's14.lead': 'Sign in with the account you backed up with',
  's14.leadHint': 'Once you sign in, your ranch will move to this phone.',
  's14.welcome': 'Welcome back!',
  's14.level': 'Level',
  's14.coins': 'Coins',
  's14.cows': 'Cows',
  's14.head': 'head',
  's14.welcomeHint': 'Your ranch is now on this phone. Your old phone has been signed out.',
  's14.elsewhereTitle': 'Your ranch is signed in on another phone',
  's14.elsewhereLead': '"{name}" is now on another phone',
  's14.elsewhereBody': 'A ranch can only be played on one phone at a time.\nSign in again on this phone to bring it back.',
  's14.elsewhereSecurity': 'If this wasn\'t you, check the security of that Apple or Google Account first, then sign in to get your ranch back.',
  's15.reconnected': 'Reconnected. Data updated.',
  's15.invalidTitle': 'Ranch data on this phone is no longer valid',
  's15.invalidBody': 'The sign-in data saved on this phone no longer works.\nIf your ranch was backed up, sign in with that account to get it back.',
  's15.longOffTitle': 'Can\'t reach the server for over {n} min',
  's15.longOffBody': 'Please check your connection. Everything will update once you\'re back online.',
  'err.not_enough_stock': 'Not enough in storage. Please pick a new amount.',
  'penFull': 'Barn is full. Expand it or ship a cow first.',
  'err.cow_not_found': 'Can\'t find this cow. It may have been shipped.',
  'err.cow_not_adult': 'This calf hasn\'t grown up yet',
  'err.already_bred': 'This cow has already been bred (each cow can breed only once)',
  'err.cow_in_field': 'This cow is working in a field. Call it back first.',
  'err.cow_listed': 'This bull is listed on the stud market. Unlist it first.',
  'err.cow_not_in_field': 'This cow is no longer in the field',
  'err.no_free_field': 'No free field. Open a new one or call back another ox.',
  'err.field_occupied': 'This field already has an ox',
  'err.field_not_found': 'Can\'t find this field. Please refresh.',
  'err.listing_gone': 'This bull was already borrowed or unlisted',
  'err.max_level': 'Already at max level',
  'err.not_yet_available': 'Not open yet. Come back in {time}.',
  'err.internal': 'Something went wrong on the server. Please try again later.',
  'unknownError': 'That didn\'t work. Please try again.',
  's16.title': 'Under maintenance',
  's16.lead': 'The server is under maintenance',
  's16.eta': 'Expected back {date}',
  's16.late': 'Taking a bit longer than expected. Please wait a little longer.',
  'date.mdw': '{w} {m}/{d} {time}',
  'weekday.0': 'Sun',
  'weekday.1': 'Mon',
  'weekday.2': 'Tue',
  'weekday.3': 'Wed',
  'weekday.4': 'Thu',
  'weekday.5': 'Fri',
  'weekday.6': 'Sat',
  'weekdayFull.0': 'Sunday',
  'weekdayFull.1': 'Monday',
  'weekdayFull.2': 'Tuesday',
  'weekdayFull.3': 'Wednesday',
  'weekdayFull.4': 'Thursday',
  'weekdayFull.5': 'Friday',
  'weekdayFull.6': 'Saturday',
  's16.body': 'You can keep playing once it\'s done. Your ranch data is safe on the server.',
  'anim.skip': 'Tap to skip',
  'anim.beep': 'Beep',
  'anim.thanks': 'Thanks for taking care of me!',
  'anim.newBreed': 'New breed found!',
  'anim.dexCount': 'Collection: {n} / {total} found',
  'news.milk_up.1': 'Schools order extra milk for lunch',
  'news.milk_up.2': 'Heat wave has ice cream shops stocking up',
  'news.milk_up.3': 'Baking expo opens; milk demand soars',
  'news.milk_up.4': 'Fresh milk passes all inspections; buyers return',
  'news.milk_down.1': 'Nearby ranches boost milk output',
  'news.milk_down.2': 'Supermarkets hold fresh milk sales',
  'news.milk_down.3': 'Cold snap cuts ice cream sales',
  'news.milk_down.4': 'Delivery jams: dairy plants pause buying',
  'news.beef_up.2': 'Restaurants launch steak festivals',
  'news.beef_up.3': 'Holiday stock-up rush starts early',
  'news.beef_up.4': 'Beef noodle contest draws big crowds',
  'news.beef_down.1': 'Healthy-eating trend cools beef demand',
  'news.beef_down.2': 'Beef imports hit a record high',
  'news.beef_down.3': 'Cold storage full; beef buyers hold off',
  'news.beef_down.4': 'Long weekend ends; restaurant orders drop',
  'news.rice_up.2': 'Bento shops snap up new rice',
  'news.rice_up.3': 'Rice food festival opens',
  'news.rice_up.4': 'Export orders grow; rice prices climb',
  'news.rice_down.1': 'Bumper harvest floods the market with new rice',
  'news.rice_down.2': 'Government rice buying paused',
  'news.rice_down.3': 'Sunny days bring early harvests everywhere',
  'news.rice_down.4': 'Granaries full; grain buyers hold off',
  'news.all_up.1': 'Crowds flock to tourist ranches',
  'news.all_up.2': 'Farm products expo opens',
  'news.all_up.3': 'Holiday travel boom boosts food demand',
  'news.all_down.1': 'Typhoon closes markets for a day',
  'news.all_down.2': 'Price survey out; shoppers cut spending',
  'news.all_down.3': 'Port strike blocks exports',
  'news.milk_super.1': 'Schools nationwide switch to fresh milk',
  'news.milk_super.2': 'Ice cream world cup opens; milk sells out',
  'news.milk_super.3': 'Milk lattes go viral; cafés run dry',
  'news.milk_swan.1': 'Dairy plants lose power; milk buying halts',
  'news.milk_swan.2': 'Cold-truck strike: milk can\'t ship',
  'news.milk_swan.3': 'Record cold snap shuts every ice cream shop',
  'news.beef_super.1': 'World steak contest comes to town',
  'news.beef_super.2': 'National BBQ fest starts early; buyers rush in',
  'news.beef_super.3': 'Beef noodle soup tops world food charts',
  'news.beef_swan.1': 'Cold-chain systems crash; beef buying stops',
  'news.beef_swan.2': 'Cheap imported beef floods in; prices crash',
  'news.beef_swan.3': 'Veggie week starts nationwide; no one buys beef',
  'news.rice_super.1': 'New rice wins world gold; price doubles',
  'news.rice_super.2': 'Rice balls take off abroad; exports soar',
  'news.rice_super.3': 'State banquet picks local rice; buyers rush in',
  'news.rice_swan.1': 'Grain buyers stop buying; rice piles up',
  'news.rice_swan.2': 'Once-in-a-century harvest: rice won\'t sell',
  'news.rice_swan.3': 'Noodle craze: no one wants rice',
  'news.all_super.1': 'World food festival comes to town',
  'news.all_super.2': 'Record tourist crowds pack every restaurant',
  'news.all_super.3': 'Mega holiday arrives; food demand doubles',
  'news.all_swan.1': 'Super typhoon shuts down all markets',
  'news.all_swan.2': 'Ports close; farm goods can\'t ship',
  'news.all_swan.3': 'Spending freezes nationwide; farm goods go unsold',
  'namegen.first.0': 'Dawn',
  'namegen.first.1': 'Fern',
  'namegen.first.2': 'Cloud',
  'namegen.first.3': 'Star',
  'namegen.first.4': 'Maple',
  'namegen.first.5': 'Sun',
  'namegen.first.6': 'Wind',
  'namegen.first.7': 'Mist',
  'namegen.first.8': 'Moon',
  'namegen.first.9': 'Wheat',
  'namegen.first.10': 'Sky',
  'namegen.first.11': 'Dew',
  'namegen.second.0': 'hill',
  'namegen.second.1': 'brook',
  'namegen.second.2': 'field',
  'namegen.second.3': 'pine',
  'namegen.second.4': 'bloom',
  'namegen.second.5': 'lake',
  'namegen.second.6': 'ridge',
  'namegen.second.7': 'grove',
  'namegen.second.8': 'stone',
  'namegen.second.9': 'creek',
  'namegen.second.10': 'vale',
  'namegen.second.11': 'wood',
  'namegen.third.0': 'Ranch',
  'namegen.third.1': 'Farm',
  'namegen.third.2': 'Acres',
  'namegen.third.3': 'Barn',
  'namegen.third.4': 'Dairy',
  'namegen.third.5': 'Fold',
  'namegen.third.6': 'Manor',
  'namegen.third.7': 'Lodge',
  'namegen.third.8': 'Cabin',
  'namegen.third.9': 'Home',
  'namegen.third.10': 'Croft',
  'namegen.third.11': 'Lea',
  'namegen.pattern': '{first}{second} {third}',
  's21.title': 'Ranch profile',
  's21.badges': 'Badges',
  's21.badgeCount': 'Unlocked {n}/{total}',
  's21.badgeDate': 'Unlocked {date}',
  's21.badgeLocked': 'Not unlocked yet',
  's21.avatarTitle': 'Change avatar',
  's21.avatarUse': 'Use this avatar',
  's21.avatarFoundOnly': 'Only breeds you\'ve found',
  's21.avatarCount': 'Found {n}/{total} breeds. Find more to unlock them.',
  's21.avatarLocked': 'You haven\'t found {name} yet. Find it to use it.',
  's21.avatarDone': 'Avatar changed!',
  's21.renameTitle': 'Rename ranch',
  's21.renameFree': 'Rename (free)',
  's21.renamePaid': 'Rename ({price} coins)',
  's21.renamedFirst': 'Ranch renamed! Next rename: {price} coins',
  'ach.firstMilk.name': 'First pail',
  'ach.firstMilk.cond': 'Collect milk for the first time',
  'ach.firstSale.name': 'Open for business',
  'ach.firstSale.cond': 'Sell something at the market for the first time',
  'ach.firstShip.name': 'First shipment',
  'ach.firstShip.cond': 'Ship a cow for the first time',
  'ach.gradeA.name': 'Grade A ranch',
  'ach.gradeA.cond': 'Get grade A on 10 shipments',
  'ach.newLife.name': 'New life',
  'ach.newLife.cond': 'Get your first calf from breeding',
  'ach.borrow.name': 'Borrowed a star',
  'ach.borrow.cond': 'Borrow another rancher\'s bull for the first time',
  'ach.popularBull.name': 'In-demand bull',
  'ach.popularBull.cond': 'Have your bulls borrowed 10 times',
  'ach.rice.name': 'Full granary',
  'ach.rice.cond': 'Harvest 1,000 kg of rice in total',
  'ach.codex.name.1': 'Breed spotter',
  'ach.codex.cond.1': 'Find 5 breeds',
  'ach.codex.name.2': 'Breed expert',
  'ach.codex.cond.2': 'Find 12 breeds',
  'ach.codex.name.3': 'Breed master',
  'ach.codex.cond.3': 'Find all 24 breeds',
  'ach.legend.name': 'A legend is born',
  'ach.legend.cond': 'Own a legendary cow',
  'ach.level.name.1': 'Rancher Lv 10',
  'ach.level.cond.1': 'Reach Lv 10',
  'ach.level.name.2': 'Rancher Lv 20',
  'ach.level.cond.2': 'Reach Lv 20',
  'ach.rich.name.1': 'Well-off',
  'ach.rich.cond.1': 'Reach 100,000 coins in net worth',
  'ach.rich.name.2': 'Tycoon',
  'ach.rich.cond.2': 'Reach 1,000,000 coins in net worth',
  'ach.tailwind.name': 'Rode the wave',
  'ach.tailwind.cond': 'Sell something during a super boom',
  'ach.weekChamp.name': 'Weekly champion',
  'ach.weekChamp.cond': 'Rank #1 in weekly income',
  'ach.pureBreed.name': 'Purebred keeper',
  'ach.pureBreed.cond': 'Raise a rare-or-better calf on its breed\'s feed (no crossbreed)',
  'ach.healer.name': 'Healing hands',
  'ach.healer.cond': 'Cure a sick cow',
  'ach.clean.name': 'Spotless ranch',
  'ach.clean.cond': 'Go 7 days in a row with no sick cows',
  'ach.trucks.name': 'Truck collector',
  'ach.trucks.cond': 'Own 3 truck styles',
};

const Map<String, String> _th = {
  'tabRanch': 'ฟาร์ม',
  'tabMarket': 'ตลาด',
  'tabFields': 'แปลงนา',
  'tabBreed': 'ผสมพันธุ์',
  'tabShop': 'ร้านค้า',
  'tabRecords': 'บันทึก',
  'level': 'Lv {lv}',
  'hud.xp': 'ค่าประสบการณ์ {pct}%',
  'hud.settings': 'ตั้งค่า',
  'hud.settingsNotBacked': 'ตั้งค่า (ยังไม่ได้สำรองฟาร์ม)',
  'connecting': 'กำลังเชื่อมต่อ…',
  'typeDairy': 'วัวนม',
  'typeDual': 'วัวงาน',
  'typeBeef': 'วัวเนื้อ',
  'bull': 'ตัวผู้',
  'cow': 'ตัวเมีย',
  'tier0': 'ธรรมดา',
  'tier1': 'พิเศษ',
  'tier2': 'หายาก',
  'tier3': 'ตำนาน',
  'days': '{d} วัน',
  'hours': '{h} ชม.',
  'minutes': '{m} นาที',
  'seconds': '{s} วินาที',
  'milk': 'นม',
  'beef': 'เนื้อวัว',
  'rice': 'ข้าว',
  'unitMilk': 'ขวด',
  'unitBeef': 'กก.',
  'unitRice': 'กก.',
  'news.rice_up.1': 'พายุพัดผ่าน ราคารับซื้อข้าวปรับขึ้น',
  'ago.min': '{n} นาทีที่แล้ว',
  'ago.hour': '{n} ชม.ที่แล้ว',
  'ago.day': '{n} วันที่แล้ว',
  'ago.now': 'เมื่อสักครู่',
  'date.today': 'วันนี้ {time}',
  'date.yesterday': 'เมื่อวาน {time}',
  'date.md': '{d}/{m} {time}',
  'appTitle': 'ฟาร์มวัวขาขึ้น',
  's01.version': 'เวอร์ชัน {v}',
  'loadingFarm': 'กำลังโหลดฟาร์ม…',
  's01.creating': 'กำลังเตรียมฟาร์มใหม่ให้…',
  's01.firstTime': 'เปิดครั้งแรกจะใช้เวลาไม่กี่วินาที',
  's01.failTitle': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
  's01.failCheck': 'ตรวจสอบการเชื่อมต่อแล้วลองใหม่',
  's01.failAuto': 'ระบบจะลองใหม่ให้เองทุก {n} วินาที',
  'retry': 'ลองใหม่',
  's05.milkName': 'นม{tier}',
  's05.spoiling': 'ใกล้เสีย',
  's05.fresh': 'ความ⁠สด',
  's05.collectedAgo': 'เก็บ {ago}',
  'g.sep': ' · ',
  's05.spoilIn': 'จะเสียในอีกราว {h} ชม. ของที่เสียจะถูกทิ้ง',
  's05.stored': 'สภาพ {pct}%',
  's05.shippedFrom': 'ส่งขาย {cow}',
  's05.lotsOldestFirst': '{n} ชุด · ขายชุดเก่าสุดก่อน',
  's05.milkCap': 'ความจุนม',
  's05.capLine': '{amount} ขวด ({pct}%)',
  's05.full': 'โกดังเต็มแล้ว: เก็บนมเข้าได้แค่บางส่วน และเมื่อถังนมเต็ม วัวจะหยุดให้นม',
  's05.nearFull': 'โกดังใกล้เต็มแล้ว อย่าลืมไปขายหรือขยายโกดัง',
  's05.capNote': 'เนื้อวัวและข้าวไม่กินพื้นที่โกดัง',
  'back': 'กลับ',
  'warehouseTitle': 'โกดัง',
  'g.levelN': 'ระดับ {n}',
  'upWarehouse': 'ขยายโกดัง',
  's05.emptyMilk': 'ยังไม่มีนมในโกดัง ไปเก็บนมที่ฟาร์มกัน',
  's05.emptyBeef': 'ยังไม่มีเนื้อวัว วัวที่โตเต็มวัยแล้วส่งขายได้',
  's05.emptyRice': 'ยังไม่มีข้าว ส่งวัวงานไปไถนาปลูกข้าวกัน',
  's05.goSell': 'ไปขายที่ตลาด',
  's05.priceNote': 'ราคาที่ได้ = ราคาตลาด × ตัวคูณ: นมคูณความหายากและความ⁠สด เนื้อวัวคูณเกรด ความหายาก และสภาพการเก็บ ข้าวคูณสภาพการเก็บ',
  'breed.holstein.name': 'โฮ⁠ลส⁠ไตน์',
  'breed.holstein.intro': 'วัวนมยอดนิยมลายด่างขาวดำ ตัวสูง ให้นมสม่ำเสมอ',
  'breed.fluffyHolstein.name': 'โฮ⁠ลส⁠ไตน์ขนฟู',
  'breed.fluffyHolstein.intro': 'โฮ⁠ลส⁠ไตน์ที่มีขนยาวฟูทั้งตัวกับผมหน้าม้า หน้าหนาวก็ไม่กลัวหนาว',
  'breed.jersey.name': 'เจ⁠อร์⁠ซีย์',
  'breed.jersey.intro': 'ตัวเล็กสีน้ำตาลอ่อน หน้าสั้น ดวงตากลมโตเป็นประกาย',
  'breed.glossBlack.name': 'วัวนมดำเงา',
  'breed.glossBlack.intro': 'ขนดำเงามีลายจุดขาว ยืนกลางแดดแล้วขนสะท้อนแสงระยิบระยับ',
  'breed.cottonCream.name': 'วัวปุยครีม',
  'breed.cottonCream.intro': 'ขนฟูสีครีมเหมือนก้อนสำลี ดูนุ่มนิ่ม',
  'breed.velvetBlack.name': 'วัวนมกำมะหยี่ดำ',
  'breed.velvetBlack.intro': 'ขนยาวสีดำเงาทั้งตัว เหมือนสวมเสื้อคลุมกำมะหยี่',
  'breed.chocolate.name': 'วัวช็อกโกแลต',
  'breed.chocolate.intro': 'ขนสีน้ำตาลแต้มลายสีครีม บนหัวมีครีมหนึ่งก้อน ดูเหมือนนมช็อกโกแลตแก้วหนึ่ง',
  'breed.strawberry.name': 'วัวสต⁠รอว์⁠เบอร์⁠รี',
  'breed.strawberry.intro': 'พื้นขาวครีมแต้มลายสีแดงสด บนหัวมีใบไม้สีเขียวหนึ่งใบ สต⁠รอว์⁠เบอร์⁠รีที่เดินได้ก็ตัวนี้เอง',
  'breed.yellow.name': 'วัวเหลืองไต้หวัน',
  'breed.yellow.intro': 'สีน้ำตาลอมเหลือง มีหนอกกลมเล็กบนไหล่ เป็นผู้ช่วยในนาที่ไว้ใจที่สุด',
  'breed.highland.name': 'ไฮ⁠แลนด์',
  'breed.highland.intro': 'ขนยาวสีเหลืองขมิ้นปรกลงมาปิดตา บนหัวมีเขายาวหนึ่งคู่',
  'breed.milkTea.name': 'วัวชานม',
  'breed.milkTea.intro': 'สีชานมอ่อน หนอกกลมมน นิสัยใจดีมาก',
  'breed.buffalo.name': 'กระบือไต้หวัน',
  'breed.buffalo.intro': 'ขนสีเทาเข้มเป็นเงา มีเขาใหญ่โค้งไปข้างหลังหนึ่งคู่ แรงเยอะมาก',
  'breed.cottonCandy.name': 'ไฮ⁠แลนด์สายไหม',
  'breed.cottonCandy.intro': 'ขนยาวสีชมพูอ่อนฟูฟ่อง เหมือนสายไหมก้อนกลมที่เดินได้',
  'breed.shaggyBuffalo.name': 'กระบือขนยาว',
  'breed.shaggyBuffalo.intro': 'กระบือที่มีขนยาวสีเทาเข้มทั้งตัว เขาก็ยังใหญ่และโค้งเหมือนเดิม',
  'breed.honey.name': 'วัวน้ำผึ้ง',
  'breed.honey.intro': 'ขนสีทองเป็นเงา เหมือนราดน้ำผึ้งไว้ทั้งตัว',
  'breed.goldenEar.name': 'วัวรวงทอง',
  'breed.goldenEar.intro': 'ตัวสีทองมีลายรวงข้าว บนหัวมีรวงข้าวช่อเล็ก ไถนาได้ผลผลิตมากเป็นพิเศษ',
  'breed.angus.name': 'แอ⁠งกัส',
  'breed.angus.intro': 'วัวเนื้อร่างบึกบึนสีดำถ่าน ไม่มีเขา',
  'breed.galloway.name': 'กัลโลเวย์',
  'breed.galloway.intro': 'ขนยาวหยิกสีดำถ่าน ทั้งหนาทั้งอุ่น ไม่มีเขา',
  'breed.charolais.name': 'ชา⁠โร⁠เลส์',
  'breed.charolais.intro': 'ตัวใหญ่สีขาวครีม กล้ามเนื้อแน่น',
  'breed.wagyu.name': 'วากิ⁠ว',
  'breed.wagyu.intro': 'ขนดำเงาวาววับ บนหัวมีเขาสั้นหนึ่งคู่',
  'breed.whiteFleece.name': 'วัวขนปุยขาว',
  'breed.whiteFleece.intro': 'ขนยาวหยิกสีขาวครีม มองจากไกลเหมือนก้อนเมฆ',
  'breed.fluffyWagyu.name': 'วากิ⁠วขนฟู',
  'breed.fluffyWagyu.intro': 'วากิ⁠วแบบขนยาว ขนทั้งเงาทั้งฟู มีเขาสั้นเหมือนกัน',
  'breed.whiteWagyu.name': 'วากิ⁠วขาว',
  'breed.whiteWagyu.intro': 'ขนสีขาวครีมเป็นเงา บนหัวมีเขาสั้นหนึ่งคู่',
  'breed.starry.name': 'วัวดวงดาว',
  'breed.starry.intro': 'ขนสีน้ำเงินเข้มมีดาวสีขาว หาเจอยากที่สุดในบรรดาวัวเนื้อ',
  'trait.A': 'ขนยาว',
  'trait.B': 'สีอ่อน',
  'trait.C': 'ขนเงา',
  's02.title': 'ตั้งชื่อให้ฟาร์ม',
  's02.sub': 'ตั้งชื่อที่ชอบได้เลย!',
  's02.placeholder': 'เช่น ฟาร์มแสงเช้าริมน้ำ',
  's02.filled': 'ได้ชื่อแล้ว! ใช้เลยหรือจะแก้ต่อก็ได้',
  's02.widthRule': 'อักษรไทย อังกฤษ และตัวเลขนับตัวละ 1 อักษรจีนนับ 2',
  's02.suggest': 'สุ่มชื่อให้',
  's02.sameName': 'ชื่อซ้ำกับคนอื่นก็ไม่เป็นไร จะมี #หมายเลขต่อท้ายไว้แยก เช่น "ฟาร์มแสงเช้าริมน้ำ #1234"',
  's02.confirm': 'ใช้ชื่อนี้',
  's02.welcome': 'ยินดีต้อนรับสู่\n{name}',
  's02.gifts': 'มีของขวัญให้ก่อน มาเริ่มทำฟาร์มกันเลย!',
  's02.giftMilk': 'ให้นมได้',
  'costCoins': '{v} เหรียญ',
  's02.giftBucket': 'ในถังนมมีนมแล้ว {n} ขวด',
  's02.boost': 'ช่วง {h} ชม. แรกให้นม ×{x} เข้าไปก็เก็บนมและขายนมได้เลย',
  'g.enterRanch': 'เข้าฟาร์ม',
  's02.errShort': 'ชื่อต้องยาวอย่างน้อย 2 ตัวอักษร',
  's02.errLong': 'ชื่อยาวได้ไม่เกิน 16 ตัวอักษร',
  's02.errEmoji': 'ใช้สัญลักษณ์แสดงอารมณ์ในชื่อไม่ได้',
  's02.errChar': 'มีอักขระที่ใช้ในชื่อไม่ได้',
  'pickForBreed': 'ไปผสมพันธุ์',
  'ship': 'ส่งขาย',
  's07.kgBeef': 'ได้เนื้อวัวราว {kg} กก.',
  's07.beefPrice': 'ราคาเนื้อวัวตอนนี้ {price} เหรียญ/⁠กก.',
  'loadingPreview': 'กำลังโหลดโอกาสได้แต่ละเกรด…',
  's07.probFailed': 'โหลดโอกาสได้แต่ละเกรดไม่สำเร็จ',
  'g.grade': 'เกรด {g}',
  's07.income': 'ได้ราว {v} เหรียญ',
  'expectedValue': 'คาดว่าจะได้ราว {v} เหรียญ',
  's07.note': 'เกรดจะสุ่มตอนส่งขาย เนื้อวัวจะเข้าโกดังทันที จะขายหรือไม่ และขายเมื่อไรก็เลือกเองได้',
  'shipConfirmTitle': 'ส่งขายเลยไหม?',
  'cancel': 'ยกเลิก',
  's07.confirm': 'ยืนยันส่งขาย',
  's07.blockWorking': 'วัวตัวนี้กำลังไถนาอยู่ ต้องเรียกกลับก่อนจึงจะส่งขายได้',
  's20.tipA': 'เลี้ยงมาพอดีเป๊ะ! เกรด A ขายได้ราคา ×1.25',
  's20.tipB': 'ไม่เลว! เกรด B ขายตามราคาตลาด',
  's20.tipC': 'เกรด C ขายได้ราคา ×0.75 คราวหน้าเลี้ยงให้ถึงน้ำหนักที่ดีที่สุดก่อนส่งขาย จะมีโอกาสได้เกรด A มากขึ้น',
  's20.title': 'เกรดส่งขายของ {cow}',
  's20.gradeFormat': 'เกรด {grade}',
  's20.kgIn': 'เนื้อวัว {kg} กก. เข้าโกดังแล้ว',
  's20.sellAll': 'ขายทั้งหมดตอนนี้จะได้ราว {v} เหรียญ',
  's20.goMarket': 'ไปตลาด',
  'ok': 'ตกลง',
  's10.upgraded': 'อัป⁠เกรดเสร็จแล้ว: {what} {effect}',
  'bucketTitle': 'ถังนม',
  's10.effectBottles': '{a} → {b} ขวด',
  'notEnoughCoins': 'เหรียญไม่พอ ขาดอีก {n} เหรียญ',
  'networkError': 'การเชื่อมต่อไม่เสถียร โปรดลองใหม่ภายหลัง',
  'g.studNoticeTitle': 'มีคนยืมพ่อพันธุ์ของคุณ',
  'g.studNoticeBody': 'ให้ {ranch} ยืม {cow} แล้ว ได้รับ {price} เหรียญ',
  'upgradesTitle': 'อัป⁠เกรด',
  'g.busySub': 'ส่งแล้ว รอเซิร์ฟเวอร์ตอบกลับ',
  'upBucket': 'ขยายถังนม',
  'g.busy': 'รอสักครู่…',
  'upFresh': 'ห้องเย็น',
  'effectFresh': 'คงความ⁠สด {a} → {b} ชม.',
  'stageCalf': 'ลูกวัว',
  'stageOld': 'วัยชรา',
  'badgeWorking': 'ไถนาอยู่',
  'badgeListed': 'ลงประกาศอยู่',
  'badgeBred': 'ผสมพันธุ์แล้ว',
  'g.newCalf': 'ลูกวัวตัวใหม่ {cow}',
  'growUp': 'จะโตในอีก {v}',
  'g.refreshing': 'กำลังโหลดใหม่…',
  'g.breedSex': '{breed} {sex}',
  'loadingShop': 'กำลังโหลดโอกาสการสุ่ม…',
  's19.probFailed': 'โหลดโอกาสการสุ่มไม่สำเร็จ',
  'probType': 'ประเภท',
  'probSex': 'เพศ',
  'probTier': 'ความหายาก',
  's19.descA': 'สุ่มได้วัวหายากง่ายที่สุด',
  's19.descB': 'มีโอกาสได้วัวหายาก',
  's19.descC': 'ราคาถูก ส่วนใหญ่เป็นวัวธรรมดา',
  's19.segDraw': 'สุ่มวัว',
  's19.segFacility': 'อัป⁠เกรด',
  's19.rule': 'เลือกได้แค่เกรด ส่วนประเภท เพศ และความหายากจะสุ่ม โดยเปิดเผยโอกาสทั้งหมด วัวที่ได้จะเป็นลูกวัว',
  's19.penFull': 'คอกวัวเต็มแล้ว ({used} / {slots} ช่อง) ขยายคอกหรือส่งขายก่อน',
  'drawnTitle': 'ได้วัวเกรด {g} แล้ว!',
  's19.drawnDraft': 'จะโตในอีก {time} พอโตแล้วส่งไปไถนาปลูกข้าวได้',
  'upPen': 'ขยายคอกวัว',
  'effectPen': '{a} → {b} ช่อง',
  's10.penTimes': 'ขยายแล้ว {n} ครั้ง',
  's10.effectFresh': 'สด 100% ได้นาน {a} → {b} ชม.',
  's10.levelOf': 'ระดับ {n} / {max}',
  'maxed': 'สูงสุดแล้ว',
  'opensIn': 'เปิดในอีก {v}',
  's10.maxLevel': 'ระดับสูงสุด',
  's10.freshMax': 'สด 100% ได้นาน {h} ชม.',
  's10.maxedEffect': 'ใหญ่ที่สุดแล้ว',
  's10.fieldsNote': 'เปิดแปลงนาใหม่ได้ที่หน้า "แปลงนา"',
  's10.penNever': 'ยังไม่เคยขยาย',
  's11.earned': 'รายได้สะสมถึง {v} เหรียญแล้ว!',
  's11.hint': 'ขายนม เนื้อวัว ข้าว หรือให้ยืมพ่อพันธุ์ต่อไป แล้วเลเวลจะสูงขึ้น',
  's11.ribbon': 'เลเวลอัป',
  's11.lv': 'Lv',
  's11.coachPenTitle': 'ขยายคอกวัวได้แล้ว!',
  's11.coachPenBody': 'เพิ่มหนึ่งช่องก็เลี้ยงวัวได้อีกหนึ่งตัว ไปที่ "ร้านค้า › อัป⁠เกรด" เพื่อขยายคอกวัว ({price} เหรียญ)',
  's11.coachPenGo': 'ไปขยาย',
  's11.coachBullTitle': 'ลูกวัวตัวผู้โตแล้ว!',
  's11.coachBullBody': 'ผสมพันธุ์กับวัวตัวเมียได้ (วัวของตัวเองฟรี) หรือส่งไปไถนาปลูกข้าวก็ได้',
  's11.coachBullGo': 'ไปผสมพันธุ์',
  's11.backupTitle': 'สำรองฟาร์มไว้กันเถอะ',
  's11.backupBody': 'เปลี่ยนมือถือหรือมือถือเสียก็กู้คืนได้',
  's11.later': 'ไว้ทีหลัง',
  's11.backupNow': 'สำรองเลย',
  's03.normal': 'ปกติ',
  's03.panAria': 'ตำแหน่งในฟาร์ม',
  's03.expandAria': 'ขยายแผงถังนม โกดัง และราคารับซื้อ',
  's03.collapseAria': 'ย่อแผงถังนม โกดัง และราคารับซื้อ',
  's03.expand': 'ขยาย',
  's03.collapse': 'ย่อ',
  'collect': 'เก็บนม',
  's03.full': 'เต็มแล้ว',
  's03.bucketCount': '{amount} ขวด',
  's03.fullStopped': 'เต็มแล้ว หยุดให้นม',
  's03.fullIn': 'เต็มในอีก ~{time}',
  's03.noMilkers': 'ไม่มีวัวที่ให้นม',
  's03.milkFull': 'นมเต็มแล้ว',
  's03.milkUsed': 'นมใช้พื้นที่ {pct}%',
  's03.prices': 'ราคารับซื้อ',
  's03.vsNormal': 'เทียบปกติ',
  's03.bubbleFull': 'ถังนมเต็มแล้ว',
  'cowsTitle': 'วัวของฉัน',
  'commodityTag': '[{name}] ',
  'bothTag': '[ทั้งหมด] ',
  's03.swipeHint': 'เลื่อนซ้ายขวาเพื่อดูทั่วฟาร์ม',
  's03.metaField': 'อยู่แปลงที่ {n} · ข้าว {rate} กก./⁠ชม.',
  's03.metaListed': 'ลงประกาศพ่อพันธุ์: {price} เหรียญ',
  'milkRate': 'ให้นม {v} ขวด/⁠ชม.',
  'weight': 'น้ำหนัก {v} กก.',
  's03.metaValue': 'มูลค่าราว {v} เหรียญ',
  'collected': 'เก็บนม {v} ขวด เข้าโกดังแล้ว',
  'collectedSpoiled': 'เก็บนม {v} ขวด ทิ้งนมที่เสีย {n} ขวด',
  's03.partial': 'โกดังเต็ม เก็บเข้าได้ {n} ขวด\nยังเหลืออีก {left} ขวดในถังนม',
  's03.popMilk': 'ให้นม{tier} {n} ขวด/⁠ชม.',
  's03.popDetail': 'ดูรายละเอียด',
  'penSummary': 'คอกวัว {used} / {slots} ช่อง',
  's03.penFullSuffix': ' (เต็ม)',
  's03.expandPen': 'ขยายคอก',
  'g.all': 'ทั้งหมด',
  'noCows': 'ยังไม่มีวัวในคอก',
  's03.emptyHint': 'ไปสุ่มวัวที่ร้านค้า หรือรอลูกวัวที่ผสมพันธุ์ไว้เกิด',
  's03.goShop': 'ไปร้านค้า',
  'g.close': 'ปิด',
  's06.bigNews': 'ข่าวใหญ่',
  'news.beef_up.1': 'ฤดูปิ้งย่างเริ่มแล้ว',
  's03.bigNewsBody': 'ราคารับซื้อ{name} {chg} ตอนนี้ {price} เหรียญ/⁠{unit}',
  's03.bigNewsAll': 'ราคารับซื้อทุกอย่าง {chg}',
  's03.bigNewsGo': 'ไปดูที่ตลาด',
  's06.vsSame': 'เท่าปกติ',
  's06.vsHigher': 'สูงกว่าปกติ {pct}',
  's06.vsLower': 'ต่ำกว่าปกติ {pct}',
  's06.loading': 'กำลังโหลดราคารับซื้อ…',
  's06.title': 'ราคารับซื้อตอนนี้',
  's06.tapToSell': 'แตะแถวเพื่อขาย',
  'priceUnit': 'เหรียญ/⁠{unit}',
  's06.baseLine': 'ปกติ (ราคาพื้นฐาน): นม {milk} เหรียญ/⁠ขวด, เนื้อวัว {beef} เหรียญ/⁠กก., ข้าว {rice} เหรียญ/⁠กก.',
  's06.multMilk': 'ราคาตลาด × ความหายาก × ความ⁠สด',
  's06.multBeef': 'ราคาตลาด × เกรด × ความหายาก × สภาพการเก็บ',
  's06.multRice': 'ราคาตลาด × สภาพการเก็บ',
  's06.sellTitle': 'ขาย{name}',
  'inventory': 'มีอยู่ {qty} {unit}',
  'nothingToSell': 'ในโกดังไม่มี{name}ให้ขาย',
  'sellTitle': 'ขาย',
  'quoting': 'กำลังคำนวณ…',
  's06.quoteFailed': 'คำนวณไม่สำเร็จ',
  'estAvgPrice': 'ราคาเฉลี่ยโดยประมาณ',
  'estAvgValue': '{avg} เหรียญ/⁠{unit}',
  's06.estTotalLabel': 'ยอดรวมโดยประมาณ',
  's06.marketPrice': 'ราคาตลาด',
  'g.pricePer': '{price} เหรียญ/⁠{unit}',
  's06.formula': 'ราคาที่ได้ = {mult}',
  's06.lots': ' ({n} ชุด)',
  's06.qty': 'จำนวน',
  's06.oldestFirst': 'ขายจากชุดที่เก่าที่สุดก่อน',
  'tooMuch': 'ขายทีเดียวเยอะเกินไป ราคาเฉลี่ยจะแย่ลง แบ่งขายหลายรอบดีไหม?',
  'sellConfirm': 'ยืนยันขาย {qty} {unit}',
  'newsTitle': 'ข่าว',
  's06.up': 'ปัจจัยบวก',
  's06.down': 'ปัจจัยลบ',
  's06.superTag': 'บูมสุดขีด',
  's06.swanTag': 'หงส์ดำ',
  's06.pinUp': 'ราคารับซื้อ{name}เพิ่มเป็นสองเท่า',
  's06.pinDown': 'ราคารับซื้อ{name}เหลือหนึ่งในสิบ',
  's06.pinUpAll': 'ราคารับซื้อทุกอย่าง\nเพิ่มเป็นสองเท่า',
  's06.pinDownAll': 'ราคารับซื้อทุกอย่าง\nเหลือหนึ่งในสิบ',
  's06.pinNow': 'ตอนนี้ {price} เหรียญ/⁠{unit}',
  'noNews': 'ตอนนี้ยังไม่มีข่าว',
  'sold': 'ขาย {qty} {unit} ราคาเฉลี่ย {avg} รวม {total} เหรียญ',
  's04.age': 'อายุ',
  's04.growIn': 'จะโตในอีก',
  'g.milk': 'ให้นม',
  'g.perHourMilk': 'ขวด/⁠ชม.',
  'g.plow': 'ไถนา',
  'g.perHourRice': 'กก./⁠ชม.',
  's04.useBeef': 'เนื้อมากสุด',
  's04.useBreed': 'ผสมพันธุ์',
  's04.weight': 'น้ำหนัก',
  'g.kg': 'กก.',
  's04.value': 'มูลค่าส่งขาย',
  's04.about': 'ราว {v}',
  'g.coin': 'เหรียญ',
  's04.originStart': 'ตอนเริ่มเกม',
  's04.originShop': 'ร้านค้า เกรด {g}',
  's04.originBreed': 'ผสมพันธุ์เอง',
  's04.originStud': 'ยืมพ่อพันธุ์',
  'origin': 'ที่มา: {v}',
  'shipGradeTitle': 'โอกาสเกรดเมื่อส่งขาย',
  's04.gradeHint': 'เลี้ยงถึงน้ำหนักที่ดีที่สุด ได้เกรด A ง่ายสุด',
  's04.oldNote': 'วัยชรา: ผ่านช่วงวัยที่ดีที่สุดแล้ว ผลผลิตและคุณภาพเนื้อจะลดลงทีละน้อย',
  's04.listStud': 'ลงประกาศพ่อพันธุ์',
  's04.studFee': 'ค่าพ่อพันธุ์',
  's04.feeHowGrow': '{tier} (กก.ละ {rate} เหรียญ) × {kg} กก. โตขึ้นจะแพงขึ้นอีก',
  's04.feeHowMax': '{tier} (กก.ละ {rate} เหรียญ) × {kg} กก. โตเต็มที่แล้ว',
  's04.listTitle': 'ลงประกาศ {cow} เป็นพ่อพันธุ์',
  's04.listHint': 'คนอื่นจ่ายเงินจำนวนนี้เพื่อยืมวัวตัวผู้ของคุณไปผสมพันธุ์ เงินเป็นของคุณ ลูกวัวเป็นของอีกฝ่าย การให้ยืมนับเป็นการผสมพันธุ์ครั้งเดียวในชีวิตของวัวตัวนี้',
  's04.listConfirm': 'ลงประกาศ ({price} เหรียญ)',
  'unlist': 'ถอนประกาศ',
  'g.assign': 'ส่งไปไถนา',
  'recallFirst': 'กำลังไถนาอยู่ที่แปลงที่ {n} ต้องเรียกกลับก่อนจึงจะส่งขายหรือผสมพันธุ์ได้',
  's04.recall': 'เรียกกลับ',
  's04.calfHint': 'ลูกวัวต้องโตก่อนจึงจะผสมพันธุ์หรือส่งขายได้',
  's04.cantBreedYet': 'ยังผสมพันธุ์ไม่ได้',
  'shipNotAdult': 'ลูกวัวยังส่งขายไม่ได้',
  's04.noteBred': 'ผสมพันธุ์แล้ว: วัวแต่ละตัวผสมพันธุ์ได้ครั้งเดียวในชีวิต',
  's04.alreadyBred': 'ผสมพันธุ์ไปแล้ว',
  'cowTitle': 'วัว #{id}',
  's04.goneTitle': 'ไม่พบวัวตัวนี้',
  's04.goneBody': 'อาจถูกส่งขายไปแล้ว หรือมีการจัดการจากมือถือเครื่องอื่น',
  's04.backRanch': 'กลับฟาร์ม',
  's04.noField': 'ไม่มีแปลงนาว่าง: เปิดแปลงใหม่ หรือเรียกวัวงานตัวอื่นกลับก่อน',
  's04.recallFirstOx': 'กำลังไถนาอยู่ที่แปลงที่ {n} ต้องเรียกกลับก่อนจึงจะส่งขาย ผสมพันธุ์ หรือลงประกาศพ่อพันธุ์ได้',
  'breedFree': 'ค่าใช้จ่าย ฟรี (วัวของตัวเอง)',
  's08.outcomeTitle': 'ลูกวัวที่อาจเกิด',
  'pickBoth': 'เลือกวัวตัวผู้และวัวตัวเมียอย่างละตัว',
  's08.calculating': 'กำลังคำนวณโอกาส…',
  's08.probFailedRetry': 'โหลดโอกาสไม่สำเร็จ จะลองใหม่ในอีก {n} วินาที',
  's08.notFound': 'ยังไม่เคยพบ',
  'bullProbLine': 'โอกาสได้ตัวผู้ {v}',
  's08.growRange': 'ลูกวัวโตใน {v}',
  's08.hoursRange': '{a}–{b} ชม.',
  'subOwnBreed': 'ผสมพันธุ์เอง',
  'subStud': 'ยืมพ่อพันธุ์',
  's08.rule': 'วัวแต่ละตัวผสมพันธุ์ได้ครั้งเดียวในชีวิต · ผสมวัวของตัวเองฟรี',
  'pickSire': 'เลือกวัวตัวผู้',
  'pickDam': 'เลือกวัวตัวเมีย',
  'noSire': 'ไม่มีวัวตัวผู้โตเต็มวัยที่ผสมพันธุ์ได้',
  'noDam': 'ไม่มีวัวตัวเมียโตเต็มวัยที่ผสมพันธุ์ได้',
  's08.noSireHint': 'ไปสุ่มวัวที่ร้านค้า หรือรอลูกวัวตัวผู้โต หรือไปที่ "ยืมพ่อพันธุ์" เพื่อยืมวัวตัวผู้ของคนอื่นก็ได้',
  's08.noDamHint': 'ไปสุ่มวัวที่ร้านค้า หรือรอลูกวัวตัวเมียโต',
  's08.breedBtnFree': 'ผสมพันธุ์ (ฟรี)',
  's08.alreadyBred': '{cow} ผสมพันธุ์ไปแล้ว (วัวแต่ละตัวผสมพันธุ์ได้ครั้งเดียวในชีวิต)',
  's08.penFull': 'คอกวัวเต็มแล้ว ขยายคอกหรือส่งขายก่อน ลูกวัวจะได้มีที่อยู่',
  's08.bredBtn': 'ผสมพันธุ์แล้ว',
  'breedDone': 'ผสมพันธุ์สำเร็จ! {cow} เกิดแล้ว',
  's18.ownerLabel': 'เจ้าของ: ',
  'botPrefix': 'บอท',
  's18.growing': 'ยังโตอยู่',
  's18.noBullTitle': 'ไม่มีวัวตัวผู้ที่ลงประกาศได้',
  's18.noBullHint': 'ต้องโตเต็มวัย ยังไม่เคยผสมพันธุ์ และไม่ได้ไถนาอยู่',
  's18.feeLabel': 'ค่าพ่อพันธุ์ {price} เหรียญ',
  'list': 'ลงประกาศ',
  's18.feeNote': 'ระบบคิดค่าพ่อพันธุ์ให้: น้ำหนักวัวตัวผู้ × ราคาต่อ กก. ตามความหายาก โตขึ้นราคาจะขึ้นเอง',
  'studMineTitle': 'พ่อพันธุ์ของฉัน',
  'studIncome': 'รายได้สะสม {v} เหรียญ',
  's18.logTitle': 'ประวัติการยืม',
  'g.loading': 'กำลังโหลด…',
  'loadFailed': 'โหลดไม่สำเร็จ',
  'reload': 'โหลดใหม่',
  'studEmpty': 'ตอนนี้ยังไม่มีใครลงประกาศพ่อพันธุ์',
  'pickDamForStud': 'เลือกวัวตัวเมียของตัวเอง',
  'studMarketTitle': 'ตลาดพ่อพันธุ์',
  's18.pullHint': 'ดึงลงเพื่อโหลดใหม่',
  's18.marketHint': 'จ่ายเงินยืมวัวตัวผู้ของคนอื่น: เงินเป็นของเจ้าของ ลูกวัวเป็นของคุณ',
  's18.feeLine': 'ค่าใช้จ่าย {price} เหรียญ (จ่ายให้เจ้าของ)',
  'borrow': 'ยืมพ่อพันธุ์ ({price} เหรียญ)',
  'pickListing': 'เลือกวัวตัวผู้ที่จะยืมก่อน แล้วค่อยเลือกวัวตัวเมียของตัวเอง',
  's18.borrowedBtn': 'ยืมแล้ว',
  'borrowed': 'ยืมพ่อพันธุ์สำเร็จ! จ่ายให้เจ้าของ {price} เหรียญ',
  's18.goneTitle': 'ยืมไม่ได้แล้ว',
  's18.goneBody': 'วัวตัวผู้ตัวนี้เพิ่งถูกคนอื่นยืมไป หรือเจ้าของถอนประกาศแล้ว\nไม่มีการหักเงิน',
  's18.reloadMarket': 'โหลดตลาดใหม่',
  's18.feeChangedTitle': 'ค่าพ่อพันธุ์เปลี่ยนแล้ว',
  's18.feeChangedBody': 'วัวตัวผู้ตัวนี้โตขึ้น ค่าพ่อพันธุ์เปลี่ยนจาก {old} เป็น {now} เหรียญ\nจะยืมในราคาใหม่ไหม?',
  's18.borrowNew': 'ยืมราคาใหม่ ({price} เหรียญ)',
  's18.logIncome': 'รายได้สะสมจากการให้ยืม {v} เหรียญ',
  's18.out': 'ให้ยืม',
  's18.in': 'ยืมมา',
  's18.lentTo': 'ให้ {ranch} ยืม {cow}',
  's18.borrowedFrom': 'ยืม {cow} จาก {ranch}',
  's18.calfBorn': 'เกิดลูกวัว {cow}',
  's18.logKeep': 'เก็บประวัติไว้แค่ {n} วันล่าสุด',
  's18.logEmpty': 'ยังไม่มีประวัติการยืม',
  's18.logEmptyOut': 'ยังไม่มีประวัติการให้ยืม',
  's18.logEmptyIn': 'ยังไม่มีประวัติการยืมมา',
  's18.deletedRanch': 'ฟาร์มที่ถูกลบแล้ว',
  'g.growsIn': 'จะโตในอีก {time}',
  'fieldName': 'แปลงที่ {n}',
  's17.leftover': 'เรียกวัวกลับแล้ว ในแปลงยังมีข้าว {kg} กก. จะเก็บเกี่ยวไปพร้อมกัน',
  's17.emptyHint': 'แปลงว่าง: ส่งวัวงานโตเต็มวัยมาไถนาปลูกข้าว',
  'fieldEmpty': 'แปลงว่าง',
  'noOx': 'ไม่มีวัวงานโตเต็มวัยที่ส่งไปไถนาได้',
  'assignOx': 'ส่งไปไถนา',
  's17.full': 'เต็มแล้ว',
  'fieldRate': 'ชั่วโมงละ {v} กก.',
  'recall': 'เรียกกลับ',
  'fieldFull': 'ข้าวเต็มแล้ว รีบเก็บเกี่ยวเลย! เก็บเกี่ยวแล้วข้าวถึงจะโตต่อ',
  's17.fullIn': 'เต็มในอีก ~{time} (สะสมได้สูงสุด {h} ชม.)',
  'fieldsTitle': 'แปลงนา',
  's17.ofMax': '/ {max} แปลง',
  's17.stock': 'ข้าวในโกดัง',
  's17.perHour': 'ต่อชั่วโมง',
  'harvestAll': 'เก็บเกี่ยว (ในนามีราว {kg} กก.)',
  's17.harvestNone': 'เก็บเกี่ยว (ในนายังไม่มีข้าว)',
  'expandField': 'เปิดแปลงใหม่ ({cost} เหรียญ)',
  'pickOx': 'ส่งวัวงานไปแปลงที่ {n}',
  's17.inField': 'อยู่แปลงที่ {n}',
  's17.noOxHint': 'วัวงานต้องโตเต็มวัย ไม่ได้อยู่แปลงอื่น และไม่ได้ลงประกาศพ่อพันธุ์\nไปสุ่มวัวที่ร้านค้า หรือผสมวัวนมกับวัวเนื้อให้ได้วัวงานก็ได้',
  'g.gotIt': 'เข้าใจแล้ว',
  'harvested': 'เก็บเกี่ยวข้าว {kg} กก. เข้าโกดังแล้ว',
  's17.maxFields': 'มีแปลงนาแล้ว {n} แปลง (สูงสุด)',
  'fieldExpanded': 'เปิดแปลงใหม่แล้ว (แปลงที่ {n})',
  'g.unknownBreed': '???',
  'subCodex': 'คอลเลกชัน',
  'subRank': 'อันดับ',
  's09.found': 'พบแล้ว',
  's09.allFound': 'พบครบทั้ง {n} สายพันธุ์แล้ว! อันดับคอลเลกชันจะแสดงว่าคุณสะสมครบ',
  's09.hint': 'ได้สายพันธุ์ใหม่จากลูกวัวที่เกิด การสุ่ม หรือการยืมพ่อพันธุ์ จะถูกบันทึกไว้ที่นี่',
  's09.useCount': '{use} {n} สายพันธุ์',
  's09.howDairy': 'พ่อแม่เป็นวัวนมทั้งคู่',
  's09.howBeef': 'พ่อแม่เป็นวัวเนื้อทั้งคู่',
  's09.howDraft': 'ฝั่งหนึ่งวัวนม อีกฝั่งวัวเนื้อ (หรือวัวงานทั้งคู่)',
  's09.howNoTrait': '{use} และไม่มีลักษณะใดปรากฏ',
  's09.howTraits': '{use} และพ่อแม่ต้องมียีน "{traits}" ทั้งคู่ (แม้ดูไม่ออกก็อาจมียีนนี้)',
  'g.listSep': ', ',
  's09.milkCow': 'ให้นม (ตัวเมีย)',
  's09.bestKg': 'น้ำหนักที่ดีที่สุด',
  's09.mult': 'ตัวคูณราคาขาย',
  's09.multBeef': '(เนื้อวัว)',
  's09.calfGrow': 'ลูกวัวโตใน',
  'g.hourUnit': 'ชม.',
  's09.notFoundYet': 'ยังไม่พบ',
  's09.no': 'No.{n}',
  's09.howTitle': 'ผสมให้ได้อย่างไร',
  's09.firstFound': 'พบครั้งแรก: {date} · ตอนนี้มี {n} ตัว',
  'date.mdOnly': '{d}/{m}',
  's09.unknownTitle': 'ยังไม่พบสายพันธุ์นี้',
  's09.unknownBody': '{use} · {tier} ลองผสมพันธุ์วัวหลายแบบ หรือไปลองสุ่มที่ร้านค้า',
  'rankNetworth': 'ทรัพย์สินรวม',
  'rankCollection': 'คอลเลกชัน',
  'rankWeekly': 'รายได้สัปดาห์นี้',
  's12.kinds': 'สายพันธุ์',
  's12.me': 'ฉัน',
  's12.complete': 'ครบ',
  's12.weeklyHint': 'คำนวณใหม่ทุกวัน{w} เวลา {time}',
  's12.networthHint': 'เหรียญ + สินค้าในโกดังคิดตามราคาตลาด + มูลค่าวัว',
  's12.collectionHint': 'จำนวนสายพันธุ์ที่พบ สูงสุด {n} สายพันธุ์',
  's12.pullHint': ' ดึงลงเพื่อโหลดใหม่',
  's12.myRank': 'อันดับของฉัน',
  's12.rankN': 'อันดับที่ {n}',
  'notRanked': 'ไม่ติดอันดับ',
  's13.web': 'เว็บ',
  's13.ssoApple': 'ลงชื่อเข้าด้วย Apple',
  's13.ssoGoogle': 'ลงชื่อเข้าใช้ด้วย Google',
  's13.privacy': 'ใช้เพื่อกู้คืนฟาร์มเท่านั้น ไม่เก็บอีเมลและชื่อของคุณ',
  's13.ssoOffline': 'เชื่อมต่ออินเทอร์เน็ตก่อนจึงจะลงชื่อเข้าใช้ได้',
  's13.notBacked': 'ยังไม่ได้สำรอง',
  's13.backed': 'สำรองแล้ว',
  's13.title': 'ตั้งค่า',
  's13.sound': 'เสียง',
  's13.language': 'ภาษา',
  's13.updown': 'สีราคา',
  's13.up': 'ขึ้น',
  's13.down': 'ลง',
  's13.backup.title': 'สำรองฟาร์ม',
  's13.backup.sub': 'เปลี่ยนมือถือหรือมือถือเสียก็กู้คืนได้',
  's13.delete': 'ลบฟาร์มของฉัน',
  's13.privacyPolicy': 'นโยบายความเป็นส่วนตัว',
  's13.version': 'เวอร์ชัน',
  's13.footer': '{game} · ทุกอย่างคำนวณบนเซิร์ฟเวอร์',
  's13.backup.done': 'สำรองฟาร์มแล้ว หลังเปลี่ยนมือถือหรือติดตั้งใหม่ ลงชื่อเข้าใช้ด้วยบัญชีที่ผูกไว้ก็กู้คืนได้',
  's13.backup.lead': 'เมื่อสำรองแล้ว จะเปลี่ยนมือถือหรือมือถือเสียก็กู้คืนฟาร์มได้',
  's13.backup.warn': 'ฟาร์มที่ไม่ได้สำรองไว้ ถ้ามือถือเสียจะกู้คืนไม่ได้',
  's13.backup.account': 'บัญชี {name}',
  's13.backup.boundOn': 'ผูกแล้ว · {date}',
  'date.ymd': '{d}/{m}/{y}',
  's13.unbind': 'เลิกผูก',
  's13.backup.addGoogle': 'ถ้าอาจเปลี่ยนไปใช้มือถือ Android ในอนาคต ให้ผูกบัญชี Google เพิ่มอีกบัญชี',
  's13.backup.addGoogleAndroid': 'บนมือถือ Android ต้องใช้บัญชี Google กู้คืนฟาร์ม แนะนำให้ผูกบัญชี Google เพิ่มอีกบัญชี',
  's13.binding': 'กำลังผูกบัญชี…',
  's13.backup.before': 'เคยสำรองไว้แล้ว? ลงชื่อเข้าใช้ด้วยบัญชีเดิม ก็เปลี่ยนกลับไปฟาร์มเดิมได้',
  's13.del.word': 'ลบ',
  's13.del.title': 'ลบแล้วกู้คืนไม่ได้',
  's13.del.item1': 'ฟาร์ม "{name}" วัวทุกตัว เหรียญ และโกดังจะถูกลบทั้งหมด',
  's13.del.item2': 'ข้อมูลในอันดับก็จะถูกลบด้วย',
  's13.del.item3': 'บัญชี Apple/Google ที่ผูกไว้จะถูกเลิกผูก แล้วนำไปผูกกับฟาร์มใหม่ได้ภายหลัง',
  's13.del.item4': 'มือถือเครื่องนี้จะกลับไปที่หน้าจอตอนเปิดครั้งแรก',
  's13.del.prompt': 'พิมพ์ "{word}" เพื่อยืนยัน',
  's13.deleted': 'ลบฟาร์มแล้ว',
  's13.thanks': 'ขอบคุณที่ดูแลกันมาตลอด',
  's14.newRanch': 'เริ่มฟาร์มใหม่',
  's13.del.failed': 'ลบไม่สำเร็จ: การเชื่อมต่อไม่เสถียร โปรดลองใหม่ภายหลัง',
  's13.other.title': 'บัญชีนี้สำรองฟาร์มอื่นไว้แล้ว',
  's13.other.body': 'หนึ่งบัญชีสำรองได้แค่หนึ่งฟาร์ม จะเปลี่ยนกลับไปฟาร์มนั้นไหม?',
  's13.other.switch': 'เปลี่ยนกลับไปฟาร์มนั้น',
  's13.switch.title': 'แน่ใจไหมว่าจะเปลี่ยนกลับ?',
  's13.switch.warn': 'ฟาร์มปัจจุบันในมือถือเครื่องนี้ "{name}" จะถูกลบ และกู้คืนไม่ได้',
  's13.switch.after': 'เมื่อเปลี่ยนกลับแล้ว มือถือเครื่องนี้จะกลับไปที่ "{name}"',
  's13.switch.confirm': 'เปลี่ยนกลับ และลบฟาร์มปัจจุบัน',
  's13.toast.bound': 'สำรองเรียบร้อย! ผูกบัญชี {name} แล้ว',
  's13.toast.cancelled': 'ยกเลิกการลงชื่อเข้าใช้แล้ว',
  's13.toast.failed': 'ลงชื่อเข้าใช้ไม่สำเร็จ โปรดลองอีกครั้ง',
  's13.toast.unbound': 'เลิกผูกบัญชี {name} แล้ว',
  's13.unbindTitle': 'เลิกผูกบัญชี {name} ไหม?',
  's13.unbindBody': 'เมื่อเลิกผูกแล้ว จะใช้บัญชีนี้กู้คืนฟาร์มไม่ได้',
  's13.unbindLast': 'นี่เป็นบัญชีเดียวที่ผูกไว้ ถ้าเลิกผูก ฟาร์มนี้จะไม่มีการสำรองอีก',
  's13.langHint': 'ครั้งแรกที่เปิดจะใช้ภาษาตามมือถือ เมื่อเปลี่ยนภาษา ข้อความบนหน้าจอ ชื่อวัว และข่าวจะเปลี่ยนตาม แต่ชื่อฟาร์มจะไม่เปลี่ยน',
  's13.redUp': 'แดง = ขึ้น',
  's13.redUpHint': 'แบบไต้หวัน',
  's13.greenUp': 'เขียว = ขึ้น',
  's13.greenUpHint': 'แบบสากล',
  's13.udNote': 'ภาษาจีนตัวเต็มตั้งต้นเป็น "แดง = ขึ้น" ส่วนภาษาอังกฤษและภาษาไทยตั้งต้นเป็น "เขียว = ขึ้น"',
  's14.recover': 'กู้คืนฟาร์มของฉัน',
  's14.signingIn': 'กำลังลงชื่อเข้าใช้…',
  's14.noneTitle': 'บัญชีนี้ไม่เคยสำรองฟาร์ม',
  's14.noneBody': 'อาจสำรองไว้ด้วยบัญชีอื่น\nฟาร์มที่ไม่เคยสำรองจะกู้คืนไม่ได้ ต้องเริ่มฟาร์มใหม่',
  's14.otherAccount': 'ใช้บัญชีอื่น',
  's14.androidHint': 'เคยใช้ iPhone และผูกไว้แค่บัญชี Apple? ให้ไปผูกบัญชี Google เพิ่มที่หน้าตั้งค่าในเกมบน iPhone ก่อน',
  's14.lead': 'ลงชื่อเข้าใช้ด้วยบัญชีที่เคยใช้สำรองฟาร์ม',
  's14.leadHint': 'เมื่อลงชื่อเข้าใช้แล้ว ฟาร์มจะกลับมาอยู่ในมือถือเครื่องนี้',
  's14.welcome': 'ยินดีต้อนรับกลับมา!',
  's14.level': 'เลเวล',
  's14.coins': 'เหรียญ',
  's14.cows': 'วัว',
  's14.head': 'ตัว',
  's14.welcomeHint': 'ฟาร์มกลับมาอยู่ในมือถือเครื่องนี้แล้ว และมือถือเครื่องเก่าออกจากระบบแล้ว',
  's14.elsewhereTitle': 'มีการลงชื่อเข้าใช้ฟาร์มนี้ในมือถือเครื่องอื่นแล้ว',
  's14.elsewhereLead': 'ตอนนี้ "{name}" อยู่ในมือถือเครื่องอื่น',
  's14.elsewhereBody': 'หนึ่งฟาร์มเล่นพร้อมกันได้แค่เครื่องเดียว\nลงชื่อเข้าใช้ที่เครื่องนี้อีกครั้งเพื่อนำฟาร์มกลับมา',
  's14.elsewhereSecurity': 'ถ้าคุณไม่ได้ทำเอง ให้ตรวจสอบความปลอดภัยของบัญชี Apple หรือ Google นั้นก่อน แล้วค่อยลงชื่อเข้าใช้เพื่อนำฟาร์มกลับมา',
  's15.reconnected': 'กลับมาเชื่อมต่อแล้ว ข้อมูลเป็นปัจจุบัน',
  's15.invalidTitle': 'ข้อมูลฟาร์มในมือถือเครื่องนี้ใช้ไม่ได้แล้ว',
  's15.invalidBody': 'ข้อมูลการลงชื่อเข้าใช้ที่เก็บไว้ในมือถือเครื่องนี้ใช้ไม่ได้แล้ว\nถ้าเคยสำรองฟาร์มไว้ ลงชื่อเข้าใช้ด้วยบัญชีที่ใช้สำรองก็กู้คืนได้',
  's15.longOffTitle': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้นานกว่า {n} นาทีแล้ว',
  's15.longOffBody': 'ตรวจสอบการเชื่อมต่อ เมื่อต่อได้แล้วข้อมูลจะโหลดใหม่เอง',
  'err.not_enough_stock': 'ของในโกดังไม่พอแล้ว โปรดเลือกจำนวนใหม่',
  'penFull': 'คอกวัวเต็มแล้ว ขยายคอกหรือส่งขายก่อน',
  'err.cow_not_found': 'ไม่พบวัวตัวนี้ อาจส่งขายไปแล้ว',
  'err.cow_not_adult': 'ลูกวัวยังไม่โต',
  'err.already_bred': 'วัวตัวนี้ผสมพันธุ์ไปแล้ว (วัวแต่ละตัวผสมพันธุ์ได้ครั้งเดียวในชีวิต)',
  'err.cow_in_field': 'วัวตัวนี้กำลังไถนาอยู่ เรียกกลับก่อน',
  'err.cow_listed': 'วัวตัวผู้ตัวนี้ลงประกาศอยู่ในตลาดพ่อพันธุ์ ถอนประกาศก่อน',
  'err.cow_not_in_field': 'วัวตัวนี้ไม่ได้อยู่ในแปลงนาแล้ว',
  'err.no_free_field': 'ไม่มีแปลงนาว่าง เปิดแปลงใหม่หรือเรียกวัวงานตัวอื่นกลับก่อน',
  'err.field_occupied': 'แปลงนี้มีวัวอยู่แล้ว',
  'err.field_not_found': 'ไม่พบแปลงนี้ โปรดโหลดใหม่',
  'err.listing_gone': 'วัวตัวผู้ตัวนี้ถูกยืมไปแล้ว หรือถอนประกาศแล้ว',
  'err.max_level': 'ถึงระดับสูงสุดแล้ว',
  'err.not_yet_available': 'ยังไม่เปิด กลับมาใหม่ในอีก {time}',
  'err.internal': 'เซิร์ฟเวอร์มีปัญหาเล็กน้อย โปรดลองใหม่ภายหลัง',
  'unknownError': 'ทำรายการไม่สำเร็จ โปรดลองอีกครั้ง',
  's16.title': 'ปิดปรับปรุง',
  's16.lead': 'เซิร์ฟเวอร์กำลังปิดปรับปรุง',
  's16.eta': 'คาดว่าจะกลับมาเปิด {date}',
  's16.late': 'ใช้เวลานานกว่าที่คาดไว้นิดหน่อย กรุณารออีกสักครู่',
  'date.mdw': '{w} {d}/{m} {time}',
  'weekday.0': 'อา.',
  'weekday.1': 'จ.',
  'weekday.2': 'อ.',
  'weekday.3': 'พ.',
  'weekday.4': 'พฤ.',
  'weekday.5': 'ศ.',
  'weekday.6': 'ส.',
  'weekdayFull.0': 'อาทิตย์',
  'weekdayFull.1': 'จันทร์',
  'weekdayFull.2': 'อังคาร',
  'weekdayFull.3': 'พุธ',
  'weekdayFull.4': 'พฤหัสบดี',
  'weekdayFull.5': 'ศุกร์',
  'weekdayFull.6': 'เสาร์',
  's16.body': 'ปรับปรุงเสร็จแล้วก็เล่นต่อได้ ข้อมูลฟาร์มทั้งหมดเก็บอยู่บนเซิร์ฟเวอร์',
  'anim.skip': 'แตะเพื่อข้าม',
  'anim.beep': 'ปี๊น',
  'anim.thanks': 'ขอบคุณที่ดูแลนะ!',
  'anim.newBreed': 'พบสายพันธุ์ใหม่!',
  'anim.dexCount': 'คอลเลกชัน พบแล้ว {n} / {total}',
  'news.milk_up.1': 'โรงเรียนสั่งนมสดเพิ่มสำหรับมื้อกลางวัน',
  'news.milk_up.2': 'อากาศร้อนจัดหลายวัน ร้านไอศกรีมแห่สั่งของ',
  'news.milk_up.3': 'งานแสดงขนมอบเปิดแล้ว ความต้องการนมสดพุ่ง',
  'news.milk_up.4': 'นมสดผ่านการตรวจคุณภาพทั้งหมด ยอดซื้อกลับมาคึกคัก',
  'news.milk_down.1': 'ฟาร์มละแวกใกล้ผลผลิตเพิ่มขึ้นมาก',
  'news.milk_down.2': 'ห้างลดราคานมสดครั้งใหญ่',
  'news.milk_down.3': 'ลมหนาวพัดหลายวัน ยอดขายไอศกรีมลดลง',
  'news.milk_down.4': 'การขนส่งติดขัด โรงงานนมหยุดรับซื้อชั่วคราว',
  'news.beef_up.2': 'ร้านอาหารจัดเทศกาลสเต็กเนื้อ',
  'news.beef_up.3': 'กระแสตุนของรับเทศกาลปีใหม่มาเร็วกว่าทุกปี',
  'news.beef_up.4': 'ศึกประกวดก๋วยเตี๋ยวเนื้อเปิดฉากคึกคัก',
  'news.beef_down.1': 'กระแสกินเพื่อสุขภาพ ความต้องการเนื้อชะลอตัว',
  'news.beef_down.2': 'เนื้อวัวนำเข้าถึงท่าเรือมากเป็นประวัติการณ์',
  'news.beef_down.3': 'คลังแช่แข็งเต็ม พ่อค้าเนื้อชะลอการรับซื้อ',
  'news.beef_down.4': 'หมดวันหยุดยาว ร้านอาหารสั่งของน้อยลง',
  'news.rice_up.2': 'ร้านข้าวกล่องแห่ซื้อข้าวใหม่',
  'news.rice_up.3': 'เทศกาลอาหารจากข้าวเปิดฉาก',
  'news.rice_up.4': 'ยอดสั่งซื้อเพื่อส่งออกเพิ่ม ราคาข้าวขยับขึ้น',
  'news.rice_down.1': 'ภาคกลางเก็บเกี่ยวได้มาก ข้าวใหม่ทะลักสู่ตลาด',
  'news.rice_down.2': 'คลังข้าวกลางหยุดรับซื้อชั่วคราว',
  'news.rice_down.3': 'อากาศดีหลายวัน หลายพื้นที่เกี่ยวข้าวเร็วขึ้น',
  'news.rice_down.4': 'ยุ้งฉางเต็ม พ่อค้าข้าวชะลอการรับซื้อ',
  'news.all_up.1': 'ฟาร์มท่องเที่ยวคนแน่นขนัด',
  'news.all_up.2': 'งานแสดงสินค้าเกษตรเปิดฉาก',
  'news.all_up.3': 'วันหยุดยาวคนแห่เที่ยว ร้านอาหารขายดี',
  'news.all_down.1': 'พายุพัดผ่าน ตลาดปิดหนึ่งวัน',
  'news.all_down.2': 'ผลสำรวจราคาสินค้าออกมา ผู้บริโภครัดเข็มขัด',
  'news.all_down.3': 'ท่าเรือนัดหยุดงาน การส่งออกสะดุด',
  'news.milk_super.1': 'โรงเรียนทั่วประเทศหันมาดื่มนมสด ออร์เดอร์พุ่ง',
  'news.milk_super.2': 'เปิดศึกไอศกรีมนานาชาติ นมสดขาดตลาด',
  'news.milk_super.3': 'ลาเต้นมสดฮิตถล่มทลาย ร้านกาแฟแย่งซื้อนม',
  'news.milk_swan.1': 'โรงงานนมไฟดับ หยุดรับซื้อนมสดทั้งหมด',
  'news.milk_swan.2': 'รถห้องเย็นหยุดวิ่ง นมสดส่งไม่ออก',
  'news.milk_swan.3': 'หนาวจัดเป็นประวัติการณ์ ร้านไอศกรีมปิดหมด',
  'news.beef_super.1': 'ศึกสเต็กโลกมาจัดที่⁠นี่',
  'news.beef_super.2': 'เทศกาลปิ้งย่างทั่วประเทศเริ่มเร็ว พ่อค้าแย่งซื้อเนื้อ',
  'news.beef_super.3': 'ก๋วยเตี๋ยวเนื้อติดอันดับอาหารโลก',
  'news.beef_swan.1': 'ระบบขนส่งห้องเย็นล่ม พ่อค้าหยุดรับซื้อเนื้อ',
  'news.beef_swan.2': 'เนื้อนำเข้าราคาถูกทะลัก ราคาดิ่ง',
  'news.beef_swan.3': 'สัปดาห์กินผักทั่วประเทศ ไม่มีใครซื้อเนื้อ',
  'news.rice_super.1': 'ข้าวใหม่คว้าทองระดับโลก ราคาพุ่งสองเท่า',
  'news.rice_super.2': 'ข้าวปั้นฮิตทั่วโลก ส่งออกพุ่ง',
  'news.rice_super.3': 'งานเลี้ยงระดับชาติเลือกข้าวใหม่ พ่อค้าแย่งซื้อ',
  'news.rice_swan.1': 'พ่อค้าข้าวหยุดรับซื้อ ข้าวใหม่กองเป็นภูเขา',
  'news.rice_swan.2': 'ผลผลิตล้นในรอบร้อยปี ข้าวใหม่ขายไม่ออก',
  'news.rice_swan.3': 'กระแสก๋วยเตี๋ยวมาแรง ไม่มีใครกินข้าว',
  'news.all_super.1': 'เทศกาลอาหารโลกมาจัดที่⁠นี่',
  'news.all_super.2': 'นักท่องเที่ยวล้นหลาม ร้านอาหารเต็มทุกวัน',
  'news.all_super.3': 'วันหยุดยาวพิเศษมาแล้ว ความต้องการอาหารเพิ่มเท่าตัว',
  'news.all_swan.1': 'ซูเปอร์ไต้ฝุ่นถล่ม ตลาดปิดทั้งหมด',
  'news.all_swan.2': 'ท่าเรือปิดหมด สินค้าเกษตรส่งไม่ออก',
  'news.all_swan.3': 'การใช้จ่ายทั่วประเทศหยุดชะงัก สินค้าเกษตรไม่มีคนซื้อ',
  'namegen.first.0': 'แสงเช้า',
  'namegen.first.1': 'ใบหญ้า',
  'namegen.first.2': 'เมฆขาว',
  'namegen.first.3': 'ดวงดาว',
  'namegen.first.4': 'ใบไม้',
  'namegen.first.5': 'แดดอุ่น',
  'namegen.first.6': 'ลมโชย',
  'namegen.first.7': 'หมอก',
  'namegen.first.8': 'จันทร์',
  'namegen.first.9': 'รวงข้าว',
  'namegen.first.10': 'รุ้ง',
  'namegen.first.11': 'น้ำค้าง',
  'namegen.second.0': 'เนิน',
  'namegen.second.1': 'ริมน้ำ',
  'namegen.second.2': 'ทุ่งโล่ง',
  'namegen.second.3': 'ดงสน',
  'namegen.second.4': 'ดอกไม้',
  'namegen.second.5': 'ริมบึง',
  'namegen.second.6': 'บนดอย',
  'namegen.second.7': 'ดงไผ่',
  'namegen.second.8': 'สะพาน',
  'namegen.second.9': 'ริมธาร',
  'namegen.second.10': 'หุบเขา',
  'namegen.second.11': 'ป่าใหญ่',
  'namegen.third.0': 'ฟาร์ม',
  'namegen.third.1': 'ไร่',
  'namegen.third.2': 'ทุ่ง',
  'namegen.third.3': 'คอก',
  'namegen.third.4': 'บ้าน',
  'namegen.third.5': 'สวน',
  'namegen.third.6': 'เรือน',
  'namegen.third.7': 'ลาน',
  'namegen.third.8': 'นา',
  'namegen.third.9': 'โรงนม',
  'namegen.third.10': 'ทุ่งหญ้า',
  'namegen.third.11': 'คอกวัว',
  'namegen.pattern': '{third}{first}{second}',
  's21.title': 'ข้อมูลฟาร์ม',
  's21.badges': 'เหรียญความสำเร็จ',
  's21.badgeCount': 'ปลดล็อกแล้ว {n}/{total}',
  's21.badgeDate': 'ปลดล็อกเมื่อ {date}',
  's21.badgeLocked': 'ยังไม่ได้ปลดล็อก',
  's21.avatarTitle': 'เปลี่ยนรูปโปรไฟล์',
  's21.avatarUse': 'ใช้รูปนี้',
  's21.avatarFoundOnly': 'เลือกได้เฉพาะสายพันธุ์ที่พบแล้ว',
  's21.avatarCount': 'พบแล้ว {n}/{total} สายพันธุ์ สายพันธุ์ที่ยังไม่พบจะใช้ได้เมื่อพบแล้ว',
  's21.avatarLocked': 'ยังไม่พบ{name} จะใช้ได้เมื่อพบแล้ว',
  's21.avatarDone': 'เปลี่ยนรูปโปรไฟล์แล้ว!',
  's21.renameTitle': 'เปลี่ยนชื่อฟาร์ม',
  's21.renameFree': 'เปลี่ยนชื่อ (ฟรี)',
  's21.renamePaid': 'เปลี่ยนชื่อ ({price} เหรียญ)',
  's21.renamedFirst': 'เปลี่ยนชื่อฟาร์มแล้ว! ครั้งต่อไปใช้ {price} เหรียญ',
  'ach.firstMilk.name': 'นมถังแรก',
  'ach.firstMilk.cond': 'เก็บนมครั้งแรก',
  'ach.firstSale.name': 'เปิดร้านวันแรก',
  'ach.firstSale.cond': 'ขายของที่ตลาดครั้งแรก',
  'ach.firstShip.name': 'ส่งวัวครั้งแรก',
  'ach.firstShip.cond': 'ส่งวัวออกจากฟาร์มครั้งแรก',
  'ach.gradeA.name': 'ฟาร์มเกรด A',
  'ach.gradeA.cond': 'ได้เกรด A จากการส่งวัว 10 ครั้ง',
  'ach.newLife.name': 'ชีวิตใหม่',
  'ach.newLife.cond': 'ได้ลูกวัวจากการผสมพันธุ์ครั้งแรก',
  'ach.borrow.name': 'ยืมพ่อพันธุ์สำเร็จ',
  'ach.borrow.cond': 'ยืมพ่อพันธุ์ของฟาร์มอื่นครั้งแรก',
  'ach.popularBull.name': 'พ่อพันธุ์ยอดนิยม',
  'ach.popularBull.cond': 'พ่อพันธุ์ของคุณถูกยืม 10 ครั้ง',
  'ach.rice.name': 'ยุ้งข้าวเต็ม',
  'ach.rice.cond': 'เก็บเกี่ยวข้าวรวม 1,000 กก.',
  'ach.codex.name.1': 'นักสะสมมือใหม่',
  'ach.codex.cond.1': 'พบวัว 5 สายพันธุ์',
  'ach.codex.name.2': 'นักสะสมตัวยง',
  'ach.codex.cond.2': 'พบวัว 12 สายพันธุ์',
  'ach.codex.name.3': 'ปรมาจารย์สายพันธุ์',
  'ach.codex.cond.3': 'พบวัวครบ 24 สายพันธุ์',
  'ach.legend.name': 'ตำนานถือกำเนิด',
  'ach.legend.cond': 'มีวัวระดับตำนาน 1 ตัว',
  'ach.level.name.1': 'เจ้าของฟาร์ม Lv 10',
  'ach.level.cond.1': 'ถึง Lv 10',
  'ach.level.name.2': 'เจ้าของฟาร์ม Lv 20',
  'ach.level.cond.2': 'ถึง Lv 20',
  'ach.rich.name.1': 'เศรษฐีน้อย',
  'ach.rich.cond.1': 'ทรัพย์สินรวมถึง 100,000 เหรียญ',
  'ach.rich.name.2': 'เศรษฐีใหญ่',
  'ach.rich.cond.2': 'ทรัพย์สินรวมถึง 1,000,000 เหรียญ',
  'ach.tailwind.name': 'โต้คลื่นราคา',
  'ach.tailwind.cond': 'ขายของระหว่างบูมสุดขีด',
  'ach.weekChamp.name': 'แชมป์ประจำสัปดาห์',
  'ach.weekChamp.cond': 'ได้อันดับ 1 รายได้ประจำสัปดาห์',
  'ach.pureBreed.name': 'เลี้ยงพันธุ์แท้',
  'ach.pureBreed.cond': 'เลี้ยงลูกวัวระดับหายากขึ้นไปด้วยอาหารตามสายพันธุ์จนโต (ไม่กลายเป็นพันธุ์ผสม)',
  'ach.healer.name': 'มือหมอ',
  'ach.healer.cond': 'รักษาวัวป่วยให้หาย 1 ตัว',
  'ach.clean.name': 'ฟาร์มสะอาด',
  'ach.clean.cond': 'ไม่มีวัวป่วยติดต่อกัน 7 วัน',
  'ach.trucks.name': 'นักสะสมรถบรรทุก',
  'ach.trucks.cond': 'มีรถบรรทุก 3 แบบ',
};

/// 每個 key 一個成員：沒有佔位符的是 getter，有佔位符的是方法、佔位符是具名參數。
/// 說明文字是繁中的字。
abstract class GeneratedStrings {
  const GeneratedStrings();

  /// 這個語言的字串表。
  Map<String, String> get table;

  /// 把 key 的文字裡的 {名稱} 換成參數。
  String fill(String key, Map<String, Object> params);

  /// `tabRanch`：牧場
  String get tabRanch => table['tabRanch']!;

  /// `tabMarket`：市場
  String get tabMarket => table['tabMarket']!;

  /// `tabFields`：田地
  String get tabFields => table['tabFields']!;

  /// `tabBreed`：配種
  String get tabBreed => table['tabBreed']!;

  /// `tabShop`：商店
  String get tabShop => table['tabShop']!;

  /// `tabRecords`：紀錄
  String get tabRecords => table['tabRecords']!;

  /// `level`：Lv {lv}
  String level({required Object lv}) => fill('level', {'lv': lv});

  /// `hud.xp`：經驗 {pct}%
  String hudXp({required Object pct}) => fill('hud.xp', {'pct': pct});

  /// `hud.settings`：設定
  String get hudSettings => table['hud.settings']!;

  /// `hud.settingsNotBacked`：設定（還沒備份牧場）
  String get hudSettingsNotBacked => table['hud.settingsNotBacked']!;

  /// `connecting`：連線中…
  String get connecting => table['connecting']!;

  /// `typeDairy`：乳牛
  String get typeDairy => table['typeDairy']!;

  /// `typeDual`：耕牛
  String get typeDual => table['typeDual']!;

  /// `typeBeef`：肉牛
  String get typeBeef => table['typeBeef']!;

  /// `bull`：公
  String get bull => table['bull']!;

  /// `cow`：母
  String get cow => table['cow']!;

  /// `tier0`：一般
  String get tier0 => table['tier0']!;

  /// `tier1`：優良
  String get tier1 => table['tier1']!;

  /// `tier2`：稀有
  String get tier2 => table['tier2']!;

  /// `tier3`：傳說
  String get tier3 => table['tier3']!;

  /// `days`：{d} 天
  String days({required Object d}) => fill('days', {'d': d});

  /// `hours`：{h} 小時
  String hours({required Object h}) => fill('hours', {'h': h});

  /// `minutes`：{m} 分
  String minutes({required Object m}) => fill('minutes', {'m': m});

  /// `seconds`：{s} 秒
  String seconds({required Object s}) => fill('seconds', {'s': s});

  /// `milk`：牛奶
  String get milk => table['milk']!;

  /// `beef`：牛肉
  String get beef => table['beef']!;

  /// `rice`：稻米
  String get rice => table['rice']!;

  /// `unitMilk`：瓶
  String get unitMilk => table['unitMilk']!;

  /// `unitBeef`：公斤
  String get unitBeef => table['unitBeef']!;

  /// `unitRice`：公斤
  String get unitRice => table['unitRice']!;

  /// `news.rice_up.1`：颱風過境，稻米收購價上漲
  String get newsRiceUp1 => table['news.rice_up.1']!;

  /// `ago.min`：{n} 分鐘前
  String agoMin({required Object n}) => fill('ago.min', {'n': n});

  /// `ago.hour`：{n} 小時前
  String agoHour({required Object n}) => fill('ago.hour', {'n': n});

  /// `ago.day`：{n} 天前
  String agoDay({required Object n}) => fill('ago.day', {'n': n});

  /// `ago.now`：剛剛
  String get agoNow => table['ago.now']!;

  /// `date.today`：今天 {time}
  String dateToday({required Object time}) => fill('date.today', {'time': time});

  /// `date.yesterday`：昨天 {time}
  String dateYesterday({required Object time}) => fill('date.yesterday', {'time': time});

  /// `date.md`：{m} 月 {d} 日 {time}
  String dateMd({required Object d, required Object m, required Object time}) => fill('date.md', {'d': d, 'm': m, 'time': time});

  /// `appTitle`：牛市牧場
  String get appTitle => table['appTitle']!;

  /// `s01.version`：版本 {v}
  String s01Version({required Object v}) => fill('s01.version', {'v': v});

  /// `loadingFarm`：正在載入牧場…
  String get loadingFarm => table['loadingFarm']!;

  /// `s01.creating`：正在幫你準備新牧場…
  String get s01Creating => table['s01.creating']!;

  /// `s01.firstTime`：第一次打開要幾秒鐘
  String get s01FirstTime => table['s01.firstTime']!;

  /// `s01.failTitle`：連不上伺服器
  String get s01FailTitle => table['s01.failTitle']!;

  /// `s01.failCheck`：請確認網路後重試。
  String get s01FailCheck => table['s01.failCheck']!;

  /// `s01.failAuto`：每 {n} 秒也會自動再試一次。
  String s01FailAuto({required Object n}) => fill('s01.failAuto', {'n': n});

  /// `retry`：重試
  String get retry => table['retry']!;

  /// `s05.milkName`：{tier}牛奶
  String s05MilkName({required Object tier}) => fill('s05.milkName', {'tier': tier});

  /// `s05.spoiling`：快壞了
  String get s05Spoiling => table['s05.spoiling']!;

  /// `s05.fresh`：新鮮度
  String get s05Fresh => table['s05.fresh']!;

  /// `s05.collectedAgo`：{ago}收
  String s05CollectedAgo({required Object ago}) => fill('s05.collectedAgo', {'ago': ago});

  /// `g.sep`：・
  String get gSep => table['g.sep']!;

  /// `s05.spoilIn`：大約 {h} 小時後壞掉，壞掉的會丟掉
  String s05SpoilIn({required Object h}) => fill('s05.spoilIn', {'h': h});

  /// `s05.stored`：存放 {pct}%
  String s05Stored({required Object pct}) => fill('s05.stored', {'pct': pct});

  /// `s05.shippedFrom`：{cow} 出貨
  String s05ShippedFrom({required Object cow}) => fill('s05.shippedFrom', {'cow': cow});

  /// `s05.lotsOldestFirst`：{n} 批・從最舊的先賣
  String s05LotsOldestFirst({required Object n}) => fill('s05.lotsOldestFirst', {'n': n});

  /// `s05.milkCap`：牛奶容量
  String get s05MilkCap => table['s05.milkCap']!;

  /// `s05.capLine`：{amount} 瓶（{pct}%）
  String s05CapLine({required Object amount, required Object pct}) => fill('s05.capLine', {'amount': amount, 'pct': pct});

  /// `s05.full`：倉庫滿了：收奶只收得進一部分，奶桶滿了就會停止產奶。
  String get s05Full => table['s05.full']!;

  /// `s05.nearFull`：倉庫快滿了，記得去賣或加大倉庫。
  String get s05NearFull => table['s05.nearFull']!;

  /// `s05.capNote`：牛肉、稻米不佔倉庫容量。
  String get s05CapNote => table['s05.capNote']!;

  /// `back`：返回
  String get back => table['back']!;

  /// `warehouseTitle`：倉庫
  String get warehouseTitle => table['warehouseTitle']!;

  /// `g.levelN`：第 {n} 級
  String gLevelN({required Object n}) => fill('g.levelN', {'n': n});

  /// `upWarehouse`：加大倉庫
  String get upWarehouse => table['upWarehouse']!;

  /// `s05.emptyMilk`：倉庫裡沒有牛奶。到牧場收奶吧。
  String get s05EmptyMilk => table['s05.emptyMilk']!;

  /// `s05.emptyBeef`：還沒有牛肉。成年的牛可以出貨。
  String get s05EmptyBeef => table['s05.emptyBeef']!;

  /// `s05.emptyRice`：還沒有稻米。派耕牛到田裡種稻。
  String get s05EmptyRice => table['s05.emptyRice']!;

  /// `s05.goSell`：去市場賣
  String get s05GoSell => table['s05.goSell']!;

  /// `s05.priceNote`：成交價 ＝ 市價 × 倍數：牛奶乘稀有度和新鮮度，牛肉乘評級、稀有度和存放折價，稻米乘存放折價。
  String get s05PriceNote => table['s05.priceNote']!;

  /// `breed.holstein.name`：荷斯坦
  String get breedHolsteinName => table['breed.holstein.name']!;

  /// `breed.holstein.intro`：黑白花斑的招牌乳牛，個子高、產奶穩定。
  String get breedHolsteinIntro => table['breed.holstein.intro']!;

  /// `breed.fluffyHolstein.name`：蓬蓬荷斯坦
  String get breedFluffyHolsteinName => table['breed.fluffyHolstein.name']!;

  /// `breed.fluffyHolstein.intro`：荷斯坦多了一身蓬蓬長毛和瀏海，冬天最不怕冷。
  String get breedFluffyHolsteinIntro => table['breed.fluffyHolstein.intro']!;

  /// `breed.jersey.name`：娟珊
  String get breedJerseyName => table['breed.jersey.name']!;

  /// `breed.jersey.intro`：淺褐色的小個子，臉短短、眼睛又大又亮。
  String get breedJerseyIntro => table['breed.jersey.intro']!;

  /// `breed.glossBlack.name`：亮黑乳牛
  String get breedGlossBlackName => table['breed.glossBlack.name']!;

  /// `breed.glossBlack.intro`：黑亮的毛上點綴白斑，站在太陽底下會反光。
  String get breedGlossBlackIntro => table['breed.glossBlack.intro']!;

  /// `breed.cottonCream.name`：奶油棉花牛
  String get breedCottonCreamName => table['breed.cottonCream.name']!;

  /// `breed.cottonCream.intro`：奶油色的蓬毛像一團棉花，看起來軟綿綿。
  String get breedCottonCreamIntro => table['breed.cottonCream.intro']!;

  /// `breed.velvetBlack.name`：黑絨乳牛
  String get breedVelvetBlackName => table['breed.velvetBlack.name']!;

  /// `breed.velvetBlack.intro`：一身亮黑長毛，像穿了一件絨毛大衣。
  String get breedVelvetBlackIntro => table['breed.velvetBlack.intro']!;

  /// `breed.chocolate.name`：巧克力牛
  String get breedChocolateName => table['breed.chocolate.name']!;

  /// `breed.chocolate.intro`：咖啡色的毛配奶油色斑，頭頂一球奶油，看起來像一杯巧克力牛奶。
  String get breedChocolateIntro => table['breed.chocolate.intro']!;

  /// `breed.strawberry.name`：草莓牛
  String get breedStrawberryName => table['breed.strawberry.name']!;

  /// `breed.strawberry.intro`：奶油白底配草莓紅斑，頭頂一片綠葉，像一顆會走路的草莓。
  String get breedStrawberryIntro => table['breed.strawberry.intro']!;

  /// `breed.yellow.name`：台灣黃牛
  String get breedYellowName => table['breed.yellow.name']!;

  /// `breed.yellow.intro`：黃褐色、肩上一個圓圓的小肩峰，田裡最可靠的幫手。
  String get breedYellowIntro => table['breed.yellow.intro']!;

  /// `breed.highland.name`：高地牛
  String get breedHighlandName => table['breed.highland.name']!;

  /// `breed.highland.intro`：薑黃色長毛蓋住眼睛，頭上一對長長的角。
  String get breedHighlandIntro => table['breed.highland.intro']!;

  /// `breed.milkTea.name`：奶茶黃牛
  String get breedMilkTeaName => table['breed.milkTea.name']!;

  /// `breed.milkTea.intro`：淡淡的奶茶色，肩峰圓圓的，脾氣很溫和。
  String get breedMilkTeaIntro => table['breed.milkTea.intro']!;

  /// `breed.buffalo.name`：台灣水牛
  String get breedBuffaloName => table['breed.buffalo.name']!;

  /// `breed.buffalo.intro`：深灰色亮毛，一對往後彎的大角，力氣很大。
  String get breedBuffaloIntro => table['breed.buffalo.intro']!;

  /// `breed.cottonCandy.name`：棉花糖高地牛
  String get breedCottonCandyName => table['breed.cottonCandy.name']!;

  /// `breed.cottonCandy.intro`：淡米粉色的長毛蓬蓬的，像一球會走路的棉花糖。
  String get breedCottonCandyIntro => table['breed.cottonCandy.intro']!;

  /// `breed.shaggyBuffalo.name`：長毛水牛
  String get breedShaggyBuffaloName => table['breed.shaggyBuffalo.name']!;

  /// `breed.shaggyBuffalo.intro`：水牛多了一身深灰長毛，角一樣又大又彎。
  String get breedShaggyBuffaloIntro => table['breed.shaggyBuffalo.intro']!;

  /// `breed.honey.name`：蜂蜜牛
  String get breedHoneyName => table['breed.honey.name']!;

  /// `breed.honey.intro`：金黃色的亮毛，像淋了一層蜂蜜。
  String get breedHoneyIntro => table['breed.honey.intro']!;

  /// `breed.goldenEar.name`：金穗牛
  String get breedGoldenEarName => table['breed.goldenEar.name']!;

  /// `breed.goldenEar.intro`：金黃色的身上有稻穗紋，頭頂一小束稻穗，耕田的產量特別多。
  String get breedGoldenEarIntro => table['breed.goldenEar.intro']!;

  /// `breed.angus.name`：安格斯
  String get breedAngusName => table['breed.angus.name']!;

  /// `breed.angus.intro`：炭灰黑的壯碩肉牛，沒有角。
  String get breedAngusIntro => table['breed.angus.intro']!;

  /// `breed.galloway.name`：蓋洛威
  String get breedGallowayName => table['breed.galloway.name']!;

  /// `breed.galloway.intro`：炭灰黑的長捲毛又厚又暖，沒有角。
  String get breedGallowayIntro => table['breed.galloway.intro']!;

  /// `breed.charolais.name`：夏洛來
  String get breedCharolaisName => table['breed.charolais.name']!;

  /// `breed.charolais.intro`：奶油白的大個子，肌肉結實。
  String get breedCharolaisIntro => table['breed.charolais.intro']!;

  /// `breed.wagyu.name`：和牛
  String get breedWagyuName => table['breed.wagyu.name']!;

  /// `breed.wagyu.intro`：黑亮的毛帶一道光澤，頭上一對短角。
  String get breedWagyuIntro => table['breed.wagyu.intro']!;

  /// `breed.whiteFleece.name`：白絨牛
  String get breedWhiteFleeceName => table['breed.whiteFleece.name']!;

  /// `breed.whiteFleece.intro`：奶油白的長捲毛，遠看像一朵雲。
  String get breedWhiteFleeceIntro => table['breed.whiteFleece.intro']!;

  /// `breed.fluffyWagyu.name`：絨毛和牛
  String get breedFluffyWagyuName => table['breed.fluffyWagyu.name']!;

  /// `breed.fluffyWagyu.intro`：和牛的長毛版本，毛又亮又蓬，一樣有短角。
  String get breedFluffyWagyuIntro => table['breed.fluffyWagyu.intro']!;

  /// `breed.whiteWagyu.name`：白和牛
  String get breedWhiteWagyuName => table['breed.whiteWagyu.name']!;

  /// `breed.whiteWagyu.intro`：奶油白的毛帶著光澤，頭上一對短角。
  String get breedWhiteWagyuIntro => table['breed.whiteWagyu.intro']!;

  /// `breed.starry.name`：星空牛
  String get breedStarryName => table['breed.starry.name']!;

  /// `breed.starry.intro`：深藍色的毛上有白色星星，是最難遇到的肉牛。
  String get breedStarryIntro => table['breed.starry.intro']!;

  /// `trait.A`：長毛
  String get traitA => table['trait.A']!;

  /// `trait.B`：淡色
  String get traitB => table['trait.B']!;

  /// `trait.C`：光澤
  String get traitC => table['trait.C']!;

  /// `s02.title`：幫牧場取個名字
  String get s02Title => table['s02.title']!;

  /// `s02.sub`：取一個自己喜歡的名字吧！
  String get s02Sub => table['s02.sub']!;

  /// `s02.placeholder`：例如：晨光河畔牧場
  String get s02Placeholder => table['s02.placeholder']!;

  /// `s02.filled`：想好了！可以直接用，也可以再改。
  String get s02Filled => table['s02.filled']!;

  /// `s02.widthRule`：中文字算 2，英文字母和數字算 1
  String get s02WidthRule => table['s02.widthRule']!;

  /// `s02.suggest`：幫我想一個
  String get s02Suggest => table['s02.suggest']!;

  /// `s02.sameName`：跟別人同名也沒關係，會加上 #編號分辨，例如「晨光河畔牧場 #1234」。
  String get s02SameName => table['s02.sameName']!;

  /// `s02.confirm`：就叫這個
  String get s02Confirm => table['s02.confirm']!;

  /// `s02.welcome`：歡迎來到\n{name}
  String s02Welcome({required Object name}) => fill('s02.welcome', {'name': name});

  /// `s02.gifts`：先送你這些，開始經營吧！
  String get s02Gifts => table['s02.gifts']!;

  /// `s02.giftMilk`：會產奶
  String get s02GiftMilk => table['s02.giftMilk']!;

  /// `costCoins`：{v} 幣
  String costCoins({required Object v}) => fill('costCoins', {'v': v});

  /// `s02.giftBucket`：奶桶裡已經有 {n} 瓶
  String s02GiftBucket({required Object n}) => fill('s02.giftBucket', {'n': n});

  /// `s02.boost`：開局 {h} 小時產奶 ×{x}，進去就能收奶、賣奶。
  String s02Boost({required Object h, required Object x}) => fill('s02.boost', {'h': h, 'x': x});

  /// `g.enterRanch`：進牧場
  String get gEnterRanch => table['g.enterRanch']!;

  /// `s02.errShort`：名字至少要 1 個中文字，或 2 個英文字母
  String get s02ErrShort => table['s02.errShort']!;

  /// `s02.errLong`：名字最多 8 個中文字（或 16 個英文字母）
  String get s02ErrLong => table['s02.errLong']!;

  /// `s02.errEmoji`：名字不能用表情符號
  String get s02ErrEmoji => table['s02.errEmoji']!;

  /// `s02.errChar`：名字裡有不能用的字
  String get s02ErrChar => table['s02.errChar']!;

  /// `pickForBreed`：選這頭去配種
  String get pickForBreed => table['pickForBreed']!;

  /// `ship`：出貨
  String get ship => table['ship']!;

  /// `s07.kgBeef`：約 {kg} 公斤牛肉
  String s07KgBeef({required Object kg}) => fill('s07.kgBeef', {'kg': kg});

  /// `s07.beefPrice`：牛肉現價 {price} 幣／公斤
  String s07BeefPrice({required Object price}) => fill('s07.beefPrice', {'price': price});

  /// `loadingPreview`：正在取得評級機率…
  String get loadingPreview => table['loadingPreview']!;

  /// `s07.probFailed`：評級機率載入失敗
  String get s07ProbFailed => table['s07.probFailed']!;

  /// `g.grade`：{g} 級
  String gGrade({required Object g}) => fill('g.grade', {'g': g});

  /// `s07.income`：收入約 {v} 幣
  String s07Income({required Object v}) => fill('s07.income', {'v': v});

  /// `expectedValue`：期望收入 約 {v} 幣
  String expectedValue({required Object v}) => fill('expectedValue', {'v': v});

  /// `s07.note`：出貨時才會隨機評級。牛肉立刻放進倉庫，要不要賣、什麼時候賣都可以自己決定。
  String get s07Note => table['s07.note']!;

  /// `shipConfirmTitle`：確定出貨？
  String get shipConfirmTitle => table['shipConfirmTitle']!;

  /// `cancel`：取消
  String get cancel => table['cancel']!;

  /// `s07.confirm`：確定出貨
  String get s07Confirm => table['s07.confirm']!;

  /// `s07.blockWorking`：這頭牛在田裡工作，先叫回來才能出貨
  String get s07BlockWorking => table['s07.blockWorking']!;

  /// `s20.tipA`：養得剛剛好！A 級賣價 ×1.25。
  String get s20TipA => table['s20.tipA']!;

  /// `s20.tipB`：不錯！B 級照市價賣。
  String get s20TipB => table['s20.tipB']!;

  /// `s20.tipC`：C 級賣價 ×0.75。下次養到最佳體重再出貨，拿到 A 級的機會比較高。
  String get s20TipC => table['s20.tipC']!;

  /// `s20.title`：{cow} 出貨評級
  String s20Title({required Object cow}) => fill('s20.title', {'cow': cow});

  /// `s20.gradeFormat`：{grade} 級
  String s20GradeFormat({required Object grade}) => fill('s20.gradeFormat', {'grade': grade});

  /// `s20.kgIn`：{kg} 公斤牛肉放進倉庫了
  String s20KgIn({required Object kg}) => fill('s20.kgIn', {'kg': kg});

  /// `s20.sellAll`：現在全部賣掉約 {v} 幣
  String s20SellAll({required Object v}) => fill('s20.sellAll', {'v': v});

  /// `s20.goMarket`：去市場
  String get s20GoMarket => table['s20.goMarket']!;

  /// `ok`：好
  String get ok => table['ok']!;

  /// `s10.upgraded`：升級完成：{what} {effect}
  String s10Upgraded({required Object effect, required Object what}) => fill('s10.upgraded', {'effect': effect, 'what': what});

  /// `bucketTitle`：奶桶
  String get bucketTitle => table['bucketTitle']!;

  /// `s10.effectBottles`：{a} → {b} 瓶
  String s10EffectBottles({required Object a, required Object b}) => fill('s10.effectBottles', {'a': a, 'b': b});

  /// `notEnoughCoins`：金幣不夠，還差 {n} 幣
  String notEnoughCoins({required Object n}) => fill('notEnoughCoins', {'n': n});

  /// `networkError`：網路不穩，請稍後再試
  String get networkError => table['networkError']!;

  /// `g.studNoticeTitle`：有人借了你的公牛
  String get gStudNoticeTitle => table['g.studNoticeTitle']!;

  /// `g.studNoticeBody`：{cow} 借給 {ranch}，收到 {price} 幣
  String gStudNoticeBody({required Object cow, required Object price, required Object ranch}) => fill('g.studNoticeBody', {'cow': cow, 'price': price, 'ranch': ranch});

  /// `upgradesTitle`：升級
  String get upgradesTitle => table['upgradesTitle']!;

  /// `g.busySub`：送出後等伺服器回覆
  String get gBusySub => table['g.busySub']!;

  /// `upBucket`：加大奶桶
  String get upBucket => table['upBucket']!;

  /// `g.busy`：處理中…
  String get gBusy => table['g.busy']!;

  /// `upFresh`：冷藏設備
  String get upFresh => table['upFresh']!;

  /// `effectFresh`：保鮮 {a} → {b} 小時
  String effectFresh({required Object a, required Object b}) => fill('effectFresh', {'a': a, 'b': b});

  /// `stageCalf`：小牛
  String get stageCalf => table['stageCalf']!;

  /// `stageOld`：老牛
  String get stageOld => table['stageOld']!;

  /// `badgeWorking`：工作中
  String get badgeWorking => table['badgeWorking']!;

  /// `badgeListed`：上架中
  String get badgeListed => table['badgeListed']!;

  /// `badgeBred`：已配種
  String get badgeBred => table['badgeBred']!;

  /// `g.newCalf`：新小牛 {cow}
  String gNewCalf({required Object cow}) => fill('g.newCalf', {'cow': cow});

  /// `growUp`：長大還要 {v}
  String growUp({required Object v}) => fill('growUp', {'v': v});

  /// `g.refreshing`：重新整理中…
  String get gRefreshing => table['g.refreshing']!;

  /// `g.breedSex`：{breed} {sex}
  String gBreedSex({required Object breed, required Object sex}) => fill('g.breedSex', {'breed': breed, 'sex': sex});

  /// `loadingShop`：正在取得機率…
  String get loadingShop => table['loadingShop']!;

  /// `s19.probFailed`：機率載入失敗
  String get s19ProbFailed => table['s19.probFailed']!;

  /// `probType`：用途
  String get probType => table['probType']!;

  /// `probSex`：公母
  String get probSex => table['probSex']!;

  /// `probTier`：稀有度
  String get probTier => table['probTier']!;

  /// `s19.descA`：最容易抽到稀有的牛
  String get s19DescA => table['s19.descA']!;

  /// `s19.descB`：有機會抽到稀有的牛
  String get s19DescB => table['s19.descB']!;

  /// `s19.descC`：便宜，大多是一般的牛
  String get s19DescC => table['s19.descC']!;

  /// `s19.segDraw`：抽牛
  String get s19SegDraw => table['s19.segDraw']!;

  /// `s19.segFacility`：設施
  String get s19SegFacility => table['s19.segFacility']!;

  /// `s19.rule`：只挑等級；用途、公母、稀有度是隨機的，機率全部公開。抽到的是小牛。
  String get s19Rule => table['s19.rule']!;

  /// `s19.penFull`：牛舍滿了（{used} / {slots} 格），先擴建或出貨
  String s19PenFull({required Object slots, required Object used}) => fill('s19.penFull', {'slots': slots, 'used': used});

  /// `drawnTitle`：{g} 級抽到了！
  String drawnTitle({required Object g}) => fill('drawnTitle', {'g': g});

  /// `s19.drawnDraft`：長大還要 {time}。長大後可以派去田裡種稻。
  String s19DrawnDraft({required Object time}) => fill('s19.drawnDraft', {'time': time});

  /// `upPen`：擴建牛舍
  String get upPen => table['upPen']!;

  /// `effectPen`：{a} → {b} 格
  String effectPen({required Object a, required Object b}) => fill('effectPen', {'a': a, 'b': b});

  /// `s10.penTimes`：擴建過 {n} 次
  String s10PenTimes({required Object n}) => fill('s10.penTimes', {'n': n});

  /// `s10.effectFresh`：新鮮 100% 的時間 {a} → {b} 小時
  String s10EffectFresh({required Object a, required Object b}) => fill('s10.effectFresh', {'a': a, 'b': b});

  /// `s10.levelOf`：第 {n} / {max} 級
  String s10LevelOf({required Object max, required Object n}) => fill('s10.levelOf', {'max': max, 'n': n});

  /// `maxed`：已滿級
  String get maxed => table['maxed']!;

  /// `opensIn`：{v}後開放
  String opensIn({required Object v}) => fill('opensIn', {'v': v});

  /// `s10.maxLevel`：最高級
  String get s10MaxLevel => table['s10.maxLevel']!;

  /// `s10.freshMax`：新鮮 100% 的時間 {h} 小時
  String s10FreshMax({required Object h}) => fill('s10.freshMax', {'h': h});

  /// `s10.maxedEffect`：已經最大了
  String get s10MaxedEffect => table['s10.maxedEffect']!;

  /// `s10.fieldsNote`：田地在「田地」分頁開新田。
  String get s10FieldsNote => table['s10.fieldsNote']!;

  /// `s10.penNever`：還沒擴建過
  String get s10PenNever => table['s10.penNever']!;

  /// `s11.earned`：累積收入到 {v} 幣了！
  String s11Earned({required Object v}) => fill('s11.earned', {'v': v});

  /// `s11.hint`：繼續賣牛奶、牛肉、稻米，或出借公牛，等級會往上升。
  String get s11Hint => table['s11.hint']!;

  /// `s11.ribbon`：場主升級
  String get s11Ribbon => table['s11.ribbon']!;

  /// `s11.lv`：Lv
  String get s11Lv => table['s11.lv']!;

  /// `s11.coachPenTitle`：牛舍可以擴建了！
  String get s11CoachPenTitle => table['s11.coachPenTitle']!;

  /// `s11.coachPenBody`：多一格就能多養一頭牛。到「商店 › 設施」擴建牛舍（{price} 幣）。
  String s11CoachPenBody({required Object price}) => fill('s11.coachPenBody', {'price': price});

  /// `s11.coachPenGo`：去擴建
  String get s11CoachPenGo => table['s11.coachPenGo']!;

  /// `s11.coachBullTitle`：小公牛長大了！
  String get s11CoachBullTitle => table['s11.coachBullTitle']!;

  /// `s11.coachBullBody`：可以跟母牛配種（自己的免費），也可以派去田裡種稻。
  String get s11CoachBullBody => table['s11.coachBullBody']!;

  /// `s11.coachBullGo`：去配種
  String get s11CoachBullGo => table['s11.coachBullGo']!;

  /// `s11.backupTitle`：把牧場備份起來
  String get s11BackupTitle => table['s11.backupTitle']!;

  /// `s11.backupBody`：換手機或手機壞了都找得回來。
  String get s11BackupBody => table['s11.backupBody']!;

  /// `s11.later`：之後再說
  String get s11Later => table['s11.later']!;

  /// `s11.backupNow`：現在備份
  String get s11BackupNow => table['s11.backupNow']!;

  /// `s03.normal`：平常
  String get s03Normal => table['s03.normal']!;

  /// `s03.panAria`：牧場的位置
  String get s03PanAria => table['s03.panAria']!;

  /// `s03.expandAria`：展開奶桶、倉庫、收購價
  String get s03ExpandAria => table['s03.expandAria']!;

  /// `s03.collapseAria`：收起奶桶、倉庫、收購價
  String get s03CollapseAria => table['s03.collapseAria']!;

  /// `s03.expand`：展開
  String get s03Expand => table['s03.expand']!;

  /// `s03.collapse`：收起
  String get s03Collapse => table['s03.collapse']!;

  /// `collect`：收奶
  String get collect => table['collect']!;

  /// `s03.full`：滿了
  String get s03Full => table['s03.full']!;

  /// `s03.bucketCount`：{amount} 瓶
  String s03BucketCount({required Object amount}) => fill('s03.bucketCount', {'amount': amount});

  /// `s03.fullStopped`：滿了，停止產奶
  String get s03FullStopped => table['s03.fullStopped']!;

  /// `s03.fullIn`：約 {time}後滿
  String s03FullIn({required Object time}) => fill('s03.fullIn', {'time': time});

  /// `s03.noMilkers`：沒有牛在產奶
  String get s03NoMilkers => table['s03.noMilkers']!;

  /// `s03.milkFull`：牛奶滿了
  String get s03MilkFull => table['s03.milkFull']!;

  /// `s03.milkUsed`：牛奶用了 {pct}%
  String s03MilkUsed({required Object pct}) => fill('s03.milkUsed', {'pct': pct});

  /// `s03.prices`：收購價
  String get s03Prices => table['s03.prices']!;

  /// `s03.vsNormal`：比平常
  String get s03VsNormal => table['s03.vsNormal']!;

  /// `s03.bubbleFull`：奶桶滿了
  String get s03BubbleFull => table['s03.bubbleFull']!;

  /// `cowsTitle`：我的牛
  String get cowsTitle => table['cowsTitle']!;

  /// `commodityTag`：【{name}】
  String commodityTag({required Object name}) => fill('commodityTag', {'name': name});

  /// `bothTag`：【全部】
  String get bothTag => table['bothTag']!;

  /// `s03.swipeHint`：左右滑動，看看整個牧場
  String get s03SwipeHint => table['s03.swipeHint']!;

  /// `s03.metaField`：在第 {n} 塊田・稻米 {rate} 公斤／時
  String s03MetaField({required Object n, required Object rate}) => fill('s03.metaField', {'n': n, 'rate': rate});

  /// `s03.metaListed`：借種上架中：{price} 幣
  String s03MetaListed({required Object price}) => fill('s03.metaListed', {'price': price});

  /// `milkRate`：產奶 {v} 瓶／時
  String milkRate({required Object v}) => fill('milkRate', {'v': v});

  /// `weight`：體重 {v} 公斤
  String weight({required Object v}) => fill('weight', {'v': v});

  /// `s03.metaValue`：估值約 {v} 幣
  String s03MetaValue({required Object v}) => fill('s03.metaValue', {'v': v});

  /// `collected`：收了 {v} 瓶牛奶，放進倉庫了
  String collected({required Object v}) => fill('collected', {'v': v});

  /// `collectedSpoiled`：收了 {v} 瓶牛奶，順便丟掉 {n} 瓶壞掉的牛奶
  String collectedSpoiled({required Object n, required Object v}) => fill('collectedSpoiled', {'n': n, 'v': v});

  /// `s03.partial`：倉庫滿了，收進 {n} 瓶，\n還有 {left} 瓶在奶桶裡
  String s03Partial({required Object left, required Object n}) => fill('s03.partial', {'left': left, 'n': n});

  /// `s03.popMilk`：產{tier}牛奶 {n} 瓶／時
  String s03PopMilk({required Object n, required Object tier}) => fill('s03.popMilk', {'n': n, 'tier': tier});

  /// `s03.popDetail`：看詳細
  String get s03PopDetail => table['s03.popDetail']!;

  /// `penSummary`：牛舍 {used} / {slots} 格
  String penSummary({required Object slots, required Object used}) => fill('penSummary', {'slots': slots, 'used': used});

  /// `s03.penFullSuffix`：（滿了）
  String get s03PenFullSuffix => table['s03.penFullSuffix']!;

  /// `s03.expandPen`：擴建
  String get s03ExpandPen => table['s03.expandPen']!;

  /// `g.all`：全部
  String get gAll => table['g.all']!;

  /// `noCows`：牛舍裡還沒有牛
  String get noCows => table['noCows']!;

  /// `s03.emptyHint`：到商店抽一頭牛，或等配種的小牛出生。
  String get s03EmptyHint => table['s03.emptyHint']!;

  /// `s03.goShop`：去商店
  String get s03GoShop => table['s03.goShop']!;

  /// `g.close`：關閉
  String get gClose => table['g.close']!;

  /// `s06.bigNews`：大新聞
  String get s06BigNews => table['s06.bigNews']!;

  /// `news.beef_up.1`：烤肉季開跑
  String get newsBeefUp1 => table['news.beef_up.1']!;

  /// `s03.bigNewsBody`：{name}收購價 {chg}，現在 {price} 幣／{unit}
  String s03BigNewsBody({required Object chg, required Object name, required Object price, required Object unit}) => fill('s03.bigNewsBody', {'chg': chg, 'name': name, 'price': price, 'unit': unit});

  /// `s03.bigNewsAll`：全部商品的收購價 {chg}
  String s03BigNewsAll({required Object chg}) => fill('s03.bigNewsAll', {'chg': chg});

  /// `s03.bigNewsGo`：去市場看看
  String get s03BigNewsGo => table['s03.bigNewsGo']!;

  /// `s06.vsSame`：跟平常一樣
  String get s06VsSame => table['s06.vsSame']!;

  /// `s06.vsHigher`：比平常高 {pct}
  String s06VsHigher({required Object pct}) => fill('s06.vsHigher', {'pct': pct});

  /// `s06.vsLower`：比平常低 {pct}
  String s06VsLower({required Object pct}) => fill('s06.vsLower', {'pct': pct});

  /// `s06.loading`：正在取得收購價…
  String get s06Loading => table['s06.loading']!;

  /// `s06.title`：現在的收購價
  String get s06Title => table['s06.title']!;

  /// `s06.tapToSell`：點一列就能賣
  String get s06TapToSell => table['s06.tapToSell']!;

  /// `priceUnit`：幣／{unit}
  String priceUnit({required Object unit}) => fill('priceUnit', {'unit': unit});

  /// `s06.baseLine`：平常（基本價）：牛奶 {milk} 幣／瓶、牛肉 {beef} 幣／公斤、稻米 {rice} 幣／公斤
  String s06BaseLine({required Object beef, required Object milk, required Object rice}) => fill('s06.baseLine', {'beef': beef, 'milk': milk, 'rice': rice});

  /// `s06.multMilk`：市價 × 稀有度 × 新鮮度
  String get s06MultMilk => table['s06.multMilk']!;

  /// `s06.multBeef`：市價 × 評級 × 稀有度 × 存放折價
  String get s06MultBeef => table['s06.multBeef']!;

  /// `s06.multRice`：市價 × 存放折價
  String get s06MultRice => table['s06.multRice']!;

  /// `s06.sellTitle`：賣出{name}
  String s06SellTitle({required Object name}) => fill('s06.sellTitle', {'name': name});

  /// `inventory`：庫存 {qty} {unit}
  String inventory({required Object qty, required Object unit}) => fill('inventory', {'qty': qty, 'unit': unit});

  /// `nothingToSell`：倉庫裡沒有{name}可以賣
  String nothingToSell({required Object name}) => fill('nothingToSell', {'name': name});

  /// `sellTitle`：賣出
  String get sellTitle => table['sellTitle']!;

  /// `quoting`：試算中…
  String get quoting => table['quoting']!;

  /// `s06.quoteFailed`：試算失敗
  String get s06QuoteFailed => table['s06.quoteFailed']!;

  /// `estAvgPrice`：預估成交均價
  String get estAvgPrice => table['estAvgPrice']!;

  /// `estAvgValue`：{avg} 幣／{unit}
  String estAvgValue({required Object avg, required Object unit}) => fill('estAvgValue', {'avg': avg, 'unit': unit});

  /// `s06.estTotalLabel`：預估總額
  String get s06EstTotalLabel => table['s06.estTotalLabel']!;

  /// `s06.marketPrice`：市價
  String get s06MarketPrice => table['s06.marketPrice']!;

  /// `g.pricePer`：{price} 幣／{unit}
  String gPricePer({required Object price, required Object unit}) => fill('g.pricePer', {'price': price, 'unit': unit});

  /// `s06.formula`：成交價 ＝ {mult}
  String s06Formula({required Object mult}) => fill('s06.formula', {'mult': mult});

  /// `s06.lots`：（{n} 批）
  String s06Lots({required Object n}) => fill('s06.lots', {'n': n});

  /// `s06.qty`：數量
  String get s06Qty => table['s06.qty']!;

  /// `s06.oldestFirst`：從最舊的一批先賣。
  String get s06OldestFirst => table['s06.oldestFirst']!;

  /// `tooMuch`：一次賣太多，均價會變差，要不要分批？
  String get tooMuch => table['tooMuch']!;

  /// `sellConfirm`：確認賣出 {qty} {unit}
  String sellConfirm({required Object qty, required Object unit}) => fill('sellConfirm', {'qty': qty, 'unit': unit});

  /// `newsTitle`：新聞
  String get newsTitle => table['newsTitle']!;

  /// `s06.up`：利多
  String get s06Up => table['s06.up']!;

  /// `s06.down`：利空
  String get s06Down => table['s06.down']!;

  /// `s06.superTag`：超級大事件
  String get s06SuperTag => table['s06.superTag']!;

  /// `s06.swanTag`：超級黑天鵝
  String get s06SwanTag => table['s06.swanTag']!;

  /// `s06.pinUp`：{name}收購價變兩倍
  String s06PinUp({required Object name}) => fill('s06.pinUp', {'name': name});

  /// `s06.pinDown`：{name}收購價只剩一成
  String s06PinDown({required Object name}) => fill('s06.pinDown', {'name': name});

  /// `s06.pinUpAll`：全部商品的收購價\n都變兩倍
  String get s06PinUpAll => table['s06.pinUpAll']!;

  /// `s06.pinDownAll`：全部商品的收購價\n都只剩一成
  String get s06PinDownAll => table['s06.pinDownAll']!;

  /// `s06.pinNow`：現在 {price} 幣／{unit}
  String s06PinNow({required Object price, required Object unit}) => fill('s06.pinNow', {'price': price, 'unit': unit});

  /// `noNews`：目前沒有新聞。
  String get noNews => table['noNews']!;

  /// `sold`：賣出 {qty} {unit}，均價 {avg}，共 {total} 幣
  String sold({required Object avg, required Object qty, required Object total, required Object unit}) => fill('sold', {'avg': avg, 'qty': qty, 'total': total, 'unit': unit});

  /// `s04.age`：年齡
  String get s04Age => table['s04.age']!;

  /// `s04.growIn`：長大還要
  String get s04GrowIn => table['s04.growIn']!;

  /// `g.milk`：產奶
  String get gMilk => table['g.milk']!;

  /// `g.perHourMilk`：瓶／時
  String get gPerHourMilk => table['g.perHourMilk']!;

  /// `g.plow`：耕田
  String get gPlow => table['g.plow']!;

  /// `g.perHourRice`：公斤稻米／時
  String get gPerHourRice => table['g.perHourRice']!;

  /// `s04.useBeef`：出貨牛肉最多
  String get s04UseBeef => table['s04.useBeef']!;

  /// `s04.useBreed`：配種
  String get s04UseBreed => table['s04.useBreed']!;

  /// `s04.weight`：體重
  String get s04Weight => table['s04.weight']!;

  /// `g.kg`：公斤
  String get gKg => table['g.kg']!;

  /// `s04.value`：出貨估值
  String get s04Value => table['s04.value']!;

  /// `s04.about`：約 {v}
  String s04About({required Object v}) => fill('s04.about', {'v': v});

  /// `g.coin`：幣
  String get gCoin => table['g.coin']!;

  /// `s04.originStart`：開局
  String get s04OriginStart => table['s04.originStart']!;

  /// `s04.originShop`：商店 {g} 級
  String s04OriginShop({required Object g}) => fill('s04.originShop', {'g': g});

  /// `s04.originBreed`：自己配種
  String get s04OriginBreed => table['s04.originBreed']!;

  /// `s04.originStud`：借種
  String get s04OriginStud => table['s04.originStud']!;

  /// `origin`：來源：{v}
  String origin({required Object v}) => fill('origin', {'v': v});

  /// `shipGradeTitle`：出貨評級機率
  String get shipGradeTitle => table['shipGradeTitle']!;

  /// `s04.gradeHint`：養到最佳體重，A 級機會最高
  String get s04GradeHint => table['s04.gradeHint']!;

  /// `s04.oldNote`：老牛：過了壯年，產出和肉質會慢慢下降
  String get s04OldNote => table['s04.oldNote']!;

  /// `s04.listStud`：上架借種
  String get s04ListStud => table['s04.listStud']!;

  /// `s04.studFee`：借種費
  String get s04StudFee => table['s04.studFee']!;

  /// `s04.feeHowGrow`：{tier}（每公斤 {rate} 幣）× {kg} 公斤，長大後會再漲
  String s04FeeHowGrow({required Object kg, required Object rate, required Object tier}) => fill('s04.feeHowGrow', {'kg': kg, 'rate': rate, 'tier': tier});

  /// `s04.feeHowMax`：{tier}（每公斤 {rate} 幣）× {kg} 公斤，已經長到最壯
  String s04FeeHowMax({required Object kg, required Object rate, required Object tier}) => fill('s04.feeHowMax', {'kg': kg, 'rate': rate, 'tier': tier});

  /// `s04.listTitle`：{cow} 上架借種
  String s04ListTitle({required Object cow}) => fill('s04.listTitle', {'cow': cow});

  /// `s04.listHint`：別人付這個錢借你的公牛配種；錢給你，小牛歸對方。借出去就算這頭公牛這輩子的那一次配種。
  String get s04ListHint => table['s04.listHint']!;

  /// `s04.listConfirm`：上架（{price} 幣）
  String s04ListConfirm({required Object price}) => fill('s04.listConfirm', {'price': price});

  /// `unlist`：下架
  String get unlist => table['unlist']!;

  /// `g.assign`：派去田裡
  String get gAssign => table['g.assign']!;

  /// `recallFirst`：在第 {n} 塊田工作，先叫回來才能出貨或配種
  String recallFirst({required Object n}) => fill('recallFirst', {'n': n});

  /// `s04.recall`：叫回來
  String get s04Recall => table['s04.recall']!;

  /// `s04.calfHint`：小牛長大以後才能配種、出貨。
  String get s04CalfHint => table['s04.calfHint']!;

  /// `s04.cantBreedYet`：還不能配種
  String get s04CantBreedYet => table['s04.cantBreedYet']!;

  /// `shipNotAdult`：小牛還不能出貨
  String get shipNotAdult => table['shipNotAdult']!;

  /// `s04.noteBred`：已配種：每頭牛一輩子只能配種一次
  String get s04NoteBred => table['s04.noteBred']!;

  /// `s04.alreadyBred`：已配過種
  String get s04AlreadyBred => table['s04.alreadyBred']!;

  /// `cowTitle`：牛 #{id}
  String cowTitle({required Object id}) => fill('cowTitle', {'id': id});

  /// `s04.goneTitle`：找不到這頭牛
  String get s04GoneTitle => table['s04.goneTitle']!;

  /// `s04.goneBody`：可能已經出貨了，或在另一支手機上處理過。
  String get s04GoneBody => table['s04.goneBody']!;

  /// `s04.backRanch`：回牧場
  String get s04BackRanch => table['s04.backRanch']!;

  /// `s04.noField`：沒有空田：先開新田，或叫回別的耕牛
  String get s04NoField => table['s04.noField']!;

  /// `s04.recallFirstOx`：在第 {n} 塊田工作，先叫回來才能出貨、配種或上架
  String s04RecallFirstOx({required Object n}) => fill('s04.recallFirstOx', {'n': n});

  /// `breedFree`：費用 免費（自己的公母）
  String get breedFree => table['breedFree']!;

  /// `s08.outcomeTitle`：可能生出的小牛
  String get s08OutcomeTitle => table['s08.outcomeTitle']!;

  /// `pickBoth`：請選一頭公牛和一頭母牛
  String get pickBoth => table['pickBoth']!;

  /// `s08.calculating`：計算機率中…
  String get s08Calculating => table['s08.calculating']!;

  /// `s08.probFailedRetry`：機率載入失敗，{n} 秒後自動再試
  String s08ProbFailedRetry({required Object n}) => fill('s08.probFailedRetry', {'n': n});

  /// `s08.notFound`：沒發現過
  String get s08NotFound => table['s08.notFound']!;

  /// `bullProbLine`：公牛機率 {v}
  String bullProbLine({required Object v}) => fill('bullProbLine', {'v': v});

  /// `s08.growRange`：小牛長大 {v}
  String s08GrowRange({required Object v}) => fill('s08.growRange', {'v': v});

  /// `s08.hoursRange`：{a}–{b} 小時
  String s08HoursRange({required Object a, required Object b}) => fill('s08.hoursRange', {'a': a, 'b': b});

  /// `subOwnBreed`：自己配種
  String get subOwnBreed => table['subOwnBreed']!;

  /// `subStud`：借種
  String get subStud => table['subStud']!;

  /// `s08.rule`：每頭牛一輩子只能配種一次・自己的公母配種免費
  String get s08Rule => table['s08.rule']!;

  /// `pickSire`：選公牛
  String get pickSire => table['pickSire']!;

  /// `pickDam`：選母牛
  String get pickDam => table['pickDam']!;

  /// `noSire`：沒有能配種的成年公牛
  String get noSire => table['noSire']!;

  /// `noDam`：沒有能配種的成年母牛
  String get noDam => table['noDam']!;

  /// `s08.noSireHint`：到商店抽牛，或等小公牛長大。也可以到「借種」借別人的公牛。
  String get s08NoSireHint => table['s08.noSireHint']!;

  /// `s08.noDamHint`：到商店抽牛，或等小母牛長大。
  String get s08NoDamHint => table['s08.noDamHint']!;

  /// `s08.breedBtnFree`：配種（免費）
  String get s08BreedBtnFree => table['s08.breedBtnFree']!;

  /// `s08.alreadyBred`：{cow} 已經配過種了（每頭牛一輩子只能配種一次）
  String s08AlreadyBred({required Object cow}) => fill('s08.alreadyBred', {'cow': cow});

  /// `s08.penFull`：牛舍滿了，先擴建或出貨，才有位子給小牛
  String get s08PenFull => table['s08.penFull']!;

  /// `s08.bredBtn`：已配種
  String get s08BredBtn => table['s08.bredBtn']!;

  /// `breedDone`：配種成功！{cow} 出生了
  String breedDone({required Object cow}) => fill('breedDone', {'cow': cow});

  /// `s18.ownerLabel`：主人：
  String get s18OwnerLabel => table['s18.ownerLabel']!;

  /// `botPrefix`：電腦
  String get botPrefix => table['botPrefix']!;

  /// `s18.growing`：還在長
  String get s18Growing => table['s18.growing']!;

  /// `s18.noBullTitle`：沒有能上架的公牛
  String get s18NoBullTitle => table['s18.noBullTitle']!;

  /// `s18.noBullHint`：要成年、沒配過種、不在田裡工作。
  String get s18NoBullHint => table['s18.noBullHint']!;

  /// `s18.feeLabel`：借種費 {price} 幣
  String s18FeeLabel({required Object price}) => fill('s18.feeLabel', {'price': price});

  /// `list`：上架
  String get list => table['list']!;

  /// `s18.feeNote`：借種費由系統算：公牛的體重 × 稀有度的每公斤價格，長大會自動漲。
  String get s18FeeNote => table['s18.feeNote']!;

  /// `studMineTitle`：我的公牛出借
  String get studMineTitle => table['studMineTitle']!;

  /// `studIncome`：借種收入累計 {v} 幣
  String studIncome({required Object v}) => fill('studIncome', {'v': v});

  /// `s18.logTitle`：借種紀錄
  String get s18LogTitle => table['s18.logTitle']!;

  /// `g.loading`：載入中…
  String get gLoading => table['g.loading']!;

  /// `loadFailed`：載入失敗
  String get loadFailed => table['loadFailed']!;

  /// `reload`：重新整理
  String get reload => table['reload']!;

  /// `studEmpty`：目前沒有別人上架的公牛
  String get studEmpty => table['studEmpty']!;

  /// `pickDamForStud`：選自己的母牛
  String get pickDamForStud => table['pickDamForStud']!;

  /// `studMarketTitle`：借種市場
  String get studMarketTitle => table['studMarketTitle']!;

  /// `s18.pullHint`：下拉重新整理
  String get s18PullHint => table['s18.pullHint']!;

  /// `s18.marketHint`：付錢借別人的公牛：錢給主人，小牛歸你。
  String get s18MarketHint => table['s18.marketHint']!;

  /// `s18.feeLine`：費用 {price} 幣（付給主人）
  String s18FeeLine({required Object price}) => fill('s18.feeLine', {'price': price});

  /// `borrow`：借種（{price} 幣）
  String borrow({required Object price}) => fill('borrow', {'price': price});

  /// `pickListing`：先選一頭要借的公牛，再選自己的母牛
  String get pickListing => table['pickListing']!;

  /// `s18.borrowedBtn`：已借種
  String get s18BorrowedBtn => table['s18.borrowedBtn']!;

  /// `borrowed`：借種成功！付給主人 {price} 幣
  String borrowed({required Object price}) => fill('borrowed', {'price': price});

  /// `s18.goneTitle`：借不到了
  String get s18GoneTitle => table['s18.goneTitle']!;

  /// `s18.goneBody`：這頭公牛剛剛被別人借走，或主人下架了。\n錢沒有扣。
  String get s18GoneBody => table['s18.goneBody']!;

  /// `s18.reloadMarket`：重新整理市場
  String get s18ReloadMarket => table['s18.reloadMarket']!;

  /// `s18.feeChangedTitle`：借種費變了
  String get s18FeeChangedTitle => table['s18.feeChangedTitle']!;

  /// `s18.feeChangedBody`：這頭公牛長大了，借種費從 {old} 幣變成 {now} 幣。\n要用新的價格借嗎？
  String s18FeeChangedBody({required Object now, required Object old}) => fill('s18.feeChangedBody', {'now': now, 'old': old});

  /// `s18.borrowNew`：用新價格借（{price} 幣）
  String s18BorrowNew({required Object price}) => fill('s18.borrowNew', {'price': price});

  /// `s18.logIncome`：借出收入累計 {v} 幣
  String s18LogIncome({required Object v}) => fill('s18.logIncome', {'v': v});

  /// `s18.out`：借出
  String get s18Out => table['s18.out']!;

  /// `s18.in`：借入
  String get s18In => table['s18.in']!;

  /// `s18.lentTo`：{cow} 借給 {ranch}
  String s18LentTo({required Object cow, required Object ranch}) => fill('s18.lentTo', {'cow': cow, 'ranch': ranch});

  /// `s18.borrowedFrom`：{cow} 借自 {ranch}
  String s18BorrowedFrom({required Object cow, required Object ranch}) => fill('s18.borrowedFrom', {'cow': cow, 'ranch': ranch});

  /// `s18.calfBorn`：生下 {cow}
  String s18CalfBorn({required Object cow}) => fill('s18.calfBorn', {'cow': cow});

  /// `s18.logKeep`：只保留最近 {n} 天的紀錄。
  String s18LogKeep({required Object n}) => fill('s18.logKeep', {'n': n});

  /// `s18.logEmpty`：還沒有借種紀錄
  String get s18LogEmpty => table['s18.logEmpty']!;

  /// `s18.logEmptyOut`：還沒有借出的紀錄
  String get s18LogEmptyOut => table['s18.logEmptyOut']!;

  /// `s18.logEmptyIn`：還沒有借入的紀錄
  String get s18LogEmptyIn => table['s18.logEmptyIn']!;

  /// `g.growsIn`：{time}後長大
  String gGrowsIn({required Object time}) => fill('g.growsIn', {'time': time});

  /// `fieldName`：第 {n} 塊田
  String fieldName({required Object n}) => fill('fieldName', {'n': n});

  /// `s17.leftover`：牛叫回來了，田裡還有 {kg} 公斤稻米，收成時一起收。
  String s17Leftover({required Object kg}) => fill('s17.leftover', {'kg': kg});

  /// `s17.emptyHint`：空田：派一頭成年耕牛來種稻。
  String get s17EmptyHint => table['s17.emptyHint']!;

  /// `fieldEmpty`：空田
  String get fieldEmpty => table['fieldEmpty']!;

  /// `noOx`：沒有能下田的成年耕牛
  String get noOx => table['noOx']!;

  /// `assignOx`：派耕牛
  String get assignOx => table['assignOx']!;

  /// `s17.full`：長滿了
  String get s17Full => table['s17.full']!;

  /// `fieldRate`：每小時 {v} 公斤
  String fieldRate({required Object v}) => fill('fieldRate', {'v': v});

  /// `recall`：叫回
  String get recall => table['recall']!;

  /// `fieldFull`：長滿了，快收成！收成後才會繼續長。
  String get fieldFull => table['fieldFull']!;

  /// `s17.fullIn`：約 {time}後長滿（最多存 {h} 小時的量）
  String s17FullIn({required Object h, required Object time}) => fill('s17.fullIn', {'h': h, 'time': time});

  /// `fieldsTitle`：田地
  String get fieldsTitle => table['fieldsTitle']!;

  /// `s17.ofMax`：/ {max} 塊
  String s17OfMax({required Object max}) => fill('s17.ofMax', {'max': max});

  /// `s17.stock`：倉庫稻米
  String get s17Stock => table['s17.stock']!;

  /// `s17.perHour`：每小時
  String get s17PerHour => table['s17.perHour']!;

  /// `harvestAll`：收成（田裡約 {kg} 公斤）
  String harvestAll({required Object kg}) => fill('harvestAll', {'kg': kg});

  /// `s17.harvestNone`：收成（田裡沒有稻米）
  String get s17HarvestNone => table['s17.harvestNone']!;

  /// `expandField`：開新田（{cost} 幣）
  String expandField({required Object cost}) => fill('expandField', {'cost': cost});

  /// `pickOx`：派一頭耕牛到第 {n} 塊田
  String pickOx({required Object n}) => fill('pickOx', {'n': n});

  /// `s17.inField`：在第 {n} 塊田
  String s17InField({required Object n}) => fill('s17.inField', {'n': n});

  /// `s17.noOxHint`：耕牛要成年、不在別的田裡、沒有上架借種。\n可以到商店抽牛，或用乳牛配肉牛生耕牛。
  String get s17NoOxHint => table['s17.noOxHint']!;

  /// `g.gotIt`：知道了
  String get gGotIt => table['g.gotIt']!;

  /// `harvested`：收成了 {kg} 公斤稻米，放進倉庫了
  String harvested({required Object kg}) => fill('harvested', {'kg': kg});

  /// `s17.maxFields`：田地已經 {n} 塊（最多）
  String s17MaxFields({required Object n}) => fill('s17.maxFields', {'n': n});

  /// `fieldExpanded`：開了一塊新田（第 {n} 塊）
  String fieldExpanded({required Object n}) => fill('fieldExpanded', {'n': n});

  /// `g.unknownBreed`：？？？
  String get gUnknownBreed => table['g.unknownBreed']!;

  /// `subCodex`：圖鑑
  String get subCodex => table['subCodex']!;

  /// `subRank`：排行榜
  String get subRank => table['subRank']!;

  /// `s09.found`：已發現
  String get s09Found => table['s09.found']!;

  /// `s09.allFound`：{n} 種全部發現了！圖鑑榜上會顯示你完成了。
  String s09AllFound({required Object n}) => fill('s09.allFound', {'n': n});

  /// `s09.hint`：小牛出生、抽到或借種生下新品種，就會記在這裡。
  String get s09Hint => table['s09.hint']!;

  /// `s09.useCount`：{use} {n} 種
  String s09UseCount({required Object n, required Object use}) => fill('s09.useCount', {'n': n, 'use': use});

  /// `s09.howDairy`：爸媽都是乳牛
  String get s09HowDairy => table['s09.howDairy']!;

  /// `s09.howBeef`：爸媽都是肉牛
  String get s09HowBeef => table['s09.howBeef']!;

  /// `s09.howDraft`：一邊乳牛、一邊肉牛（或兩頭耕牛）
  String get s09HowDraft => table['s09.howDraft']!;

  /// `s09.howNoTrait`：{use}，而且沒有顯現任何特徵。
  String s09HowNoTrait({required Object use}) => fill('s09.howNoTrait', {'use': use});

  /// `s09.howTraits`：{use}，而且爸媽都要帶「{traits}」的基因（看起來沒有也可能帶著）。
  String s09HowTraits({required Object traits, required Object use}) => fill('s09.howTraits', {'traits': traits, 'use': use});

  /// `g.listSep`：、
  String get gListSep => table['g.listSep']!;

  /// `s09.milkCow`：產奶（母牛）
  String get s09MilkCow => table['s09.milkCow']!;

  /// `s09.bestKg`：最佳體重
  String get s09BestKg => table['s09.bestKg']!;

  /// `s09.mult`：賣價倍數
  String get s09Mult => table['s09.mult']!;

  /// `s09.multBeef`：（牛肉）
  String get s09MultBeef => table['s09.multBeef']!;

  /// `s09.calfGrow`：小牛長大
  String get s09CalfGrow => table['s09.calfGrow']!;

  /// `g.hourUnit`：小時
  String get gHourUnit => table['g.hourUnit']!;

  /// `s09.notFoundYet`：還沒發現
  String get s09NotFoundYet => table['s09.notFoundYet']!;

  /// `s09.no`：No.{n}
  String s09No({required Object n}) => fill('s09.no', {'n': n});

  /// `s09.howTitle`：怎麼配出來
  String get s09HowTitle => table['s09.howTitle']!;

  /// `s09.firstFound`：第一次發現：{date}　・　目前有 {n} 頭
  String s09FirstFound({required Object date, required Object n}) => fill('s09.firstFound', {'date': date, 'n': n});

  /// `date.mdOnly`：{m} 月 {d} 日
  String dateMdOnly({required Object d, required Object m}) => fill('date.mdOnly', {'d': d, 'm': m});

  /// `s09.unknownTitle`：還沒發現這個品種
  String get s09UnknownTitle => table['s09.unknownTitle']!;

  /// `s09.unknownBody`：{use}・{tier}。多試試不同的牛配種，或到商店抽抽看。
  String s09UnknownBody({required Object tier, required Object use}) => fill('s09.unknownBody', {'tier': tier, 'use': use});

  /// `rankNetworth`：總資產
  String get rankNetworth => table['rankNetworth']!;

  /// `rankCollection`：圖鑑
  String get rankCollection => table['rankCollection']!;

  /// `rankWeekly`：本週收入
  String get rankWeekly => table['rankWeekly']!;

  /// `s12.kinds`：種
  String get s12Kinds => table['s12.kinds']!;

  /// `s12.me`：我
  String get s12Me => table['s12.me']!;

  /// `s12.complete`：完成
  String get s12Complete => table['s12.complete']!;

  /// `s12.weeklyHint`：每週{w} {time} 重新計算。
  String s12WeeklyHint({required Object time, required Object w}) => fill('s12.weeklyHint', {'time': time, 'w': w});

  /// `s12.networthHint`：金幣＋庫存照市價估＋牛的估值。
  String get s12NetworthHint => table['s12.networthHint']!;

  /// `s12.collectionHint`：發現的品種數，最多 {n} 種。
  String s12CollectionHint({required Object n}) => fill('s12.collectionHint', {'n': n});

  /// `s12.pullHint`：下拉可以重新整理。
  String get s12PullHint => table['s12.pullHint']!;

  /// `s12.myRank`：我的名次
  String get s12MyRank => table['s12.myRank']!;

  /// `s12.rankN`：第 {n} 名
  String s12RankN({required Object n}) => fill('s12.rankN', {'n': n});

  /// `notRanked`：未上榜
  String get notRanked => table['notRanked']!;

  /// `s13.web`：網頁
  String get s13Web => table['s13.web']!;

  /// `s13.ssoApple`：使用 Apple 登入
  String get s13SsoApple => table['s13.ssoApple']!;

  /// `s13.ssoGoogle`：使用 Google 登入
  String get s13SsoGoogle => table['s13.ssoGoogle']!;

  /// `s13.privacy`：只用來找回牧場，不會留下你的 email 和姓名。
  String get s13Privacy => table['s13.privacy']!;

  /// `s13.ssoOffline`：連上網路以後才能登入
  String get s13SsoOffline => table['s13.ssoOffline']!;

  /// `s13.notBacked`：還沒備份
  String get s13NotBacked => table['s13.notBacked']!;

  /// `s13.backed`：已備份
  String get s13Backed => table['s13.backed']!;

  /// `s13.title`：設定
  String get s13Title => table['s13.title']!;

  /// `s13.sound`：音效
  String get s13Sound => table['s13.sound']!;

  /// `s13.language`：語言
  String get s13Language => table['s13.language']!;

  /// `s13.updown`：漲跌顏色
  String get s13Updown => table['s13.updown']!;

  /// `s13.up`：漲
  String get s13Up => table['s13.up']!;

  /// `s13.down`：跌
  String get s13Down => table['s13.down']!;

  /// `s13.backup.title`：備份牧場
  String get s13BackupTitle => table['s13.backup.title']!;

  /// `s13.backup.sub`：換手機或手機壞了都能找回
  String get s13BackupSub => table['s13.backup.sub']!;

  /// `s13.delete`：刪除我的牧場
  String get s13Delete => table['s13.delete']!;

  /// `s13.privacyPolicy`：隱私權政策
  String get s13PrivacyPolicy => table['s13.privacyPolicy']!;

  /// `s13.version`：版本
  String get s13Version => table['s13.version']!;

  /// `s13.footer`：{game}　・　所有帳都在伺服器計算
  String s13Footer({required Object game}) => fill('s13.footer', {'game': game});

  /// `s13.backup.done`：牧場已經備份了。換手機或重裝後，用綁定的帳號登入就能找回。
  String get s13BackupDone => table['s13.backup.done']!;

  /// `s13.backup.lead`：備份以後，換手機或手機壞了，都能找回牧場。
  String get s13BackupLead => table['s13.backup.lead']!;

  /// `s13.backup.warn`：沒有備份的牧場，手機壞了就找不回來。
  String get s13BackupWarn => table['s13.backup.warn']!;

  /// `s13.backup.account`：{name} 帳號
  String s13BackupAccount({required Object name}) => fill('s13.backup.account', {'name': name});

  /// `s13.backup.boundOn`：已綁定・{date}
  String s13BackupBoundOn({required Object date}) => fill('s13.backup.boundOn', {'date': date});

  /// `date.ymd`：{y}/{m}/{d}
  String dateYmd({required Object d, required Object m, required Object y}) => fill('date.ymd', {'d': d, 'm': m, 'y': y});

  /// `s13.unbind`：解除
  String get s13Unbind => table['s13.unbind']!;

  /// `s13.backup.addGoogle`：以後可能換 Android 手機的話，再綁一個 Google 帳號。
  String get s13BackupAddGoogle => table['s13.backup.addGoogle']!;

  /// `s13.backup.addGoogleAndroid`：在 Android 手機找回牧場要用 Google 帳號，建議再綁一個 Google 帳號。
  String get s13BackupAddGoogleAndroid => table['s13.backup.addGoogleAndroid']!;

  /// `s13.binding`：綁定中…
  String get s13Binding => table['s13.binding']!;

  /// `s13.backup.before`：之前備份過？用同一個帳號登入，就能換回舊牧場。
  String get s13BackupBefore => table['s13.backup.before']!;

  /// `s13.del.word`：刪除
  String get s13DelWord => table['s13.del.word']!;

  /// `s13.del.title`：刪除後不能復原
  String get s13DelTitle => table['s13.del.title']!;

  /// `s13.del.item1`：牧場「{name}」、所有的牛、金幣、倉庫會全部刪掉。
  String s13DelItem1({required Object name}) => fill('s13.del.item1', {'name': name});

  /// `s13.del.item2`：排行榜上的紀錄也會刪掉。
  String get s13DelItem2 => table['s13.del.item2']!;

  /// `s13.del.item3`：綁定的 Apple／Google 帳號會解除，之後可以再綁新的牧場。
  String get s13DelItem3 => table['s13.del.item3']!;

  /// `s13.del.item4`：這支手機會回到第一次打開的畫面。
  String get s13DelItem4 => table['s13.del.item4']!;

  /// `s13.del.prompt`：請輸入「{word}」兩個字確認
  String s13DelPrompt({required Object word}) => fill('s13.del.prompt', {'word': word});

  /// `s13.deleted`：牧場已經刪除了
  String get s13Deleted => table['s13.deleted']!;

  /// `s13.thanks`：謝謝你這段時間的照顧。
  String get s13Thanks => table['s13.thanks']!;

  /// `s14.newRanch`：開新牧場
  String get s14NewRanch => table['s14.newRanch']!;

  /// `s13.del.failed`：刪除失敗：網路不穩，請稍後再試
  String get s13DelFailed => table['s13.del.failed']!;

  /// `s13.other.title`：這個帳號已經備份了另一個牧場
  String get s13OtherTitle => table['s13.other.title']!;

  /// `s13.other.body`：一個帳號只能備份一個牧場。要換回那個牧場嗎？
  String get s13OtherBody => table['s13.other.body']!;

  /// `s13.other.switch`：換回那個牧場
  String get s13OtherSwitch => table['s13.other.switch']!;

  /// `s13.switch.title`：確定要換回嗎？
  String get s13SwitchTitle => table['s13.switch.title']!;

  /// `s13.switch.warn`：這支手機現在的牧場「{name}」會刪除，不能復原。
  String s13SwitchWarn({required Object name}) => fill('s13.switch.warn', {'name': name});

  /// `s13.switch.after`：換回以後，這支手機會回到「{name}」。
  String s13SwitchAfter({required Object name}) => fill('s13.switch.after', {'name': name});

  /// `s13.switch.confirm`：換回，並刪除現在的牧場
  String get s13SwitchConfirm => table['s13.switch.confirm']!;

  /// `s13.toast.bound`：備份好了！已綁定 {name} 帳號
  String s13ToastBound({required Object name}) => fill('s13.toast.bound', {'name': name});

  /// `s13.toast.cancelled`：已取消登入
  String get s13ToastCancelled => table['s13.toast.cancelled']!;

  /// `s13.toast.failed`：登入失敗，請再試一次
  String get s13ToastFailed => table['s13.toast.failed']!;

  /// `s13.toast.unbound`：已解除 {name} 帳號的綁定
  String s13ToastUnbound({required Object name}) => fill('s13.toast.unbound', {'name': name});

  /// `s13.unbindTitle`：解除 {name} 帳號的綁定？
  String s13UnbindTitle({required Object name}) => fill('s13.unbindTitle', {'name': name});

  /// `s13.unbindBody`：解除以後，就不能用這個帳號找回牧場。
  String get s13UnbindBody => table['s13.unbindBody']!;

  /// `s13.unbindLast`：這是唯一綁定的帳號，解除後這個牧場就沒有備份了。
  String get s13UnbindLast => table['s13.unbindLast']!;

  /// `s13.langHint`：第一次打開時跟著手機的語言。換語言以後，畫面上的字、牛的名字和新聞都會跟著換；牧場名不會變。
  String get s13LangHint => table['s13.langHint']!;

  /// `s13.redUp`：漲紅跌綠
  String get s13RedUp => table['s13.redUp']!;

  /// `s13.redUpHint`：台灣的習慣
  String get s13RedUpHint => table['s13.redUpHint']!;

  /// `s13.greenUp`：綠漲紅跌
  String get s13GreenUp => table['s13.greenUp']!;

  /// `s13.greenUpHint`：國際的習慣
  String get s13GreenUpHint => table['s13.greenUpHint']!;

  /// `s13.udNote`：繁體中文預設漲紅跌綠，English、ไทย 預設綠漲紅跌。
  String get s13UdNote => table['s13.udNote']!;

  /// `s14.recover`：找回我的牧場
  String get s14Recover => table['s14.recover']!;

  /// `s14.signingIn`：登入中…
  String get s14SigningIn => table['s14.signingIn']!;

  /// `s14.noneTitle`：這個帳號沒有備份過牧場
  String get s14NoneTitle => table['s14.noneTitle']!;

  /// `s14.noneBody`：可能是用另一個帳號備份的。\n沒有備份過的牧場找不回來，只能開新牧場。
  String get s14NoneBody => table['s14.noneBody']!;

  /// `s14.otherAccount`：換一個帳號
  String get s14OtherAccount => table['s14.otherAccount']!;

  /// `s14.androidHint`：之前用 iPhone、只綁了 Apple 帳號？請先在 iPhone 的設定裡再綁一個 Google 帳號。
  String get s14AndroidHint => table['s14.androidHint']!;

  /// `s14.lead`：用之前備份牧場的帳號登入
  String get s14Lead => table['s14.lead']!;

  /// `s14.leadHint`：登入以後，牧場就會回到這支手機。
  String get s14LeadHint => table['s14.leadHint']!;

  /// `s14.welcome`：歡迎回來！
  String get s14Welcome => table['s14.welcome']!;

  /// `s14.level`：等級
  String get s14Level => table['s14.level']!;

  /// `s14.coins`：金幣
  String get s14Coins => table['s14.coins']!;

  /// `s14.cows`：牛
  String get s14Cows => table['s14.cows']!;

  /// `s14.head`：頭
  String get s14Head => table['s14.head']!;

  /// `s14.welcomeHint`：牧場已經回到這支手機，舊手機已經登出。
  String get s14WelcomeHint => table['s14.welcomeHint']!;

  /// `s14.elsewhereTitle`：牧場已經在另一支手機登入
  String get s14ElsewhereTitle => table['s14.elsewhereTitle']!;

  /// `s14.elsewhereLead`：「{name}」現在在另一支手機上
  String s14ElsewhereLead({required Object name}) => fill('s14.elsewhereLead', {'name': name});

  /// `s14.elsewhereBody`：一個牧場同一時間只能在一支手機上玩。\n在這支手機再登入一次，就能拿回來。
  String get s14ElsewhereBody => table['s14.elsewhereBody']!;

  /// `s14.elsewhereSecurity`：如果不是你做的，請先檢查那個 Apple 或 Google 帳號的安全，再登入拿回牧場。
  String get s14ElsewhereSecurity => table['s14.elsewhereSecurity']!;

  /// `s15.reconnected`：已重新連線，資料更新了
  String get s15Reconnected => table['s15.reconnected']!;

  /// `s15.invalidTitle`：這支手機的牧場資料失效了
  String get s15InvalidTitle => table['s15.invalidTitle']!;

  /// `s15.invalidBody`：這支手機存的登入資料不能用了。\n備份過的牧場，用備份的帳號登入就能找回來。
  String get s15InvalidBody => table['s15.invalidBody']!;

  /// `s15.longOffTitle`：連不上伺服器，已經超過 {n} 分鐘
  String s15LongOffTitle({required Object n}) => fill('s15.longOffTitle', {'n': n});

  /// `s15.longOffBody`：請檢查網路。連上以後會自動更新。
  String get s15LongOffBody => table['s15.longOffBody']!;

  /// `err.not_enough_stock`：倉庫裡的數量不夠了，請重新選數量
  String get errNotEnoughStock => table['err.not_enough_stock']!;

  /// `penFull`：牛舍滿了，先擴建或出貨
  String get penFull => table['penFull']!;

  /// `err.cow_not_found`：找不到這頭牛，可能已經出貨了
  String get errCowNotFound => table['err.cow_not_found']!;

  /// `err.cow_not_adult`：小牛還沒長大
  String get errCowNotAdult => table['err.cow_not_adult']!;

  /// `err.already_bred`：這頭牛已經配過種了（每頭牛一輩子只能配種一次）
  String get errAlreadyBred => table['err.already_bred']!;

  /// `err.cow_in_field`：這頭牛在田裡工作，先叫回來
  String get errCowInField => table['err.cow_in_field']!;

  /// `err.cow_listed`：這頭公牛在借種市場上架中，先下架
  String get errCowListed => table['err.cow_listed']!;

  /// `err.cow_not_in_field`：這頭牛已經不在田裡了
  String get errCowNotInField => table['err.cow_not_in_field']!;

  /// `err.no_free_field`：沒有空田，先開新田或叫回別的耕牛
  String get errNoFreeField => table['err.no_free_field']!;

  /// `err.field_occupied`：這塊田已經有牛了
  String get errFieldOccupied => table['err.field_occupied']!;

  /// `err.field_not_found`：找不到這塊田，請重新整理
  String get errFieldNotFound => table['err.field_not_found']!;

  /// `err.listing_gone`：這頭公牛已經被借走或下架了
  String get errListingGone => table['err.listing_gone']!;

  /// `err.max_level`：已經是最高級了
  String get errMaxLevel => table['err.max_level']!;

  /// `err.not_yet_available`：還沒開放，{time}後再來
  String errNotYetAvailable({required Object time}) => fill('err.not_yet_available', {'time': time});

  /// `err.internal`：伺服器出了點問題，請稍後再試
  String get errInternal => table['err.internal']!;

  /// `unknownError`：操作失敗，請再試一次
  String get unknownError => table['unknownError']!;

  /// `s16.title`：維護中
  String get s16Title => table['s16.title']!;

  /// `s16.lead`：伺服器正在維護
  String get s16Lead => table['s16.lead']!;

  /// `s16.eta`：預計 {date} 恢復
  String s16Eta({required Object date}) => fill('s16.eta', {'date': date});

  /// `s16.late`：比預計的時間晚一點，請再等一下
  String get s16Late => table['s16.late']!;

  /// `date.mdw`：{m} 月 {d} 日（{w}）{time}
  String dateMdw({required Object d, required Object m, required Object time, required Object w}) => fill('date.mdw', {'d': d, 'm': m, 'time': time, 'w': w});

  /// `weekday.0`：日
  String get weekday0 => table['weekday.0']!;

  /// `weekday.1`：一
  String get weekday1 => table['weekday.1']!;

  /// `weekday.2`：二
  String get weekday2 => table['weekday.2']!;

  /// `weekday.3`：三
  String get weekday3 => table['weekday.3']!;

  /// `weekday.4`：四
  String get weekday4 => table['weekday.4']!;

  /// `weekday.5`：五
  String get weekday5 => table['weekday.5']!;

  /// `weekday.6`：六
  String get weekday6 => table['weekday.6']!;

  /// `weekdayFull.0`：日
  String get weekdayFull0 => table['weekdayFull.0']!;

  /// `weekdayFull.1`：一
  String get weekdayFull1 => table['weekdayFull.1']!;

  /// `weekdayFull.2`：二
  String get weekdayFull2 => table['weekdayFull.2']!;

  /// `weekdayFull.3`：三
  String get weekdayFull3 => table['weekdayFull.3']!;

  /// `weekdayFull.4`：四
  String get weekdayFull4 => table['weekdayFull.4']!;

  /// `weekdayFull.5`：五
  String get weekdayFull5 => table['weekdayFull.5']!;

  /// `weekdayFull.6`：六
  String get weekdayFull6 => table['weekdayFull.6']!;

  /// `s16.body`：維護完成後就能繼續玩。牧場的資料都保存在伺服器上。
  String get s16Body => table['s16.body']!;

  /// `anim.skip`：點一下跳過
  String get animSkip => table['anim.skip']!;

  /// `anim.beep`：嗶
  String get animBeep => table['anim.beep']!;

  /// `anim.thanks`：謝謝你的照顧！
  String get animThanks => table['anim.thanks']!;

  /// `anim.newBreed`：發現新品種！
  String get animNewBreed => table['anim.newBreed']!;

  /// `anim.dexCount`：圖鑑 已發現 {n} / {total}
  String animDexCount({required Object n, required Object total}) => fill('anim.dexCount', {'n': n, 'total': total});

  /// `news.milk_up.1`：學校午餐加訂鮮奶
  String get newsMilkUp1 => table['news.milk_up.1']!;

  /// `news.milk_up.2`：連日高溫，冰品店大量進貨
  String get newsMilkUp2 => table['news.milk_up.2']!;

  /// `news.milk_up.3`：烘焙展開幕，鮮奶需求大增
  String get newsMilkUp3 => table['news.milk_up.3']!;

  /// `news.milk_up.4`：鮮奶檢驗全數合格，買氣回溫
  String get newsMilkUp4 => table['news.milk_up.4']!;

  /// `news.milk_down.1`：鄰近牧場產量大增
  String get newsMilkDown1 => table['news.milk_down.1']!;

  /// `news.milk_down.2`：超市推出鮮奶特賣
  String get newsMilkDown2 => table['news.milk_down.2']!;

  /// `news.milk_down.3`：連日寒流，冰品銷量下滑
  String get newsMilkDown3 => table['news.milk_down.3']!;

  /// `news.milk_down.4`：物流塞車，乳品廠暫停收購
  String get newsMilkDown4 => table['news.milk_down.4']!;

  /// `news.beef_up.2`：餐廳推出牛排節
  String get newsBeefUp2 => table['news.beef_up.2']!;

  /// `news.beef_up.3`：年節備貨潮提前
  String get newsBeefUp3 => table['news.beef_up.3']!;

  /// `news.beef_up.4`：牛肉麵大賽熱鬧登場
  String get newsBeefUp4 => table['news.beef_up.4']!;

  /// `news.beef_down.1`：健康飲食風潮，肉品需求降溫
  String get newsBeefDown1 => table['news.beef_down.1']!;

  /// `news.beef_down.2`：進口牛肉到港量創新高
  String get newsBeefDown2 => table['news.beef_down.2']!;

  /// `news.beef_down.3`：冷凍倉庫滿載，肉商暫緩收購
  String get newsBeefDown3 => table['news.beef_down.3']!;

  /// `news.beef_down.4`：連假結束，餐廳訂單減少
  String get newsBeefDown4 => table['news.beef_down.4']!;

  /// `news.rice_up.2`：便當業者搶購新米
  String get newsRiceUp2 => table['news.rice_up.2']!;

  /// `news.rice_up.3`：米食文化節開幕
  String get newsRiceUp3 => table['news.rice_up.3']!;

  /// `news.rice_up.4`：外銷訂單增加，米價走揚
  String get newsRiceUp4 => table['news.rice_up.4']!;

  /// `news.rice_down.1`：中部豐收，新米大量上市
  String get newsRiceDown1 => table['news.rice_down.1']!;

  /// `news.rice_down.2`：公糧收購暫停
  String get newsRiceDown2 => table['news.rice_down.2']!;

  /// `news.rice_down.3`：連日好天氣，各地提早收割
  String get newsRiceDown3 => table['news.rice_down.3']!;

  /// `news.rice_down.4`：米倉滿載，糧商暫緩收購
  String get newsRiceDown4 => table['news.rice_down.4']!;

  /// `news.all_up.1`：觀光牧場人潮湧入
  String get newsAllUp1 => table['news.all_up.1']!;

  /// `news.all_up.2`：農產品博覽會開幕
  String get newsAllUp2 => table['news.all_up.2']!;

  /// `news.all_up.3`：連假出遊潮，餐飲需求旺
  String get newsAllUp3 => table['news.all_up.3']!;

  /// `news.all_down.1`：颱風過境，市場休市一日
  String get newsAllDown1 => table['news.all_down.1']!;

  /// `news.all_down.2`：物價調查公布，消費者縮減開支
  String get newsAllDown2 => table['news.all_down.2']!;

  /// `news.all_down.3`：港口罷工，出口受阻
  String get newsAllDown3 => table['news.all_down.3']!;

  /// `news.milk_super.1`：全國學校改喝鮮奶，訂單暴增
  String get newsMilkSuper1 => table['news.milk_super.1']!;

  /// `news.milk_super.2`：國際冰淇淋大賽開幕，鮮奶搶光
  String get newsMilkSuper2 => table['news.milk_super.2']!;

  /// `news.milk_super.3`：鮮奶拿鐵爆紅，咖啡店搶不到奶
  String get newsMilkSuper3 => table['news.milk_super.3']!;

  /// `news.milk_swan.1`：乳品廠大停電，鮮奶全面停收
  String get newsMilkSwan1 => table['news.milk_swan.1']!;

  /// `news.milk_swan.2`：冷藏車大罷工，鮮奶運不出去
  String get newsMilkSwan2 => table['news.milk_swan.2']!;

  /// `news.milk_swan.3`：超級寒流來襲，冰品店全部休息
  String get newsMilkSwan3 => table['news.milk_swan.3']!;

  /// `news.beef_super.1`：世界牛排大賽在本地舉辦
  String get newsBeefSuper1 => table['news.beef_super.1']!;

  /// `news.beef_super.2`：全國烤肉節提前開跑，肉商搶貨
  String get newsBeefSuper2 => table['news.beef_super.2']!;

  /// `news.beef_super.3`：牛肉麵登上國際美食榜
  String get newsBeefSuper3 => table['news.beef_super.3']!;

  /// `news.beef_swan.1`：冷凍物流大當機，肉商全面停收
  String get newsBeefSwan1 => table['news.beef_swan.1']!;

  /// `news.beef_swan.2`：便宜進口牛肉湧入，價格崩盤
  String get newsBeefSwan2 => table['news.beef_swan.2']!;

  /// `news.beef_swan.3`：全國蔬食週開跑，牛肉沒人買
  String get newsBeefSwan3 => table['news.beef_swan.3']!;

  /// `news.rice_super.1`：新米拿下國際金獎，米價翻倍
  String get newsRiceSuper1 => table['news.rice_super.1']!;

  /// `news.rice_super.2`：海外飯糰大流行，外銷訂單爆量
  String get newsRiceSuper2 => table['news.rice_super.2']!;

  /// `news.rice_super.3`：國宴指定在地新米，糧商搶貨
  String get newsRiceSuper3 => table['news.rice_super.3']!;

  /// `news.rice_swan.1`：糧商全面停收，新米堆成山
  String get newsRiceSwan1 => table['news.rice_swan.1']!;

  /// `news.rice_swan.2`：百年一見大豐收，新米賣不出去
  String get newsRiceSwan2 => table['news.rice_swan.2']!;

  /// `news.rice_swan.3`：麵食大流行，米飯沒人吃
  String get newsRiceSwan3 => table['news.rice_swan.3']!;

  /// `news.all_super.1`：世界美食節在本地登場
  String get newsAllSuper1 => table['news.all_super.1']!;

  /// `news.all_super.2`：觀光人潮創新高，餐廳天天客滿
  String get newsAllSuper2 => table['news.all_super.2']!;

  /// `news.all_super.3`：超級連假來了，餐飲需求翻倍
  String get newsAllSuper3 => table['news.all_super.3']!;

  /// `news.all_swan.1`：超級颱風來襲，市場全面停擺
  String get newsAllSwan1 => table['news.all_swan.1']!;

  /// `news.all_swan.2`：港口全面封閉，農產品出不了貨
  String get newsAllSwan2 => table['news.all_swan.2']!;

  /// `news.all_swan.3`：全國消費急凍，農產品沒人買
  String get newsAllSwan3 => table['news.all_swan.3']!;

  /// `namegen.first.0`：晨光
  String get namegenFirst0 => table['namegen.first.0']!;

  /// `namegen.first.1`：青草
  String get namegenFirst1 => table['namegen.first.1']!;

  /// `namegen.first.2`：白雲
  String get namegenFirst2 => table['namegen.first.2']!;

  /// `namegen.first.3`：星河
  String get namegenFirst3 => table['namegen.first.3']!;

  /// `namegen.first.4`：楓葉
  String get namegenFirst4 => table['namegen.first.4']!;

  /// `namegen.first.5`：暖陽
  String get namegenFirst5 => table['namegen.first.5']!;

  /// `namegen.first.6`：微風
  String get namegenFirst6 => table['namegen.first.6']!;

  /// `namegen.first.7`：山嵐
  String get namegenFirst7 => table['namegen.first.7']!;

  /// `namegen.first.8`：月牙
  String get namegenFirst8 => table['namegen.first.8']!;

  /// `namegen.first.9`：麥浪
  String get namegenFirst9 => table['namegen.first.9']!;

  /// `namegen.first.10`：彩虹
  String get namegenFirst10 => table['namegen.first.10']!;

  /// `namegen.first.11`：露珠
  String get namegenFirst11 => table['namegen.first.11']!;

  /// `namegen.second.0`：小丘
  String get namegenSecond0 => table['namegen.second.0']!;

  /// `namegen.second.1`：河畔
  String get namegenSecond1 => table['namegen.second.1']!;

  /// `namegen.second.2`：原野
  String get namegenSecond2 => table['namegen.second.2']!;

  /// `namegen.second.3`：松林
  String get namegenSecond3 => table['namegen.second.3']!;

  /// `namegen.second.4`：花田
  String get namegenSecond4 => table['namegen.second.4']!;

  /// `namegen.second.5`：湖邊
  String get namegenSecond5 => table['namegen.second.5']!;

  /// `namegen.second.6`：坡地
  String get namegenSecond6 => table['namegen.second.6']!;

  /// `namegen.second.7`：竹林
  String get namegenSecond7 => table['namegen.second.7']!;

  /// `namegen.second.8`：石橋
  String get namegenSecond8 => table['namegen.second.8']!;

  /// `namegen.second.9`：溪谷
  String get namegenSecond9 => table['namegen.second.9']!;

  /// `namegen.second.10`：谷地
  String get namegenSecond10 => table['namegen.second.10']!;

  /// `namegen.second.11`：森林
  String get namegenSecond11 => table['namegen.second.11']!;

  /// `namegen.third.0`：牧場
  String get namegenThird0 => table['namegen.third.0']!;

  /// `namegen.third.1`：農莊
  String get namegenThird1 => table['namegen.third.1']!;

  /// `namegen.third.2`：牧園
  String get namegenThird2 => table['namegen.third.2']!;

  /// `namegen.third.3`：農場
  String get namegenThird3 => table['namegen.third.3']!;

  /// `namegen.third.4`：乳坊
  String get namegenThird4 => table['namegen.third.4']!;

  /// `namegen.third.5`：牛舍
  String get namegenThird5 => table['namegen.third.5']!;

  /// `namegen.third.6`：莊園
  String get namegenThird6 => table['namegen.third.6']!;

  /// `namegen.third.7`：牧舍
  String get namegenThird7 => table['namegen.third.7']!;

  /// `namegen.third.8`：小屋
  String get namegenThird8 => table['namegen.third.8']!;

  /// `namegen.third.9`：家園
  String get namegenThird9 => table['namegen.third.9']!;

  /// `namegen.third.10`：田園
  String get namegenThird10 => table['namegen.third.10']!;

  /// `namegen.third.11`：牧野
  String get namegenThird11 => table['namegen.third.11']!;

  /// `namegen.pattern`：{first}{second}{third}
  String namegenPattern({required Object first, required Object second, required Object third}) => fill('namegen.pattern', {'first': first, 'second': second, 'third': third});

  /// `s18.deletedRanch`：已刪除的牧場
  String get s18DeletedRanch => table['s18.deletedRanch']!;

  /// `s21.title`：牧場資料
  String get s21Title => table['s21.title']!;

  /// `s21.badges`：成就徽章
  String get s21Badges => table['s21.badges']!;

  /// `s21.badgeCount`：已解鎖 {n} / {total}
  String s21BadgeCount({required Object n, required Object total}) => fill('s21.badgeCount', {'n': n, 'total': total});

  /// `s21.badgeDate`：{date} 解鎖
  String s21BadgeDate({required Object date}) => fill('s21.badgeDate', {'date': date});

  /// `s21.badgeLocked`：還沒解鎖
  String get s21BadgeLocked => table['s21.badgeLocked']!;

  /// `s21.avatarTitle`：換頭像
  String get s21AvatarTitle => table['s21.avatarTitle']!;

  /// `s21.avatarUse`：用這個頭像
  String get s21AvatarUse => table['s21.avatarUse']!;

  /// `s21.avatarFoundOnly`：只有圖鑑裡發現過的能選
  String get s21AvatarFoundOnly => table['s21.avatarFoundOnly']!;

  /// `s21.avatarCount`：已發現 {n} / {total} 種；還沒發現的，發現以後就能用
  String s21AvatarCount({required Object n, required Object total}) => fill('s21.avatarCount', {'n': n, 'total': total});

  /// `s21.avatarLocked`：還沒發現「{name}」，在圖鑑發現以後就能用
  String s21AvatarLocked({required Object name}) => fill('s21.avatarLocked', {'name': name});

  /// `s21.avatarDone`：頭像換好了！
  String get s21AvatarDone => table['s21.avatarDone']!;

  /// `s21.renameTitle`：改牧場名
  String get s21RenameTitle => table['s21.renameTitle']!;

  /// `s21.renameFree`：改名（免費）
  String get s21RenameFree => table['s21.renameFree']!;

  /// `s21.renamePaid`：改名（{price} 幣）
  String s21RenamePaid({required Object price}) => fill('s21.renamePaid', {'price': price});

  /// `s21.renamedFirst`：牧場名改好了！下次改名要 {price} 幣
  String s21RenamedFirst({required Object price}) => fill('s21.renamedFirst', {'price': price});

  /// `ach.firstMilk.name`：第一桶奶
  String get achFirstMilkName => table['ach.firstMilk.name']!;

  /// `ach.firstMilk.cond`：第一次收奶
  String get achFirstMilkCond => table['ach.firstMilk.cond']!;

  /// `ach.firstSale.name`：開張大吉
  String get achFirstSaleName => table['ach.firstSale.name']!;

  /// `ach.firstSale.cond`：第一次在市場賣出東西
  String get achFirstSaleCond => table['ach.firstSale.cond']!;

  /// `ach.firstShip.name`：第一趟出貨
  String get achFirstShipName => table['ach.firstShip.name']!;

  /// `ach.firstShip.cond`：第一次出貨
  String get achFirstShipCond => table['ach.firstShip.cond']!;

  /// `ach.gradeA.name`：A 級牧場
  String get achGradeAName => table['ach.gradeA.name']!;

  /// `ach.gradeA.cond`：出貨評到 A 級 10 次
  String get achGradeACond => table['ach.gradeA.cond']!;

  /// `ach.newLife.name`：新生命
  String get achNewLifeName => table['ach.newLife.name']!;

  /// `ach.newLife.cond`：第一次配種生出小牛
  String get achNewLifeCond => table['ach.newLife.cond']!;

  /// `ach.borrow.name`：借將成功
  String get achBorrowName => table['ach.borrow.name']!;

  /// `ach.borrow.cond`：第一次借到別人的公牛
  String get achBorrowCond => table['ach.borrow.cond']!;

  /// `ach.popularBull.name`：搶手公牛
  String get achPopularBullName => table['ach.popularBull.name']!;

  /// `ach.popularBull.cond`：自己的公牛被借走 10 次
  String get achPopularBullCond => table['ach.popularBull.cond']!;

  /// `ach.rice.name`：稻香滿倉
  String get achRiceName => table['ach.rice.name']!;

  /// `ach.rice.cond`：累計收成 1,000 公斤稻米
  String get achRiceCond => table['ach.rice.cond']!;

  /// `ach.codex.name.1`：圖鑑新手
  String get achCodexName1 => table['ach.codex.name.1']!;

  /// `ach.codex.cond.1`：發現 5 種牛
  String get achCodexCond1 => table['ach.codex.cond.1']!;

  /// `ach.codex.name.2`：圖鑑達人
  String get achCodexName2 => table['ach.codex.name.2']!;

  /// `ach.codex.cond.2`：發現 12 種牛
  String get achCodexCond2 => table['ach.codex.cond.2']!;

  /// `ach.codex.name.3`：圖鑑大師
  String get achCodexName3 => table['ach.codex.name.3']!;

  /// `ach.codex.cond.3`：發現全部 24 種牛
  String get achCodexCond3 => table['ach.codex.cond.3']!;

  /// `ach.legend.name`：傳說誕生
  String get achLegendName => table['ach.legend.name']!;

  /// `ach.legend.cond`：擁有一頭傳說牛
  String get achLegendCond => table['ach.legend.cond']!;

  /// `ach.level.name.1`：牧場主 Lv 10
  String get achLevelName1 => table['ach.level.name.1']!;

  /// `ach.level.cond.1`：升到 Lv 10
  String get achLevelCond1 => table['ach.level.cond.1']!;

  /// `ach.level.name.2`：牧場主 Lv 20
  String get achLevelName2 => table['ach.level.name.2']!;

  /// `ach.level.cond.2`：升到 Lv 20
  String get achLevelCond2 => table['ach.level.cond.2']!;

  /// `ach.rich.name.1`：小富翁
  String get achRichName1 => table['ach.rich.name.1']!;

  /// `ach.rich.cond.1`：總資產到 100,000 幣
  String get achRichCond1 => table['ach.rich.cond.1']!;

  /// `ach.rich.name.2`：大富翁
  String get achRichName2 => table['ach.rich.name.2']!;

  /// `ach.rich.cond.2`：總資產到 1,000,000 幣
  String get achRichCond2 => table['ach.rich.cond.2']!;

  /// `ach.tailwind.name`：順風車
  String get achTailwindName => table['ach.tailwind.name']!;

  /// `ach.tailwind.cond`：在超級大事件期間賣出東西
  String get achTailwindCond => table['ach.tailwind.cond']!;

  /// `ach.weekChamp.name`：週冠軍
  String get achWeekChampName => table['ach.weekChamp.name']!;

  /// `ach.weekChamp.cond`：本週收入排行榜第 1 名
  String get achWeekChampCond => table['ach.weekChamp.cond']!;

  /// `ach.pureBreed.name`：純種飼育
  String get achPureBreedName => table['ach.pureBreed.name']!;

  /// `ach.pureBreed.cond`：照品種的飼料養大一頭稀有以上的小牛（沒變雜種）
  String get achPureBreedCond => table['ach.pureBreed.cond']!;

  /// `ach.healer.name`：妙手回春
  String get achHealerName => table['ach.healer.name']!;

  /// `ach.healer.cond`：治好一頭病牛
  String get achHealerCond => table['ach.healer.cond']!;

  /// `ach.clean.name`：乾淨牧場
  String get achCleanName => table['ach.clean.name']!;

  /// `ach.clean.cond`：連續 7 天沒有牛生病
  String get achCleanCond => table['ach.clean.cond']!;

  /// `ach.trucks.name`：卡車收藏家
  String get achTrucksName => table['ach.trucks.name']!;

  /// `ach.trucks.cond`：擁有 3 種卡車造型
  String get achTrucksCond => table['ach.trucks.cond']!;
}
