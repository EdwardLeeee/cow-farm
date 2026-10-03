// Apple／Google 登入按鈕（設計稿 s13.js 的 sso；screens.css 的 .sso、.sso.apple、.sso.google、.sso-mark）。
// 備份牧場（S13-02）和之後的找回牧場（S14-02）共用。
//
// 照核准的設計稿畫：Apple 黑底白字、Google 白底細外框，兩顆一樣大，48 高、圓角 16、字 17 粗、標誌和字隔 8。
// 設計稿的虛線方塊是標誌的位置，放官方的標誌：
// - Apple：sign_in_with_apple 套件的 AppleLogoPainter（套件的按鈕寫死 .SF Pro Text 字型，字照設計稿就自己排）。
// - Google：Google 官方素材包（signin-assets.zip，2026-04 版）的「G」，原樣切出來不縮放、不改色（m3-backlog：可以內建
//   官方的 G、註明來源）。assets/sso/ 的 1x～4x 各對應素材包的同一種解析度。
// Google 規格的字是 Google Sans Medium 14／20，設計稿是 17 粗；字級由 cow-ui 定（ceo 2026-10-03），先照設計稿。
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show AppleLogoPainter;

import '../../auth/sign_in.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/press.dart';

class SsoButton extends StatelessWidget {
  const SsoButton({super.key, required this.provider, required this.onTap});

  final SignInProvider provider;

  /// null 是停用（斷線、處理中）：整顆變淡、按了沒反應。
  final VoidCallback? onTap;

  static const _googleLine = Color(0xFF747775);
  static const _googleText = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final apple = provider == SignInProvider.apple;
    final fg = apple ? Colors.white : _googleText;
    final label = s.s13SsoSignIn(name: provider.label);
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          builder: (context, look) => PressTint(
            tint: look.tint,
            borderRadius: const BorderRadius.all(AppRadii.r16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: apple ? Colors.black : Colors.white,
                border: apple ? null : Border.all(color: _googleLine, width: 1),
                borderRadius: const BorderRadius.all(AppRadii.r16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(dimension: 20, child: apple ? const _AppleMark() : const _GoogleMark()),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: AppText.style(17, weight: FontWeight.w700, lineHeight: 22, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple 標誌：寬高比照套件的按鈕（25：31），高 20 放進 20×20 的位置。
class _AppleMark extends StatelessWidget {
  const _AppleMark();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 20 * 25 / 31,
      height: 20,
      child: CustomPaint(painter: AppleLogoPainter(color: Colors.white)),
    ),
  );
}

/// Google 的「G」：官方素材包原樣（20×20，白底就是按鈕的白底）。
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/sso/google_g.png', width: 20, height: 20, filterQuality: FilterQuality.medium);
}
