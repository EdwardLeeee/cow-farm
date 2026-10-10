// 24 個品種（協定 1.6；企劃書 4.5）：3 種用途 × 8 種特徵組合。特徵是 3 個位元：1 = A 長毛、2 = B 淡色、4 = C 光澤，
// 稀有度 = 位元數。代號跟 design/m2/src/cow/breeds.js 的 key 一樣；test/breeds_test.dart 讀 breeds.js 比對。
import 'models.dart';

/// 雜種牛的品種代號（D35；圖鑑的第 25 格、頭像）：`state.codex` 的品種、`profile.avatar`、換頭像送的 `breed`。
/// 不算在 24 種的完成度裡。協定 C1（ceo 2026-10-08 核准 cow-back 的提案），cow-back 寫進 protocol.md。
const kHybrid = 'hybrid';

/// 小牛的長相（v0.3 #151，設計稿 cow/calf.js 的 CALF_LOOK）：小牛只有 6 種樣子（用途 × 公母），照用途的一般品種畫；
/// 母小牛的圖已經有蝴蝶結（匯出的素材畫好了）。
const kCalfLook = {CowType.dairy: 'holstein', CowType.dual: 'yellow', CowType.beef: 'angus'};

/// 雜種牛的長相（v0.3 #157，設計稿 cow/breeds.js 的 MIX_LOOK）：照用途三種體型，毛色都是灰褐素色。只有長大的圖。
const kMixLook = {CowType.dairy: 'mixDairy', CowType.dual: 'mixDraft', CowType.beef: 'mixBeef'};

/// 一個品種代號畫哪個圖：雜種牛照用途的體型，其他照品種。
String lookOf(String breed, CowType type) => breed == kHybrid ? kMixLook[type]! : breed;

extension CowLook on Cow {
  /// 這頭牛畫哪個品種的圖：小牛照用途的一般品種（[kCalfLook]），雜種牛照用途的體型（[kMixLook]），其他照品種。
  String get look => !revealed ? kCalfLook[type]! : (hybrid ? kMixLook[type]! : lookOf(breed, type));
}

/// 品種代號，依特徵組合（0–7）排。
const kBreedsByType = <CowType, List<String>>{
  CowType.dairy: [
    'holstein', 'fluffyHolstein', 'jersey', 'cottonCream', 'glossBlack', 'velvetBlack', 'chocolate', 'strawberry', //
  ],
  CowType.dual: ['yellow', 'highland', 'milkTea', 'cottonCandy', 'buffalo', 'shaggyBuffalo', 'honey', 'goldenEar'],
  CowType.beef: ['angus', 'galloway', 'charolais', 'whiteFleece', 'wagyu', 'fluffyWagyu', 'whiteWagyu', 'starry'],
};

/// 圖鑑的順序（企劃書 4.5 的編號 1–24，跟 breeds.js 的 CODEX_ORDER 一樣）。
const kCodexOrder = [
  'holstein', 'fluffyHolstein', 'jersey', 'glossBlack', 'cottonCream', 'velvetBlack', 'chocolate', 'strawberry', //
  'yellow', 'highland', 'milkTea', 'buffalo', 'cottonCandy', 'shaggyBuffalo', 'honey', 'goldenEar', //
  'angus', 'galloway', 'charolais', 'wagyu', 'whiteFleece', 'fluffyWagyu', 'whiteWagyu', 'starry', //
];

/// 一個品種的用途、特徵組合、稀有度。
class BreedInfo {
  const BreedInfo(this.breed, this.type, this.traits);
  final String breed;
  final CowType type;
  final int traits; // 0–7

  int get tier => (traits & 1) + (traits >> 1 & 1) + (traits >> 2 & 1);
  bool get longHair => traits & 1 != 0; // A
  bool get light => traits & 2 != 0; // B
  bool get gloss => traits & 4 != 0; // C
}

/// 品種代號 → 資料；不認得的代號回 null。
BreedInfo? breedInfo(String breed) {
  for (final e in kBreedsByType.entries) {
    final i = e.value.indexOf(breed);
    if (i >= 0) return BreedInfo(breed, e.key, i);
  }
  return null;
}
