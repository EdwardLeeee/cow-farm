// 打開 app 到進牧場之前的畫面：S01 啟動與載入、S02 取名（建立牧場）、S13-04 牧場已經刪除了、S14 找回牧場。
// 順序（ceo 2026-10-02 方案 A）：沒有牧場 → S02 取名 → 就叫這個 → S01-03 建立中 → S02-02 歡迎卡 → 進牧場。
// 設好 Apple／Google 登入的建置，第一次打開先問 S14-01：開新牧場 → S02；找回我的牧場 → S14-02 → S14-04 歡迎回來 → 進牧場
// （recover_pages.dart）。網頁試玩版、沒設 client ID 的建置沒有 S14-01，照原本直接 S02。
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../widgets/action_button.dart';
import 'namer.dart';
import 'recover_pages.dart';
import 'splash.dart';
import 'welcome.dart';

/// 現在該顯示哪一個開場畫面（不在牧場裡的時候）。
bool showsStartFlow(GameModel m) =>
    m.maintenance == null &&
    m.authLost == null &&
    (m.state == null || m.needsRanch || m.creating || m.welcomePending || m.welcomeBack);

class StartFlow extends StatefulWidget {
  const StartFlow({super.key, this.random});

  /// 「幫我想一個」用的亂數；測試給固定的。
  final Random? random;

  /// 測試用：整個 app 裡的 StartFlow 都用這個亂數（截圖要固定填「晨光河畔牧場」）。
  @visibleForTesting
  static Random? debugRandom;

  @override
  State<StartFlow> createState() => _StartFlowState();
}

class _StartFlowState extends State<StartFlow> {
  // 名字放在這裡（不放在 S02 頁面裡）：S01-03 建立中會暫時換掉 S02，失敗回來名字還在
  final _name = TextEditingController();
  final _focus = FocusNode();
  late final Random _random = widget.random ?? StartFlow.debugRandom ?? Random();
  bool _filled = false;
  String? _serverError;
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _name.addListener(_edited);
  }

  String _lastText = '';

  void _edited() {
    if (_name.text == _lastText) return; // 只動了游標
    _lastText = _name.text;
    if (_filled || _serverError != null) {
      setState(() {
        _filled = false;
        _serverError = null;
      });
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _suggest() {
    final s = Strings.of(context, listen: false);
    _name.text = s.suggestRanchName(_random);
    _lastText = _name.text;
    setState(() {
      _filled = true;
      _serverError = null;
    });
  }

  Future<void> _create(String name) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    _focus.unfocus();
    final r = await m.createRanch(name);
    if (!mounted || r.ok) return;
    switch (r.error) {
      case ApiActionError(:final error) when error.code == 'invalid_name':
        // 伺服器不收（例如手機的表比伺服器舊）：回 S02，提示在輸入框下面（S02-05）
        setState(() => _serverError = s.errorText(error.code, detail: error.detail));
      case ApiActionError(:final error) when error.maintenance || error.unauthorized:
        break; // 整個畫面會換成 S16-01／S15-03
      case final ActionError e?:
        _showToast(actionErrorKind(e), actionErrorTextWith(s, m, e));
      case null:
        break;
    }
  }

  void _showToast(ToastKind kind, String text) {
    _toastTimer?.cancel();
    setState(() => _toast = (kind: kind, text: text));
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final Widget page;
    if (m.creating) {
      page = SplashScreen(
        child: Column(
          children: [
            _LoadingRow(s.s01Creating),
            const SizedBox(height: 6),
            Text(s.s01FirstTime, textAlign: TextAlign.center, style: KitText.hint()),
          ],
        ),
      );
    } else if (m.ranchDeleted) {
      page = SplashScreen(scenery: false, child: _Deleted(model: m));
    } else if (m.welcomeBack) {
      page = const WelcomeBackPage();
    } else if (m.recoverOpen) {
      page = const RecoverPage();
    } else if (m.showsFirstOpen) {
      page = const FirstOpenPage();
    } else if (m.needsRanch || m.welcomePending) {
      page = NamerPage(
        controller: _name,
        focusNode: _focus,
        filled: _filled,
        serverError: _serverError,
        onSuggest: _suggest,
        onConfirm: _create,
        overlay: m.welcomePending ? WelcomeDialog(model: m) : null,
      );
    } else if (m.startError != null && !m.starting) {
      page = SplashScreen(child: _LoadFailed(model: m));
    } else if (m.starting) {
      page = SplashScreen(child: _LoadingRow(s.loadingFarm));
    } else {
      page = const SplashScreen();
    }
    return Scaffold(
      backgroundColor: AppColors.cream,
      resizeToAvoidBottomInset: false, // 鍵盤的位置由 S02 自己讓（MediaQuery.viewInsets）
      body: Stack(
        children: [
          Positioned.fill(child: page),
          if (_toast != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: Center(
                child: ToastPill(_toast!.text, kind: _toast!.kind, key: const Key('toast')),
              ),
            ),
        ],
      ),
    );
  }
}

/// .loading-row：轉圈加一句話。
class _LoadingRow extends StatelessWidget {
  const _LoadingRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Spinner(),
      const SizedBox(width: 10),
      Flexible(
        child: Text(text, style: AppText.style(16, weight: FontWeight.w900)),
      ),
    ],
  );
}

/// S13-04 牧場已經刪除了：牛、「牧場已經刪除了」「謝謝你這段時間的照顧。」、「開新牧場」（→ S02 取名）。
class _Deleted extends StatelessWidget {
  const _Deleted({required this.model});

  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('ranch-deleted'),
      child: Column(
        children: [
          const CowPicture(breed: 'holstein', width: 120, height: 120),
          // <b> 在一般的 div 裡：字 18，跟 div 的 16px 一起排成 26 高的一行（基線照 Chrome 的，見 CssParagraph）
          CssParagraph(
            TextSpan(text: s.s13Deleted),
            style: AppText.style(18, weight: FontWeight.w700, lineHeight: 26),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(s.s13Thanks, textAlign: TextAlign.center, style: KitText.hint()),
          const SizedBox(height: 12),
          AppButton(
            s.s14NewRanch,
            key: const Key('new-ranch'),
            kind: ButtonKind.primary,
            block: true,
            onPressed: model.startNewRanch,
          ),
        ],
      ),
    );
  }
}

/// S01-04 載入失敗：連不上伺服器、請確認網路、每幾秒也會自動再試，加「重試」。
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.model});

  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon('offline', size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(s.s01FailTitle, style: AppText.style(16, weight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${s.s01FailCheck}\n${s.s01FailAuto(n: model.refreshEvery.inSeconds)}',
            textAlign: TextAlign.center,
            style: KitText.hint(),
          ),
          const SizedBox(height: 12),
          AppButton(
            s.retry,
            key: const Key('retry'),
            kind: ButtonKind.primary,
            block: true,
            icon: 'refresh',
            onPressed: model.start,
          ),
        ],
      ),
    );
  }
}
