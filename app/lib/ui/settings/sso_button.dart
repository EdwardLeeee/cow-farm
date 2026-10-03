// Apple／Google 登入按鈕（設計稿 s13.js 的 sso；screens.css 的 .sso、.sso.apple、.sso.google、.sso-mark）。
// 備份牧場（S13-02）和之後的找回牧場（S14-02）共用。
//
// 照核准的設計稿畫：Apple 黑底白字、Google 白底細外框，兩顆一樣大，48 高、圓角 16、字 17、標誌和字隔 8。
// 字照 #126：Apple、Google 各自一個 key（s13.ssoApple、s13.ssoGoogle，照官方的叫法）；Apple 粗（700），Google 是 Medium
// （500，Google 規範 40 高、Google Sans Medium 14／20 等比例放大到 48 高；ceo 2026-10-03）。
// 設計稿的虛線方塊是標誌的位置，放官方的標誌：
// - Apple：sign_in_with_apple 套件的 AppleLogoPainter（套件的按鈕寫死 .SF Pro Text 字型，字照設計稿就自己排）。
// - Google：Google 官方素材包（signin-assets.zip，2026-04 版）的「G」，原樣切出來不縮放、不改色（m3-backlog：可以內建
//   官方的 G、註明來源）。assets/sso/ 的 1x～4x 各對應素材包的同一種解析度。
// Google Sans 能不能放進 app 要先確認授權，確認前用 app 的字型（#126）。
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show AppleLogoPainter;

import '../../auth/sign_in.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../kit/kit.dart';
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
    final label = apple ? s.s13SsoApple : s.s13SsoGoogle;
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
                      style: AppText.style(
                        17,
                        weight: apple ? FontWeight.w700 : FontWeight.w500,
                        lineHeight: 22,
                        color: fg,
                      ),
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

/// .sso-area：登入按鈕一顆一顆往下排（間距 12），下面一行說明（間距 10）。[hint] 是按鈕和說明中間多的一句
/// （S14-07 Android 的提醒）。[onTap] 是 null 就全部停用。
class SsoArea extends StatelessWidget {
  const SsoArea({super.key, required this.providers, required this.onTap, this.hint, this.offline = false});

  final List<SignInProvider> providers;
  final void Function(SignInProvider)? onTap;
  final String? hint;

  /// 斷線（S13-21）：按鈕停用（[onTap] 給 null），最下面那行換成「連上網路以後才能登入」。
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final tap = onTap;
    return Column(
      key: const Key('sso-area'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, p) in providers.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          SsoButton(key: Key('sso-${p.wire}'), provider: p, onTap: tap == null ? null : () => tap(p)),
        ],
        if (hint case final h?) ...[
          const SizedBox(height: 10),
          Text(h, key: const Key('sso-hint'), style: KitText.hint()),
        ],
        const SizedBox(height: 10),
        if (offline)
          Text(s.s13SsoOffline, key: const Key('sso-offline'), textAlign: TextAlign.center, style: KitText.hint())
        else
          Text(s.s13Privacy, textAlign: TextAlign.center, style: KitText.hint()),
      ],
    );
  }
}

/// .card.sso-busy：登入畫面關掉以後、等伺服器回覆（S13-15「綁定中…」、S14-06「登入中…」）。最少 108 高。
class SsoBusyCard extends StatelessWidget {
  const SsoBusyCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
    child: ConstrainedBox(
      // min-height 108 含上下內距 10、12 和框 3
      constraints: const BoxConstraints(minHeight: 108 - 10 - 12 - 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spinner(),
          const SizedBox(width: 10),
          Text(text, style: AppText.style(16, weight: FontWeight.w900)),
        ],
      ),
    ),
  );
}
