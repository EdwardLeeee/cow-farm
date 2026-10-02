// 一行說明或提醒（screens.css 的 .rule-line.shop-rule 藍底、.note-line 橘底）：商店的規則、牛舍滿了、牛的詳細的橘字提醒。
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_icon.dart';
import 'kit.dart';

enum NoteKind { info, warn }

/// .rule-line.shop-rule（藍底，說明）、.note-line（橘底，提醒）：圖示加一句。
class NoteLine extends StatelessWidget {
  const NoteLine({super.key, required this.icon, required this.text, required this.kind});

  final String icon;
  final String text;
  final NoteKind kind;

  @override
  Widget build(BuildContext context) {
    final info = kind == NoteKind.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info ? const Color(0xFFEAF5FF) : const Color(0xFFFFF1DC),
        border: Border.all(color: info ? const Color(0xFFA9D2F2) : const Color(0xFFF3C98F), width: 2),
        borderRadius: const BorderRadius.all(AppRadii.r12),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: info ? AppText.style(13, weight: FontWeight.w900, lineHeight: 18) : KitText.warn(),
            ),
          ),
        ],
      ),
    );
  }
}
