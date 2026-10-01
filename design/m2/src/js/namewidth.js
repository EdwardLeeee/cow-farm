// 名字的顯示寬度（D23；ceo 2026-10-01 定的算法，伺服器、app、i18ncheck 都用同一套）：逐個 Unicode 字元算
// - 類別是 Mn、Me、Cf 的算 0：例如泰文的上下標記號（ั ี ่ ้ ์），玩家看到的是一個字。
// - East Asian Width 是 W 或 F 的算 2：中文字和全形符號。
// - 其他算 1：英文字母、數字、泰文的子音和母音。名字總共 2–16。
// 例：「ฟาร์ม」5 個字元，์ 算 0，寬度 4；「晨光河畔牧場」寬度 12。
// W／F 的範圍：Python 3.10 的 unicodedata（Unicode 13.0，跟伺服器一樣）裡已指派的字，漢字區塊補到區塊結尾。
// 這個檔不引用別的檔，node（harness/i18ncheck.mjs）也能直接用。
const ZERO = /[\p{Mn}\p{Me}\p{Cf}]/u;
const WIDE = new RegExp('[' +
  '\u{1100}-\u{115F}\u{231A}-\u{231B}\u{2329}-\u{232A}\u{23E9}-\u{23EC}\u{23F0}\u{23F3}\u{25FD}-\u{25FE}\u{2614}-\u{2615}\u{2648}-\u{2653}\u{267F}\u{2693}' +
  '\u{26A1}\u{26AA}-\u{26AB}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26CE}\u{26D4}\u{26EA}\u{26F2}-\u{26F3}\u{26F5}\u{26FA}\u{26FD}\u{2705}\u{270A}-\u{270B}\u{2728}' +
  '\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2795}-\u{2797}\u{27B0}\u{27BF}\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}\u{2E80}-\u{2E99}\u{2E9B}-\u{2EF3}\u{2F00}-\u{2FD5}' +
  '\u{2FF0}-\u{2FFB}\u{3000}-\u{303E}\u{3041}-\u{3096}\u{3099}-\u{30FF}\u{3105}-\u{312F}\u{3131}-\u{318E}\u{3190}-\u{31E3}\u{31F0}-\u{321E}\u{3220}-\u{3247}' +
  '\u{3250}-\u{4DBF}\u{4E00}-\u{A48C}\u{A490}-\u{A4C6}\u{A960}-\u{A97C}\u{AC00}-\u{D7A3}\u{F900}-\u{FA6D}\u{FA70}-\u{FAD9}\u{FE10}-\u{FE19}\u{FE30}-\u{FE52}' +
  '\u{FE54}-\u{FE66}\u{FE68}-\u{FE6B}\u{FF01}-\u{FF60}\u{FFE0}-\u{FFE6}\u{16FE0}-\u{16FE4}\u{16FF0}-\u{16FF1}\u{17000}-\u{187F7}\u{18800}-\u{18CD5}\u{18D00}-\u{18D08}' +
  '\u{1B000}-\u{1B11E}\u{1B150}-\u{1B152}\u{1B164}-\u{1B167}\u{1B170}-\u{1B2FB}\u{1F004}\u{1F0CF}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F200}-\u{1F202}\u{1F210}-\u{1F23B}' +
  '\u{1F240}-\u{1F248}\u{1F250}-\u{1F251}\u{1F260}-\u{1F265}\u{1F300}-\u{1F320}\u{1F32D}-\u{1F335}\u{1F337}-\u{1F37C}\u{1F37E}-\u{1F393}\u{1F3A0}-\u{1F3CA}' +
  '\u{1F3CF}-\u{1F3D3}\u{1F3E0}-\u{1F3F0}\u{1F3F4}\u{1F3F8}-\u{1F43E}\u{1F440}\u{1F442}-\u{1F4FC}\u{1F4FF}-\u{1F53D}\u{1F54B}-\u{1F54E}\u{1F550}-\u{1F567}' +
  '\u{1F57A}\u{1F595}-\u{1F596}\u{1F5A4}\u{1F5FB}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CC}\u{1F6D0}-\u{1F6D2}\u{1F6D5}-\u{1F6D7}\u{1F6EB}-\u{1F6EC}\u{1F6F4}-\u{1F6FC}' +
  '\u{1F7E0}-\u{1F7EB}\u{1F90C}-\u{1F93A}\u{1F93C}-\u{1F945}\u{1F947}-\u{1F978}\u{1F97A}-\u{1F9CB}\u{1F9CD}-\u{1F9FF}\u{1FA70}-\u{1FA74}\u{1FA78}-\u{1FA7A}' +
  '\u{1FA80}-\u{1FA86}\u{1FA90}-\u{1FAA8}\u{1FAB0}-\u{1FAB6}\u{1FAC0}-\u{1FAC2}\u{1FAD0}-\u{1FAD6}\u{20000}-\u{2FFFD}\u{30000}-\u{3FFFD}' +
  ']', 'u');

export function nameWidth(s) {
  let n = 0;
  for (const ch of s) n += ZERO.test(ch) ? 0 : WIDE.test(ch) ? 2 : 1;
  return n;
}
