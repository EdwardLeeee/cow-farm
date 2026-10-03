import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../l10n/strings.dart';
import 'breed/breed_page.dart';
import 'cow/cow_detail_page.dart';
import 'fields/fields_page.dart';
import 'kit/frame.dart';
import 'kit/kit.dart';
import 'market/market_page.dart';
import 'ranch/pen_list.dart';
import 'ranch/ranch_page.dart';
import 'records/records_page.dart';
import '../state/game_model.dart';
import 'widgets/action_button.dart';
import 'settings/settings_page.dart';
import 'shop/shop_page.dart';
import 'start/recover_pages.dart';
import 'start/splash.dart';
import 'start/start_flow.dart';
import 'status/connection.dart';
import 'warehouse/warehouse_page.dart';

/// 外框：照 M2 設計稿的頂列（G-02）、底部分頁列（G-01）。牧場分頁是正式的 S03；其他分頁先把 M1 的畫面放在內容區，
/// 之後照設計稿一組一組換掉。分頁切換不算「按鈕」，斷線時仍可切換查看。
/// 伺服器推來的提示（例如有人借了你的公牛）用 SnackBar 顯示（G-05 之後照設計稿做）；
/// 斷線後重新連上（S15-02）是一般的提示條，在分頁列上面 14。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<GameNotice>? _sub;

  /// S15-02「已重新連線，資料更新了」正在顯示（2.5 秒）。
  bool _reconnected = false;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();
    _sub = context.read<GameModel>().notices.listen((notice) {
      if (!mounted) return;
      if (notice is ReconnectedNotice) {
        _reconnectedTimer?.cancel();
        setState(() => _reconnected = true);
        _reconnectedTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) setState(() => _reconnected = false);
        });
        return;
      }
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          key: const Key('notice'),
          content: Text(noticeText(context, notice)),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    // 還沒進牧場：S01 啟動與載入、S02 取名（正式畫面）
    if (showsStartFlow(m)) return const StartFlow();
    final Widget page;
    if (m.maintenance case final maint?) {
      // 維護中（S16-01、04、05）：整頁，沒有頂列和分頁列。預計恢復的時間照手機的時區顯示
      final ends = maint.endsAtReal;
      page = MaintenanceScreen(
        ends: ends == null ? null : DateTime.fromMillisecondsSinceEpoch((ends * 1000).round()),
        late: m.maintenanceLate,
        onReload: m.checkMaintenance,
      );
    } else if (m.authLost != null && m.recoverOpen) {
      // S15-03、S14-05 按「找回我的牧場」：S14-02 找回頁（返回回到原本那一頁）
      page = const RecoverPage();
    } else if (m.authLost case final code?) {
      // 牧場在另一支手機登入（S14-05）、帳號失效（S15-03）：整頁，沒有頂列和分頁列
      page = code == 'signed_in_elsewhere' ? const ElsewherePage() : const AuthLostPage();
    } else if (m.state == null) {
      // 載入中：整頁，沒有頂列和分頁列
      page = AppFrame(hud: false, content: _content(m));
    } else if (m.settingsView != null) {
      // 設定（S13）：頂列的齒輪打開，整頁，沒有頂列和分頁列；關掉回到原本那一頁
      page = const SettingsPage();
    } else if (m.detailCowKey case final key?) {
      // 牛的詳細（S04）：自己的外框，下面固定的按鈕區；上架面板、出貨確認疊在上面
      page = CowDetailPage(key: ValueKey('cow-$key'), cowKey: key);
    } else if (m.tab == AppTab.ranch && !m.penListOpen && !m.warehouseOpen) {
      page = const RanchPage();
    } else if (m.tab == AppTab.market) {
      // 市場（S06）：自己的外框，賣出的提示疊在最上面
      page = const MarketPage();
    } else if (m.tab == AppTab.shop) {
      // 商店（S19 抽牛、S10 設施）：自己的外框，升級的提示疊在最上面
      page = const ShopPage();
    } else if (m.tab == AppTab.breed) {
      // 配種（S08）：自己的外框，配種成功的提示疊在最上面
      page = const BreedPage();
    } else if (m.tab == AppTab.fields) {
      // 田地（S17）：自己的外框，選耕牛的面板、收成的提示疊在最上面
      page = const FieldsPage();
    } else if (m.tab == AppTab.records) {
      // 紀錄：圖鑑（S09）和排行榜（S12，還是 M1）
      page = const RecordsPage();
    } else {
      page = AppFrame(tab: m.tab, content: _content(m), contentPadding: EdgeInsets.zero);
    }
    final safe = MediaQuery.paddingOf(context);
    return PopScope(
      canPop:
          m.settingsView == null &&
          m.detailCowKey == null &&
          !m.penListOpen &&
          !m.warehouseOpen &&
          !(m.tab == AppTab.breed && m.studLogOpen) &&
          !(m.tab == AppTab.records && m.codexBreed != null),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (m.settingsView != null) {
          m.settingsBack();
        } else if (m.detailCowKey != null) {
          m.closeCow();
        } else if (m.tab == AppTab.breed && m.studLogOpen) {
          m.closeStudLog();
        } else if (m.tab == AppTab.records && m.codexBreed != null) {
          m.closeCodex();
        } else if (m.warehouseOpen) {
          m.closeWarehouse();
        } else {
          m.closePenList();
        }
      },
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: page),
              // S15-04：照設計稿 .long-off 的位置，在「連線中…」膠囊下面（頂列下 56），不蓋到它
              if (m.maintenance == null && m.state != null)
                Positioned(left: 12, right: 12, top: safe.top + FrameSizes.hud + 56, child: const LongOfflineCard()),
              // S15-02：.toast 的位置（分頁列上面 14）
              if (_reconnected)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: safe.bottom + FrameSizes.tab + 14,
                  child: Center(
                    child: ToastPill(
                      Strings.of(context).s15Reconnected,
                      kind: ToastKind.ok,
                      key: const Key('reconnected'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(GameModel m) {
    // 玩到一半牧場在別的手機登入（WebSocket 4401）也要換成 S14-05，不能留在牧場畫面
    if (m.state == null || m.authLost != null) return const _Loading();
    return switch (m.tab) {
      // 倉庫（S05-02）、牛舍清單（S03-07）
      AppTab.ranch => m.warehouseOpen ? const WarehousePage() : const PenListPage(),
      AppTab.market => const SizedBox.shrink(), // 市場是自己的整頁（MarketPage），不會走到這裡
      AppTab.fields => const SizedBox.shrink(), // 田地是自己的整頁（FieldsPage），不會走到這裡
      AppTab.breed => const SizedBox.shrink(), // 配種是自己的整頁（BreedPage），不會走到這裡
      AppTab.shop => const SizedBox.shrink(), // 商店是自己的整頁（ShopPage），不會走到這裡
      AppTab.records => const SizedBox.shrink(), // 紀錄是自己的整頁（RecordsPage），不會走到這裡
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    // M1 的原型畫面：只用文字（S15-03、S14-05 在 status/connection.dart，正式畫面）。
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.loadingFarm, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(S.prototypeNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 紀錄：圖鑑與排行榜兩個分頁。
