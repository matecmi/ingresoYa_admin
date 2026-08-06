
import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/Icon_mini_btn.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/pill_state.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    required this.course,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final CourseEntity course;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white.withOpacity(.92),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                           //PillState(active: true,),

                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit),
                const SizedBox(width: 8),
                IconMiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

