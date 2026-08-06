import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/mini_btn.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_pro.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';


class RowCard extends StatelessWidget {
  const RowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rightPill,
    required this.rightPillTone,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String rightPill;
  final PillTone rightPillTone;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppTheme.accent : Colors.white.withOpacity(.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: AppTheme.cardDeco(radius: 22).copyWith(
        color: selected ? AppTheme.accent.withOpacity(.10) : null,
        border: Border.all(color: border, width: selected ? 2.2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 5,
                height: 90,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.accent.withOpacity(.20)
                              : Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppTheme.accent.withOpacity(.50)
                                : Colors.white.withOpacity(.10),
                          ),
                        ),
                        child: Icon(
                          selected ? Icons.check_circle_rounded : icon,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: selected ? 15.5 : 14,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.70),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                fontSize: 12.5,
                              ),
                            ),

                            const SizedBox(height: 8),

                            PillPro(
                              text: selected ? '✓ Seleccionado' : rightPill,
                              tone: selected ? PillTone.good : rightPillTone,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),
                      if (onEdit != null)
                        MiniBtn(icon: Icons.edit_rounded, onTap: onEdit!),

                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        MiniBtn(
                          icon: Icons.delete_outline_rounded,
                          onTap: onDelete!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
