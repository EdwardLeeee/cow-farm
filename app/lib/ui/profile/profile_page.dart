// S21 牧場資料（D34；設計稿 s21.js、screens.css 的 .prof-card、.ach-*）。點頂列的頭像打開；整頁，沒有頂列和分頁列。
// - 牧場卡：大頭像（右下角小鉛筆）、牧場名（鉛筆加箭頭）、「#1234・Lv 4」。點頭像換頭像（S21-02，avatar_sheet.dart），
//   點牧場名進改名頁（S21-04，rename_page.dart）；改好、換好了在這一頁跳提示（S21-09、S21-10）。
// - 成就徽章：伺服器給的 `state.achievements`（協定 2.3 節）。舊的伺服器沒有，就不放這張卡。
//   點一個徽章打開詳細（S21-11 已解鎖、S21-12 還沒解鎖、S21-13 分階段）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../breed/stud_log_page.dart' show logWhen;
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/frame.dart' show HudEdit;
import '../kit/kit.dart';
import '../kit/meter.dart';
import '../kit/press.dart';
import '../settings/settings_page.dart' show SettingsFrame, ranchMeta;
import '../widgets/action_button.dart' show actionErrorTextWith;
import 'avatar_sheet.dart';
import 'rename_page.dart';

/// 徽章的圖示和解鎖以後的底色（設計稿 s21.js 的 BADGES 的 ic、bg）。
/// - 圖示是 AppIcon 的名字；`tab_market_on` 是分頁列的市場圖示（固定 28，設計稿的 tabIcon），`txt:` 開頭的畫字。
/// - 底色 null 的：分階段的照解鎖到的階段（[tierColor]），傳說是漸層（[_legendBg]）。
/// 伺服器給的 key 不在這裡的不放：app 還沒有它的圖和字（也不算在「已解鎖 n / 總數」裡）。
const badgeLooks = <String, (String, Color?)>{
  'firstMilk': ('pail', Color(0xFFA9DBFF)),
  'firstSale': ('tab_market_on', Color(0xFFBDE8A6)),
  'firstShip': ('box', Color(0xFFFFC2B6)),
  'gradeA': ('txt:A', Color(0xFFFFC98A)),
  'newLife': ('sprout', Color(0xFFCFEFC4)),
  'borrow': ('transfer', Color(0xFFFFD0DE)),
  'popularBull': ('bull', Color(0xFFFFD0DE)),
  'rice': ('rice', Color(0xFFBDE8A6)),
  'codex': ('book', null),
  'legend': ('star', null),
  'level': ('txt:Lv', null),
  'rich': ('coins', null),
  'tailwind': ('news', Color(0xFFFFE98F)),
  'weekChamp': ('trophy', Color(0xFFFFD45E)),
  'pureBreed': ('leaf', Color(0xFFCFEFC4)),
  'healer': ('heart', Color(0xFFFFD0DE)),
  'clean': ('sparkle', Color(0xFFD5EBFF)),
  'trucks': ('truck', Color(0xFFFFC2B6)),
};

/// 傳說誕生的底色：135 度、#FFE27A 到 #FFC4D6。正方形裡 135 度的漸層線就是左上到右下的對角線。
const _legendBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFE27A), Color(0xFFFFC4D6)],
);

/// 分階段的第 [i] 階（從 0 開始，共 [n] 階）的顏色：三階是銅、銀、金，兩階是銀、金（跟排行榜的獎牌同色）。
Color tierColor(int i, int n) =>
    const [Color(0xFFF2C29B), Color(0xFFE3E7EE), Color(0xFFFFD45E)][(i + 3 - n).clamp(0, 2)];

/// 認得的徽章（照伺服器給的順序）。
List<Achievement> knownBadges(List<Achievement> all) => [
  for (final a in all)
    if (badgeLooks.containsKey(a.key)) a,
];

/// 徽章的名稱：分階段的照現在的階段（還沒解鎖的寫第一階）。
String badgeName(Strings s, Achievement a) =>
    a.staged ? s.achName(a.key, tier: a.tierAt.clamp(1, a.tiers.length)) : s.achName(a.key);

/// S21-01 牧場資料。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 打開詳細的徽章（S21-11～13）。
  String? _detail;

  /// 換頭像的面板開著（S21-02）。
  bool _avatarOpen = false;
  final _avatarSheet = GlobalKey<AvatarSheetState>();

  /// 下面的提示（改好名字、換好頭像、失敗）。
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _setAvatar(String breed) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await m.setAvatar(breed);
    if (!mounted) return;
    switch (r.error) {
      case null:
        setState(() => _avatarOpen = false);
        _showToast(ToastKind.ok, s.s21AvatarDone);
      case ApiActionError(:final error) when error.code == 'avatar_locked':
        _avatarSheet.currentState?.showLocked(breed);
      case ApiActionError(:final error) when error.maintenance || error.unauthorized:
        break; // 整個畫面會換成 S16-01／S15-03
      case final ActionError e:
        _showToast(ToastKind.err, actionErrorTextWith(s, m, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state;
    if (m.renameOpen) {
      return RenamePage(onRenamed: () => _showToast(ToastKind.ok, s.s21RenamedFirst(price: fmt(renamePrice(m)))));
    }
    final badges = knownBadges(st?.achievements ?? const []);
    final detail = badges.where((a) => a.key == _detail).firstOrNull;
    final avatar = st?.profile.avatarBreed ?? 'holstein';
    final safe = MediaQuery.paddingOf(context);
    return SettingsFrame(
      title: s.s21Title,
      scrollKey: const Key('profile'),
      onBack: m.closeProfile,
      overlays: [
        if (detail != null) BadgeSheet(achievement: detail, onClose: () => setState(() => _detail = null)),
        if (_avatarOpen)
          AvatarSheet(
            key: _avatarSheet,
            current: avatar,
            found: st?.codex.keys.toSet() ?? const {},
            busy: m.busy,
            onUse: _setAvatar,
            onClose: () => setState(() => _avatarOpen = false),
          ),
        // .no-tab .toast：下面留安全區加 16
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: safe.bottom + 16,
            child: Center(
              child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
            ),
          ),
      ],
      children: [
        ProfileCard(
          breed: avatar,
          name: m.ranchName,
          meta: ranchMeta(s, m),
          onAvatar: () => setState(() => _avatarOpen = true),
          onName: m.openRename,
        ),
        if (badges.isNotEmpty) BadgeCard(badges: badges, onOpen: (a) => setState(() => _detail = a.key)),
      ],
    );
  }
}

/// .card.prof-card：大頭像、牧場名（鉛筆加箭頭）、「#1234・Lv 4」（內距 12 12 12 14，頭像和字隔 14）。
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.breed,
    required this.name,
    required this.meta,
    required this.onAvatar,
    required this.onName,
  });

  final String breed;
  final String name;
  final String meta;

  /// 點頭像：換頭像（S21-02）。
  final VoidCallback onAvatar;

  /// 點牧場名：改名頁（S21-04）。
  final VoidCallback onName;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('prof-card'),
    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
    child: Row(
      children: [
        // .prof-av：頭像加小鉛筆是一顆按鈕（浮起的元件：按下往下移、陰影變薄）
        Semantics(
          container: true,
          button: true,
          label: Strings.of(context).s21AvatarTitle,
          onTap: onAvatar,
          excludeSemantics: true,
          child: Pressable(
            key: const Key('prof-av'),
            lift: 3,
            onTap: onAvatar,
            builder: (context, look) => SizedBox.square(
              dimension: 80,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  BigAvatar(breed: breed, shadow: look.shadow),
                  // .hud-edit.big：右下角的小鉛筆（28、鉛筆 15），超出頭像 4
                  const Positioned(left: 56, top: 56, child: HudEdit(size: 28, icon: 15)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // .prof-name：一顆平的按鈕（按下蓋一層顏色），最少 44 高，名字放不下用「…」截短，後面鉛筆 14、箭頭 16
              Semantics(
                container: true,
                button: true,
                label: name,
                hint: Strings.of(context).s21RenameTitle,
                onTap: onName,
                excludeSemantics: true,
                child: Pressable(
                  key: const Key('prof-name-btn'),
                  onTap: onName,
                  builder: (context, look) => PressTint(
                    tint: look.tint,
                    borderRadius: const BorderRadius.all(AppRadii.r12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 字照 Chrome 的基線（.prof-name b 的行高 26）：Flutter 照 Material 3 的 even 分行高，會低 0.7
                          Flexible(
                            child: CssLine(
                              TextSpan(
                                text: name,
                                style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
                              ),
                              textKey: const Key('prof-name'),
                              ellipsis: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const AppIcon('pencil', size: 14),
                          const SizedBox(width: 2),
                          const AppIcon('chevron', size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(meta, style: KitText.hint()),
            ],
          ),
        ),
      ],
    ),
  );
}

/// .avatar.xl：80 的圓頭像（框 3、下陰影 3），牛臉 74、margin-top 6。框裡只有 74 高：CSS 的 grid 格子照內容撐成 80，
/// place-items: center 在撐大的格子裡沒有作用，所以臉從框裡的上緣往下 6 開始放，下面超出的被圓裁掉（同 CowPicBox）。
class BigAvatar extends StatelessWidget {
  const BigAvatar({super.key, required this.breed, this.shadow = 3});

  final String breed;

  /// 下陰影（按下時變 1）。
  final double shadow;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('prof-avatar'),
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFBFE6FF),
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      boxShadow: AppShadows.solid(shadow),
    ),
    child: ClipOval(
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned(left: 0, top: 6, child: CowFace(breed: breed, size: 74))],
      ),
    ),
  );
}

/// .card.ach-card：「成就徽章」標籤、「已解鎖 n / 總數」，下面徽章的格子（4 欄，窄於 340 是 3 欄；上下隔 14、左右 6）。
class BadgeCard extends StatelessWidget {
  const BadgeCard({super.key, required this.badges, required this.onOpen});

  final List<Achievement> badges;
  final ValueChanged<Achievement> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final cols = MediaQuery.sizeOf(context).width < 340 ? 3 : 4;
    final rows = <Widget>[];
    for (var i = 0; i < badges.length; i += cols) {
      if (i > 0) rows.add(const SizedBox(height: 14));
      rows.add(
        // 同一列的格子一樣高（CSS grid 的 stretch），按下的顏色蓋滿整格
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 6),
                Expanded(
                  child: i + c < badges.length
                      ? BadgeCell(badge: badges[i + c], onTap: () => onOpen(badges[i + c]))
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return AppCard(
      key: const Key('ach-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CardTitle(s.s21Badges, icon: 'medal', iconSize: 16),
              const SizedBox(width: 8),
              Flexible(
                child: CssParagraph(
                  TextSpan(
                    text: s.s21BadgeCount(n: badges.where((a) => a.unlocked).length, total: badges.length),
                  ),
                  key: const Key('ach-count'),
                  textAlign: TextAlign.end,
                  style: AppText.style(12, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

/// .ach：一格徽章（圖 52、名稱 12 特粗、有計數的寫進度；還沒解鎖的名稱是淡色）。平的元件：按下蓋一層顏色。
class BadgeCell extends StatelessWidget {
  const BadgeCell({super.key, required this.badge, required this.onTap});

  final Achievement badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final name = badgeName(s, badge);
    final p = badge.progressPair;
    // 格子裡的進度用短的寫法（一萬以上寫「5.8萬」「58.9K」），詳細寫完整的數字
    final prog = p == null ? null : '${compact(p.$1, s.lang)} / ${compact(p.$2, s.lang)}';
    final color = badge.unlocked ? AppColors.ink : AppColors.ink2;
    return Semantics(
      container: true,
      button: true,
      label: [name, if (!badge.unlocked) s.s21BadgeLocked, ?prog].join('\n'),
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        key: Key('ach-${badge.key}'),
        onTap: onTap,
        builder: (context, look) => PressTint(
          tint: look.tint,
          borderRadius: const BorderRadius.all(AppRadii.r12),
          child: Column(
            children: [
              BadgeArt(badge: badge),
              const SizedBox(height: 4),
              // 12 的字照 Chrome 的基線（Flutter 會低 1 左右）
              CssParagraph(
                TextSpan(text: name),
                textAlign: TextAlign.center,
                style: AppText.style(12, weight: FontWeight.w900, color: color, lineHeight: 16),
              ),
              if (prog != null) ...[
                const SizedBox(height: 4),
                CssParagraph(
                  TextSpan(text: prog),
                  textAlign: TextAlign.center,
                  style: AppText.number(12, color: AppColors.ink2, lineHeight: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// .ach-b：徽章的圓（框 3、下陰影 3）。圖示是 [size] 的 0.52；字是 0.44（兩個字的 Lv 是 0.34）。
/// 還沒解鎖的：底和框是停用色、陰影是停用的框色，圖變成 22% 的黑色剪影（CSS 的 brightness(0) 加 opacity 0.22）。
class BadgeArt extends StatelessWidget {
  const BadgeArt({super.key, required this.badge, this.size = 52});

  final Achievement badge;
  final double size;

  static const _black = ColorFilter.matrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]);

  @override
  Widget build(BuildContext context) {
    final on = badge.unlocked;
    final (icon, bg) = badgeLooks[badge.key] ?? ('medal', AppColors.yellow);
    final Widget art;
    if (icon.startsWith('txt:')) {
      final text = icon.substring(4);
      final px = (size * (text.length > 1 ? 0.34 : 0.44)).roundToDouble();
      art = CssLine(
        TextSpan(
          text: text,
          style: AppText.style(px, weight: FontWeight.w900, lineHeight: px),
        ),
      );
    } else {
      art = AppIcon(icon, size: icon.startsWith('tab_') ? 28 : (size * 0.52).roundToDouble());
    }
    final line = on ? AppColors.ink : AppColors.disabledLine;
    final fill = !on
        ? AppColors.disabledBg
        : badge.staged
        ? tierColor((badge.tierAt - 1).clamp(0, badge.tiers.length - 1), badge.tiers.length)
        : bg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: line, width: AppSizes.border),
        boxShadow: [BoxShadow(color: line, offset: const Offset(0, 3))],
      ),
      // 漸層畫在框裡面（CSS 的背景以內距框為準）
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: on && fill == null ? _legendBg : null),
        child: Center(
          child: on
              ? art
              : Opacity(
                  opacity: 0.22,
                  child: ColorFiltered(colorFilter: _black, child: art),
                ),
        ),
      ),
    );
  }
}

/// 點一個徽章（.sheet.ach-sheet，沒有標題）：大圖 88、名稱、條件、解鎖的日期（還沒解鎖的寫「還沒解鎖」和進度），
/// 分階段的列出每一階。下面「關閉」。
class BadgeSheet extends StatelessWidget {
  const BadgeSheet({super.key, required this.achievement, required this.onClose});

  final Achievement achievement;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final a = achievement;
    final Widget status;
    if (a.staged) {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in a.tiers.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _TierRow(
              key: Key('ach-tier-${i + 1}'),
              name: s.achName(a.key, tier: i + 1),
              cond: s.achCond(a.key, tier: i + 1),
              dot: t.unlockedAt == null ? null : tierColor(i, a.tiers.length),
              trailing: t.unlockedAt != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon('ok', size: 18),
                        const SizedBox(width: 4),
                        Text(logWhen(s, m, t.unlockedAt!), style: _whenStyle),
                      ],
                    )
                  : Text('${fmt(a.progress ?? 0)} / ${fmt(t.goal)}', style: _whenStyle.merge(_numStyle)),
            ),
          ],
        ],
      );
    } else if (a.unlockedAt case final at?) {
      status = Row(
        key: const Key('ach-date'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('ok', size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              s.s21BadgeDate(date: logWhen(s, m, at)),
              style: AppText.style(14, weight: FontWeight.w900, lineHeight: 20),
            ),
          ),
        ],
      );
    } else {
      final p = a.progressPair;
      status = Column(
        children: [
          Row(
            key: const Key('ach-locked'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon('lock', size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.s21BadgeLocked,
                  style: AppText.style(14, weight: FontWeight.w900, color: AppColors.ink2, lineHeight: 20),
                ),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 8),
            // .ach-bar：粗的黃色進度條（寬度照設計稿取整數的百分比）、右邊完整的數字
            Row(
              key: const Key('ach-bar'),
              children: [
                Expanded(child: MeterBar.yellow(fraction: (p.$1 / p.$2 * 100).round() / 100, height: 18, radius: 10)),
                const SizedBox(width: 10),
                CssLine(TextSpan(text: '${fmt(p.$1)} / ${fmt(p.$2)}', style: AppText.number(15))),
              ],
            ),
          ],
        ],
      );
    }
    return AppSheet(
      onClose: onClose,
      children: [
        // .ach-detail：置中、每塊隔 8，上 4、下 14
        Padding(
          key: Key('ach-detail-${a.key}'),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
          child: Column(
            children: [
              BadgeArt(badge: a, size: 88),
              const SizedBox(height: 8),
              Text(
                badgeName(s, a),
                textAlign: TextAlign.center,
                style: AppText.style(20, weight: FontWeight.w900, lineHeight: 26),
              ),
              if (!a.staged) ...[
                const SizedBox(height: 8),
                CssParagraph(
                  TextSpan(text: s.achCond(a.key)),
                  textAlign: TextAlign.center,
                  style: AppText.style(15, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 22),
                ),
              ],
              const SizedBox(height: 8),
              status,
            ],
          ),
        ),
        AppButton(s.gClose, key: const Key('ach-close'), block: true, onPressed: onClose),
      ],
    );
  }

  /// .ach-when：13 特粗、淡色（行高跟外層一樣是 normal）。
  static final _whenStyle = AppText.style(13, weight: FontWeight.w900, color: AppColors.ink2);
  static const _numStyle = TextStyle(letterSpacing: 0.2, fontFeatures: [FontFeature.tabularFigures()]);
}

/// .ach-tier：分階段的一階（白底、淡色框 2、圓角 14、內距 8 10）：圓點（解鎖了是那一階的顏色）、名稱和條件、右邊日期或進度。
class _TierRow extends StatelessWidget {
  const _TierRow({super.key, required this.name, required this.cond, required this.dot, required this.trailing});

  final String name;
  final String cond;

  /// 解鎖了的圓點顏色；null 是還沒。
  final Color? dot;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.lineSoft, width: 2),
      borderRadius: const BorderRadius.all(AppRadii.r14),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot ?? AppColors.disabledBg,
            border: Border.all(color: dot == null ? AppColors.disabledLine : AppColors.ink, width: 2.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20)),
              Text(cond, style: KitText.hint()),
            ],
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    ),
  );
}
