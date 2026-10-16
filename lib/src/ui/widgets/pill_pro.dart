import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';

class PillPro extends StatelessWidget {
  const PillPro({required this.text, this.tone = PillTone.neutral});
  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (tone == PillTone.good) {
      bg = const Color(0xFF22C55E).withOpacity(.14);
      border = const Color(0xFF22C55E).withOpacity(.35);
    } else if (tone == PillTone.bad) {
      bg = const Color(0xFFEF4444).withOpacity(.14);
      border = const Color(0xFFEF4444).withOpacity(.35);
    } else {
      bg = AppTheme.ink.withOpacity(.06);
      border = AppTheme.ink.withOpacity(.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.ink.withOpacity(.90),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
