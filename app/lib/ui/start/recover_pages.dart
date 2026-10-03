// S14 找回牧場（設計稿 s13.js 的 firstOpen、recoverPage、S14-04；D22，協定 5.5）：新手機或重裝後，用備份牧場的
// Apple／Google 帳號登入，把牧場拿回這支手機。只有設好 Apple／Google 登入的建置有（GameModel.canSignIn）；
// 網頁試玩版、沒設 client ID 的建置跟原本一樣，沒有牧場就直接取名（S02）。
// - S14-01 第一次打開：開新牧場（→ S02）或找回我的牧場（→ S14-02）。
// - S14-02 找回我的牧場（iPhone 兩顆）、S14-07 Android 只有 Google 和提醒、S14-06 登入中、
//   S14-03 這個帳號沒有備份過牧場、S14-08 取消登入、登入失敗的提示。
// - S14-04 找回成功：歡迎回來（等級、金幣、牛、圖鑑），進牧場。
// S14-05（舊手機：牧場已經在另一支手機登入）和 S15-03 的「找回我的牧場」接在 #123 的正式畫面上，#123 合併後再做。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/breeds.dart';
import '../../api/models.dart';
import '../../auth/sign_in.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/kv.dart';
import '../settings/settings_page.dart';
import '../settings/sso_button.dart';
import '../widgets/action_button.dart';
import 'splash.dart';

/// S14-01 第一次打開：S01 的天空、遊戲名、兩頭牛、草地，下面「開新牧場」「找回我的牧場」（設計稿沒有小草小花和版本號）。
class FirstOpenPage extends StatelessWidget {
  const FirstOpenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    return SplashScreen(
      key: const Key('first-open'),
      deco: false,
      version: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            s.s14NewRanch,
            key: const Key('first-new'),
            kind: ButtonKind.primary,
            block: true,
            onPressed: m.chooseNewRanch,
          ),
          const SizedBox(height: 12),
          AppButton(
            s.s14Recover,
            key: const Key('first-recover'),
            block: true,
            icon: 'transfer',
            onPressed: m.openRecover,
          ),
        ],
      ),
    );
  }
}

/// S14-02 找回我的牧場：牛、「用之前備份牧場的帳號登入」，下面登入按鈕（S14-07 Android 只有 Google）；
/// 登入中（S14-06）換成「登入中…」，帳號沒有備份過牧場（S14-03）換成「換一個帳號」「開新牧場」。
class RecoverPage extends StatefulWidget {
  const RecoverPage({super.key});

  @override
  State<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends State<RecoverPage> {
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

  /// 按登入按鈕：成功整個畫面換成 S14-04；取消、失敗照 S14-08 跳提示；沒有備份過換成 S14-03。
  Future<void> _recover(SignInProvider p) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await m.recoverRanch(p);
    if (!mounted) return;
    switch (r.status) {
      case RecoverStatus.recovered || RecoverStatus.none:
        break;
      case RecoverStatus.cancelled:
        _showToast(ToastKind.info, s.s13ToastCancelled);
      case RecoverStatus.failed:
        _showToast(ToastKind.err, s.s13ToastFailed);
      case RecoverStatus.error:
        final e = r.error;
        if (e is ApiActionError && e.error.maintenance) return; // 整個畫面換成維護中
        if (e != null) _showToast(ToastKind.err, actionErrorTextWith(s, m, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final mq = MediaQuery.of(context);
    final android = m.signInPlatform == SignInPlatform.android;
    // 還沒有牧場、沒有在玩：按鈕只看有沒有在處理別的（GameModel.canAct 要連著推播，這時候沒有）
    final canTap = !m.busy;
    // 手機的返回鍵：回到 S14-01（找回中不能離開）
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) m.closeRecover();
      },
      child: _frame(context, m, s, mq, android: android, canTap: canTap),
    );
  }

  Widget _frame(
    BuildContext context,
    GameModel m,
    Strings s,
    MediaQueryData mq, {
    required bool android,
    required bool canTap,
  }) {
    return SettingsFrame(
      title: s.s14Recover,
      scrollKey: const Key('recover'),
      onBack: m.closeRecover,
      overlays: [
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: mq.padding.bottom + 16,
            child: Center(
              child: ToastPill(t.text, kind: t.kind, key: const Key('toast')),
            ),
          ),
      ],
      children: [
        const _RecoverHero(),
        if (m.recovering)
          SsoBusyCard(s.s14SigningIn, key: const Key('sso-busy'))
        else if (m.recoverNone)
          _NoRanch(onAnother: m.recoverAnother, onNew: m.chooseNewRanch)
        else
          SsoArea(
            providers: m.signInPlatform.providers,
            onTap: canTap ? _recover : null,
            hint: android ? s.s14AndroidHint : null,
          ),
      ],
    );
  }
}

/// .card.rec-hero：側面的牛（150×110）、「用之前備份牧場的帳號登入」（17 特粗、行高 24，上面 6）、下面一行小字。
class _RecoverHero extends StatelessWidget {
  const _RecoverHero();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('rec-hero'),
      child: Column(
        children: [
          const CowPicture(breed: 'holstein', front: false, width: 150, height: 110),
          const SizedBox(height: 6),
          Text(
            s.s14Lead,
            textAlign: TextAlign.center,
            style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
          ),
          Text(s.s14LeadHint, textAlign: TextAlign.center, style: KitText.hint()),
        ],
      ),
    );
  }
}

/// .card.no-ranch（S14-03）：.empty 的兩行字（第二行有換行），下面「換一個帳號」「開新牧場」一樣寬。
class _NoRanch extends StatelessWidget {
  const _NoRanch({required this.onAnother, required this.onNew});

  final VoidCallback onAnother;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('no-ranch'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              children: [
                Text(
                  s.s14NoneTitle,
                  textAlign: TextAlign.center,
                  style: AppText.style(17, weight: FontWeight.w900, lineHeight: 24),
                ),
                const SizedBox(height: 10),
                // .empty .t2：14、行高 21，照 Chrome 的基線（Flutter 低 1.8）
                CssParagraph(
                  TextSpan(text: s.s14NoneBody),
                  style: AppText.style(14, weight: FontWeight.w700, color: AppColors.ink2, lineHeight: 21),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          BtnRow(
            children: [
              AppButton(s.s14OtherAccount, key: const Key('recover-another'), onPressed: onAnother),
              AppButton(s.s14NewRanch, key: const Key('recover-new'), kind: ButtonKind.primary, onPressed: onNew),
            ],
          ),
        ],
      ),
    );
  }
}

/// S14-04 找回成功：牧場卡（大頭像、名字、#編號）、等級、金幣、牛、圖鑑，「牧場已經回到這支手機，舊手機已經登出。」、
/// 進牧場。沒有返回鈕。
class WelcomeBackPage extends StatelessWidget {
  const WelcomeBackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final st = m.state;
    return SettingsFrame(
      title: s.s14Welcome,
      scrollKey: const Key('welcome-back'),
      noBack: true,
      children: [
        AppCard(
          key: const Key('welcome-card'),
          child: Row(
            children: [
              _BigAvatar(breed: st?.profile.avatarBreed ?? 'holstein'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // .welcome b：18 粗、行高 normal
                    Text(m.ranchName, style: AppText.style(18, weight: FontWeight.w700)),
                    if (Strings.ranchTag(RanchRef(playerId: st?.playerId)) case final tag?)
                      Text(tag, strutStyle: kDivStrut, style: KitText.hint()),
                  ],
                ),
              ),
            ],
          ),
        ),
        KvGrid(
          key: const Key('welcome-kv'),
          cells: [
            (s.s14Level, s.level(lv: st?.level ?? 1), null),
            (s.s14Coins, fmt(st?.coins ?? 0), null),
            (s.s14Cows, fmt(st?.cows.length ?? 0), s.s14Head),
            (s.subCodex, fmt(st?.codex.length ?? 0), '/ ${kCodexOrder.length}'),
          ],
        ),
        Text(s.s14WelcomeHint, style: KitText.hint()),
        AppButton(
          s.gEnterRanch,
          key: const Key('enter-recovered'),
          kind: ButtonKind.primary,
          block: true,
          onPressed: m.enterRecoveredRanch,
        ),
      ],
    );
  }
}

/// .welcome .avatar：56 的牛臉圓頭像（框 3、下陰影 3），臉 52、往下 4（跟頂列的頭像一樣）。
class _BigAvatar extends StatelessWidget {
  const _BigAvatar({required this.breed});

  /// 牧場選的頭像（S21；沒選過是荷斯坦）。
  final String breed;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFBFE6FF),
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      boxShadow: AppShadows.solid(),
    ),
    child: ClipOval(
      child: OverflowBox(
        maxWidth: 52,
        maxHeight: 52,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: CowFace(breed: breed, size: 52),
        ),
      ),
    ),
  );
}
