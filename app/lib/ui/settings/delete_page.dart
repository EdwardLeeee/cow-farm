// S13-03 刪除牧場（設計稿 s13.js 的 deletePage；screens.css 的 .del-card、.del-list、.field-label、.input）：
// 說明後果、輸入「刪除」兩個字（S13-06）才能按「刪除我的牧場」。刪除失敗（S13-05）在下面跳提示；
// 成功就整個換成 S13-04「牧場已經刪除了」（start/start_flow.dart）。Apple 5.1.1(v)：app 裡要能刪除帳號。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import 'settings_page.dart';

class DeletePage extends StatefulWidget {
  const DeletePage({super.key});

  @override
  State<DeletePage> createState() => _DeletePageState();
}

class _DeletePageState extends State<DeletePage> {
  final _word = TextEditingController();
  final _focus = FocusNode();
  final _confirm = GlobalKey();
  bool _deleting = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _word.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 打的字等於「刪除」（英文不分大小寫：手機鍵盤會把第一個字母變大寫）。
  bool _typed(String word) => _word.text.trim().toUpperCase() == word.toUpperCase();

  Future<void> _delete() async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    _focus.unfocus();
    setState(() => _deleting = true);
    final r = await m.deleteRanch();
    if (!mounted) return;
    setState(() => _deleting = false);
    switch (r.error) {
      case null:
        break; // 成功：整個畫面換成 S13-04
      case ApiActionError(:final error) when error.maintenance || error.unauthorized:
        break; // 整個畫面換成 S16-01／S14-05
      case _:
        _showToast(s.s13DelFailed); // S13-05：伺服器錯誤或斷線
    }
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// 鍵盤開著：捲到「刪除我的牧場」整顆看得到（m3-backlog：輸入框和按鈕都要在鍵盤上面）。
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
    final word = s.s13DelWord;
    // 鍵盤蓋住的部分（HomeShell 的 Scaffold 不幫忙讓位置）：內容下面多留這麼多，才捲得到按鈕
    final keyboard = (mq.viewInsets.bottom - mq.padding.bottom).clamp(0.0, double.infinity);
    if (keyboard > 0) WidgetsBinding.instance.addPostFrameCallback(_revealConfirm);
    return SettingsFrame(
      title: s.s13Delete,
      scrollKey: const Key('settings-delete'),
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
        _DeleteCard(name: m.ranchName),
        // 輸入「刪除」、兩顆按鈕（S13-06 的局部狀態就是這一塊）
        Column(
          key: const Key('delete-form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .field-label：字 14 特粗、行高 normal
            CssLine(
              TextSpan(
                text: s.s13DelPrompt(word: word),
                style: AppText.style(14, weight: FontWeight.w900),
              ),
              wrap: true,
            ),
            const SizedBox(height: AppSizes.gap),
            _WordField(controller: _word, focusNode: _focus, hint: word),
            const SizedBox(height: AppSizes.gap),
            ListenableBuilder(
              listenable: _word,
              builder: (context, _) => KeyedSubtree(
                key: _confirm,
                child: AppButton(
                  s.s13Delete,
                  key: const Key('delete-confirm'),
                  kind: ButtonKind.danger,
                  block: true,
                  icon: 'trash',
                  busy: _deleting,
                  onPressed: _typed(word) && m.canAct ? _delete : null,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            AppButton(
              s.cancel,
              key: const Key('delete-cancel'),
              block: true,
              onPressed: _deleting ? null : m.settingsBack,
            ),
          ],
        ),
      ],
    );
  }
}

/// .del-card：牛、「刪除後不能復原」（紅字）、四條後果。
class _DeleteCard extends StatelessWidget {
  const _DeleteCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      key: const Key('delete-card'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CowPicture(breed: 'holstein', width: 96, height: 96)),
          const SizedBox(height: 4),
          // 一行放得下就照 Chrome 的行高排（Flutter 的基線比設計稿低 1）；放不下照一般的換行、置中
          Center(
            child: CssLine(
              TextSpan(
                text: s.s13DelTitle,
                style: AppText.style(18, weight: FontWeight.w900, color: KitText.errText, lineHeight: 26),
              ),
              wrap: true,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in [s.s13DelItem1(name: name), s.s13DelItem2, s.s13DelItem3, s.s13DelItem4]) _Bullet(item),
        ],
      ),
    );
  }
}

/// .del-list 的一條：左邊留 20，圓點（直徑 5）在左邊 3、第一行的上面 8；字 14、行高 22。
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 3, top: 8, right: 12),
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
        ),
      ),
      Expanded(
        child: CssParagraph(
          TextSpan(children: cjkTrimSpans(text)),
          style: AppText.style(14, weight: FontWeight.w700, lineHeight: 22),
        ),
      ),
    ],
  );
}

/// .input：白底、框 3、圓角 14、至少 52 高；字 20 特粗，還沒打字時顯示淡色的「刪除」。
class _WordField extends StatelessWidget {
  const _WordField({required this.controller, required this.focusNode, required this.hint});

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.ink, width: AppSizes.border),
      borderRadius: const BorderRadius.all(AppRadii.r14),
    ),
    child: TextField(
      key: const Key('delete-word'),
      controller: controller,
      focusNode: focusNode,
      style: AppText.style(20, weight: FontWeight.w900),
      cursorColor: AppColors.ink,
      cursorWidth: 2,
      cursorHeight: 24,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: AppText.style(20, weight: FontWeight.w700, color: AppColors.ink3),
      ),
    ),
  );
}
