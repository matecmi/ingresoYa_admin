import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

class EmptyCard extends StatelessWidget {
  const EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
