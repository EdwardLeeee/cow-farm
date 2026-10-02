// S02 自己取牧場名（D23；design/m2/src/js/screens/s02.js、screens.css 的 .namer、.name-card）。
// 長度用顯示寬度算（util/ranch_name.dart，跟伺服器同一套表）：總共 2–16，中文字算 2。
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../../util/name_tables.g.dart' show kNameMaxWidth;
import '../../util/ranch_name.dart';
import '../kit/cow_art.dart';
import '../kit/frame.dart';
import '../kit/kit.dart';

/// 輸入框、字數、提示（或錯誤）那一張卡的版面（.name-card）。S02 頁面和 S02-05 的錯誤一覽都用它。
class NameCard extends StatelessWidget {
  const NameCard({
    super.key,
    required this.field,
    required this.width,
    this.error,
    this.hint,
    this.focused = false,
    this.filled = false,
    this.trailing,
  });

  /// 輸入框裡面的東西（打字的 TextField，或一段字）。
  final Widget field;

  /// 顯示寬度（字數那格的 {w} / 16）。
  final int width;
  final String? error;
  final String? hint;
  final bool focused;
  final bool filled;

  /// 卡片最下面的按鈕（「幫我想一個」）。
  final Widget? trailing;

  static const _errLine = Color(0xFFD9443F);

  @override
  Widget build(BuildContext context) {
    final err = error != null;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: err ? const Color(0xFFFFF4F2) : Colors.white,
              border: Border.all(
                color: err ? _errLine : (focused ? const Color(0xFF3D8BD9) : AppColors.ink),
                width: AppSizes.border,
              ),
              borderRadius: const BorderRadius.all(AppRadii.r14),
              // 打字中：外面一圈 3px 的淡藍光
              boxShadow: focused && !err ? const [BoxShadow(color: Color(0xFFCFE6FF), spreadRadius: 3)] : null,
            ),
            child: field,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  error ?? hint ?? '',
                  style: err ? KitText.err(size: 12.5, lineHeight: 18) : KitText.hint(size: 12.5, lineHeight: 18),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$width / $kNameMaxWidth',
                style: AppText.number(14, color: width > kNameMaxWidth ? _errLine : AppColors.ink2),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ],
      ),
    );
  }
}

/// 名字的樣式（.name-input：20 號特粗）。
TextStyle nameInputStyle() => AppText.style(20, weight: FontWeight.w900);

/// 名字哪裡不能用 → 字串表的提示（S02-05）。
String nameProblemText(Strings s, NameProblem p) => switch (p) {
  NameProblem.tooShort => s.s02ErrShort,
  NameProblem.tooLong => s.s02ErrLong,
  NameProblem.emoji => s.s02ErrEmoji,
  NameProblem.badChar => s.s02ErrChar,
};

/// S02 的頁面：牛和標題、名字卡、同名說明、「就叫這個」。鍵盤開著時標題縮小、牛和說明收起來（S02-03）。
/// 鍵盤開著時，輸入框、字數和「就叫這個」都要在鍵盤上面看得到（m3-backlog）：每次版面變了（鍵盤打開、
/// 提示從一行變兩行）就捲到整顆按鈕看得到，標題可以捲出畫面（ceo 2026-10-02）。
class NamerPage extends StatefulWidget {
  const NamerPage({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.filled,
    required this.serverError,
    required this.onSuggest,
    required this.onConfirm,
    this.overlay,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 剛按了「幫我想一個」、還沒改過（提示換成「想好了！可以直接用，也可以再改。」）。
  final bool filled;

  /// 伺服器不收這個名字的原因（invalid_name），已經換成給玩家看的字。改名字就清掉。
  final String? serverError;
  final VoidCallback onSuggest;

  /// 名字可以用時才給（按鈕才會亮）。
  final ValueChanged<String> onConfirm;

  /// 疊在最上面的東西（S02-02 歡迎卡）。
  final Widget? overlay;

  @override
  State<NamerPage> createState() => _NamerPageState();
}

class _NamerPageState extends State<NamerPage> {
  final _confirm = GlobalKey();

  /// 鍵盤開著：捲到「就叫這個」整顆（含下面 4 的陰影）看得到；本來就看得到就不動。
  void _revealConfirm(Duration _) {
    final ctx = _confirm.currentContext;
    if (!mounted || ctx == null || MediaQuery.viewInsetsOf(context).bottom == 0) return;
    Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.focusNode]),
      builder: (context, _) {
        final text = widget.controller.text;
        final check = checkRanchName(text);
        final problem = text.isEmpty ? null : check.problem;
        final error = problem != null ? nameProblemText(s, problem) : widget.serverError;
        final ok = text.isNotEmpty && check.problem == null && widget.serverError == null;
        if (keyboard) WidgetsBinding.instance.addPostFrameCallback(_revealConfirm);
        return Stack(
          children: [
            Positioned.fill(child: PageBackground(safeTop: mq.padding.top)),
            Positioned.fill(
              top: mq.padding.top,
              bottom: keyboard ? mq.viewInsets.bottom : mq.padding.bottom,
              child: SingleChildScrollView(
                // 下面留 16（.content 的 padding）：按鈕外面那層已經包了 6（陰影），這裡只留 10
                padding: const EdgeInsets.fromLTRB(12, 4 + 6, 12, 16 - 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (keyboard)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(s.s02Title, style: AppText.style(20, weight: FontWeight.w900, lineHeight: 28)),
                      )
                    else
                      Row(
                        children: [
                          const CowPicture(breed: 'holstein', width: 84, height: 84),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.s02Title, style: AppText.style(22, weight: FontWeight.w900, lineHeight: 28)),
                                Text(s.s02Sub, style: KitText.hint()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    NameCard(
                      width: check.width,
                      error: error,
                      hint: widget.filled ? s.s02Filled : s.s02WidthRule,
                      focused: widget.focusNode.hasFocus,
                      field: TextField(
                        key: const Key('ranch-name'),
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        style: nameInputStyle(),
                        cursorColor: AppColors.ink,
                        cursorWidth: 2,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => ok ? widget.onConfirm(check.name) : null,
                        decoration: InputDecoration.collapsed(
                          hintText: s.s02Placeholder,
                          hintStyle: AppText.style(20, weight: FontWeight.w700, color: AppColors.ink3),
                        ),
                      ),
                      trailing: AppButton(
                        s.s02Suggest,
                        key: const Key('suggest'),
                        icon: 'sparkle',
                        block: true,
                        onPressed: widget.onSuggest,
                      ),
                    ),
                    if (!keyboard) ...[
                      const SizedBox(height: 14),
                      Text(s.s02SameName, textAlign: TextAlign.center, style: KitText.hint()),
                    ],
                    const SizedBox(height: 14),
                    Padding(
                      key: _confirm,
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppButton(
                        s.s02Confirm,
                        key: const Key('confirm-name'),
                        kind: ButtonKind.primary,
                        block: true,
                        onPressed: ok ? () => widget.onConfirm(check.name) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?widget.overlay,
          ],
        );
      },
    );
  }
}
