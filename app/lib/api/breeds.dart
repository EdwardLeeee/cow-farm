// 24 個品種（協定 1.6；企劃書 4.5）：3 種用途 × 8 種特徵組合。特徵是 3 個位元：1 = A 長毛、2 = B 淡色、4 = C 光澤，
// 稀有度 = 位元數。代號跟 design/m2/src/cow/breeds.js 的 key 一樣；test/breeds_test.dart 讀 breeds.js 比對。
import 'models.dart';

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
