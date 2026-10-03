// S11-03 新手引導卡（設計稿 s10.js 的 S11-03；screens.css 的 .coach、.coach-ic、.coach-go）。
// 規則（cow-app 的提案，ceo 2026-10-03 同意；design/m2/scope.md 的 S11）：
// - 伺服器沒有送「該跳提示了」的訊號，app 從 state 看：
//   1.「牛舍可以擴建了」：還沒擴建過，第一次擴建開放了（pen.next_open_at 到了，教學第 15 分鐘）。
//   2.「小公牛長大了」：開局那頭小公耕牛（origin start、公的、兼用）長大了，還沒配種、沒下田、沒上架。
// - 放在牧場頁、跑馬燈下面，左右各 12，蓋在場景上；不在牧場頁時等回到牧場頁再出。跟大新聞（S03-15）一樣在最上層：
//   很矮的手機（320 × 568）英文、泰文的卡片比較高，會暫時蓋到面板的上緣，按鈕和 × 都點得到。
// - 一次一張：兩張都到時間時先出擴建那張，關掉以後才出下一張。
// - 右上角一個小 ×（點得到的範圍 44 × 44；設計稿沒畫 ×，做成貼在卡片角上的小圓章）。按 × 或按卡上的按鈕（去擴建、去配種）都算看過，以後不再出；
//   記在手機上，照牧場分開。
// - × 是另一個元件 [CoachClose]，牧場頁放在卡片的右上角：點得到的範圍大部分在卡片外面（卡片裡右上角放不下 44 × 44：
//   按鈕垂直置中，上緣離卡片上緣最少 19），包在卡片裡 Flutter 會點不到。卡片 [CoachCard] 就是設計稿局部表畫的樣子。
import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/format.dart';
import '../../l10n/l10n.dart';
import '../../state/game_model.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/cow_art.dart';
import '../kit/kit.dart';
import '../kit/press.dart';

/// 哪一張引導卡。[id] 是記在手機上的名字。
enum CoachKind {
  pen('pen'),
  bull('bull');

  const CoachKind(this.id);
  final String id;
}

/// 現在該出的引導卡（沒有是 null）：先擴建、再小公牛；看過的不出。
CoachKind? coachToShow(GameModel m, SettingsController settings) {
  final st = m.state;
  if (st == null) return null;
  final now = m.gameNow;
  final id = st.playerId;
  if (!settings.coachSeen(CoachKind.pen.id, id)) {
    final pen = st.upgrades[UpgradeKind.pen];
    final never = (pen?.level ?? 0) == 0;
    final openAt = st.pen.nextOpenAt;
    // 已經滿級（沒有價格）就不提
    if (never && st.pen.nextCost != null && (openAt == null || now >= openAt)) return CoachKind.pen;
  }
  if (!settings.coachSeen(CoachKind.bull.id, id)) {
    for (final c in st.cows) {
      if (c.origin != 'start' || !c.bull || c.type != CowType.dual) continue;
      final grown = c.stage != CowStage.calf || (c.adultAt != null && now >= c.adultAt!);
      if (grown && !c.bred && c.fieldIndex == null && c.listedId == null) return CoachKind.bull;
    }
  }
  return null;
}

/// .coach：牛臉圓圈、標題和說明、右邊小按鈕（× 是 [CoachClose]）。
class CoachCard extends StatelessWidget {
  const CoachCard({super.key, required this.kind, this.penPrice, required this.onGo});

  final CoachKind kind;

  /// 擴建牛舍要多少幣（「到『商店 › 設施』擴建牛舍（{price} 幣）」）。
  final double? penPrice;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pen = kind == CoachKind.pen;
    final title = pen ? s.s11CoachPenTitle : s.s11CoachBullTitle;
    final body = pen ? s.s11CoachPenBody(price: fmt(penPrice ?? 0)) : s.s11CoachBullBody;
    return Container(
      key: Key('coach-${kind.id}'),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink, width: AppSizes.border),
        borderRadius: const BorderRadius.all(AppRadii.r18),
        boxShadow: AppShadows.solid(4),
      ),
      child: Row(
        children: [
          _CoachFace(pen: pen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // .coach b 是行內的字：這一行的高度和基線也算外層的字（沒設字級：16、行高 normal，CSS 的 strut），
                // 是 24 高、基線在 19（Chrome 的算法，CssLine），不是 20
                CssLine(
                  TextSpan(
                    style: AppText.style(16),
                    children: [
                      TextSpan(
                        text: title,
                        style: AppText.style(15, weight: FontWeight.w700, lineHeight: 20),
                      ),
                    ],
                  ),
                  wrap: true,
                ),
                const SizedBox(height: 2),
                // 相鄰的全形標點擠掉半格（「（自己的免費），」），跟設計稿（Chrome）一樣
                Text.rich(TextSpan(children: cjkTrimSpans(body)), style: KitText.hint()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            pen ? s.s11CoachPenGo : s.s11CoachBullGo,
            key: Key('coach-go-${kind.id}'),
            small: true,
            kind: pen ? ButtonKind.primary : ButtonKind.pink,
            onPressed: onGo,
          ),
        ],
      ),
    );
  }
}

/// 引導卡右上角的 ×（設計稿的狀態表沒畫 ×，照 scope.md 加）：白色小圓章（直徑 24），圓心在卡片的右上角。
/// 整個是點得到的範圍（44 × 44）：比卡片上緣高 [outTop]、比卡片右緣多 [outRight]，放的時候照這兩個數字對齊卡片。
class CoachClose extends StatelessWidget {
  const CoachClose({super.key, required this.onTap});

  /// 往上 26：範圍的下緣在卡片上緣下面 18，碰不到按鈕；上面是跑馬燈，點了沒有動作。
  static const outTop = 26.0;

  /// 往右 12：卡片離螢幕右邊 12，範圍不超出螢幕。
  static const outRight = 12.0;

  static const _badge = 24.0;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: Strings.of(context).gClose,
    child: Pressable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      builder: (context, look) => SizedBox(
        width: AppSizes.minTouch,
        height: AppSizes.minTouch,
        child: Stack(
          children: [
            Positioned(
              right: outRight - _badge / 2,
              top: outTop - _badge / 2,
              child: PressTint(
                tint: look.tint,
                shape: BoxShape.circle,
                child: Container(
                  width: _badge,
                  height: _badge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 2.5),
                  ),
                  child: const AppIcon('close', size: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// .coach-ic：56 的圓（淡藍底、框 2.5），擴建是荷斯坦，小公牛是台灣黃牛的小公牛。
/// 56 的牛圖放進框裡 51 的空間：CSS 的 grid 格子照內容撐成 56，place-items: end center 在撐大的格子裡沒有作用，
/// 所以牛圖貼在左上角、往右下超出 5 被圓裁掉（設計稿 Chrome 畫出來的樣子）。
class _CoachFace extends StatelessWidget {
  const _CoachFace({required this.pen});

  final bool pen;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFBFE6FF),
      border: Border.all(color: AppColors.ink, width: 2.5),
    ),
    child: ClipOval(
      child: OverflowBox(
        maxWidth: 56,
        maxHeight: 56,
        alignment: Alignment.topLeft,
        child: pen
            ? const CowPicture(breed: 'holstein', width: 56, height: 56)
            : const CowPicture(breed: 'yellow', bull: true, width: 56, height: 56),
      ),
    ),
  );
}
