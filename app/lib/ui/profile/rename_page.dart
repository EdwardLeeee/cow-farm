// S21-04～08 改牧場名（D34；設計稿 s21.js 的 renamePage、screens.css 的 .namer、.rn-warn）。在牧場資料點牧場名打開；
// 整頁，沒有頂列和分頁列，返回回到牧場資料。輸入框、字數、「幫我想一個」跟 S02 一樣（NameCard），名字規則照 D23。
// - 一開始放現在的名字；跟現在一樣時按鈕不能按（scope.md S21）。
// - 第一次免費（「改名（免費）」），之後每次 economy.rename_price（「改名（1,000 幣）」）；錢不夠時按鈕停用，上面寫還差多少。
// - 伺服器不收這個名字（invalid_name）：提示放在輸入框下面（同 S02-05）。改好了回到牧場資料，提示由牧場資料頁顯示（S21-09）。
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../../util/ranch_name.dart';
import '../kit/app_icon.dart';
import '../kit/kit.dart';
import '../settings/settings_page.dart' show SettingsFrame;
import '../start/namer.dart';
import '../widgets/action_button.dart' show actionErrorTextWith;

/// 改名的價錢（暫定協定 `economy.rename_price`；舊的伺服器沒有時用 D34 的 1,000 幣）。
double renamePrice(GameModel m) => m.state?.economy?.renamePrice ?? 1000;

/// 下次改名要不要錢：改過一次以後（`profile.renames` ≥ 1）。舊的伺服器不知道次數，當成還沒改過。
bool renamePaid(GameModel m) => (m.state?.profile.renames ?? 0) > 0;

class RenamePage extends StatefulWidget {
  const RenamePage({super.key, required this.onRenamed, this.random});

  /// 改好了（改名頁已經關掉）：牧場資料頁跳提示。
  final VoidCallback onRenamed;

  /// 「幫我想一個」用的亂數（測試固定）。
  final Random? random;

  @override
  State<RenamePage> createState() => _RenamePageState();
}

class _RenamePageState extends State<RenamePage> {
  late final _name = TextEditingController(text: context.read<GameModel>().ranchName);
  final _focus = FocusNode();
  final _confirm = GlobalKey();
  late final Random _random = widget.random ?? Random();
  late String _lastText = _name.text;
  bool _filled = false;
  String? _serverError;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _name.addListener(_edited);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

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

  void _suggest() {
    final s = Strings.of(context, listen: false);
    _name.text = s.suggestRanchName(_random);
    _lastText = _name.text;
    setState(() {
      _filled = true;
      _serverError = null;
    });
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _submit(String name) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final done = widget.onRenamed;
    _focus.unfocus();
    final r = await m.renameRanch(name);
    if (r.ok) {
      done();
      return;
    }
    if (!mounted) return;
    switch (r.error) {
      case ApiActionError(:final error) when error.code == 'invalid_name':
        setState(() => _serverError = s.errorText(error.code, detail: error.detail));
      case ApiActionError(:final error) when error.maintenance || error.unauthorized:
        break; // 整個畫面會換成 S16-01／S15-03
      case final ActionError e?:
        _showToast(actionErrorTextWith(s, m, e));
      case null:
        break;
    }
  }

  /// 鍵盤開著：捲到按鈕整顆看得到（輸入框、字數和按鈕都要在鍵盤上面，同 S02-03）。
  void _revealConfirm(Duration _) {
    final ctx = _confirm.currentContext;
    if (!mounted || ctx == null || MediaQuery.viewInsetsOf(context).bottom == 0) return;
    Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final mq = MediaQuery.of(context);
    final keyboard = (mq.viewInsets.bottom - mq.padding.bottom).clamp(0.0, double.infinity);
    if (keyboard > 0) WidgetsBinding.instance.addPostFrameCallback(_revealConfirm);
    final paid = renamePaid(m);
    final price = renamePrice(m);
    final short = paid ? (price - (m.state?.coins ?? 0)).ceil() : 0;
    return SettingsFrame(
      title: s.s21RenameTitle,
      scrollKey: const Key('rename'),
      onBack: m.closeRename,
      bottomInset: keyboard,
      overlays: [
        if (_toast case final t?)
          Positioned(
            left: 16,
            right: 16,
            bottom: mq.padding.bottom + 16,
            child: Center(
              child: ToastPill(t, kind: ToastKind.err, key: const Key('toast')),
            ),
          ),
      ],
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([_name, _focus]),
          builder: (context, _) {
            final text = _name.text;
            final check = checkRanchName(text);
            final problem = text.isEmpty ? null : check.problem;
            final error = problem != null ? nameProblemText(s, problem) : _serverError;
            final ok =
                text.isNotEmpty &&
                check.problem == null &&
                _serverError == null &&
                check.name != m.ranchName &&
                short <= 0;
            // .namer：上面多 6，名字卡、提示、按鈕每塊隔 14
            return Padding(
              key: const Key('namer'),
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NameCard(
                    width: check.width,
                    error: error,
                    hint: _filled ? s.s02Filled : s.s02WidthRule,
                    focused: _focus.hasFocus,
                    field: TextField(
                      key: const Key('rename-field'),
                      controller: _name,
                      focusNode: _focus,
                      style: nameInputStyle(),
                      cursorColor: AppColors.ink,
                      cursorWidth: 2,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => ok ? _submit(check.name) : null,
                      decoration: InputDecoration.collapsed(
                        hintText: s.s02Placeholder,
                        hintStyle: AppText.style(20, weight: FontWeight.w700, color: AppColors.ink3),
                      ),
                    ),
                    trailing: AppButton(
                      s.s02Suggest,
                      key: const Key('rename-suggest'),
                      icon: 'sparkle',
                      block: true,
                      onPressed: _suggest,
                    ),
                  ),
                  if (short > 0) ...[
                    const SizedBox(height: 14),
                    // .warn-text.rn-warn：金幣不夠，還差多少
                    Row(
                      key: const Key('rename-short'),
                      children: [
                        const AppIcon('warn', size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(s.notEnoughCoins(n: fmt(short)), style: KitText.warn()),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Padding(
                    key: _confirm,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AppButton(
                      paid ? s.s21RenamePaid(price: fmt(price)) : s.s21RenameFree,
                      key: const Key('rename-confirm'),
                      kind: ButtonKind.primary,
                      block: true,
                      onPressed: ok ? () => _submit(check.name) : null,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
