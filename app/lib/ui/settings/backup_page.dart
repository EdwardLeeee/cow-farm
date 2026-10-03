// S13 備份牧場（設計稿 s13.js 的 backupPage；D22，協定 5.0–5.4）：綁定 Apple／Google 帳號，換手機或重裝後用它找回牧場。
// 設定主頁的「備份牧場」打開；只有設好 client ID 的建置有這一頁（GameModel.canSignIn）。
// - S13-02 還沒綁定（iPhone 兩顆登入按鈕）、S13-11 Android 只有 Google。
// - S13-07 綁了 Apple（還能再綁 Google）、S13-14 兩種都綁了、S13-16 Android 只綁 Google、S13-19 Android 只綁 Apple。
// - S13-15 綁定中（登入畫面關掉以後等伺服器）、S13-12 結果的提示。
// - S13-08 帳號已經綁了別的牧場 → S13-09 換回前再確認；S13-13 解除綁定的確認。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../auth/sign_in.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_bits.dart';
import '../kit/kit.dart';
import '../kit/note_line.dart';
import '../widgets/action_button.dart';
import 'settings_kit.dart';
import 'settings_page.dart';
import 'sso_button.dart';

/// 牧場有沒有綁 [p]。
bool linkedTo(List<AccountLink> links, SignInProvider p) => links.any((l) => l.provider == p.wire);

/// 設定主頁和備份牧場頁的牧場卡右邊：「已備份」綠標或「還沒備份」橘標（S13-10）。
class BackupBadge extends StatelessWidget {
  const BackupBadge({super.key, required this.backed});

  final bool backed;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return CowBadge(
      backed ? BadgeKind.working : BadgeKind.listed,
      backed ? s.s13Backed : s.s13NotBacked,
      key: const Key('backup-status'),
    );
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  ({ToastKind kind, String text})? _toast;
  Timer? _toastTimer;

  /// 帳號已經綁了別的牧場（S13-08）；[_confirmSwitch] 是按了「換回那個牧場」以後的再確認（S13-09）。
  LinkConflict? _conflict;
  bool _confirmSwitch = false;
  bool _switching = false;

  /// 正在確認要不要解除的帳號（S13-13）。
  SignInProvider? _unbind;
  bool _unbinding = false;

  @override
  void initState() {
    super.initState();
    // 打開過這一頁，頂列齒輪的小點（G-10）就不再出現
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsController>().markBackupSeen();
    });
  }

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

  /// 按登入按鈕：結果照 S13-12 跳提示；帳號已經綁了別的牧場跳 S13-08。
  Future<void> _bind(SignInProvider p) async {
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    final r = await m.bindAccount(p);
    if (!mounted) return;
    switch (r.status) {
      case BindStatus.bound:
        _showToast(ToastKind.ok, s.s13ToastBound(name: p.label));
      case BindStatus.cancelled:
        _showToast(ToastKind.info, s.s13ToastCancelled);
      case BindStatus.failed:
        _showToast(ToastKind.err, s.s13ToastFailed);
      case BindStatus.conflict:
        setState(() {
          _conflict = r.conflict;
          _confirmSwitch = false;
        });
      case BindStatus.error:
        final e = r.error;
        // 維護、token 失效：整個畫面會換掉；其他照一般的錯誤提示
        if (e is ApiActionError && (e.error.maintenance || e.error.unauthorized)) return;
        if (e != null) _showToast(ToastKind.err, actionErrorTextWith(s, m, e));
    }
  }

  /// S13-09 按「換回，並刪除現在的牧場」：成功整個畫面換成那個牧場；失敗留在這裡、跳提示。
  Future<void> _switch() async {
    final c = _conflict;
    if (c == null) return;
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    setState(() => _switching = true);
    final r = await m.switchRanch(c);
    if (!mounted) return;
    setState(() => _switching = false);
    final e = r.error;
    if (e == null) return; // 換好了：設定頁已經關掉
    if (e is ApiActionError && (e.error.maintenance || e.error.unauthorized)) return;
    // 沒收到回應：留著對話框，再按一次原封不動重送（GameModel.switchRanch）；ticket 過期、用過了就關掉重來
    if (e is! NetworkActionError) setState(() => _conflict = null);
    _showToast(ToastKind.err, actionErrorTextWith(s, m, e));
  }

  Future<void> _doUnbind() async {
    final p = _unbind;
    if (p == null) return;
    final m = context.read<GameModel>();
    final s = Strings.of(context, listen: false);
    setState(() => _unbinding = true);
    final r = await m.unlinkAccount(p);
    if (!mounted) return;
    setState(() {
      _unbinding = false;
      _unbind = null;
    });
    final e = r.error;
    if (e == null) {
      _showToast(ToastKind.ok, s.s13ToastUnbound(name: p.label));
    } else if (!(e is ApiActionError && (e.error.maintenance || e.error.unauthorized))) {
      _showToast(ToastKind.err, actionErrorTextWith(s, m, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<GameModel>();
    final s = Strings.of(context);
    final mq = MediaQuery.of(context);
    final links = m.accountLinks;
    // 綁了的帳號各一列，Apple 在上（Android 綁過 Apple 才有 Apple 那一列，S13-19）
    final bound = [
      for (final p in SignInProvider.values)
        if (linkedTo(links, p)) p,
    ];
    // 還沒綁的才有登入按鈕（Android 本來就沒有 Apple）
    final todo = [
      for (final p in m.signInPlatform.providers)
        if (!bound.contains(p)) p,
    ];
    final busy = m.binding;
    final canTap = m.canAct;
    final onlyApple = bound.length == 1 && bound.single == SignInProvider.apple;
    final android = m.signInPlatform == SignInPlatform.android;
    return SettingsFrame(
      title: s.s13BackupTitle,
      scrollKey: const Key('settings-backup'),
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
        if (_conflict case final c? when !_confirmSwitch) _otherRanchDialog(s, c),
        if (_conflict case final c? when _confirmSwitch) _switchDialog(s, m, c),
        if (_unbind case final p?) _unbindDialog(s, p, last: bound.length == 1),
      ],
      children: [
        MeCard(
          name: m.ranchName,
          meta: ranchMeta(s, m),
          trailing: BackupBadge(backed: bound.isNotEmpty),
        ),
        Column(
          key: const Key('bk-body'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _gap(12, [
            if (bound.isEmpty) ...[
              _Lead(s.s13BackupLead),
              NoteLine(icon: 'warn', text: s.s13BackupWarn, kind: NoteKind.warn),
            ] else ...[
              _Lead(s.s13BackupDone),
              AppCard(
                key: const Key('bind-list'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in bound.indexed)
                      _BindRow(
                        key: Key('bind-${p.wire}'),
                        provider: p,
                        linkedAtReal: links.firstWhere((l) => l.provider == p.wire).linkedAtReal,
                        divider: i > 0,
                        onUnbind: canTap ? () => setState(() => _unbind = p) : null,
                      ),
                  ],
                ),
              ),
            ],
            // 只綁了 Apple：iPhone 提醒以後換 Android 要再綁 Google；Android 提醒找回要用 Google（S13-19）
            if (onlyApple)
              Text(
                android ? s.s13BackupAddGoogleAndroid : s.s13BackupAddGoogle,
                key: const Key('backup-more'),
                style: KitText.hint(),
              ),
            if (busy)
              const _BusyCard(key: Key('sso-busy'))
            else if (todo.isNotEmpty)
              Column(
                key: const Key('sso-area'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, p) in todo.indexed) ...[
                    if (i > 0) const SizedBox(height: 12),
                    SsoButton(key: Key('sso-${p.wire}'), provider: p, onTap: canTap ? () => _bind(p) : null),
                  ],
                  const SizedBox(height: 10),
                  Text(s.s13Privacy, textAlign: TextAlign.center, style: KitText.hint()),
                ],
              ),
            if (bound.isEmpty && !busy)
              NoteLine(key: const Key('backup-before'), icon: 'info', text: s.s13BackupBefore, kind: NoteKind.info),
          ]),
        ),
      ],
    );
  }

  /// S13-08：這個帳號已經備份了另一個牧場。
  Widget _otherRanchDialog(Strings s, LinkConflict c) => AppDialog(
    title: s.s13OtherTitle,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtherRanch(ranch: c.ranch),
        const SizedBox(height: 10),
        _DialogText(s.s13OtherBody),
        const SizedBox(height: 14),
        AppButton(
          s.s13OtherSwitch,
          key: const Key('switch-go'),
          kind: ButtonKind.primary,
          block: true,
          onPressed: () => setState(() => _confirmSwitch = true),
        ),
        const SizedBox(height: 10),
        AppButton(
          s.cancel,
          key: const Key('switch-cancel'),
          block: true,
          onPressed: () => setState(() => _conflict = null),
        ),
      ],
    ),
  );

  /// S13-09：換回前再確認，這支手機現在的牧場會刪除。
  Widget _switchDialog(Strings s, GameModel m, LinkConflict c) {
    final here = [m.ranchName, ?Strings.ranchTag(RanchRef(playerId: m.state?.playerId))].join(' ');
    final there = [s.ranchName(c.ranch), ?Strings.ranchTag(c.ranch)].join(' ');
    return AppDialog(
      title: s.s13SwitchTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteLine(
            icon: 'warn',
            iconSize: 20,
            text: s.s13SwitchWarn(name: here),
            kind: NoteKind.danger,
          ),
          const SizedBox(height: 8),
          _DialogText(s.s13SwitchAfter(name: there)),
          const SizedBox(height: 14),
          AppButton(
            s.s13SwitchConfirm,
            key: const Key('switch-confirm'),
            kind: ButtonKind.danger,
            block: true,
            busy: _switching,
            onPressed: m.canAct || _switching ? _switch : null,
          ),
          const SizedBox(height: 10),
          AppButton(
            s.cancel,
            key: const Key('switch-cancel'),
            block: true,
            onPressed: _switching ? null : () => setState(() => _conflict = null),
          ),
        ],
      ),
    );
  }

  /// S13-13：解除綁定的確認；唯一綁定的帳號多一句「這個牧場就沒有備份了」。
  Widget _unbindDialog(Strings s, SignInProvider p, {required bool last}) => AppDialog(
    title: s.s13UnbindTitle(name: p.label),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogText(s.s13UnbindBody),
        if (last) ...[
          const SizedBox(height: 6),
          _DialogText(s.s13UnbindLast, key: const Key('unbind-last'), style: KitText.warn()),
        ],
      ],
    ),
    buttons: [
      AppButton(
        s.cancel,
        key: const Key('unbind-cancel'),
        onPressed: _unbinding ? null : () => setState(() => _unbind = null),
      ),
      AppButton(
        s.s13Unbind,
        key: const Key('unbind-confirm'),
        kind: ButtonKind.danger,
        busy: _unbinding,
        onPressed: _doUnbind,
      ),
    ],
  );
}

/// 每塊中間隔 [gap]（.bk-body 的 gap）。
List<Widget> _gap(double gap, List<Widget> children) => [
  for (final (i, c) in children.indexed) ...[if (i > 0) SizedBox(height: gap), c],
];

/// .bk-lead：一段說明（字 16 粗、行高 24，左右內縮 2）。
class _Lead extends StatelessWidget {
  const _Lead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(text, style: AppText.style(16, weight: FontWeight.w700, lineHeight: 24)),
  );
}

/// .bind-row：綁好的帳號一列（打勾、「Apple 帳號」、「已綁定・2026/10/01」、「解除」）。最少 62 高，第二列起上面是虛線。
class _BindRow extends StatelessWidget {
  const _BindRow({
    super.key,
    required this.provider,
    required this.linkedAtReal,
    required this.divider,
    required this.onUnbind,
  });

  final SignInProvider provider;
  final double? linkedAtReal;
  final bool divider;
  final VoidCallback? onUnbind;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final at = linkedAtReal;
    final date = at == null ? null : DateTime.fromMillisecondsSinceEpoch((at * 1000).round());
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: divider ? 60 : 62),
      child: Row(
        children: [
          const AppIcon('ok', size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.s13BackupAccount(name: provider.label),
                  style: AppText.style(16, weight: FontWeight.w900, lineHeight: 21),
                ),
                if (date != null)
                  Text(
                    s.s13BackupBoundOn(
                      date: s.dateYmd(
                        y: date.year,
                        m: date.month.toString().padLeft(2, '0'),
                        d: date.day.toString().padLeft(2, '0'),
                      ),
                    ),
                    style: KitText.hint(size: 12, lineHeight: 17),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppButton(s.s13Unbind, key: Key('unbind-${provider.wire}'), small: true, onPressed: onUnbind),
        ],
      ),
    );
    if (!divider) return row;
    return CustomPaint(
      painter: const DashedTopLine(),
      child: Padding(padding: const EdgeInsets.only(top: 2), child: row),
    );
  }
}

/// 對話框的內文（.dialog .body：14、粗、行高 21）。
final _dialogBody = AppText.style(14, weight: FontWeight.w700, lineHeight: 21);

/// 對話框裡的一段字：照 Chrome 的基線畫（14／21 的字 Flutter 比設計稿低 1.8，[CssParagraph]）。
class _DialogText extends StatelessWidget {
  const _DialogText(this.text, {super.key, this.style});

  final String text;

  /// 換字色、字級（例：.warn-text 13／19 橘字）；行高跟著換。
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      CssParagraph(TextSpan(text: text), style: style == null ? _dialogBody : _dialogBody.merge(style));
}

/// .other-ranch：S13-08 對話框裡那個牧場（頭像、「晨光河畔牧場 #1234」、「Lv 4」）。
class _OtherRanch extends StatelessWidget {
  const _OtherRanch({required this.ranch});

  final RanchRef ranch;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final name = [s.ranchName(ranch), ?Strings.ranchTag(ranch)].join(' ');
    return Container(
      key: const Key('other-ranch'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
      ),
      child: Row(
        children: [
          const SmallAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.style(16, weight: FontWeight.w700, lineHeight: 21)),
                // .hint 是對話框 .body 裡的一般文字：行高照 .body 的 14／21 算（設定頁的牧場卡是 16 的 normal）
                CssLine(
                  TextSpan(
                    style: _dialogBody,
                    children: [
                      TextSpan(
                        text: s.level(lv: ranch.level ?? 1),
                        style: KitText.hint(),
                      ),
                    ],
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

/// .card.sso-busy：綁定中…（S13-15；登入畫面關掉以後，等伺服器回覆）。
class _BusyCard extends StatelessWidget {
  const _BusyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 108 - 10 - 12 - 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spinner(),
            const SizedBox(width: 10),
            Text(s.s13Binding, style: AppText.style(16, weight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
