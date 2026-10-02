// S02-02 歡迎卡：牧場建好之後，送的牛、金幣、奶桶裡的牛奶、新手期加倍。數字都照伺服器建好牧場後回的 state（ceo 2026-10-02），
// 設計稿上的「乳牛 #1、黃牛小公牛 #2、100 幣、20 瓶」只是範例。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key, required this.model});

  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final st = model.state;
    final tag = Strings.ranchTag(RanchRef(playerId: st?.playerId));
    final name = tag == null ? model.ranchName : '${model.ranchName} $tag';
    return AppDialog(
      title: s.s02Welcome(name: name),
      body: st == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.s02Gifts, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, cow) in st.cows.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _Gift(cow: cow, model: model),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _CoinsAndMilk(state: st),
                if (st.bucket.boostMult != null && st.bucket.boostUntil != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.s02Boost(
                      // 新手期多長：照伺服器的遊戲時間算小時（正式版倍率 1，就是現實的小時）
                      h: math.max(1, ((st.bucket.boostUntil! - st.serverTime) / 3600).round()),
                      x: fmt(st.bucket.boostMult!, st.bucket.boostMult! % 1 == 0 ? 0 : 1),
                    ),
                    textAlign: TextAlign.center,
                    style: KitText.hint(),
                  ),
                ],
              ],
            ),
      buttons: [
        AppButton(
          s.gEnterRanch,
          key: const Key('enter-ranch'),
          kind: ButtonKind.primary,
          block: true,
          onPressed: model.enterRanch,
        ),
      ],
    );
  }
}

/// 一頭送的牛（.gift）：正面的圖、名字、公母和一句說明（母牛「會產奶」，小牛「{time}後長大」）。
class _Gift extends StatelessWidget {
  const _Gift({required this.cow, required this.model});

  final Cow cow;
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final id = cow.id is int ? cow.id as int : int.tryParse('${cow.id}') ?? 0;
    final calf = cow.stage == CowStage.calf;
    final adultAt = cow.adultAt;
    final String note;
    if (calf && adultAt != null) {
      // 倒數一律寫現實時間
      note = s.gGrowsIn(time: s.countdown((adultAt - model.gameNow) / model.timeScale));
    } else if (cow.milkPerH > 0) {
      note = s.s02GiftMilk;
    } else {
      note = '';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r16),
      ),
      child: Column(
        children: [
          CowPicture(breed: cow.breed, bull: cow.bull, calf: calf, variant: id, width: 96, height: 96),
          Text(
            s.cowName(cow.breed, id),
            textAlign: TextAlign.center,
            style: AppText.style(15, weight: FontWeight.w900, lineHeight: 20),
          ),
          Text(
            [cow.bull ? s.bull : s.cow, if (note.isNotEmpty) note].join(s.gSep),
            textAlign: TextAlign.center,
            style: KitText.hint(size: 12, lineHeight: 17),
          ),
        ],
      ),
    );
  }
}

/// .gift-coin：金幣、奶桶裡的牛奶（數字大一號、特粗）。
class _CoinsAndMilk extends StatelessWidget {
  const _CoinsAndMilk({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final base = AppText.style(13, weight: FontWeight.w700);
    final num = AppText.number(17);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        const AppIcon('coin', size: 26),
        Text.rich(
          TextSpan(
            style: base,
            children: fillSpans(s.costCoins(v: '\u0000'), num, fmt(state.coins)),
          ),
        ),
        const SizedBox(width: 13), // 全形空格
        const AppIcon('pail', size: 22),
        Text.rich(
          TextSpan(
            style: base,
            children: fillSpans(s.s02GiftBucket(n: '\u0000'), num, fmt(state.bucket.amount)),
          ),
        ),
      ],
    );
  }
}
