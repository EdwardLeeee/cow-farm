// 協定 v2 的資料格式（docs/protocol.md）。欄位名稱全部集中在這個檔案的 fromJson，協定改了只要改這裡。
//
// 時間：伺服器一律用「遊戲時間」的 Unix 秒數（可有小數），另外附 real_time 與 time_scale；名字以 _real 結尾的是現實時間。
// app 只拿來顯示與倒數，不回報任何時間或數量。
// v2 起伺服器不送給玩家看的中文（type_name、新聞 title、排行榜 name…），app 用代碼查字串表（l10n/l10n.dart）。

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

/// 伺服器說「現在不能做」的一個原因（出貨、配種、借種預覽的 blockers[]）：app 用 [code] 查字串表，不顯示 message。
class Blocker {
  const Blocker(this.code, [this.detail = const {}]);
  final String code;
  final Map<String, dynamic> detail;

  factory Blocker.fromJson(Map<String, dynamic> j) => Blocker('${j['code'] ?? ''}', {
    for (final e in j.entries)
      if (e.key != 'code' && e.key != 'message') e.key: e.value,
  });
}

List<Blocker> _blockers(Object? v) =>
    _l(v).map((e) => Blocker.fromJson(_m(e))).where((b) => b.code.isNotEmpty).toList();

// ---------------------------------------------------------------------------
// 共用物件（協定 1.6）
// ---------------------------------------------------------------------------
/// 牧場：排行榜、借種上架的主人、借種紀錄的對方、借種通知的借方。顯示方式見 Strings.ranchName。
class RanchRef {
  const RanchRef({this.playerId, this.name, this.nameWords, this.isBot = false, this.level});
  final int? playerId; // 公營種牛站是 null（不顯示 #編號）
  final String? name; // 真人自己取的名字；電腦是 null
  final List<int>? nameWords; // 電腦牧場名的三組詞編號；真人是 null
  final bool isBot;
  final int? level; // 公營種牛站是 null

  static RanchRef? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    final words = j['name_words'];
    return RanchRef(
      playerId: j['player_id'] is num ? (j['player_id'] as num).toInt() : null,
      name: j['name'] as String?,
      nameWords: words is List && words.length == 3 ? [for (final w in words) _i(w)] : null,
      isBot: _b(j['is_bot']),
      level: j['level'] is num ? (j['level'] as num).toInt() : null,
    );
  }
}

/// 借種費（D26）：公牛現在的體重 × 每公斤價格，四捨五入到 10 幣，跟著公牛長大自動漲。
class StudFee {
  const StudFee({required this.price, required this.perKg, required this.kg, required this.atMax});
  final int price;
  final double perKg;
  final double kg;
  final bool atMax; // 已經長到最壯，不會再漲

  static StudFee? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    return StudFee(price: _i(j['price']), perKg: _d(j['per_kg']), kg: _d(j['kg']), atMax: _b(j['at_max']));
  }
}

enum CowStage { calf, adult, old }

class Cow {
  Cow({
    required this.id,
    required this.type,
    required this.bull,
    required this.tier,
    required this.stage,
    this.breed = '',
    this.ageH,
    this.milkPerH = 0,
    this.weightKg = 0,
    this.shipValue,
    this.adultAt,
    this.bred = false,
    this.fieldIndex,
    this.listedId,
    this.serverCanBreed,
    this.serverCanShip,
    this.serverCanWork,
    this.ricePerH = 0,
    this.gradeProbs,
    this.origin,
    this.studFee,
  });

  /// 伺服器給的原始 id（送回伺服器時原樣送）。畫面顯示「品種名 #id」。
  final Object id;
  final CowType type;
  final bool bull;
  final int tier; // 0 一般、1 優良、2 稀有、3 傳說
  final CowStage stage;

  /// 品種代號（協定 1.6，跟 design/m2/src/cow/breeds.js 的 key 一樣）；名字查字串表。
  final String breed;
  final double? ageH; // 遊戲小時
  final double milkPerH;
  final double weightKg;
  final double? shipValue; // 出貨估值（幣）
  final double? adultAt; // 遊戲時間：長大的時間

  final bool bred; // 這輩子配過種了（借出去也算）
  final int? fieldIndex; // 在第幾塊田工作；null = 沒下田
  final Object? listedId; // 借種市場上架編號；null = 沒上架
  final bool? serverCanBreed; // 伺服器的 can_breed（沒給是 null）
  final bool? serverCanShip;
  final bool? serverCanWork;
  final double ricePerH; // 耕牛下田的話每小時產的稻米（沒下田也給，協定 2.3）
  final Map<String, double>? gradeProbs; // 現在出貨評到 A／B／C 的機率；小牛 null
  final String? origin; // start／A／B／C／breed／stud

  /// 成年、沒配過種的公牛現在的借種費（S04-04 上架前就先顯示）；其他牛 null。
  final StudFee? studFee;

  String get key => '$id';

  /// 畫面上「品種名 #編號」的編號，也拿來挑花色（T3）。
  int get number => id is int ? id as int : int.tryParse('$id') ?? 0;

  bool get working => fieldIndex != null;
  bool get listed => listedId != null;
  bool get busy => working || listed;

  /// 只有母乳牛產奶（v0.2）。
  bool get milker => type == CowType.dairy && !bull;

  bool isAdultAt(double gameNow) => adultAt == null ? stage != CowStage.calf : gameNow >= adultAt!;

  /// 伺服器給的 can_* 為準；沒給時照規則推。
  bool canBreedAt(double gameNow) => serverCanBreed ?? (isAdultAt(gameNow) && !bred && !busy);
  bool canShipAt(double gameNow) => serverCanShip ?? (isAdultAt(gameNow) && !busy);
  bool canWorkAt(double gameNow) => serverCanWork ?? (type == CowType.dual && isAdultAt(gameNow) && !busy);
  bool canListAt(double gameNow) => bull && isAdultAt(gameNow) && !bred && !busy;

  factory Cow.fromJson(Map<String, dynamic> j) {
    final stage = switch (j['stage']) {
      'calf' => CowStage.calf,
      'old' => CowStage.old,
      _ => CowStage.adult,
    };
    return Cow(
      id: j['id'] ?? '?',
      type: CowType.parse(j['type']),
      bull: _b(j['bull']),
      tier: _i(j['tier']).clamp(0, 3),
      stage: stage,
      breed: '${j['breed'] ?? ''}',
      ageH: _dn(j['age_h']),
      milkPerH: _d(j['milk_per_h']),
      weightKg: _d(j['weight_kg']),
      shipValue: _dn(j['ship_value']),
      adultAt: _dn(j['adult_at']),
      bred: _b(j['bred']),
      fieldIndex: j['field'] is num ? (j['field'] as num).toInt() : null,
      listedId: j['listed'],
      serverCanBreed: j['can_breed'] is bool ? j['can_breed'] as bool : null,
      serverCanShip: j['can_ship'] is bool ? j['can_ship'] as bool : null,
      serverCanWork: j['can_work'] is bool ? j['can_work'] as bool : null,
      ricePerH: _d(j['rice_per_h']),
      gradeProbs: j['grade_probs'] is Map ? _gradeMap(j['grade_probs']) : null,
      origin: j['origin'] as String?,
      studFee: StudFee.fromJson(j['stud_fee']),
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

/// 倉庫裡的一批（協定 2.3 的 milk_lots、beef_lots、rice_lots）。
class Lot {
  const Lot({
    required this.qty,
    this.freshness,
    this.tier = 0,
    this.at,
    this.spoilsAt,
    this.cowId,
    this.breed,
    this.grade,
    this.quality,
    this.storageFactor,
  });
  final double qty;
  final double? freshness; // 0–1，只有牛奶有
  final int tier;

  /// 進倉庫的時間（遊戲時間）：牛奶 collected_at、牛肉 shipped_at、稻米 harvested_at。
  final double? at;

  /// 牛奶壞掉的時間（遊戲時間）。
  final double? spoilsAt;

  /// 牛肉：出貨的那頭牛（編號、品種；品種是 null 就只寫編號）。
  final Object? cowId;
  final String? breed;

  /// 牛肉的評級 A／B／C。
  final String? grade;

  /// 稻米：存放折價（0.7–1）；牛肉：評級倍率 × 存放折價。
  final double? quality;

  /// 牛肉的存放折價。
  final double? storageFactor;

  factory Lot.fromJson(Map<String, dynamic> j) => Lot(
    qty: _d(_pick(j, ['qty', 'kg', 'amount'])),
    freshness: _dn(_pick(j, ['freshness', 'fresh'])),
    tier: _i(_pick(j, ['tier'])),
    at: _dn(_pick(j, ['collected_at', 'shipped_at', 'harvested_at'])),
    spoilsAt: _dn(j['spoils_at']),
    cowId: j['cow_id'],
    breed: j['breed'] is String ? j['breed'] as String : null,
    grade: j['grade'] is String ? j['grade'] as String : null,
    quality: _dn(j['quality']),
    storageFactor: _dn(j['storage_factor']),
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

  /// 那種商品的每一批。
  List<Lot> lotsOf(Commodity c) => switch (c) {
    Commodity.milk => milkLots,
    Commodity.beef => beefLots,
    Commodity.rice => riceLots,
  };

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

/// 經濟倍數（協定 2.3 的 economy，直接讀伺服器的 params.py）。**只給畫面顯示**（例 S05「優良牛奶 ×1.3」），
/// app 不能拿來自己算成交價或收入：要價格用 POST /v1/sell/quote、GET /v1/ship/preview。
class Economy {
  const Economy({
    this.tierMult = const [],
    this.beefGradeMult = const {},
    this.oxRicePerH,
    this.dairyMilkPerH,
    this.calfGrowH = const [],
    this.peakWeightKg = const {},
    this.bullWeightMult,
    this.fieldCapH,
  });

  /// 一般、優良、稀有、傳說：牛奶、牛肉的賣價倍率，也是耕牛的稻米產量倍率。
  final List<double> tierMult;

  /// 牛肉評級 A／B／C 的賣價倍率。
  final Map<String, double> beefGradeMult;

  /// 壯年一般耕牛每遊戲小時的稻米公斤數。
  final double? oxRicePerH;

  /// 壯年母乳牛每遊戲小時產幾瓶（再乘年齡曲線；稀有度不影響產量）。
  final double? dairyMilkPerH;

  /// 小牛長大要幾遊戲小時，依稀有度 0–3（S08-06「小牛長大 1–4 小時」）。
  final List<double> calfGrowH;

  /// 母牛的最佳體重，依用途；公牛 = 這個 × [bullWeightMult]。
  final Map<CowType, double> peakWeightKg;
  final double? bullWeightMult;

  /// 一塊田最多存這頭耕牛壯年幾小時的產量（S17「最多存 8 小時的量」）；田的上限 = [oxRicePerH] × 稀有度倍率 × 這個。
  final double? fieldCapH;

  /// 稀有度 [tier] 的倍率；沒有就是 null（畫面不寫倍數）。
  double? tier(int tier) => tier >= 0 && tier < tierMult.length ? tierMult[tier] : null;

  static Economy? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    return Economy(
      tierMult: [
        for (final e in _l(j['tier_mult']))
          if (e is num) e.toDouble(),
      ],
      beefGradeMult: {
        for (final e in _m(j['beef_grade_mult']).entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      oxRicePerH: _dn(j['ox_rice_per_h']),
      dairyMilkPerH: _dn(j['dairy_milk_per_h']),
      calfGrowH: [
        for (final e in _l(j['calf_grow_h']))
          if (e is num) e.toDouble(),
      ],
      peakWeightKg: {
        for (final e in _m(j['peak_weight_kg']).entries)
          if (e.value is num) CowType.parse(e.key): (e.value as num).toDouble(),
      },
      bullWeightMult: _dn(j['bull_weight_mult']),
      fieldCapH: _dn(j['field_cap_h']),
    );
  }
}

/// 場主等級的進度（頂列經驗條）：這一級從 [levelAt] 開始，到 [nextAt] 升級；[earned] 是累積收入。
class LevelProgress {
  const LevelProgress({this.earned = 0, this.levelAt = 0, this.nextAt = 0});
  final double earned;
  final double levelAt;
  final double nextAt;

  /// 這一級走了幾成（0–1）。
  double get fraction => nextAt <= levelAt ? 1 : ((earned - levelAt) / (nextAt - levelAt)).clamp(0.0, 1.0);

  factory LevelProgress.fromJson(Map<String, dynamic> j) =>
      LevelProgress(earned: _d(j['earned']), levelAt: _d(j['level_at']), nextAt: _d(j['next_at']));
}

/// 綁定的帳號（D22；協定 2.3 account.links）。
class AccountLink {
  const AccountLink({required this.provider, this.linkedAtReal});
  final String provider; // apple／google
  final double? linkedAtReal; // 現實時間

  factory AccountLink.fromJson(Map<String, dynamic> j) =>
      AccountLink(provider: '${j['provider'] ?? ''}', linkedAtReal: _dn(j['linked_at_real']));

  /// `account.links`（綁定、解除的回應也是這個形狀，協定 5.2、5.4）。
  static List<AccountLink> listFrom(Object? account) =>
      _l(_m(account)['links']).map((e) => AccountLink.fromJson(_m(e))).toList();
}

/// 綁定時帳號已經綁了別的牧場（協定 5.2 的 409 account_in_use；S13-08「這個帳號已經備份了另一個牧場」）。
/// 玩家選「換回那個牧場」並再確認（S13-09）後，用 [ticket] 打 `POST /v1/account/switch`。
class LinkConflict {
  const LinkConflict({required this.provider, required this.ranch, required this.ticket, this.ticketExpiresAtReal});
  final String provider;
  final RanchRef ranch; // 那個牧場：名字、#編號、等級
  final String ticket; // switch_ticket：10 分鐘內有效、只能用一次
  final double? ticketExpiresAtReal;

  /// 從錯誤的 detail 讀；少了牧場或 ticket 就是 null（當成一般的錯誤）。
  static LinkConflict? fromDetail(Map<String, dynamic> d) {
    final ranch = RanchRef.fromJson(d['ranch']);
    final ticket = d['switch_ticket'];
    if (ranch == null || ticket is! String || ticket.isEmpty) return null;
    return LinkConflict(
      provider: '${d['provider'] ?? ''}',
      ranch: ranch,
      ticket: ticket,
      ticketExpiresAtReal: _dn(d['ticket_expires_at_real']),
    );
  }
}

/// 維護（協定第 6 節）：/v1/status、/v1/state、WS 都用這個形狀；沒有安排維護是 null。
class Maintenance {
  const Maintenance({this.startsAtReal, this.endsAtReal, this.active = false});
  final double? startsAtReal; // 現實時間
  final double? endsAtReal; // 預計恢復（S16-01）；過了也可能還在維護
  final bool active;

  static Maintenance? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    return Maintenance(
      startsAtReal: _dn(j['starts_at_real']),
      endsAtReal: _dn(j['ends_at_real']),
      active: _b(j['active']),
    );
  }
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
    this.codex = const {},
    this.playerId,
    this.ranchName,
    this.levelProgress = const LevelProgress(),
    this.shopGrades = const [],
    this.fields = const [],
    this.rice = const RiceInfo(),
    this.stud = const StudInfo(),
    this.accountLinks = const [],
    this.maintenance,
    this.economy,
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

  /// 圖鑑：發現過的品種 → 第一次發現的遊戲時間（24 種裡沒出現的顯示剪影）。
  final Map<String, double> codex;
  final int? playerId; // 顯示「牧場名 #編號」
  final String? ranchName;
  final LevelProgress levelProgress;
  final List<GradePrice> shopGrades; // 商店各等級價格（機率看 GET /v1/shop）
  final List<FieldInfo> fields;
  final RiceInfo rice;
  final StudInfo stud;

  /// 綁定的帳號；空的代表還沒備份（頂列齒輪的小點 G-10）。
  final List<AccountLink> accountLinks;
  final Maintenance? maintenance;

  /// 經濟倍數（協定 2.3 的 economy）：只給畫面顯示說明數字，帳一律由伺服器算。舊的伺服器沒有，是 null。
  final Economy? economy;

  /// 綁定、解除以後換掉 [accountLinks]（協定 5.2、5.4 的回應只有 account），其他照舊，等下一次 state 校正。
  GameState withAccountLinks(List<AccountLink> links) => GameState(
    serverTime: serverTime,
    realTime: realTime,
    timeScale: timeScale,
    coins: coins,
    level: level,
    cows: cows,
    bucket: bucket,
    warehouse: warehouse,
    pen: pen,
    upgrades: upgrades,
    codex: codex,
    playerId: playerId,
    ranchName: ranchName,
    levelProgress: levelProgress,
    shopGrades: shopGrades,
    fields: fields,
    rice: rice,
    stud: stud,
    accountLinks: links,
    maintenance: maintenance,
    economy: economy,
  );

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
    final ups = _m(j['upgrades']);
    final pen = Pen.fromJson(_m(j['pen']));
    final upgrades = <UpgradeKind, UpgradeInfo>{
      for (final k in UpgradeKind.values)
        if (ups.containsKey(k.wire)) k: UpgradeInfo.fromJson(ups[k.wire]),
    };
    // 擴建的費用與開放時間也寫在 pen 裡。
    upgrades.putIfAbsent(UpgradeKind.pen, () => UpgradeInfo(cost: pen.nextCost, openAt: pen.nextOpenAt));
    final account = _m(j['account']);
    return GameState(
      serverTime: _d(j['server_time']),
      realTime: _d(j['real_time']),
      timeScale: _d(j['time_scale'], 1),
      coins: _d(j['coins']),
      level: _i(j['level'], 1),
      cows: _l(j['cows']).map((e) => Cow.fromJson(_m(e))).toList(),
      bucket: Bucket.fromJson(_m(j['bucket'])),
      warehouse: Warehouse.fromJson(_m(j['warehouse'])),
      pen: pen,
      upgrades: upgrades,
      codex: {
        for (final e in _l(j['codex']))
          if (_m(e)['breed'] is String) _m(e)['breed'] as String: _d(_m(e)['found_at']),
      },
      playerId: j['player_id'] is num ? (j['player_id'] as num).toInt() : null,
      ranchName: j['ranch_name'] as String?,
      levelProgress: LevelProgress.fromJson(_m(j['level_progress'])),
      shopGrades: _l(_m(j['shop'])['grades']).map((e) => GradePrice.fromJson(_m(e))).toList(),
      fields: _l(j['fields']).map((e) => FieldInfo.fromJson(_m(e))).toList(),
      rice: RiceInfo.fromJson(_m(j['rice'])),
      stud: StudInfo.fromJson(_m(j['stud'])),
      accountLinks: AccountLink.listFrom(account),
      maintenance: Maintenance.fromJson(j['maintenance']),
      economy: Economy.fromJson(j['economy']),
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

  /// 經過 [elapsedS] 遊戲秒後田裡大概有多少（長滿就停）。已經比上限多的（叫回稀有耕牛後改派一般耕牛，S17-12）不會再長。
  double riceAfter(double elapsedS) {
    final cap = capacity;
    if (cap != null && rice >= cap) return rice;
    final grown = rice + perHour * (elapsedS > 0 ? elapsedS : 0) / 3600;
    return cap == null || grown < cap ? grown : cap;
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
    cow: j['cow'] is Map ? Cow.fromJson(_m(j['cow'])) : null,
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
  final List<Blocker> blockers; // cow_not_adult、cow_in_field、cow_listed

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
    required this.breed,
    required this.type,
    required this.tier,
    required this.fee,
    this.owner,
    this.isMine = false,
    this.cowId,
    this.listedAt,
  });
  final Object id; // 上架編號（借種、下架用，原樣送回）
  final String breed;
  final CowType type;
  final int tier;
  final StudFee fee; // 借種費，這一刻現算（D26）
  final RanchRef? owner; // 主人；公營種牛站是 player_id null 的電腦牧場
  final bool isMine;
  final Object? cowId; // 主人牧場裡的牛編號；公營種牛站 null
  final double? listedAt;

  String get key => '$id';

  /// 借種費（幣）。
  int get price => fee.price;

  factory StudListing.fromJson(Map<String, dynamic> j) => StudListing(
    id: j['id'] ?? '?',
    breed: '${j['breed'] ?? ''}',
    type: CowType.parse(j['type']),
    tier: _i(j['tier']).clamp(0, 3),
    fee: StudFee.fromJson(j['fee']) ?? const StudFee(price: 0, perKg: 0, kg: 0, atMax: false),
    owner: RanchRef.fromJson(j['owner']),
    isMine: _b(j['is_mine']),
    cowId: j['cow_id'],
    listedAt: _dn(j['listed_at']),
  );
}

/// state.stud：自己上架的、借種收入。
class StudInfo {
  const StudInfo({this.listings = const [], this.income = 0});
  final List<StudListing> listings;
  final double income;

  factory StudInfo.fromJson(Map<String, dynamic> j) =>
      StudInfo(listings: _l(j['listings']).map((e) => StudListing.fromJson(_m(e))).toList(), income: _d(j['income']));
}

/// `GET /v1/stud`：全部上架（便宜的在前）和自己上架的。
class StudMarket {
  const StudMarket({required this.listings, this.mine = const []});
  final List<StudListing> listings;
  final List<StudListing> mine;

  factory StudMarket.fromJson(Map<String, dynamic> j) => StudMarket(
    listings: _l(j['listings']).map((e) => StudListing.fromJson(_m(e))).toList(),
    mine: _l(j['mine']).map((e) => StudListing.fromJson(_m(e))).toList(),
  );
}

/// `GET /v1/stud/log` 借種紀錄（協定 4.6，S18-11）：借出、借入，新的在前，只留最近 [keepDays] 遊戲天。
class StudLog {
  const StudLog({this.keepDays = 30, this.incomeTotal = 0, this.entries = const []});
  final int keepDays;

  /// 借出收入累計（全部時間，= state.stud.income）。
  final double incomeTotal;
  final List<StudLogEntry> entries;

  factory StudLog.fromJson(Map<String, dynamic> j) => StudLog(
    keepDays: _i(j['keep_days'], 30),
    incomeTotal: _d(j['income_total']),
    entries: [for (final e in _l(j['entries'])) StudLogEntry.fromJson(_m(e))],
  );
}

/// 借種紀錄的一筆。
class StudLogEntry {
  const StudLogEntry({
    required this.out,
    required this.time,
    required this.price,
    required this.bullBreed,
    this.bullId,
    this.calfId,
    this.calfBreed,
    this.ranch,
  });

  /// 借出（別人借了我的公牛）；false 是借入（我借別人的公牛）。
  final bool out;

  /// 遊戲時間。
  final double time;

  /// 借出是收到的、借入是付出的（幣）。
  final int price;
  final String bullBreed;

  /// 公牛的編號：只有借出時有（自己牧場的牛，可能已經出貨了）。
  final Object? bullId;

  /// 借入時生下的小牛；借出時 null。
  final Object? calfId;
  final String? calfBreed;

  /// 對方的牧場（含公營種牛站）；對方的牧場已經刪除時是 null（顯示「已刪除的牧場」）。
  final RanchRef? ranch;

  factory StudLogEntry.fromJson(Map<String, dynamic> j) {
    final bull = _m(j['bull']);
    final calf = j['calf'] is Map ? _m(j['calf']) : null;
    return StudLogEntry(
      out: j['kind'] == 'out',
      time: _d(j['t']),
      price: _i(j['price']),
      bullBreed: '${bull['breed'] ?? ''}',
      bullId: bull['id'],
      calfId: calf?['id'],
      calfBreed: calf == null ? null : '${calf['breed'] ?? ''}',
      ranch: RanchRef.fromJson(j['ranch']),
    );
  }
}

// ---------------------------------------------------------------------------
// 帳號
// ---------------------------------------------------------------------------
/// `POST /v1/session` 建立牧場（取好名字才建立，協定 2.1）。
class Session {
  const Session({
    required this.token,
    required this.playerId,
    required this.ranchName,
    this.created = true,
    this.state,
  });
  final String token;
  final int playerId;
  final String ranchName; // 去掉前後空白之後的名字
  final bool created; // 重送同一個 request_id 時是 false
  final GameState? state; // S02-02 的開局牛、金幣、奶桶從這裡拿

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    token: '${j['token']}',
    playerId: _i(j['player_id']),
    ranchName: '${j['ranch_name'] ?? ''}',
    created: j['created'] is bool ? j['created'] as bool : true,
    state: j['state'] is Map ? GameState.fromJson(_m(j['state'])) : null,
  );
}

/// `GET /v1/status`（不用 token）：開機先打，決定要不要顯示維護畫面（協定 6.1）。
class ServerStatus {
  const ServerStatus({this.protocol, this.maintenance, this.realTime});
  final int? protocol;
  final Maintenance? maintenance;

  /// 伺服器的現實時間（Unix 秒）：維護畫面判斷「過了預計恢復的時間」（S16-04）用，不信手機的時鐘。
  final double? realTime;

  factory ServerStatus.fromJson(Map<String, dynamic> j) => ServerStatus(
    protocol: j['protocol'] is num ? (j['protocol'] as num).toInt() : null,
    maintenance: Maintenance.fromJson(j['maintenance']),
    realTime: _dn(j['real_time']),
  );
}

// ---------------------------------------------------------------------------
// 行情
// ---------------------------------------------------------------------------
class Quote {
  const Quote({required this.price, required this.change24h, this.ma24, this.serverPct, this.basePrice, this.ratio});
  final double price;
  final double? serverPct;

  /// 基本價（平常的價）：牛奶 12、牛肉 12、稻米 5。
  final double? basePrice;

  /// 現價 ÷ 基本價。「比平常高／低幾 %」= ratio − 1（D24）。
  final double? ratio;

  /// 24 小時的價格變化（幣，現價減 24 小時前）。畫面的漲跌顏色只看正負號。
  final double change24h;
  final double? ma24;

  /// 比平常（基本價）高或低幾 %，四捨五入到整數（fixtures.js 的 vsBase）；伺服器沒給基本價是 null。只是顯示。
  int? get vsBasePct {
    final r = ratio ?? (basePrice != null && basePrice! > 0 ? price / basePrice! : null);
    return r == null ? null : ((r - 1) * 100).round();
  }

  /// 百分比（0.05 = +5%）。
  double get changePct {
    if (serverPct != null) return serverPct!;
    final before = price - change24h;
    return before.abs() < 1e-9 ? 0 : change24h / before;
  }

  /// WebSocket 每秒推的 market 只有 price、change_24h、change_24h_pct、ma24（協定第 7 節），沒有基本價：
  /// 基本價沿用 [GET /v1/market] 拿到的那一份；ratio 是舊價格算的，不留（改用新價格 ÷ 基本價）。
  Quote mergedOver(Quote? old) => Quote(
    price: price,
    change24h: change24h,
    ma24: ma24 ?? old?.ma24,
    serverPct: serverPct,
    basePrice: basePrice ?? old?.basePrice,
    ratio: basePrice == null ? null : ratio,
  );

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    price: _d(_pick(j, ['price'])),
    change24h: _d(_pick(j, ['change_24h', 'change'])),
    ma24: _dn(_pick(j, ['ma24', 'ma_24h'])),
    serverPct: _dn(j['change_24h_pct']),
    basePrice: _dn(j['base_price']),
    ratio: _dn(j['ratio']),
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

/// 新聞（協定 3.11）：標題由 app 用 [code] 查字串表 `news.<code>`（Strings.newsTitle）。
/// 新聞的級別（D33；協定 `news[].tier`）。舊的伺服器沒有 tier：照 `big` 分一般、大新聞。
enum NewsTier {
  normal('normal'),
  big('big'),

  /// 超級大事件（+100%，收購價變兩倍，只往上）。
  superUp('super'),

  /// 超級黑天鵝（−90%，剩一成，只往下）。
  crash('crash');

  const NewsTier(this.wire);
  final String wire;

  static NewsTier? tryParse(Object? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }

  /// 超級大事件、超級黑天鵝：進行中時在市場的新聞卡變成釘在最上面的大卡（S06-17），牧場頁的提示換顏色（S03-22～24）。
  bool get extreme => this == superUp || this == crash;
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.code,
    this.params = const {},
    this.pct = 0,
    this.commodity,
    this.targets = const [],
    this.up,
    this.big = false,
    this.time,
    this.announceAt,
    this.startAt,
    this.endAt,
    this.upcoming = false,
    this.tier = NewsTier.normal,
    this.ended = false,
  });
  final String id;
  final String code; // 例 milk_up.1、all_down.3
  final Map<String, dynamic> params;

  /// 全幅時讓價格變多少（+0.18 = 漲 18%）。|pct| ≥ 0.2 時牧場頁提示一次（S03-15）。
  final double pct;
  final Commodity? commodity; // 不只一種時是 null（看 targets）
  final List<Commodity> targets;
  final bool? up; // 利多 true／利空 false
  final bool big; // 大事件以上（tier 不是 normal；D33 以前是罕見的大新聞 ±30–40%）
  final double? time; // 遊戲時間（= announceAt）
  final double? announceAt;
  final double? startAt; // 開始影響價格
  final double? endAt;
  final bool upcoming; // 伺服器給的狀態：預告，還沒開始影響價格
  final NewsTier tier;
  final bool ended; // 伺服器給的狀態：已經結束

  /// 在 [gameNow] 時要不要釘在新聞卡最上面（S06-17）：進行中的超級大事件、超級黑天鵝。結束以後回到清單。
  bool pinnedAt(double gameNow) => tier.extreme && !ended && (endAt == null || gameNow < endAt!);

  /// 在 [gameNow] 時是不是還在預告階段（「即將發生 → 進行中」由 app 用 start_at 判斷）。
  bool isUpcomingAt(double gameNow) => startAt != null ? gameNow < startAt! : upcoming;

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
    id: '${j['id'] ?? j['time'] ?? j.hashCode}',
    code: '${j['code'] ?? ''}',
    params: _m(j['params']),
    pct: _d(j['pct']),
    commodity: Commodity.tryParse(j['commodity']),
    targets: _l(j['targets']).map(Commodity.tryParse).whereType<Commodity>().toList(),
    up: j['direction'] == null ? null : j['direction'] == 'up',
    big: _b(j['big']),
    time: _dn(j['time']),
    announceAt: _dn(j['announce_at']),
    startAt: _dn(j['start_at']),
    endAt: _dn(j['end_at']),
    upcoming: j['state'] == 'upcoming',
    tier: NewsTier.tryParse(j['tier']) ?? (_b(j['big']) ? NewsTier.big : NewsTier.normal),
    ended: j['state'] == 'ended',
  );
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
/// 配種／借種前的預覽：小牛各稀有度、各用途、公母的精確機率；借種另外有這一刻的借種費。
class BreedPreview {
  const BreedPreview({
    required this.tierProbs,
    this.fee,
    this.typeProbs = const {},
    this.bullProb,
    this.canBreed = true,
    this.blockers = const [],
    this.distribution = const [],
  });
  final List<double> tierProbs; // 稀有度 0–3
  final StudFee? fee; // 借種費（自己配種免費，是 null）。借種時把 fee.price 原樣送回
  final Map<CowType, double> typeProbs;
  final double? bullProb;
  final bool canBreed; // can_breed／can_borrow
  final List<Blocker> blockers;

  /// 完整分布：每種（用途、公母、特徵組合）的機率（協定 3.7）。畫面一列一個品種，同品種的公母加起來（[byBreed]）。
  final List<OffspringOdds> distribution;

  /// 可能生出的品種和機率：同一個品種的公母兩列加起來；機率大的在前，一樣大的稀有的在前。
  List<({String breed, int tier, double p})> get byBreed {
    final sum = <String, ({String breed, int tier, double p})>{};
    for (final d in distribution) {
      final old = sum[d.breed];
      sum[d.breed] = (breed: d.breed, tier: d.tier, p: (old?.p ?? 0) + d.p);
    }
    return sum.values.toList()..sort((a, b) {
      final byP = b.p.compareTo(a.p);
      if (byP != 0) return byP;
      final byTier = b.tier.compareTo(a.tier);
      return byTier != 0 ? byTier : a.breed.compareTo(b.breed);
    });
  }

  factory BreedPreview.fromJson(Map<String, dynamic> j) {
    final can = j['can_breed'] ?? j['can_borrow'];
    return BreedPreview(
      tierProbs: _tierProbs(j['tier_probs']),
      fee: StudFee.fromJson(j['fee']),
      typeProbs: _typeProbs(j['type_probs']),
      bullProb: _dn(j['bull_prob']),
      canBreed: can is bool ? can : true,
      blockers: _blockers(j['blockers']),
      distribution: [
        for (final e in _l(j['distribution']))
          if (e is Map) OffspringOdds.fromJson(e.cast<String, dynamic>()),
      ],
    );
  }
}

/// 預覽分布的一列（協定 3.5、3.7 的 distribution）：品種、稀有度、用途、公母、機率。
class OffspringOdds {
  const OffspringOdds({
    required this.breed,
    required this.tier,
    required this.type,
    required this.bull,
    required this.p,
  });
  final String breed;
  final int tier;
  final CowType type;
  final bool bull;
  final double p;

  factory OffspringOdds.fromJson(Map<String, dynamic> j) => OffspringOdds(
    breed: '${j['breed'] ?? ''}',
    tier: _i(j['tier']).clamp(0, 3),
    type: CowType.parse(j['type']),
    bull: _b(j['bull']),
    p: _d(j['p']),
  );
}

class BreedResult {
  const BreedResult({this.calf});
  final Cow? calf;

  factory BreedResult.fromJson(Map<String, dynamic> j) {
    final c = _pick(j, ['calf', 'cow']);
    return BreedResult(calf: c is Map ? Cow.fromJson(c.cast<String, dynamic>()) : null);
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
  const RankEntry({required this.rank, required this.score, this.ranch, this.isMe = false});
  final int rank;
  final double score; // 總資產與本週收入是幣，圖鑑是種數
  final RanchRef? ranch; // 每列的等級是 ranch.level
  final bool isMe;

  factory RankEntry.fromJson(Map<String, dynamic> j) =>
      RankEntry(rank: _i(j['rank']), score: _d(j['score']), ranch: RanchRef.fromJson(j['ranch']), isMe: _b(j['is_me']));
}

class Leaderboard {
  const Leaderboard({required this.entries, this.me, this.total, this.weekStartedAtReal, this.nextResetAtReal});
  final List<RankEntry> entries; // 前 50 名
  final RankEntry? me; // 自己的名次（不論在不在前 50）
  final int? total;

  /// kind=weekly 才有：這一週開始、下次重算的現實時間（s12.weeklyHint 依手機時區換算）。
  final double? weekStartedAtReal;
  final double? nextResetAtReal;

  factory Leaderboard.fromJson(Map<String, dynamic> j) => Leaderboard(
    entries: _l(j['entries']).map((e) => RankEntry.fromJson(_m(e))).toList(),
    me: j['me'] is Map ? RankEntry.fromJson(_m(j['me'])) : null,
    total: j['total'] is num ? (j['total'] as num).toInt() : null,
    weekStartedAtReal: _dn(j['week_started_at_real']),
    nextResetAtReal: _dn(j['next_reset_at_real']),
  );
}

// ---------------------------------------------------------------------------
// WebSocket 推播
// ---------------------------------------------------------------------------
sealed class PushMessage {
  const PushMessage();

  /// 伺服器送的訊息（協定第 7 節）；不認得的 type 回 null（要忽略）。
  static PushMessage? fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'hello':
        return HelloPush(protocol: j['protocol'] is num ? (j['protocol'] as num).toInt() : null);
      case 'market':
        final quotes = <Commodity, Quote>{};
        for (final c in Commodity.values) {
          final cj = _m(j[c.wire]);
          if (cj.isNotEmpty) quotes[c] = Quote.fromJson(cj);
        }
        return MarketPush(quotes, _dn(j['server_time']));
      case 'news':
        // v2：新聞的欄位平鋪在訊息裡
        return NewsPush(NewsItem.fromJson(j['news'] is Map ? _m(j['news']) : j));
      case 'stud':
        final cow = _m(j['cow']);
        return StudPush(
          event: '${j['event'] ?? ''}',
          listingId: j['listing_id'],
          cowId: cow['id'],
          breed: cow['breed'] as String?,
          price: _d(j['price']),
          borrower: RanchRef.fromJson(j['borrower']),
        );
      case 'maintenance':
        return MaintenancePush(Maintenance.fromJson(j['maintenance']));
      case 'error':
        return ServerErrorPush('${_m(j['error'])['code'] ?? ''}');
      default:
        return null;
    }
  }
}

/// 連上時一次：協定版本（v2 是 2）。
class HelloPush extends PushMessage {
  const HelloPush({this.protocol});
  final int? protocol;
}

class MarketPush extends PushMessage {
  const MarketPush(this.quotes, this.serverTime);
  final Map<Commodity, Quote> quotes;
  final double? serverTime;
}

/// 有人借了你上架的公牛（你在線時）。G-05「{cow} 借給 {ranch}，收到 {price} 幣」。
class StudPush extends PushMessage {
  const StudPush({required this.event, this.listingId, this.cowId, this.breed, this.price = 0, this.borrower});
  final String event; // borrowed
  final Object? listingId;
  final Object? cowId;
  final String? breed;
  final double price;
  final RanchRef? borrower;
}

/// 安排、改變、取消維護，和開始維護的那一刻（取消時 maintenance 是 null）。
class MaintenancePush extends PushMessage {
  const MaintenancePush(this.maintenance);
  final Maintenance? maintenance;
}

/// 伺服器關閉連線前送的錯誤（unauthorized、signed_in_elsewhere）。
class ServerErrorPush extends PushMessage {
  const ServerErrorPush(this.code);
  final String code;
}

/// WebSocket 的 token 無效（伺服器用關閉碼 4401 關閉）：不要重連。
/// [code] 是關閉前送來的錯誤碼：unauthorized（S15-03）或 signed_in_elsewhere（S14-05）。
class PushAuthFailed extends PushMessage {
  const PushAuthFailed(this.token, [this.code = 'unauthorized']);
  final String token;
  final String code;
}

class NewsPush extends PushMessage {
  const NewsPush(this.item);
  final NewsItem item;
}
