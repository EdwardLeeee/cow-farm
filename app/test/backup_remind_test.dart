// S11-05 升到 Lv2 以後提醒備份牧場：慶祝卡（S11-01）按「好」以後跳一次；「之後再說」「現在備份」；
// 只在能登入的建置、還沒備份、這個牧場還沒提醒過的時候出（照牧場分開記在手機上）。畫面本身在 test/pages/s11_cases.dart。
import 'package:cowfarm/app.dart';
import 'package:cowfarm/auth/sign_in.dart';
import 'package:cowfarm/l10n/l10n.dart';
import 'package:cowfarm/state/game_model.dart';
import 'package:cowfarm/state/settings.dart';
import 'package:cowfarm/ui/level/backup_remind.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'pages/page_case.dart';
import 'pages/s03_cases.dart';
import 'pages/s13_cases.dart';

final _zh = Strings.forLang(AppLang.zhHant);

SettingsController _settings([Map<String, String> prefs = const {}]) =>
    SettingsController(MemoryPrefsStore({...swipeHintSeen, ...prefs}), deviceLocales: () => const [Locale('zh', 'TW')]);

/// 設計稿的牧場（#1234）。[signIn] 是 null 就是沒設登入的建置（網頁試玩版）；[links] 是綁定的帳號。
Future<GameModel> _ranch({SignInService? signIn, List<String> links = const []}) => ranchModel(
  state: settingsState(links: links),
  signIn: signIn,
);

void main() {
  setUpAll(loadAppAssets);

  group('要不要提醒', () {
    test('能登入的建置、還沒備份、這個牧場還沒提醒過：Lv2 以上的慶祝卡關掉時提醒（跳過 Lv2 的，Lv3 也算）', () async {
      final m = await _ranch(signIn: FakeSignIn());
      final s = _settings();
      await s.load();
      expect(BackupRemindDialog.shouldRemind(m, s, 2), isTrue);
      expect(BackupRemindDialog.shouldRemind(m, s, 3), isTrue);
      expect(BackupRemindDialog.shouldRemind(m, s, 1), isFalse);
    });

    test('沒設登入的建置（網頁試玩版）、已經備份過、這個牧場提醒過都不出；別的牧場（另一個編號）會再出', () async {
      final s = _settings();
      await s.load();
      expect(BackupRemindDialog.shouldRemind(await _ranch(), s, 2), isFalse, reason: '沒設登入');
      expect(BackupRemindDialog.shouldRemind(await _ranch(signIn: FakeSignIn(), links: ['apple']), s, 2), isFalse);
      final m = await _ranch(signIn: FakeSignIn());
      final seen = _settings({SettingsController.backupRemindKey: '1234'});
      await seen.load();
      expect(BackupRemindDialog.shouldRemind(m, seen, 2), isFalse, reason: '#1234 提醒過了');
      final other = _settings({SettingsController.backupRemindKey: '5678'});
      await other.load();
      expect(BackupRemindDialog.shouldRemind(m, other, 2), isTrue, reason: '提醒過的是別的牧場');
    });
  });

  group('畫面', () {
    /// 牧場剛升到 Lv2、慶祝卡還開著。
    Future<(GameModel, FakeGameApi, MemoryPrefsStore)> show(WidgetTester tester) async {
      Screen.w430.apply(tester);
      final api = FakeGameApi(state: settingsState(), market: ranchMarket());
      final m = await ranchModel(api: api, signIn: FakeSignIn());
      final store = MemoryPrefsStore({...swipeHintSeen});
      final s = SettingsController(store, deviceLocales: () => const [Locale('zh', 'TW')]);
      await s.load();
      m.levelUp = (level: 2, levelAt: 500);
      await tester.pumpWidget(CowFarmApp(model: m, settings: s));
      await tester.pump();
      return (m, api, store);
    }

    testWidgets('Lv2 的慶祝卡按「好」以後跳出來；「之後再說」關掉、記在手機上，下一次升級不再出', (tester) async {
      final (m, api, store) = await show(tester);
      expect(find.byKey(const Key('backup-remind')), findsNothing, reason: '慶祝卡還開著');
      await tester.tap(find.byKey(const Key('level-up-ok')));
      await tester.pump();
      expect(find.byKey(const Key('backup-remind')), findsOneWidget);
      expect(find.text(_zh.s11BackupTitle), findsOneWidget);
      expect(find.text(_zh.s11BackupBody), findsOneWidget);
      await tester.tap(find.byKey(const Key('backup-later')));
      await tester.pump();
      expect(find.byKey(const Key('backup-remind')), findsNothing);
      expect(store.values[SettingsController.backupRemindKey], '1234');
      expect(m.settingsView, isNull, reason: '「之後再說」留在原本的頁面');
      // 再升一級（伺服器的 state）：慶祝卡照樣跳，關掉以後不再提醒
      api.stateJson = {...api.stateJson, 'level': (api.stateJson['level'] as int) + 1};
      await m.refreshState();
      await tester.pump();
      expect(find.byKey(const Key('level-up-ok')), findsOneWidget);
      await tester.tap(find.byKey(const Key('level-up-ok')));
      await tester.pump();
      expect(find.byKey(const Key('backup-remind')), findsNothing, reason: '只出現一次');
    });

    testWidgets('「現在備份」到備份牧場頁（S13-02），也算提醒過', (tester) async {
      final (m, _, store) = await show(tester);
      await tester.tap(find.byKey(const Key('level-up-ok')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('backup-now')));
      await tester.pump();
      await tester.pump();
      expect(m.settingsView, SettingsView.backup);
      expect(find.byKey(const Key('settings-backup')), findsOneWidget);
      expect(find.byKey(const Key('backup-remind')), findsNothing);
      expect(store.values[SettingsController.backupRemindKey], '1234');
    });

    testWidgets('沒設登入的建置（網頁試玩版）：慶祝卡關掉就沒了', (tester) async {
      Screen.w430.apply(tester);
      final m = await _ranch();
      m.levelUp = (level: 2, levelAt: 500);
      await pumpAppIn(tester, m, AppLang.zhHant, prefs: swipeHintSeen);
      await tester.tap(find.byKey(const Key('level-up-ok')));
      await tester.pump();
      expect(find.byKey(const Key('backup-remind')), findsNothing);
      expect(m.backupRemind, isFalse);
    });
  });
}
