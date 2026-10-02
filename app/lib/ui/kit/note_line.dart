// 一行說明或提醒（screens.css 的 .rule-line 粉紅底、.rule-line.shop-rule 藍底、.note-line 橘底）：配種、商店的規則，牛舍滿了、牛的詳細的橘字提醒。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_icon.dart';
import 'kit.dart';

enum NoteKind { info, rule, warn }

/// .rule-line（粉紅底，配種的規則）、.rule-line.shop-rule（藍底，說明）、.note-line（橘底，提醒）：圖示加一句。
class NoteLine extends StatelessWidget {
  const NoteLine({super.key, required this.icon, required this.text, required this.kind});

  final String icon;
  final String text;
  final NoteKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, line) = switch (kind) {
      NoteKind.info => (const Color(0xFFEAF5FF), const Color(0xFFA9D2F2)),
      NoteKind.rule => (const Color(0xFFFFE9F0), const Color(0xFFF5B5C8)),
      NoteKind.warn => (const Color(0xFFFFF1DC), const Color(0xFFF3C98F)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line, width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r12),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 6),
          // 一行放得下就照 Chrome 的行高排（字才不會比設計稿低半格）；放不下照一般的換行
          Expanded(
            child: CssLine(
              TextSpan(
                text: text,
                style: kind == NoteKind.warn
                    ? KitText.warn()
                    : AppText.style(13, weight: FontWeight.w900, lineHeight: 18),
              ),
              wrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
