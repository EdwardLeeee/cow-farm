// 協定 v1（含 v0.2 新增）的資料格式。欄位名稱全部集中在這個檔案的 fromJson，協定改了只要改這裡。
// 依據：docs/protocol.md（伺服器端負責）。
//
// 時間：伺服器一律用「遊戲時間」的 Unix 秒數（可有小數），另外附 real_time 與 time_scale。
// app 只拿來顯示與倒數，不回報任何時間或數量。

double _d(Object? v, [double def = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? def;
  return def;
}

double? _dn(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _i(Object? v, [int def = 0]) {
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

bool _b(Object? v) => v == true || v == 1 || v == 'true';

Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

List<dynamic> _l(Object? v) => v is List ? v : const [];

/// 第一個存在的欄位值。
Object? _pick(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (j.containsKey(k) && j[k] != null) return j[k];
  }
  return null;
}

// ---------------------------------------------------------------------------
// 牛
// ---------------------------------------------------------------------------
enum CowType {
  dairy('dairy'),
  dual('dual'),
  beef('beef');

  const CowType(this.wire);
  final String wire;

  static CowType parse(Object? v) {
    if (v is num) return CowType.values[v.round().clamp(0, 2)];
    switch (v) {
      case 'dual':
        return CowType.dual;
      case 'beef':
        return CowType.beef;
      default:
        return CowType.dairy;
    }
  }
}

/// 行情商品。v0.2 多了稻米。
enum Commodity {
  milk('milk'),
  beef('beef'),
  rice('rice');

  const Commodity(this.wire);
  final String wire;

  static Commodity? tryParse(Object? v) {
    for (final c in Commodity.values) {
      if (c.wire == v) return c;
    }
    return null;
  }
}

/// 評級（商店等級、出貨肉品評級）：A 最好。
const gradeNames = ['A', 'B', 'C'];

Map<String, double> _gradeMap(Object? v) {
  final j = _m(v);
  return {
    for (final g in gradeNames)
      if (j[g] is num) g: (j[g] as num).toDouble(),
  };
}

Map<CowType, double> _typeProbs(Object? v) {
  final j = _m(v);
  return {
    for (final t in CowType.values)
      if (j[t.wire] is num) t: (j[t.wire] as num).toDouble(),
  };
}

List<double> _tierProbs(Object? raw) {
  final probs = List<double>.filled(4, 0);
  if (raw is List) {
    for (var i = 0; i < raw.length && i < 4; i++) {
      probs[i] = _d(raw[i] is Map ? (raw[i] as Map)['p'] ?? (raw[i] as Map)['prob'] : raw[i]);
    }
  } else if (raw is Map) {
    raw.forEach((k, v) {
      final i = int.tryParse('$k');
      if (i != null && i >= 0 && i < 4) probs[i] = _d(v);
    });
  }
  return probs;
}

/// 伺服器說「現在不能做」的原因（blockers[]），直接顯示 message。
List<String> _blockers(Object? v) =>
    _l(v).map((e) => '${_m(e)['message'] ?? _m(e)['code'] ?? ''}').where((x) => x.isNotEmpty).toList();

enum CowStage { calf, adult, old }

class Cow {
  Cow({
    required this.id,
    required this.type,
    required this.bull,
    required this.tier,
    required this.stage,
    this.ageH,
    this.milkPerH = 0,
    this.weightKg = 0,
    this.shipValue,
    this.adultAt,
    this.readyAt,
    this.bred = false,
    this.fieldIndex,
    this.listedId,
    this.serverCanBreed,
    this.serverCanShip,
    this.serverCanWork,
    this.ricePerH = 0,
    this.gradeProbs,
    this.origin,
  });

  /// 伺服器給的原始 id（送回伺服器時原樣送）。
  final Object id;
  final CowType type;
  final bool bull;
  final int tier; // 0 一般、1 優良、2 稀有、3 傳說
  final CowStage stage;
  final double? ageH; // 遊戲小時
  final double milkPerH;
  final double weightKg;
  final double? shipValue; // 出貨估值（幣）
  final double? adultAt; // 遊戲時間：長大的時間
  final double? readyAt; // v0.1 的配種冷卻；v0.2 固定 = adult_at

  // ---- v0.2 ----
  final bool bred; // 這輩子配過種了（借出去也算）
  final int? fieldIndex; // 在第幾塊田工作；null = 沒下田
  final Object? listedId; // 借種市場上架編號；null = 沒上架
  final bool? serverCanBreed; // 伺服器的 can_breed（沒給是 null）
  final bool? serverCanShip;
  final bool? serverCanWork;
  final double ricePerH; // 在田裡時每小時產稻米
  final Map<String, double>? gradeProbs; // 現在出貨評到 A／B／C 的機率；小牛 null
  final String? origin; // start／A／B／C／breed／stud

  String get key => '$id';

  bool get working => fieldIndex != null;
  bool get listed => listedId != null;
  bool get busy => working || listed;

  /// 只有母乳牛產奶（v0.2）。
  bool get milker => type == CowType.dairy && !bull;

  bool isAdultAt(double gameNow) => adultAt == null ? stage != CowStage.calf : gameNow >= adultAt!;

  /// 伺服器給的 can_* 為準；舊伺服器沒給時照規則推。
  bool canBreedAt(double gameNow) => serverCanBreed ?? (isAdultAt(gameNow) && !bred && !busy);
  bool canShipAt(double gameNow) => serverCanShip ?? (isAdultAt(gameNow) && !busy);
  bool canWorkAt(double gameNow) => serverCanWork ?? (type == CowType.dual && isAdultAt(gameNow) && !busy);
  bool canListAt(double gameNow) => bull && isAdultAt(gameNow) && !bred && !busy;

  factory Cow.fromJson(Map<String, dynamic> j, {double serverTime = 0}) {
    final stageRaw = _pick(j, ['stage']);
    final stage = switch (stageRaw) {
      'calf' || '小牛' => CowStage.calf,
      'old' || '老牛' => CowStage.old,
      _ => CowStage.adult,
    };
    double? readyAt = _dn(_pick(j, ['ready_at', 'breed_ready_at']));
    if (readyAt == null) {
      // 另一種寫法：剩餘冷卻秒數（遊戲時間）。
      final left = _dn(_pick(j, ['breed_cooldown_s', 'breed_cooldown']));
      if (left != null) readyAt = serverTime + left;
    }
    final sex = _pick(j, ['bull', 'sex']);
    return Cow(
      id: _pick(j, ['id', 'cow_id']) ?? '?',
      type: CowType.parse(_pick(j, ['type', 'ctype'])),
      bull: sex is String ? (sex == 'M' || sex == 'male' || sex == 'bull') : _b(sex),
      tier: _i(_pick(j, ['tier', 'rarity'])).clamp(0, 3),
      stage: stage,
      ageH: _dn(_pick(j, ['age_h', 'age'])),
      milkPerH: _d(_pick(j, ['milk_per_h', 'milk_rate'])),
      weightKg: _d(_pick(j, ['weight_kg', 'weight'])),
      shipValue: _dn(_pick(j, ['ship_value', 'value'])),
      adultAt: _dn(_pick(j, ['adult_at'])),
      readyAt: readyAt,
      bred: _b(j['bred']),
      fieldIndex: j['field'] is num ? (j['field'] as num).toInt() : null,
      listedId: j['listed'],
      serverCanBreed: j['can_breed'] is bool ? j['can_breed'] as bool : null,
      serverCanShip: j['can_ship'] is bool ? j['can_ship'] as bool : null,
      serverCanWork: j['can_work'] is bool ? j['can_work'] as bool : null,
      ricePerH: _d(j['rice_per_h']),
      gradeProbs: j['grade_probs'] is Map ? _gradeMap(j['grade_probs']) : null,
      origin: j['origin'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// 牧場狀態
// ---------------------------------------------------------------------------
class Bucket {
  const Bucket({required this.amount, required this.capacity, required this.perHour, this.boostMult, this.boostUntil});
  final double amount; // 瓶，server_time 當下
  final double capacity;
  final double perHour; // 已含新手加倍
  final double? boostMult; // 新手期加倍；結束後 null
  final double? boostUntil; // 遊戲時間

  /// 從 server_time 起經過 [elapsedS] 遊戲秒後，奶桶大概有多少（跨過新手期結束時改用一般產量）。
  double amountAfter(double serverTime, double elapsedS) {
    if (elapsedS <= 0) return amount;
    var produced = perHour * elapsedS / 3600;
    final until = boostUntil, mult = boostMult;
    if (until != null && mult != null && mult > 0) {
      final boosted = (until - serverTime).clamp(0.0, elapsedS);
      produced = perHour * boosted / 3600 + perHour / mult * (elapsedS - boosted) / 3600;
    }
    return (amount + produced).clamp(0.0, capacity < amount ? amount : capacity);
  }

  factory Bucket.fromJson(Map<String, dynamic> j) {
    final boost = _m(j['boost']);
    return Bucket(
      amount: _d(_pick(j, ['amount', 'qty'])),
      capacity: _d(_pick(j, ['capacity', 'cap']), 1),
      perHour: _d(_pick(j, ['per_hour', 'rate_per_h', 'rate'])),
      boostMult: _dn(boost['mult']),
      boostUntil: _dn(boost['until']),
    );
  }
}

class Lot {
  const Lot({required this.qty, this.freshness, this.tier = 0});
  final double qty;
  final double? freshness; // 0–1，只有牛奶有
  final int tier;

  factory Lot.fromJson(Map<String, dynamic> j) => Lot(
    qty: _d(_pick(j, ['qty', 'kg', 'amount'])),
    freshness: _dn(_pick(j, ['freshness', 'fresh'])),
    tier: _i(_pick(j, ['tier'])),
  );
}

class Warehouse {
  const Warehouse({
    required this.milkLots,
    required this.beefLots,
    required this.capacity,
    this.riceLots = const [],
    this.serverMilkTotal,
    this.serverBeefTotal,
    this.serverRiceTotal,
  });
  final List<Lot> milkLots;
  final List<Lot> beefLots;
  final List<Lot> riceLots; // v0.2
  final double? serverRiceTotal;
  final double capacity;
  final double? serverMilkTotal; // 伺服器算的（不含已壞掉的）
  final double? serverBeefTotal;

  double get milkTotal => serverMilkTotal ?? milkLots.fold(0, (a, l) => a + l.qty);
  double get beefTotal => serverBeefTotal ?? beefLots.fold(0, (a, l) => a + l.qty);
  double get riceTotal => serverRiceTotal ?? riceLots.fold(0, (a, l) => a + l.qty);

  double total(Commodity c) => switch (c) {
    Commodity.milk => milkTotal,
    Commodity.beef => beefTotal,
    Commodity.rice => riceTotal,
  };

  /// 最舊一批（新鮮度最低）的新鮮度。
  double? get worstFreshness {
    double? w;
    for (final l in milkLots) {
      if (l.freshness != null && (w == null || l.freshness! < w)) w = l.freshness;
    }
    return w;
  }

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
    milkLots: _l(_pick(j, ['milk', 'milk_lots'])).map((e) => Lot.fromJson(_m(e))).toList(),
    beefLots: _l(_pick(j, ['beef', 'beef_lots'])).map((e) => Lot.fromJson(_m(e))).toList(),
    capacity: _d(_pick(j, ['capacity', 'cap'])),
    riceLots: _l(j['rice_lots']).map((e) => Lot.fromJson(_m(e))).toList(),
    serverMilkTotal: _dn(j['milk_total']),
    serverBeefTotal: _dn(j['beef_total']),
    serverRiceTotal: _dn(j['rice_total']),
  );
}

class Pen {
  const Pen({required this.slots, required this.used, this.nextCost, this.nextOpenAt});
  final int slots;
  final int used;
  final double? nextCost; // null = 已滿級
  final double? nextOpenAt; // 遊戲時間；null = 已開放

  bool get full => used >= slots;

  factory Pen.fromJson(Map<String, dynamic> j) => Pen(
    slots: _i(_pick(j, ['slots'])),
    used: _i(_pick(j, ['used'])),
    nextCost: _dn(_pick(j, ['next_cost', 'cost'])),
    nextOpenAt: _dn(_pick(j, ['next_open_at', 'open_at'])),
  );
}

enum UpgradeKind {
  pen('pen'),
  bucket('bucket'),
  warehouse('warehouse'),
  fresh('fresh'),
  field('field'); // v0.2：開新田

  const UpgradeKind(this.wire);
  final String wire;
}

class UpgradeInfo {
  const UpgradeInfo({this.cost, this.level, this.openAt, this.current, this.next, this.maxLevel});
  final int? maxLevel; // 田地：最多幾塊
  final double? cost; // null = 已滿級
  final int? level;
  final double? openAt; // 遊戲時間；只有擴建有

  /// 升級前後的效果：牛舍格數、奶桶／倉庫容量、冷藏維持新鮮的小時數。
  final double? current;
  final double? next;

  factory UpgradeInfo.fromJson(Object? v) {
    if (v is num) return UpgradeInfo(cost: v.toDouble());
    final j = _m(v);
    return UpgradeInfo(
      cost: _dn(_pick(j, ['cost', 'next_cost'])),
      level: j['level'] == null ? null : _i(j['level']),
      openAt: _dn(_pick(j, ['open_at', 'next_open_at'])),
      current: _dn(_pick(j, ['slots', 'capacity', 'fresh_h', 'count'])),
      next: _dn(_pick(j, ['next_slots', 'next_capacity', 'next_fresh_h'])),
      maxLevel: j['max'] is num ? (j['max'] as num).toInt() : null,
    );
  }
}

/// 圖鑑一格：用途 × 稀有度。
typedef CodexKey = ({CowType type, int tier});

Set<CodexKey> _parseCodex(Object? v) {
  final out = <CodexKey>{};
  if (v is List) {
    for (var i = 0; i < v.length; i++) {
      final e = v[i];
      if (e is Map) {
        final j = e.cast<String, dynamic>();
        out.add((type: CowType.parse(j['type']), tier: _i(j['tier']).clamp(0, 3)));
      } else if (e is String && e.contains(':')) {
        final p = e.split(':');
        out.add((type: CowType.parse(p[0]), tier: _i(p[1]).clamp(0, 3)));
      } else if (e is List && i < 3) {
        // [[bool×4]×3] 矩陣
        for (var t = 0; t < e.length && t < 4; t++) {
          if (_b(e[t])) out.add((type: CowType.values[i], tier: t));
        }
      }
    }
  } else if (v is Map) {
    // {"dairy": [0, 2], ...}
    v.forEach((k, tiers) {
      for (final t in _l(tiers)) {
        out.add((type: CowType.parse(k), tier: _i(t).clamp(0, 3)));
      }
    });
  }
  return out;
}

class GameState {
  GameState({
    required this.serverTime,
    required this.realTime,
    required this.timeScale,
    required this.coins,
    required this.level,
    required this.cows,
    required this.bucket,
    required this.warehouse,
    required this.pen,
    required this.upgrades,
    required this.codex,
    this.calfPrices = const {},
    this.ranchName,
    this.shopGrades = const [],
    this.fields = const [],
    this.rice = const RiceInfo(),
    this.stud = const StudInfo(),
  });

  final double serverTime; // 遊戲時間 Unix 秒
  final double realTime;
  final double timeScale;
  final double coins;
  final int level;
  final List<Cow> cows;
  final Bucket bucket;
  final Warehouse warehouse;
  final Pen pen;
  final Map<UpgradeKind, UpgradeInfo> upgrades;
  final Set<CodexKey> codex;

  /// 商店小牛價格（依用途）；沒給就是 null，畫面不擋錢不夠。
  final Map<CowType, double> calfPrices;
  final String? ranchName;

  // ---- v0.2 ----
  final List<GradePrice> shopGrades; // 商店各等級價格（機率看 GET /v1/shop）
  final List<FieldInfo> fields;
  final RiceInfo rice;
  final StudInfo stud;

  double? calfPrice(CowType t) => calfPrices[t];

  double? gradePrice(String grade) {
    for (final g in shopGrades) {
      if (g.grade == grade) return g.price;
    }
    return null;
  }

  Cow? cowById(String key) {
    for (final c in cows) {
      if (c.key == key) return c;
    }
    return null;
  }

  factory GameState.fromJson(Map<String, dynamic> j) {
    final st = _d(_pick(j, ['server_time']));
    final ups = _m(j['upgrades']);
    final pen = Pen.fromJson(_m(j['pen']));
    final upgrades = <UpgradeKind, UpgradeInfo>{
      for (final k in UpgradeKind.values)
        if (ups.containsKey(k.wire)) k: UpgradeInfo.fromJson(ups[k.wire]),
    };
    // 擴建的費用與開放時間也可能只寫在 pen 裡。
    upgrades.putIfAbsent(UpgradeKind.pen, () => UpgradeInfo(cost: pen.nextCost, openAt: pen.nextOpenAt));
    final shop = _m(j['shop']);
    final rawPrice = _pick(shop, ['calf_price']) ?? j['calf_price'];
    final calfPrices = <CowType, double>{
      for (final t in CowType.values)
        if (rawPrice is num)
          t: rawPrice.toDouble()
        else if (rawPrice is Map && rawPrice[t.wire] is num)
          t: (rawPrice[t.wire] as num).toDouble(),
    };
    return GameState(
      serverTime: st,
      realTime: _d(_pick(j, ['real_time'])),
      timeScale: _d(_pick(j, ['time_scale']), 1),
      coins: _d(_pick(j, ['coins'])),
      level: _i(_pick(j, ['level']), 1),
      cows: _l(j['cows']).map((e) => Cow.fromJson(_m(e), serverTime: st)).toList(),
      bucket: Bucket.fromJson(_m(j['bucket'])),
      warehouse: Warehouse.fromJson(_m(j['warehouse'])),
      pen: pen,
      upgrades: upgrades,
      codex: _parseCodex(j['codex']),
      calfPrices: calfPrices,
      ranchName: _pick(j, ['ranch_name']) as String?,
      shopGrades: _l(shop['grades']).map((e) => GradePrice.fromJson(_m(e))).toList(),
      fields: _l(j['fields']).map((e) => FieldInfo.fromJson(_m(e))).toList(),
      rice: RiceInfo.fromJson(_m(j['rice'])),
      stud: StudInfo.fromJson(_m(j['stud'])),
    );
  }
}

// ---------------------------------------------------------------------------
// v0.2：田地與稻米
// ---------------------------------------------------------------------------
class FieldInfo {
  const FieldInfo({required this.index, this.cowId, this.rice = 0, this.capacity, this.perHour = 0});
  final int index;
  final Object? cowId; // 在這塊田工作的耕牛；空田 null
  final double rice; // server_time 當下田裡長好還沒收的稻米（公斤）
  final double? capacity; // 最多累積多少；空田 null
  final double perHour;

  bool get empty => cowId == null;

  /// 經過 [elapsedS] 遊戲秒後田裡大概有多少（長滿就停）。
  double riceAfter(double elapsedS) {
    final grown = rice + perHour * (elapsedS > 0 ? elapsedS : 0) / 3600;
    final cap = capacity;
    return cap == null || cap < rice ? grown : (grown > cap ? cap : grown);
  }

  factory FieldInfo.fromJson(Map<String, dynamic> j) => FieldInfo(
    index: _i(j['index']),
    cowId: j['cow_id'],
    rice: _d(j['rice']),
    capacity: _dn(j['capacity']),
    perHour: _d(j['per_hour']),
  );
}

class RiceInfo {
  const RiceInfo({this.inFields = 0, this.stock = 0, this.perHour = 0});
  final double inFields;
  final double stock;
  final double perHour;

  factory RiceInfo.fromJson(Map<String, dynamic> j) =>
      RiceInfo(inFields: _d(j['in_fields']), stock: _d(j['stock']), perHour: _d(j['per_hour']));
}

// ---------------------------------------------------------------------------
// v0.2：商店等級抽牛
// ---------------------------------------------------------------------------
class GradePrice {
  const GradePrice({required this.grade, required this.price});
  final String grade;
  final double price;

  factory GradePrice.fromJson(Map<String, dynamic> j) => GradePrice(grade: '${j['grade']}', price: _d(j['price']));
}

/// `GET /v1/shop` 的一個等級：價格與精確機率（伺服器算，app 不寫死）。
class ShopGrade {
  const ShopGrade({
    required this.grade,
    required this.price,
    required this.tierProbs,
    required this.typeProbs,
    required this.bullProb,
  });
  final String grade;
  final double price;
  final List<double> tierProbs;
  final Map<CowType, double> typeProbs;
  final double bullProb;

  factory ShopGrade.fromJson(Map<String, dynamic> j) => ShopGrade(
    grade: '${j['grade']}',
    price: _d(j['price']),
    tierProbs: _tierProbs(j['tier_probs']),
    typeProbs: _typeProbs(j['type_probs']),
    bullProb: _d(j['bull_prob'], 0.5),
  );
}

class ShopInfo {
  const ShopInfo({required this.grades, this.freeSlots});
  final List<ShopGrade> grades;
  final int? freeSlots;

  factory ShopInfo.fromJson(Map<String, dynamic> j) => ShopInfo(
    grades: _l(j['grades']).map((e) => ShopGrade.fromJson(_m(e))).toList(),
    freeSlots: j['free_slots'] is num ? (j['free_slots'] as num).toInt() : null,
  );
}

/// 商店抽到的牛。
class ShopBuyResult {
  const ShopBuyResult({required this.grade, this.cow, this.cost});
  final String grade;
  final Cow? cow;
  final double? cost;

  factory ShopBuyResult.fromJson(Map<String, dynamic> j) => ShopBuyResult(
    grade: '${j['grade'] ?? ''}',
    cow: j['cow'] is Map ? Cow.fromJson(_m(j['cow']), serverTime: _d(j['server_time'])) : null,
    cost: _dn(j['cost']),
  );
}

// ---------------------------------------------------------------------------
// v0.2：出貨評級
// ---------------------------------------------------------------------------
class ShipPreview {
  const ShipPreview({
    required this.gradeProbs,
    this.gradeMult = const {},
    this.valueByGrade = const {},
    this.expectedValue,
    this.weightKg,
    this.canShip = true,
    this.blockers = const [],
  });
  final Map<String, double> gradeProbs;
  final Map<String, double> gradeMult;
  final Map<String, double> valueByGrade;
  final double? expectedValue;
  final double? weightKg;
  final bool canShip;
  final List<String> blockers;

  factory ShipPreview.fromJson(Map<String, dynamic> j) => ShipPreview(
    gradeProbs: _gradeMap(j['grade_probs']),
    gradeMult: _gradeMap(j['grade_mult']),
    valueByGrade: _gradeMap(j['value_by_grade']),
    expectedValue: _dn(j['expected_value']),
    weightKg: _dn(j['weight_kg']),
    canShip: j['can_ship'] is bool ? j['can_ship'] as bool : true,
    blockers: _blockers(j['blockers']),
  );
}

class ShipResult {
  const ShipResult({this.grade, this.gradeProbs = const {}, this.beefQty, this.valueEstimate});
  final String? grade; // 評到的等級
  final Map<String, double> gradeProbs;
  final double? beefQty;
  final double? valueEstimate; // 這批牛肉現在全部賣掉的估計收入

  factory ShipResult.fromJson(Map<String, dynamic> j) {
    final beef = _m(j['beef']);
    return ShipResult(
      grade: (j['grade'] ?? beef['grade']) as String?,
      gradeProbs: _gradeMap(j['grade_probs']),
      beefQty: _dn(beef['qty']),
      valueEstimate: _dn(beef['value_estimate']),
    );
  }
}

// ---------------------------------------------------------------------------
// v0.2：借種市場
// ---------------------------------------------------------------------------
class StudListing {
  const StudListing({
    required this.id,
    required this.price,
    required this.type,
    required this.tier,
    required this.ownerName,
    this.isBot = false,
    this.isMine = false,
    this.cowId,
    this.weightKg,
  });
  final Object id; // 上架編號（借種、下架用，原樣送回）
  final double price;
  final CowType type;
  final int tier;
  final String ownerName; // 電腦假玩家前面有「電腦」
  final bool isBot;
  final bool isMine;
  final Object? cowId; // 主人牧場裡的牛編號；系統上架 null
  final double? weightKg;

  String get key => '$id';

  factory StudListing.fromJson(Map<String, dynamic> j) => StudListing(
    id: j['id'] ?? '?',
    price: _d(j['price']),
    type: CowType.parse(j['type']),
    tier: _i(j['tier']).clamp(0, 3),
    ownerName: '${j['owner_name'] ?? ''}',
    isBot: _b(j['is_bot']),
    isMine: _b(j['is_mine']),
    cowId: j['cow_id'],
    weightKg: _dn(j['weight_kg']),
  );
}

/// state.stud：自己上架的、借種收入、可選價位。
class StudInfo {
  const StudInfo({this.listings = const [], this.income = 0, this.prices = const []});
  final List<StudListing> listings;
  final double income;
  final List<double> prices;

  factory StudInfo.fromJson(Map<String, dynamic> j) => StudInfo(
    listings: _l(j['listings']).map((e) => StudListing.fromJson(_m(e))).toList(),
    income: _d(j['income']),
    prices: _l(j['prices']).map((e) => _d(e)).toList(),
  );
}

/// `GET /v1/stud`。
class StudMarket {
  const StudMarket({required this.listings, this.mine = const [], this.prices = const []});
  final List<StudListing> listings;
  final List<StudListing> mine;
  final List<double> prices;

  factory StudMarket.fromJson(Map<String, dynamic> j) => StudMarket(
    listings: _l(j['listings']).map((e) => StudListing.fromJson(_m(e))).toList(),
    mine: _l(j['mine']).map((e) => StudListing.fromJson(_m(e))).toList(),
    prices: _l(j['prices']).map((e) => _d(e)).toList(),
  );
}

// ---------------------------------------------------------------------------
// 帳號
// ---------------------------------------------------------------------------
class Session {
  const Session({required this.token, required this.playerId, required this.ranchName});
  final String token;
  final String playerId;
  final String ranchName;

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    token: '${j['token']}',
    playerId: '${_pick(j, ['player_id', 'id']) ?? ''}',
    ranchName: '${_pick(j, ['ranch_name']) ?? ''}',
  );
}

// ---------------------------------------------------------------------------
// 行情
// ---------------------------------------------------------------------------
class Quote {
  const Quote({required this.price, required this.change24h, this.ma24, this.serverPct});
  final double price;
  final double? serverPct;

  /// 24 小時的價格變化（幣，現價減 24 小時前）。畫面的漲跌顏色只看正負號。
  final double change24h;
  final double? ma24;

  /// 百分比（0.05 = +5%）。
  double get changePct {
    if (serverPct != null) return serverPct!;
    final before = price - change24h;
    return before.abs() < 1e-9 ? 0 : change24h / before;
  }

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    price: _d(_pick(j, ['price'])),
    change24h: _d(_pick(j, ['change_24h', 'change'])),
    ma24: _dn(_pick(j, ['ma24', 'ma_24h'])),
    serverPct: _dn(j['change_24h_pct']),
  );
}

class PricePoint {
  const PricePoint(this.t, this.price);
  final double t; // 遊戲時間
  final double price;

  static PricePoint? fromJson(Object? v) {
    if (v is List && v.length >= 2) return PricePoint(_d(v[0]), _d(v[1]));
    if (v is Map) {
      final j = v.cast<String, dynamic>();
      return PricePoint(_d(_pick(j, ['t', 'time', 'ts'])), _d(_pick(j, ['price', 'p'])));
    }
    return null;
  }

  static List<PricePoint> listFrom(Object? v) => _l(v).map(PricePoint.fromJson).whereType<PricePoint>().toList();
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    this.commodity,
    this.up,
    this.time,
    this.upcoming = false,
    this.startAt,
  });
  final bool upcoming; // 伺服器給的狀態：預告，還沒開始影響價格
  final double? startAt; // 開始影響價格的遊戲時間

  /// 在 [gameNow] 時是不是還在預告階段（「即將發生 → 進行中」由 app 用 start_at 判斷）。
  bool isUpcomingAt(double gameNow) => startAt != null ? gameNow < startAt! : upcoming;
  final String id;
  final String title;
  final Commodity? commodity; // null = 兩者都受影響
  final bool? up; // 利多 true／利空 false
  final double? time; // 遊戲時間

  factory NewsItem.fromJson(Map<String, dynamic> j) {
    final dir = _pick(j, ['direction', 'up', 'sign']);
    return NewsItem(
      id: '${_pick(j, ['id']) ?? _pick(j, ['time', 't']) ?? j.hashCode}',
      title: '${_pick(j, ['title', 'headline']) ?? ''}',
      commodity: Commodity.tryParse(_pick(j, ['commodity', 'target'])),
      up: dir == null ? null : (dir is num ? dir > 0 : (dir == 'up' || dir == '+' || dir == true)),
      time: _dn(_pick(j, ['time', 't', 'announce_at', 'start_at'])),
      upcoming: j['state'] == 'upcoming',
      startAt: _dn(j['start_at']),
    );
  }
}

class MarketInfo {
  const MarketInfo({required this.quotes, required this.recent, required this.news, this.serverTime});
  final Map<Commodity, Quote> quotes;
  final Map<Commodity, List<PricePoint>> recent; // 最近 24 遊戲小時
  final List<NewsItem> news;
  final double? serverTime;

  MarketInfo copyWith({
    Map<Commodity, Quote>? quotes,
    Map<Commodity, List<PricePoint>>? recent,
    List<NewsItem>? news,
  }) => MarketInfo(
    quotes: quotes ?? this.quotes,
    recent: recent ?? this.recent,
    news: news ?? this.news,
    serverTime: serverTime,
  );

  factory MarketInfo.fromJson(Map<String, dynamic> j) {
    final quotes = <Commodity, Quote>{};
    final recent = <Commodity, List<PricePoint>>{};
    for (final c in Commodity.values) {
      final cj = _m(j[c.wire]);
      if (cj.isEmpty) continue;
      quotes[c] = Quote.fromJson(cj);
      recent[c] = PricePoint.listFrom(_pick(cj, ['history', 'recent', 'series', 'points']));
    }
    return MarketInfo(
      quotes: quotes,
      recent: recent,
      news: _l(j['news']).map((e) => NewsItem.fromJson(_m(e))).toList(),
      serverTime: _dn(j['server_time']),
    );
  }
}

class SellQuote {
  const SellQuote({
    required this.qty,
    required this.avgPrice,
    required this.total,
    required this.marketPrice,
    this.serverWarn,
  });
  final double qty;
  final double avgPrice;
  final double total;
  final double marketPrice;

  /// 伺服器判斷「單量大」（warn_big_order）；沒給就用 app 的門檻。
  final bool? serverWarn;

  /// 均價比市價低幾成（0.1 = 低 10%）。
  double get discount => marketPrice <= 0 ? 0 : 1 - avgPrice / marketPrice;

  factory SellQuote.fromJson(Map<String, dynamic> j) => SellQuote(
    qty: _d(j['qty']),
    avgPrice: _d(_pick(j, ['avg_price'])),
    total: _d(_pick(j, ['total'])),
    marketPrice: _d(_pick(j, ['market_price', 'price'])),
    serverWarn: j['warn_big_order'] is bool ? j['warn_big_order'] as bool : null,
  );
}

class SellResult {
  const SellResult({required this.qty, required this.avgPrice, required this.total, this.priceAfter});
  final double qty;
  final double avgPrice;
  final double total;
  final double? priceAfter;

  factory SellResult.fromJson(Map<String, dynamic> j) => SellResult(
    qty: _d(j['qty']),
    avgPrice: _d(_pick(j, ['avg_price'])),
    total: _d(_pick(j, ['total'])),
    priceAfter: _dn(_pick(j, ['price_after'])),
  );
}

// ---------------------------------------------------------------------------
// 配種
// ---------------------------------------------------------------------------
/// 配種／借種前的預覽：小牛各稀有度、各用途、公母的精確機率，以及費用。
class BreedPreview {
  const BreedPreview({
    required this.tierProbs,
    required this.fee,
    this.typeProbs = const {},
    this.bullProb,
    this.canBreed = true,
    this.blockers = const [],
  });
  final List<double> tierProbs; // 稀有度 0–3
  final double fee; // 自己配種 0；借種是借出價
  final Map<CowType, double> typeProbs;
  final double? bullProb;
  final bool canBreed; // can_breed／can_borrow
  final List<String> blockers;

  factory BreedPreview.fromJson(Map<String, dynamic> j) {
    final can = j['can_breed'] ?? j['can_borrow'];
    return BreedPreview(
      tierProbs: _tierProbs(_pick(j, ['tier_probs', 'probs', 'tiers'])),
      fee: _d(_pick(j, ['price', 'fee', 'cost'])),
      typeProbs: _typeProbs(j['type_probs']),
      bullProb: _dn(j['bull_prob']),
      canBreed: can is bool ? can : true,
      blockers: _blockers(j['blockers']),
    );
  }
}

class BreedResult {
  const BreedResult({this.calf});
  final Cow? calf;

  factory BreedResult.fromJson(Map<String, dynamic> j) {
    final c = _pick(j, ['calf', 'cow']);
    return BreedResult(
      calf: c is Map ? Cow.fromJson(c.cast<String, dynamic>(), serverTime: _d(j['server_time'])) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// 排行榜
// ---------------------------------------------------------------------------
enum RankKind {
  networth('networth'),
  collection('collection'),
  weekly('weekly');

  const RankKind(this.wire);
  final String wire;
}

class RankEntry {
  const RankEntry({required this.rank, required this.name, required this.score, this.isBot = false, this.isMe = false});
  final int rank;
  final String name;
  final double score;
  final bool isBot;
  final bool isMe;

  factory RankEntry.fromJson(Map<String, dynamic> j) => RankEntry(
    rank: _i(j['rank']),
    name: '${_pick(j, ['name', 'ranch_name']) ?? ''}',
    score: _d(_pick(j, ['score', 'value'])),
    isBot: _b(_pick(j, ['is_bot', 'bot'])),
    isMe: _b(_pick(j, ['is_me', 'me'])),
  );
}

class Leaderboard {
  const Leaderboard({required this.entries, this.me});
  final List<RankEntry> entries;
  final RankEntry? me;

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final me = _pick(j, ['me', 'self', 'mine']);
    return Leaderboard(
      entries: _l(_pick(j, ['entries', 'top', 'rows'])).map((e) => RankEntry.fromJson(_m(e))).toList(),
      me: me is Map ? RankEntry.fromJson(me.cast<String, dynamic>()) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// WebSocket 推播
// ---------------------------------------------------------------------------
sealed class PushMessage {
  const PushMessage();

  static PushMessage? fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'market':
        final quotes = <Commodity, Quote>{};
        for (final c in Commodity.values) {
          final cj = _m(j[c.wire]);
          if (cj.isNotEmpty) quotes[c] = Quote.fromJson(cj);
        }
        return MarketPush(quotes, _dn(j['server_time']));
      case 'news':
        final n = j['news'] is Map ? _m(j['news']) : j;
        return NewsPush(NewsItem.fromJson(n));
      case 'stud':
        return StudPush(
          event: '${j['event'] ?? ''}',
          listingId: j['listing_id'],
          cowId: j['cow_id'],
          price: _d(j['price']),
        );
      default:
        return null;
    }
  }
}

class MarketPush extends PushMessage {
  const MarketPush(this.quotes, this.serverTime);
  final Map<Commodity, Quote> quotes;
  final double? serverTime;
}

/// v0.2：有人借了你上架的公牛（你在線時）。
class StudPush extends PushMessage {
  const StudPush({required this.event, this.listingId, this.cowId, this.price = 0});
  final String event; // borrowed
  final Object? listingId;
  final Object? cowId;
  final double price;
}

/// WebSocket 的 token 無效（伺服器用關閉碼 4401 關閉）。app 不要重連，改建立新帳號。
class PushAuthFailed extends PushMessage {
  const PushAuthFailed(this.token);
  final String token;
}

class NewsPush extends PushMessage {
  const NewsPush(this.item);
  final NewsItem item;
}
