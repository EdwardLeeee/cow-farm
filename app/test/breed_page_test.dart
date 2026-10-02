// S08 配種（正式畫面）：選牛、機率的狀態、伺服器說不能配、配好以後、借種分頁、窄手機的機率列。
// 畫面狀態本身（S08-01～09、11）在 test/pages/s08_cases.dart。
import 'package:cowfarm/api/models.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/ui/breed/breed_page.dart';
import 'package:cowfarm/ui/kit/kit.dart';
import 'package:cowfarm/ui/screens/stud_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s08_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

AppButton _go(WidgetTester tester) => tester.widget<AppButton>(find.byKey(const Key('breed-go')));

PickCard _card(WidgetTester tester, String key) => tester.widget<PickCard>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadAppAssets);

  testWidgets('選公牛、選母牛 → 機率 → 配種：按鈕換成「已配種」、下面放新小牛、提示出生了', (tester) async {
    Screen.w430.apply(tester);
    final api = BreedApi()..after = bredState();
    final m = await showBreed(tester, AppLang.zhHant, api: api);
    expect(find.text(_zh.pickBoth), findsOneWidget);

    await _tap(tester, 'sire-14');
    expect(m.breedSireKey, '14');
    expect(find.text(_zh.pickBoth), findsOneWidget, reason: '還沒選母牛');
    await _tap(tester, 'dam-3');
    expect(api.calls, contains('preview:14:3'));
    await tester.scrollUntilVisible(find.byKey(const Key('breed-go')), 200, scrollable: breedScrollable);
    expect(find.text('6.25%'), findsNWidgets(2));
    expect(_go(tester).onPressed, isNotNull);

    await tapBreed(tester);
    expect(api.calls, contains('breed:14:3'));
    expect(_go(tester).label, _zh.s08BredBtn);
    expect(_go(tester).onPressed, isNull);
    expect(find.byType(CalfCard), findsOneWidget);
    expect(find.text(_zh.breedDone(cow: _zh.cowName('jersey', 16))), findsOneWidget);
    // 剛配好的那一對還是選好的樣子（捲回上面看）
    await tester.scrollUntilVisible(find.byKey(const Key('sire-14')), -200, scrollable: breedScrollable);
    expect(_card(tester, 'sire-14').on, isTrue);
    expect(_card(tester, 'sire-14').off, isNull);
    expect(_card(tester, 'dam-3').on, isTrue);

    // 換選別的母牛：剛配好的那對不再是選好的；公牛 #14 配過了，要重選
    await _tap(tester, 'dam-7');
    expect(find.byType(CalfCard), findsNothing);
    expect(_card(tester, 'sire-14').off, PickOff.bred);
    expect(_card(tester, 'dam-7').on, isTrue);
    expect(find.text(_zh.pickBoth), findsOneWidget);
    expect(_go(tester).label, _zh.s08BreedBtnFree);
    expect(_go(tester).onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('不能選的牛點了沒反應；選好的再點一次就取消', (tester) async {
    Screen.w430.apply(tester);
    final m = await showBreed(tester, AppLang.zhHant);
    await tester.tap(find.byKey(const Key('sire-5')), warnIfMissed: false);
    await tester.pump();
    expect(m.breedSireKey, isNull, reason: '上架中的公牛不能選');
    await _tap(tester, 'sire-14');
    expect(m.breedSireKey, '14');
    await _tap(tester, 'sire-14');
    expect(m.breedSireKey, isNull);
  });

  testWidgets('機率載入失敗：寫「3 秒後自動再試」，3 秒後自己再抓', (tester) async {
    Screen.w430.apply(tester);
    final api = BreedApi()..fail = true;
    await showBreed(tester, AppLang.zhHant, api: api, sire: '14', dam: '3');
    expect(find.textContaining(_zh.s08ProbFailedRetry(n: 3), findRichText: true), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('preview')), hasLength(1));
    expect(_go(tester).onPressed, isNull);

    api.fail = false;
    await tester.pump(BreedPage.retryAfter);
    await tester.pump();
    await tester.pump();
    expect(api.calls.where((c) => c.startsWith('preview')), hasLength(2));
    expect(find.byKey(const Key('oc-holstein')), findsOneWidget);
  });

  testWidgets('斷線時不抓機率（機率卡寫「連線中…」）；連回來自己抓', (tester) async {
    Screen.w430.apply(tester);
    final api = BreedApi();
    final (m, _, push) = await loadedModel(api: api, connected: false);
    m
      ..setBreedSire('14')
      ..setBreedDam('3')
      ..selectTab(AppTab.breed);
    await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
    await tester.pump();
    expect(api.calls.where((c) => c.startsWith('preview')), isEmpty);
    expect(find.descendant(of: find.byKey(const Key('outcome')), matching: find.text(_zh.connecting)), findsOneWidget);

    push.isConnected = true;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(api.calls, contains('preview:14:3'));
    expect(find.byKey(const Key('oc-holstein')), findsOneWidget);
  });

  testWidgets('伺服器說不能配：原因一個一行（已配種寫那頭牛的名字），牛舍滿了只寫一次；按鈕停用', (tester) async {
    Screen.w430.apply(tester);
    final api = BreedApi(state: breedState(penSlots: 10))
      ..blockers = [
        {'code': 'already_bred', 'cow_id': 3},
        {'code': 'pen_full'},
      ];
    await showBreed(tester, AppLang.zhHant, api: api, sire: '14', dam: '3');
    await tester.scrollUntilVisible(find.byKey(const Key('breed-go')), 200, scrollable: breedScrollable);
    expect(find.text(_zh.s08AlreadyBred(cow: _zh.cowName('holstein', 3))), findsOneWidget);
    expect(find.text(_zh.s08PenFull), findsOneWidget);
    expect(find.byKey(const Key('breed-note-2')), findsNothing);
    expect(_go(tester).onPressed, isNull);
  });

  testWidgets('牛舍滿了：還沒選牛也先提醒，按鈕停用', (tester) async {
    Screen.w430.apply(tester);
    await showBreed(tester, AppLang.zhHant, api: BreedApi(state: breedState(penSlots: 10)));
    await tester.scrollUntilVisible(find.byKey(const Key('breed-go')), 200, scrollable: breedScrollable);
    expect(find.text(_zh.s08PenFull), findsOneWidget);
    expect(_go(tester).onPressed, isNull);
  });

  testWidgets('沒有成年的公牛：放空的框（小公牛不算）；母牛照常列出來', (tester) async {
    Screen.w430.apply(tester);
    final cows = [
      for (final c in designCows())
        if (c['bull'] != true) c,
      designCow(20, 'yellow', bull: true, stage: 'calf'),
    ];
    await showBreed(
      tester,
      AppLang.zhHant,
      api: BreedApi(state: breedState(cows: cows)),
    );
    expect(find.byKey(const Key('no-sire')), findsOneWidget);
    expect(find.text(_zh.noSire), findsOneWidget);
    expect(find.byKey(const Key('dam-row')), findsOneWidget);
  });

  testWidgets('從牛的詳細按「選這頭去配種」：回到自己配種，那頭牛選好了', (tester) async {
    Screen.w430.apply(tester);
    final m = await showBreed(tester, AppLang.zhHant);
    await _tap(tester, 'seg-1');
    expect(m.breedStud, isTrue);
    expect(find.byType(StudView), findsOneWidget);

    m.selectForBreeding(m.state!.cowById('14')!);
    await tester.pump();
    await tester.pump();
    expect(m.breedStud, isFalse);
    expect(find.byType(StudView), findsNothing);
    expect(_card(tester, 'sire-14').on, isTrue);
  });

  testWidgets('機率列的排法：一行放得下照順序排、機率靠右；窄手機放不下的換到下一行（名字留在第一行）', (tester) async {
    Future<RenderOutcomeRow> lay(double width, {required bool wrap}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: OutcomeRowLayout(
                gap: 4,
                wrap: wrap,
                children: const [
                  SizedBox(width: 44, height: 44),
                  SizedBox(width: 80, height: 21),
                  SizedBox(width: 40, height: 22),
                  SizedBox(width: 40, height: 22),
                  SizedBox(width: 50, height: 24),
                ],
              ),
            ),
          ),
        ),
      );
      return tester.renderObject<RenderOutcomeRow>(find.byType(OutcomeRowLayout));
    }

    Offset at(RenderOutcomeRow r, int i) {
      var c = r.firstChild;
      for (var k = 0; k < i; k++) {
        c = r.childAfter(c!);
      }
      return (c!.parentData! as OutcomeRowParentData).offset;
    }

    // 放得下：一行，機率靠右，每個上下置中（行高 44）
    var r = await lay(300, wrap: true);
    expect(r.lineOf, [0, 0, 0, 0, 0]);
    expect(r.size, const Size(300, 44));
    expect(at(r, 1), const Offset(48, 11.5));
    expect(at(r, 4), const Offset(250, 10));
    // 窄手機放不下：標籤、機率換到第二行，機率一樣靠右
    r = await lay(200, wrap: true);
    expect(r.lineOf, [0, 0, 0, 1, 1]);
    expect(r.size, const Size(200, 44 + 24));
    expect(at(r, 3), const Offset(0, 44 + 1));
    expect(at(r, 4), const Offset(150, 44));
    // 不換行（寬度 340 以上）：名字縮（min-width: 0），其他的不縮
    r = await lay(200, wrap: false);
    expect(r.lineOf, [0, 0, 0, 0, 0]);
    expect(at(r, 2), Offset(44 + 4 + (200 - 44 - 40 - 40 - 50 - 16) + 4, 11));
    expect(at(r, 4).dx, 150);
  });

  testWidgets('窄手機（320）英文、泰文：機率列不溢出，名字都在第一行', (tester) async {
    Screen.w320.apply(tester);
    for (final lang in [AppLang.en, AppLang.th]) {
      await showBreed(tester, lang, sire: '14', dam: '3');
      await tester.scrollUntilVisible(find.byKey(const Key('oc-glossBlack')), 200, scrollable: breedScrollable);
      for (final b in ['holstein', 'jersey', 'fluffyHolstein', 'cottonCream', 'glossBlack']) {
        final r = tester.renderObject<RenderOutcomeRow>(
          find.descendant(of: find.byKey(Key('oc-$b')), matching: find.byType(OutcomeRowLayout)),
        );
        expect(r.lineOf.take(2), [0, 0], reason: '$lang $b');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('寬手機（430）繁中：機率列都是一行', (tester) async {
    Screen.w430.apply(tester);
    await showBreed(tester, AppLang.zhHant, sire: '14', dam: '3');
    await tester.scrollUntilVisible(find.byKey(const Key('oc-glossBlack')), 200, scrollable: breedScrollable);
    for (final b in ['holstein', 'jersey', 'fluffyHolstein', 'cottonCream', 'glossBlack']) {
      final r = tester.renderObject<RenderOutcomeRow>(
        find.descendant(of: find.byKey(Key('oc-$b')), matching: find.byType(OutcomeRowLayout)),
      );
      expect(r.lineOf.toSet(), {0}, reason: b);
    }
  });

  test('機率的寫法：不到 10% 兩位小數，其他一位，去掉後面的 0', () {
    expect(outcomePct(0.5), '50%');
    expect(outcomePct(1), '100%');
    expect(outcomePct(0.125), '12.5%');
    expect(outcomePct(0.0625), '6.25%');
    expect(outcomePct(0.05), '5%');
    expect(outcomePct(0.005), '0.5%');
    expect(outcomePct(0.10), '10%');
  });

  test('小牛長大要多久：最短到最長；一樣長只寫一個；時鐘倍率不是 1 寫現實時間', () {
    BreedPreview p(List<double> tiers) => BreedPreview(tierProbs: tiers);
    const grow = [1.0, 2.0, 4.0, 8.0];
    expect(growRangeText(_zh, p([0.5, 0.4375, 0.0625, 0]), grow, 1), _zh.s08HoursRange(a: '1', b: '4'));
    expect(growRangeText(_zh, p([1, 0, 0, 0]), grow, 1), _zh.hours(h: '1'));
    expect(growRangeText(_zh, p([0, 1, 0, 0]), const [], 1), isNull);
    expect(growRangeText(_zh, p([0.5, 0.5, 0, 0]), grow, 144), '${_zh.countdown(25)}–${_zh.countdown(50)}');
  });

  test('不能選的原因：配過種又在田裡的寫「已配種」；小牛寫「小牛」', () {
    Cow cow(Map<String, dynamic> j) => Cow.fromJson(j);
    final now = t0.toDouble();
    expect(pickOff(cow(designCow(2, 'yellow', bull: true, field: 0, bred: true)), now), PickOff.bred);
    expect(pickOff(cow(designCow(2, 'yellow', bull: true, field: 0)), now), PickOff.working);
    expect(pickOff(cow(designCow(5, 'angus', bull: true, listed: 7)), now), PickOff.listed);
    expect(pickOff(cow(designCow(15, 'holstein', stage: 'calf')), now), PickOff.calf);
    expect(pickOff(cow(designCow(3, 'holstein')), now), isNull);
  });
}
