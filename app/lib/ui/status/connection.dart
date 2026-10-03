// S15 連線與斷線（設計稿 s13.js 的 S15；screens.css 的 .long-off）：帳號失效（S15-03）、斷線超過 60 秒（S15-04）。
// S14-05（牧場在另一支手機登入）跟 S15-03 同一個樣子，也放在這裡。
// 斷線、重連中（S15-01）是外框的「連線中…」，在 kit/frame.dart；重新連上（S15-02）的提示在 home_shell.dart。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';
import '../kit/page_head.dart';
import '../widgets/ticker_builder.dart';

/// S15-03 帳號失效：這支手機存的 token 伺服器不認得了（HTTP 401、WebSocket 4401）。
/// 深色的牛剪影、說明；「找回我的牧場」「開新牧場」。
class AuthLostPage extends StatelessWidget {
  const AuthLostPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return _LostPage(
      pageKey: const Key('auth-lost'),
      title: s.s15InvalidTitle,
      card: AppCard(
        child: Column(
          children: [
            const CowSilhouette.dark(breed: 'holstein', width: 110, height: 110),
            const SizedBox(height: 6),
            Text(s.s15InvalidBody, textAlign: TextAlign.center, style: KitText.hint()),
          ],
        ),
      ),
    );
  }
}

/// S14-05 舊手機：牧場在另一支手機找回了（伺服器說 signed_in_elsewhere，HTTP 401 或 WebSocket 4401）。
/// 朝右的側面荷斯坦、「『牧場名』現在在另一支手機上」、一個牧場同時只能在一支手機玩、安全提醒；「找回我的牧場」「開新牧場」。
class ElsewherePage extends StatelessWidget {
  const ElsewherePage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    return _LostPage(
      pageKey: const Key('elsewhere'),
      title: s.s14ElsewhereTitle,
      card: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CowPicture(breed: 'holstein', front: false, right: true, width: 150, height: 110)),
            const SizedBox(height: 6),
            // 字 16 特粗，行高照外層（16、行高 normal 是 24）
            Text(
              s.s14ElsewhereLead(name: m.ranchName),
              textAlign: TextAlign.center,
              style: AppText.style(16, weight: FontWeight.w900, lineHeight: 24),
            ),
            const SizedBox(height: 4),
            Text(s.s14ElsewhereBody, textAlign: TextAlign.center, style: KitText.hint()),
            const SizedBox(height: 8),
            Text(s.s14ElsewhereSecurity, textAlign: TextAlign.center, style: KitText.hint()),
          ],
        ),
      ),
    );
  }
}

/// S15-03、S14-05 共用的整頁：標題（沒有返回）、說明卡、按鈕。
/// 「找回我的牧場」打開 S14-02（#128 的找回頁），只在設好登入的建置出現（跟 S14-01 一樣；網頁試玩版沒有）。
/// 「開新牧場」清掉 token，直接到 S02 取名。
class _LostPage extends StatelessWidget {
  const _LostPage({required this.pageKey, required this.title, required this.card});

  final Key pageKey;
  final String title;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    return AppFrame(
      hud: false,
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        key: pageKey,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(title: title),
            const SizedBox(height: AppSizes.gap),
            card,
            const SizedBox(height: AppSizes.gap),
            if (m.canSignIn) ...[
              AppButton(
                s.s14Recover,
                key: const Key('lost-recover'),
                kind: ButtonKind.primary,
                block: true,
                icon: 'transfer',
                onPressed: m.openRecover,
              ),
              const SizedBox(height: AppSizes.gap),
            ],
            AppButton(s.s14NewRanch, key: const Key('start-over'), block: true, onPressed: m.startOver),
          ],
        ),
      ),
    );
  }
}

/// S15-04 斷線超過 60 秒（.long-off）：連不上伺服器、已經多久，請檢查網路，「重試」。
/// 放在頂列下面 56（「連線中…」膠囊的下面，不蓋到它）。斷線時間一直在走，定時重畫。
class LongOfflineCard extends StatelessWidget {
  const LongOfflineCard({super.key});

  @override
  Widget build(BuildContext context) => TickerBuilder(
    builder: (context) {
      final m = context.watch<GameModel>();
      if (!m.longOffline) return const SizedBox.shrink();
      final s = Strings.of(context);
      return Container(
        key: const Key('long-offline'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5E6),
          border: Border.all(color: AppColors.ink, width: AppSizes.border),
          borderRadius: const BorderRadius.all(AppRadii.r18),
          boxShadow: AppShadows.solid(4),
        ),
        child: Row(
          children: [
            const AppIcon('offline', size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // <b> 在一般的 div 裡：字 15、這一行照 div 的 16px（行高 24）
                  Text(
                    s.s15LongOffTitle(n: m.offlineMinutes),
                    strutStyle: kDivStrut,
                    style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20),
                  ),
                  Text(s.s15LongOffBody, style: KitText.hint()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              s.retry,
              key: const Key('long-offline-retry'),
              small: true,
              icon: 'refresh',
              onPressed: m.retryConnection,
            ),
          ],
        ),
      );
    },
  );
}
