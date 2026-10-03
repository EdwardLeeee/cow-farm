// 頁面外框（設計稿 design/m2/src/js/kit.js 的 frame、hud、tabbar；kit.css）：頂列（G-02）、內容區、底部分頁列（G-01）、
// 斷線時的「連線中…」（S15-01）。整個畫面從狀態列底下畫起（場景要延伸到狀態列後面），所以不包 SafeArea，自己讀安全區。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:provider/provider.dart';

import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../../util/ranch_name.dart';
import '../level/level_up.dart';
import 'app_icon.dart';
import 'cow_art.dart';
import 'press.dart';

/// 版面的固定尺寸（base.css）。
abstract final class FrameSizes {
  static const hud = AppSizes.hudHeight; // 52
  static const tab = AppSizes.tabBarHeight; // 62

  /// 內容區的上緣：頂列下面再留 12。
  static double contentTop(EdgeInsets safe, {bool hud = true}) => hud ? safe.top + FrameSizes.hud + 12 : safe.top;

  /// 內容區的下緣到螢幕底的距離。
  static double contentBottom(EdgeInsets safe, {bool tab = true}) => tab ? safe.bottom + FrameSizes.tab : safe.bottom;
}

/// .page-bg：暖米色，上方一條淡淡的天空色。
class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.safeTop});

  final double safeTop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final h = c.maxHeight;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFCDEBFF), Color(0xFFE9F6FF), AppColors.cream],
            stops: [0, ((safeTop + 64) / h).clamp(0, 1), ((safeTop + 150) / h).clamp(0, 1)],
          ),
        ),
      );
    },
  );
}

/// 一頁的外框。[scene] 是整個畫面的背景（牧場、田地），沒有就是一般頁面的底色；[content] 放在頂列和分頁列之間；
/// [body] 是貼在畫面上固定位置的東西（Positioned，例如牧場頁的跑馬燈、面板）；
/// [underlays] 在面板下面、場景上面（泡泡）；[overlays] 在最上面（提示、對話框）。
class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    this.tab,
    this.hud = true,
    this.scene,
    this.content,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 4, 12, 16),
    this.body = const [],
    this.underlays = const [],
    this.overlays = const [],
  });

  /// 選中的分頁；null 是沒有分頁列的頁面。
  final AppTab? tab;
  final bool hud;
  final Widget? scene;
  final Widget? content;
  final EdgeInsets contentPadding;
  final List<Widget> body;
  final List<Widget> underlays;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final m = context.watch<GameModel>();
    // 斷線、重連中（S15-01）：在玩的時候連不上才顯示
    final offline = m.state != null && !m.online && m.maintenance == null && m.authLost == null;
    return ColoredBox(
      color: AppColors.cream,
      child: Stack(
        children: [
          Positioned.fill(child: scene ?? PageBackground(safeTop: safe.top)),
          if (content != null)
            Positioned(
              left: 0,
              right: 0,
              top: FrameSizes.contentTop(safe, hud: hud),
              bottom: FrameSizes.contentBottom(safe, tab: tab != null),
              child: Padding(padding: contentPadding, child: content),
            ),
          ...underlays,
          ...body,
          if (hud) Positioned(left: 12, right: 12, top: safe.top + 6, height: FrameSizes.hud, child: const Hud()),
          if (tab != null) Positioned(left: 0, right: 0, bottom: 0, child: AppTabBar(active: tab!)),
          if (offline)
            Positioned(
              left: 0,
              right: 0,
              top: safe.top + FrameSizes.hud + 12,
              child: const Center(child: OfflinePill()),
            ),
          ...overlays,
          // 場主升級慶祝（S11-01）：在哪一頁升級就在哪一頁跳，蓋在最上面
          if (m.levelUp case final up?) LevelUpOverlay(level: up.level, levelAt: up.levelAt, onOk: m.dismissLevelUp),
        ],
      ),
    );
  }
}

/// 頂列要顯示的東西（伺服器的 state）。
class HudData {
  const HudData({required this.name, required this.level, required this.xp, required this.coins});

  factory HudData.of(GameModel m) => HudData(
    name: m.ranchName,
    level: m.state?.level ?? 1,
    xp: m.state?.levelProgress.fraction ?? 0,
    coins: m.state?.coins ?? 0,
  );

  final String name;
  final int level;
  final double xp; // 這一級走了幾成（0–1）
  final num coins;
}

/// 頂列（G-02）：頭像、牧場名、等級和經驗條、金幣、設定。
/// 窄手機（寬度 < 390、< 340）照 kit.css 的兩段 @media 縮小；牧場名顯示寬度超過 12 時字縮小，再放不下用「…」截短（D23）。
class Hud extends StatelessWidget {
  const Hud({super.key, this.data, this.gearDot = false});

  /// 沒給就讀 GameModel。
  final HudData? data;

  /// 齒輪上的小點（G-10：還沒備份牧場、也還沒打開過「備份牧場」頁）。「備份牧場」頁（S13）做好之前一律不顯示。
  final bool gearDot;

  @override
  Widget build(BuildContext context) {
    final d = data ?? HudData.of(context.watch<GameModel>());
    final s = Strings.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 390, tiny = w < 340;
    final name = d.name;
    final long = nameWidth(name) > 12;
    final coins = d.coins;
    final xp = d.xp;
    final avatar = tiny ? 46.0 : (narrow ? 50.0 : 56.0);
    final face = tiny ? 42.0 : (narrow ? 46.0 : 52.0);
    final coinIcon = tiny ? 30.0 : 34.0;
    // 頂列自己一個無障礙節點：裡面照名字、Lv、經驗、金幣、設定的順序讀。不然在牧場分頁會跟鋪滿整頁的場景
    // 一起照位置排，變成「設定」先讀（8790 走查看到；ceo 2026-10-02：每個分頁的頂列順序都一樣）
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // .profile-text：頭像右邊的白底名牌，左邊被頭像蓋住 18（窄手機 16）
                      Padding(
                        padding: EdgeInsets.only(left: avatar - (narrow ? 16 : 18)),
                        child: Container(
                          height: narrow ? 46 : 48,
                          padding: EdgeInsets.fromLTRB(narrow ? 20 : 24, 3, narrow ? 10 : 12, 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.ink, width: AppSizes.border),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                            boxShadow: AppShadows.solid(),
                          ),
                          // 名字加等級列比名牌的內容區高 4：跟設計稿一樣上下各超出 2，不裁切（CSS 的 overflow: visible）
                          child: OverflowBox(
                            maxHeight: double.infinity,
                            fit: OverflowBoxFit.deferToChild,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  key: const Key('hud-name'),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.style(
                                    long || tiny ? 13 : (narrow ? 14 : 15),
                                    weight: FontWeight.w900,
                                    lineHeight: narrow ? 18 : 19,
                                    letterSpacing: long || narrow ? 0 : 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.yellow,
                                        border: Border.all(color: AppColors.ink, width: 2),
                                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      ),
                                      child: Text(s.level(lv: d.level), style: AppText.number(12, lineHeight: 14)),
                                    ),
                                    const SizedBox(width: 5),
                                    // 320 寬放不下時經驗條縮短（設計稿是超出名牌）
                                    Flexible(
                                      child: Semantics(
                                        label: s.hudXp(pct: (xp * 100).round()),
                                        child: _XpBar(width: tiny ? 38 : (narrow ? 44 : 58), fraction: xp),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // .avatar：牛臉的圓頭像，疊在名牌左邊
                      Positioned(
                        left: 0,
                        top: (narrow ? 46 : 48) / 2 - avatar / 2,
                        child: Container(
                          width: avatar,
                          height: avatar,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFBFE6FF),
                            border: Border.all(color: AppColors.ink, width: AppSizes.border),
                            boxShadow: AppShadows.solid(),
                          ),
                          child: ClipOval(
                            child: OverflowBox(
                              maxWidth: face,
                              maxHeight: face,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: CowFace(size: face),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: narrow ? 6 : 8),
          // .coins：金幣膠囊，金幣圖示一半在外面
          Padding(
            padding: EdgeInsets.only(left: narrow ? 17 : 18),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 40,
                  padding: EdgeInsets.fromLTRB(narrow ? 20 : 24, 0, narrow ? 10 : 12, 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: AppSizes.border),
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    boxShadow: AppShadows.solid(),
                  ),
                  child: Text(
                    compact(coins, s.lang, from: narrow ? 100000 : 1000000),
                    key: const Key('hud-coins'),
                    style: AppText.number(tiny ? 15 : (narrow ? 17 : 18), lineHeight: tiny ? 15 : (narrow ? 17 : 18)),
                  ),
                ),
                Positioned(
                  left: tiny ? -16 : -19,
                  child: AppIcon('coin', size: coinIcon),
                ),
              ],
            ),
          ),
          SizedBox(width: narrow ? 6 : 8),
          Semantics(
            container: true,
            button: true,
            label: gearDot ? s.hudSettingsNotBacked : s.hudSettings,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: AppSizes.border),
                    boxShadow: AppShadows.solid(),
                  ),
                  child: const AppIcon('gear', size: 24),
                ),
                if (gearDot)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      key: const Key('gear-dot'),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF6B5E),
                        // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .xp：經驗條。
class _XpBar extends StatelessWidget {
  const _XpBar({required this.width, required this.fraction});

  final double width;
  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
    // 寬度固定；放不下時（320）被外面的 Flexible 壓短
    width: width,
    height: 9,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4CC),
      border: Border.all(color: AppColors.ink, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(6)),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0, 1),
        child: const ColoredBox(color: Color(0xFFFFB938)),
      ),
    ),
  );
}

/// 底部分頁列（G-01）：6 個分頁；選中的那個圖示套一個粉色膠囊、往上 6、字變粗。
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.active, this.bottomPadding});

  final AppTab active;

  /// 下面的安全區（Home 指示條）；沒給就讀手機的。設計稿的 G-01 狀態表是 0。
  final double? bottomPadding;

  static String label(Strings s, AppTab t) => switch (t) {
    AppTab.ranch => s.tabRanch,
    AppTab.market => s.tabMarket,
    AppTab.fields => s.tabFields,
    AppTab.breed => s.tabBreed,
    AppTab.shop => s.tabShop,
    AppTab.records => s.tabRecords,
  };

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final bottom = bottomPadding ?? MediaQuery.paddingOf(context).bottom;
    final m = context.read<GameModel>();
    return Container(
      height: FrameSizes.tab + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8EC),
        border: Border(
          top: BorderSide(color: AppColors.ink, width: AppSizes.border),
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          for (final t in AppTab.values)
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: t == active,
                // 平的元件：按下蓋一層顏色（圓角 12，G-12）
                child: Pressable(
                  key: Key('tab-${t.name}'),
                  onTap: () => m.selectTab(t),
                  builder: (context, look) => PressTint(
                    tint: look.tint,
                    borderRadius: const BorderRadius.all(AppRadii.r12),
                    child: _Tab(label: label(s, t), icon: t.name, on: t == active),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.on});

  final String label;
  final String icon;
  final bool on;

  @override
  Widget build(BuildContext context) {
    // 設計稿的分頁圖示畫成 28×28（icons.js 的 TAB）
    final pic = AppIcon('tab_${icon}_${on ? 'on' : 'off'}', size: 28);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (on)
          // margin-top: -6px：膠囊（28 + 上下 2 + 框 2×2 = 36 高）往上凸 6，排版只佔 30
          SizedBox(
            height: 36 - 6,
            child: OverflowBox(
              maxHeight: 36,
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE2DA),
                  // CSS 寫 2.5px，boards 量出來是 2（Chrome 畫成 2px）；照核准的 boards
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: AppShadows.solid(2),
                ),
                child: pic,
              ),
            ),
          )
        else
          pic,
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: AppText.style(
            12,
            weight: on ? FontWeight.w900 : FontWeight.w700,
            color: on ? AppColors.ink : AppColors.ink2,
            lineHeight: 15,
          ),
        ),
      ],
    );
  }
}

/// 斷線時頂列下面的「連線中…」膠囊（.hud-offline，S15-01）。
class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('offline-pill'),
    height: 34,
    padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
    decoration: BoxDecoration(
      color: AppColors.orange,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(Radius.circular(17)),
      boxShadow: AppShadows.solid(),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon('offline', size: 20),
        const SizedBox(width: 6),
        Text(Strings.of(context).connecting, style: AppText.style(14, weight: FontWeight.w900)),
      ],
    ),
  );
}
