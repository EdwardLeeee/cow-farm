// S04 牛的詳細資料：依牛的狀態放的按鈕（叫回、下架、派去田裡、上架）、上架借種的面板（S04-04）、斷線、牛不在了（S04-11）；
// S07 出貨確認（機率和收入是伺服器給的、載入失敗重試、不能出貨）、S20 出貨結果（去市場、好）。
// 另外：Chrome 排一行字的高度（CssLine）、並排按鈕放不下換行（BtnRow）、年齡的寫法。
import 'package:cowfarm/api/game_api.dart';
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/theme/tokens.dart';
import 'package:cowfarm/ui/cow/cow_detail_page.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s04_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _btn(WidgetTester tester, String key) => tester.widget<AppButton>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('出貨（S07 → S20）：機率和各等級收入照伺服器給的；按「確定出貨」才出貨，結果頁按「好」回到清單', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(3)))..after = detailState(detailCow(11));
    final (m, _) = await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    expect(api.calls, contains('ship-preview:3'));
    expect(find.textContaining('2,968', findRichText: true), findsOneWidget);
    expect(find.text(_zh.expectedValue(v: '2,514'), findRichText: true), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('ship:')), isEmpty, reason: '還沒按確定');

    await confirmShip(tester);
    expect(api.calls, contains('ship:3'));
    expect(find.byKey(const Key('ship-result')), findsOneWidget);
    expect(find.text(_zh.s20KgIn(kg: '212'), findRichText: true), findsOneWidget);
    expect(find.text(_zh.s20SellAll(v: '2,968'), findRichText: true), findsOneWidget);
    expect(find.text(_zh.s20TipA), findsOneWidget);
    expect(m.detailCowKey, isNull, reason: '牛出貨了，詳細頁關掉');

    await tester.tap(find.byKey(const Key('ship-result-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship-result')), findsNothing);
    expect(m.tab, AppTab.ranch);
  });

  testWidgets('出貨確認按「取消」不出貨', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(3)));
    await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    await tester.tap(find.byKey(const Key('ship-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship-confirm-dialog')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('ship:')), isEmpty);
  });

  testWidgets('結果頁「去市場」：到市場、選好牛肉', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(3)))
      ..grade = 'C'
      ..after = detailState(detailCow(11));
    final (m, _) = await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    await confirmShip(tester);
    expect(find.text(_zh.s20TipC), findsOneWidget);
    await tester.tap(find.byKey(const Key('ship-go-market')));
    await tester.pumpAndSettle();
    expect(m.tab, AppTab.market);
    expect(m.marketCommodity, Commodity.beef);
  });

  testWidgets('機率載入失敗：不能按確定；重試再拿一次', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(3)))..fail = true;
    await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    expect(find.text(_zh.s07ProbFailed), findsOneWidget);
    expect(_btn(tester, 'ship-confirm').onPressed, isNull);
    api.fail = false;
    await _tap(tester, 'preview-retry');
    expect(find.text(_zh.s07ProbFailed), findsNothing);
    expect(_btn(tester, 'ship-confirm').onPressed, isNotNull);
  });

  testWidgets('伺服器說不能出貨（上架中）：橘字寫原因，不能按確定', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(3)))
      ..blockers = [
        {'code': 'cow_listed', 'message': 'listed'},
      ];
    await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    expect(find.text(_zh.errorText('cow_listed')), findsOneWidget);
    expect(_btn(tester, 'ship-confirm').onPressed, isNull);
  });

  testWidgets('出貨失敗（伺服器拒絕）：跳錯誤提示，還在詳細頁', (tester) async {
    Screen.w390.apply(tester);
    final api = _FailShipApi(state: detailState(detailCow(3)));
    final (m, _) = await showCow(tester, AppLang.zhHant, detailCow(3), api: api);
    await openShip(tester);
    await confirmShip(tester);
    expect(find.byKey(const Key('ship-result')), findsNothing);
    expect(find.text(_zh.errorText('cow_in_field')), findsOneWidget);
    expect(m.detailCowKey, '3');
  });

  testWidgets('耕牛：派去田裡、叫回來都問伺服器', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(2)));
    await showCow(tester, AppLang.zhHant, detailCow(2), api: api);
    await _tap(tester, 'detail-assign');
    expect(api.calls, contains('field-assign:2:null'));

    api.stateJson = detailState(detailCow(2, field: 0));
    final (_, _) = await showCow(tester, AppLang.zhHant, detailCow(2, field: 0), api: api);
    await _tap(tester, 'detail-recall');
    expect(api.calls, contains('field-recall:2'));
  });

  testWidgets('沒有空田：「派去田裡」停用、說明；有空田就能按', (tester) async {
    Screen.w390.apply(tester);
    await showCow(tester, AppLang.zhHant, detailCow(2), freeField: false);
    expect(_btn(tester, 'detail-assign').onPressed, isNull);
    expect(find.text(_zh.s04NoField), findsOneWidget);
  });

  testWidgets('公牛上架（S04-04）：面板寫系統算的借種費；取消就關掉；確定才上架', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(5)));
    await showCow(tester, AppLang.zhHant, detailCow(5), api: api);
    await _tap(tester, 'detail-list');
    expect(find.byKey(const Key('fee-box')), findsOneWidget);
    await _tap(tester, 'list-cancel');
    expect(find.byKey(const Key('fee-box')), findsNothing);
    expect(api.calls.where((c) => c.startsWith('stud-list')), isEmpty);

    await _tap(tester, 'detail-list');
    await _tap(tester, 'list-confirm');
    expect(api.calls, contains('stud-list:5'));
    expect(find.byKey(const Key('fee-box')), findsNothing);
  });

  testWidgets('上架中的公牛：下架用那一筆的上架編號；出貨、配種停用', (tester) async {
    Screen.w390.apply(tester);
    final api = DetailApi(state: detailState(detailCow(5, listed: true)));
    await showCow(tester, AppLang.zhHant, detailCow(5, listed: true), api: api);
    expect(_btn(tester, 'detail-ship').onPressed, isNull);
    expect(_btn(tester, 'detail-breed').onPressed, isNull);
    await _tap(tester, 'detail-unlist');
    expect(api.calls, contains('stud-unlist:7'));
  });

  testWidgets('「選這頭去配種」切到配種頁並選好', (tester) async {
    Screen.w390.apply(tester);
    final (m, _) = await showCow(tester, AppLang.zhHant, detailCow(3));
    await _tap(tester, 'detail-breed');
    expect(m.tab, AppTab.breed);
    expect(m.breedDamKey, '3');
  });

  testWidgets('斷線：按鈕全部停用；連回來恢復', (tester) async {
    Screen.w390.apply(tester);
    final (_, push) = await showCow(tester, AppLang.zhHant, detailCow(5), connected: false);
    for (final k in ['detail-list', 'detail-breed', 'detail-ship']) {
      expect(_btn(tester, k).onPressed, isNull, reason: k);
    }
    push.isConnected = true;
    await tester.pump();
    for (final k in ['detail-list', 'detail-breed', 'detail-ship']) {
      expect(_btn(tester, k).onPressed, isNotNull, reason: k);
    }
  });

  testWidgets('牛不在了（S04-11）：「回牧場」關掉詳細頁', (tester) async {
    Screen.w390.apply(tester);
    final (m, _, _) = await loadedModel(api: DetailApi(state: detailState(detailCow(11))));
    m.openCow('3');
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    await tester.pump();
    expect(find.text(_zh.s04GoneTitle), findsOneWidget);
    await _tap(tester, 'gone-back');
    expect(m.detailCowKey, isNull);
  });

  test('年齡：不到 1 小時寫分，不到 1 天寫時分，其他寫天時', () {
    expect(ageText(_zh, 18 * 60), _zh.duration(m: 18));
    expect(ageText(_zh, 20), _zh.duration(m: 1));
    expect(ageText(_zh, 3 * 3600 + 20 * 60), _zh.duration(h: 3, m: 20));
    expect(ageText(_zh, (2 * 24 + 5) * 3600 + 59 * 60), _zh.duration(d: 2, h: 5));
  });

  test('Chrome 排一行字：大小不同的字放同一行，行高照 Chrome 算', () {
    // .kv .v：17px、行高 22，小字 12px：Chrome 是 25 高、基線在 18
    final kv = AppText.number(17, lineHeight: 22);
    expect(
      CssLine.metrics(
        TextSpan(
          style: kv,
          children: [
            const TextSpan(text: '14 '),
            TextSpan(text: '瓶／時', style: AppText.style(12, lineHeight: 22)),
          ],
        ),
      ),
      (18.0, 7.0),
    );
    expect(CssLine.metrics(TextSpan(text: '2 天', style: kv)), (18.0, 4.0));
    // .fee-top 的大字：30px、行高 34
    expect(CssLine.metrics(TextSpan(text: '870', style: AppText.number(30, lineHeight: 34))), (30.0, 4.0));
  });

  testWidgets('並排的按鈕：放得下平分；有一顆比平分寬就照它的寬；兩顆加起來放不下就上下排', (tester) async {
    Future<List<Rect>> layout(double width, List<String> labels) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: BtnRow(
                  children: [for (final (i, l) in labels.indexed) AppButton(l, key: Key('b$i'), onPressed: () {})],
                ),
              ),
            ),
          ),
        ),
      );
      return [for (var i = 0; i < labels.length; i++) tester.getRect(find.byKey(Key('b$i')))];
    }

    var r = await layout(300, ['A', 'B']);
    expect(r[0].width, 145);
    expect(r[1].left, 155);
    expect(r[0].top, r[1].top);

    r = await layout(300, ['A', 'Medium long label']);
    expect(r[0].top, r[1].top, reason: '一排放得下');
    expect(r[1].width, greaterThan(145));
    expect(r[0].width + 10 + r[1].width, 300);

    r = await layout(200, ['First label', 'Second label']);
    expect(r[1].top, greaterThan(r[0].bottom), reason: '上下排');
    expect(r[0].width, 200);
    expect(r[1].width, 200);
  });
}

/// 出貨時伺服器說牛在田裡（別的手機剛派下田）。
class _FailShipApi extends DetailApi {
  _FailShipApi({required super.state});

  @override
  Future<ShipResult> ship(Object cowId) async {
    calls.add('ship:$cowId');
    throw const ApiException(409, 'cow_in_field', 'cow is in a field');
  }
}
