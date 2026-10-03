// S13 設定（設計稿 s13.js 的 settings、S13-17 語言、S13-18 漲跌顏色）。頂列的齒輪打開；整頁，沒有頂列和分頁列。
// 備份牧場（S13-02 以後）在 backup_page.dart，刪除牧場（S13-03）在 delete_page.dart。
// - 「備份牧場」那一列（S13-01、S13-10）只在設好 Apple／Google 登入的建置顯示（GameModel.canSignIn；ceo 2026-10-03），
//   網頁試玩版、沒設 client ID 的建置沒有。
// - 「隱私權政策」先不顯示：網頁 M5 才有，網址填好以後再加，用瀏覽器打開（ceo 2026-10-03，不放按了沒反應的列）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../../version.dart';
import '../kit/app_icon.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/page_head.dart';
import '../kit/press.dart';
import 'backup_page.dart';
import 'delete_page.dart';
import 'settings_kit.dart';

/// 設定：照 [GameModel.settingsView] 顯示設定主頁、語言、備份牧場或刪除牧場。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => switch (context.watch<GameModel>().settingsView) {
    SettingsView.language => const LanguagePage(),
    SettingsView.backup when context.read<GameModel>().canSignIn => const BackupPage(),
    SettingsView.delete => const DeletePage(),
    _ => const SettingsHome(),
  };
}

/// 語言名稱：每種語言都用自己的文字寫，不翻譯（s13.js 的 LANGS）。
String langName(AppLang lang) => switch (lang) {
  AppLang.zhHant => '繁體中文',
  AppLang.en => 'English',
  AppLang.th => 'ไทย',
};

/// 牧場卡的第二行：「#1234・Lv 4」。
String ranchMeta(Strings s, GameModel m) {
  final st = m.state;
  final tag = Strings.ranchTag(RanchRef(playerId: st?.playerId));
  final lv = s.level(lv: st?.level ?? 1);
  return tag == null ? lv : '$tag${s.gSep}$lv';
}

/// 設定頁共用的外框：頁首（返回、標題）加可以捲的內容（.content 的 padding 4 12 16，.stack 每塊隔 12）。
class SettingsFrame extends StatelessWidget {
  const SettingsFrame({
    super.key,
    required this.title,
    required this.children,
    this.overlays = const [],
    this.scrollKey,
    this.bottomInset = 0,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> overlays;
  final Key? scrollKey;

  /// 內容下面多留的空間（鍵盤蓋住的部分）。
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    // 斷線（S15-01）：沒有頂列，「連線中…」放在標題那一列的右邊（S13-20，#126）
    final offline = m.state != null && !m.online && m.maintenance == null && m.authLost == null;
    return AppFrame(
      hud: false,
      offlinePill: false,
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        key: scrollKey,
        padding: EdgeInsets.fromLTRB(12, 4, 12, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(
              title: title,
              onBack: m.settingsBack,
              action: offline ? const OfflinePill() : null,
              actionFixed: true,
            ),
            for (final c in children) ...[const SizedBox(height: AppSizes.gap), c],
          ],
        ),
      ),
      overlays: overlays,
    );
  }
}

/// S13-01 設定主頁。
class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  /// 漲跌顏色的面板（S13-18）開著。
  bool _upDown = false;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final settings = context.watch<SettingsController>();
    final s = Strings.of(context);
    final backed = m.accountLinks.isNotEmpty;
    const chevron = AppIcon('chevron', size: 18);
    return SettingsFrame(
      title: s.s13Title,
      scrollKey: const Key('settings'),
      overlays: [if (_upDown) UpDownSheet(onClose: () => setState(() => _upDown = false))],
      children: [
        MeCard(name: m.ranchName, meta: ranchMeta(s, m)),
        SetGroup(
          rows: [
            SetRow(
              key: const Key('set-sound'),
              icon: 'sound',
              label: s.s13Sound,
              trailing: SetToggle(on: settings.soundOn),
              toggled: settings.soundOn,
              onTap: () => settings.setSoundOn(!settings.soundOn),
            ),
            SetRow(
              key: const Key('set-lang'),
              icon: 'globe',
              label: s.s13Language,
              trailing: SetValue(langName(settings.lang)),
              semanticsLabel: '${s.s13Language} ${langName(settings.lang)}',
              onTap: () => m.openSettingsView(SettingsView.language),
            ),
            SetRow(
              key: const Key('set-updown'),
              icon: 'updown',
              label: s.s13Updown,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UpDownSample(upIsRed: settings.upIsRed, up: '▲${s.s13Up}', down: '▼${s.s13Down}'),
                  const SizedBox(width: 4),
                  chevron,
                ],
              ),
              semanticsLabel: '${s.s13Updown} ${settings.upIsRed ? s.s13RedUp : s.s13GreenUp}',
              onTap: () => setState(() => _upDown = true),
            ),
          ],
        ),
        SetGroup(
          key: const Key('set-account'),
          rows: [
            if (m.canSignIn)
              SetRow(
                key: const Key('set-backup'),
                icon: 'backup',
                label: s.s13BackupTitle,
                sub: s.s13BackupSub,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BackupBadge(backed: backed),
                    const SizedBox(width: 4),
                    chevron,
                  ],
                ),
                semanticsLabel: '${s.s13BackupTitle} ${backed ? s.s13Backed : s.s13NotBacked}',
                onTap: () => m.openSettingsView(SettingsView.backup),
              ),
            SetRow(
              key: const Key('set-delete'),
              icon: 'trash',
              label: s.s13Delete,
              danger: true,
              trailing: chevron,
              onTap: () => m.openSettingsView(SettingsView.delete),
            ),
          ],
        ),
        SetGroup(
          rows: [
            SetRow(
              key: const Key('set-version'),
              icon: 'info',
              label: s.s13Version,
              trailing: const SetValue(appVersion, chevron: false),
            ),
          ],
        ),
        Text(
          s.s13Footer(game: s.appTitle),
          textAlign: TextAlign.center,
          style: KitText.hint(),
        ),
      ],
    );
  }
}

/// S13-18 漲跌顏色：兩個選項（漲紅跌綠、綠漲紅跌），選中的淡黃底加勾。點一個就換、面板收起來。
class UpDownSheet extends StatelessWidget {
  const UpDownSheet({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = Strings.of(context);
    void pick(bool red) {
      settings.chooseUpIsRed(red);
      onClose();
    }

    return AppSheet(
      title: s.s13Updown,
      onClose: onClose,
      children: [
        _UpDownOption(
          key: const Key('ud-red'),
          on: settings.upIsRed,
          title: s.s13RedUp,
          hint: s.s13RedUpHint,
          upIsRed: true,
          onTap: () => pick(true),
        ),
        const SizedBox(height: 10),
        _UpDownOption(
          key: const Key('ud-green'),
          on: !settings.upIsRed,
          title: s.s13GreenUp,
          hint: s.s13GreenUpHint,
          upIsRed: false,
          onTap: () => pick(false),
        ),
        const SizedBox(height: 10),
        Text(s.s13UdNote, style: KitText.hint()),
      ],
    );
  }
}

/// .card.ud-opt：一個漲跌顏色的選項（名稱、說明、兩行樣本；選中的淡黃底、右邊一個勾）。
class _UpDownOption extends StatelessWidget {
  const _UpDownOption({
    super.key,
    required this.on,
    required this.title,
    required this.hint,
    required this.upIsRed,
    required this.onTap,
  });

  final bool on;
  final String title;
  final String hint;
  final bool upIsRed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      child: Pressable(
        lift: 4,
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFFF1B8) : AppColors.paper,
              border: Border.all(color: AppColors.ink, width: AppSizes.border),
              borderRadius: const BorderRadius.all(AppRadii.r18),
              boxShadow: AppShadows.solid(look.shadow),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.style(16, weight: FontWeight.w700, lineHeight: 21)),
                      Text(hint, strutStyle: kDivStrut, style: KitText.hint()),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                UpDownSample(
                  upIsRed: upIsRed,
                  up: '▲ ${s.s06VsHigher(pct: '12%')}',
                  down: '▼ ${s.s06VsLower(pct: '7%')}',
                  big: true,
                ),
                if (on) ...[const SizedBox(width: 10), const AppIcon('ok', size: 24)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S13-17 語言：繁體中文、English、ไทย，現在的語言打勾。點一個馬上換，留在這一頁。
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = Strings.of(context);
    return SettingsFrame(
      title: s.s13Language,
      scrollKey: const Key('settings-lang'),
      children: [
        SetGroup(
          rows: [
            for (final lang in AppLang.values)
              SetRow(
                key: Key('lang-${lang.code}'),
                label: langName(lang),
                labelSize: 17,
                trailing: lang == settings.lang ? const AppIcon('ok', size: 24) : null,
                selected: lang == settings.lang,
                onTap: () => settings.chooseLang(lang),
              ),
          ],
        ),
        Text(s.s13LangHint, style: KitText.hint()),
      ],
    );
  }
}
