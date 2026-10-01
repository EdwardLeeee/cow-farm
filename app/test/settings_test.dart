// 語言和漲跌顏色的設定（S13；D25）：還沒選過跟著手機和語言，選過以後固定並存起來（ceo 2026-10-02）。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('還沒選過語言：跟著手機，手機換語言也跟著換', () async {
    var device = const [Locale('th', 'TH')];
    final s = SettingsController(MemoryPrefsStore(), deviceLocales: () => device);
    await s.load();
    expect(s.lang, AppLang.th);
    expect(s.chosenLang, isNull);
    var notified = 0;
    s.addListener(() => notified++);
    device = const [Locale('zh', 'TW')];
    s.deviceLocalesChanged();
    expect(s.lang, AppLang.zhHant);
    expect(notified, 1);
  });

  test('選過語言：存起來，下次打開照用；手機換語言也不變', () async {
    final store = MemoryPrefsStore();
    var device = const [Locale('zh', 'TW')];
    final s = SettingsController(store, deviceLocales: () => device);
    await s.load();
    await s.chooseLang(AppLang.en);
    expect(store.values[SettingsController.langKey], 'en');

    final again = SettingsController(store, deviceLocales: () => device);
    await again.load();
    expect(again.lang, AppLang.en);
    var notified = 0;
    again.addListener(() => notified++);
    device = const [Locale('th')];
    again.deviceLocalesChanged();
    expect(again.lang, AppLang.en);
    expect(notified, 0);
  });

  test('漲跌顏色：還沒選過跟著語言，選過以後固定', () async {
    final store = MemoryPrefsStore();
    final s = SettingsController(store, deviceLocales: () => const [Locale('zh', 'TW')]);
    await s.load();
    expect(s.upIsRed, isTrue, reason: '繁中漲紅跌綠');
    await s.chooseLang(AppLang.en);
    expect(s.upIsRed, isFalse, reason: '英文綠漲紅跌');
    await s.chooseUpIsRed(true);
    expect(s.upIsRed, isTrue);
    expect(store.values[SettingsController.upColorKey], 'red');
    await s.chooseLang(AppLang.th);
    expect(s.upIsRed, isTrue, reason: '選過以後不跟著語言變');
  });

  test('存的值看不懂（例如舊版）：當作沒選過', () async {
    final s = SettingsController(
      MemoryPrefsStore({SettingsController.langKey: 'fr'}),
      deviceLocales: () => const [Locale('th')],
    );
    await s.load();
    expect(s.chosenLang, isNull);
    expect(s.lang, AppLang.th);
  });

  testWidgets('app 的語言、字串跟著設定換', (tester) async {
    final (m, _, _) = await loadedModel();
    final settings = SettingsController(MemoryPrefsStore(), deviceLocales: () => const [Locale('zh', 'TW')]);
    await settings.load();
    await tester.pumpWidget(CowFarmApp(model: m, settings: settings));
    await tester.pump();
    final home = tester.element(find.byType(Scaffold).first);
    expect(Strings.of(home, listen: false).lang, AppLang.zhHant);
    expect(Localizations.localeOf(home).languageCode, 'zh');

    await settings.chooseLang(AppLang.th);
    await tester.pump();
    final after = tester.element(find.byType(Scaffold).first);
    expect(Strings.of(after, listen: false).lang, AppLang.th);
    expect(Localizations.localeOf(after).languageCode, 'th');
  });
}
