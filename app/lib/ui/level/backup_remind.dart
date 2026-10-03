// S11-05 升到 Lv2 以後提醒備份牧場（設計稿 s10.js 的 S11-05；kit.js 的 dialog、screens.css 的 .bk-pic）：
// 對話框「把牧場備份起來」、荷斯坦（110）、「換手機或手機壞了都找得回來。」、「之後再說」「現在備份」。
// 什麼時候出（企劃書 4.11，D22）：Lv2 以上的慶祝卡（S11-01）按「好」以後跳一次；一次升好幾級跳過 Lv2 的，下一張慶祝卡關掉時出。
// 只在能登入的建置（設好 client ID；網頁試玩版沒有備份功能）、牧場還沒綁任何帳號、這支手機還沒對這個牧場提醒過的時候出現。
// 「現在備份」到備份牧場頁（S13-02）；「之後再說」關掉。按哪一個都算提醒過，以後不再出。
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';

class BackupRemindDialog extends StatelessWidget {
  const BackupRemindDialog({super.key, required this.onLater, required this.onNow});

  final VoidCallback onLater;
  final VoidCallback onNow;

  /// 升到 [level] 的慶祝卡關掉時要不要提醒。
  static bool shouldRemind(GameModel m, SettingsController settings, int level) {
    final st = m.state;
    return level >= 2 && st != null && m.canSignIn && m.accountLinks.isEmpty && !settings.backupReminded(st.playerId);
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AppDialog(
      key: const Key('backup-remind'),
      title: s.s11BackupTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .bk-pic：牛置中，下面留 4
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Center(child: CowPicture(breed: 'holstein', width: 110, height: 110)),
          ),
          // 對話框的字（14／21）照 Chrome 的基線
          CssParagraph(
            TextSpan(text: s.s11BackupBody),
            style: AppText.style(14, weight: FontWeight.w700, lineHeight: 21),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      buttons: [
        AppButton(s.s11Later, key: const Key('backup-later'), onPressed: onLater),
        AppButton(s.s11BackupNow, key: const Key('backup-now'), kind: ButtonKind.primary, onPressed: onNow),
      ],
    );
  }
}
