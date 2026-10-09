// v0.3 C1a（協定 2.3、cow-back #181）：小牛的品種、稀有度長大才揭曉（伺服器送 null），雜種牛的品種是 "hybrid"、
// 稀有度照樣送原本的（畫面不顯示）；牛多了 hybrid、need、ate、missed，批次多了 hybrid，economy 多了 hybrid_mult。
// 下面的 JSON 是用 cow-back 的服務層（backend/server/views.py 的 state_view）開一個牧場直接產生的，沒有手改。
import 'dart:convert';

import 'package:cowfarm/api/breeds.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

const _starterCalf =
    '{"id": 2, "type": "dual", "bull": true, "tier": null, "breed": null, "stage": "calf", "born_at": 1791129600.0, '
    '"adult_at": 1791130800.0, "age_h": 0.02, "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 0.0, '
    '"beef_quality": 1.0, "ship_value": 0, "bred": false, "working": false, "field": null, "listed": null, '
    '"can_breed": false, "can_ship": false, "can_work": false, "rice_per_h": 0.0, "grade_probs": null, '
    '"origin": "start", "stud_fee": null, "hybrid": false, "need": [], "ate": [], "missed": [], "feed_bonus_kg": 0.0, '
    '"fed_until": null, "feed_block": null, "poop": 0, "sick": false, "sick_since": null}';

const _hybrid =
    '{"id": 3, "type": "dairy", "bull": false, "tier": 2, "breed": "hybrid", "stage": "adult", "born_at": 1791115260.0, '
    '"adult_at": 1791126060.0, "age_h": 4.0, "milk_per_h": 14.0, "milk_frac": 1.0, "weight_kg": 33.06, '
    '"beef_quality": 1.0, "ship_value": 222, "bred": false, "working": false, "field": null, "listed": null, '
    '"can_breed": true, "can_ship": true, "can_work": false, "rice_per_h": 0.0, '
    '"grade_probs": {"A": 0.146279, "B": 0.490744, "C": 0.362977}, "origin": "A", "stud_fee": null, "hybrid": true, '
    '"need": ["oats", "soy"], "ate": [], "missed": ["oats", "soy"], "feed_bonus_kg": 0.0, "fed_until": null, '
    '"feed_block": null, "poop": 0, "sick": false, "sick_since": null}';

const _rareCalf =
    '{"id": 4, "type": "dairy", "bull": false, "tier": null, "breed": null, "stage": "calf", "born_at": 1791129660.0, '
    '"adult_at": 1791140460.0, "age_h": 0.0, "milk_per_h": 0.0, "milk_frac": 0.0, "weight_kg": 0.0, '
    '"beef_quality": 1.0, "ship_value": 0, "bred": false, "working": false, "field": null, "listed": null, '
    '"can_breed": false, "can_ship": false, "can_work": false, "rice_per_h": 0.0, "grade_probs": null, '
    '"origin": "breed", "stud_fee": null, "hybrid": false, "need": ["oats", "soy"], "ate": ["oats"], "missed": [], '
    '"feed_bonus_kg": 2.0, "fed_until": 1791132360.0, "feed_block": "full", "poop": 0, "sick": false, '
    '"sick_since": null}';

Cow _cow(String j) => Cow.fromJson(jsonDecode(j) as Map<String, dynamic>);

void main() {
  final zh = Strings.forLang(AppLang.zhHant);

  test('小牛：品種、稀有度是 null → 還沒揭曉；照用途畫一般品種、叫「小耕牛 #2」', () {
    final c = _cow(_starterCalf);
    expect(c.revealed, isFalse);
    expect(c.breed, '');
    expect(c.type, CowType.dual);
    expect(c.look, 'yellow', reason: '耕牛的小牛畫台灣黃牛');
    expect(zh.cowLabel(c), zh.calfName(CowType.dual, 2));
    expect(zh.cowLabel(c), '小耕牛 #2');
  });

  test('稀有的小牛：need、ate 照伺服器的（集點卡用）', () {
    final c = _cow(_rareCalf);
    expect(c.revealed, isFalse);
    expect(c.look, 'holstein', reason: '乳牛的小牛畫荷斯坦');
    expect(c.need, ['oats', 'soy']);
    expect(c.ate, ['oats']);
    expect(c.missed, isEmpty);
    expect(zh.cowLabel(c), '小乳牛 #4');
  });

  test('雜種牛：品種 "hybrid"、照用途畫雜種牛的體型、叫「雜種牛 #3」；稀有度照樣有（畫面不顯示）', () {
    final c = _cow(_hybrid);
    expect(c.revealed, isTrue);
    expect(c.hybrid, isTrue);
    expect(c.breed, kHybrid);
    expect(c.tier, 2);
    expect(c.look, 'mixDairy');
    expect(c.missed, ['oats', 'soy']);
    expect(zh.cowLabel(c), '雜種牛 #3');
  });

  test('長大的牛照舊：品種名 #編號', () {
    final c = _cow(
      _hybrid.replaceAll('"breed": "hybrid"', '"breed": "jersey"').replaceAll('"hybrid": true', '"hybrid": false'),
    );
    expect(c.look, 'jersey');
    expect(zh.cowLabel(c), zh.cowName('jersey', 3));
  });

  test('批次的 hybrid、economy.hybrid_mult', () {
    final lot = Lot.fromJson({'qty': 3.5, 'tier': 0, 'hybrid': true, 'collected_at': 1791129600.0});
    expect(lot.hybrid, isTrue);
    expect(Lot.fromJson({'qty': 1, 'tier': 2}).hybrid, isFalse);
    expect(Economy.fromJson({'hybrid_mult': 0.6})!.hybridMult, 0.6);
  });

  test('雜種牛借種：照用途畫體型（lookOf）', () {
    expect(lookOf(kHybrid, CowType.beef), 'mixBeef');
    expect(lookOf('angus', CowType.beef), 'angus');
  });
}
