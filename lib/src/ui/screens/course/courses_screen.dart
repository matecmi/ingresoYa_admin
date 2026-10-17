import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_card.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/search_bar.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/confirm_pro.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepoProvider);

    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: AppTheme.headerGradient(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Cursos',
                    style: TextStyle(
                      color: AppTheme.ink.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                _GlassBtn(
                  icon: Icons.add_rounded,
                  label: 'Crear',
                  onTap: () => _openCourseForm(context),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: SearchBarCourse(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              onClear: () {
                _search.clear();
                setState(() => _q = '');
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<List<CourseEntity>>(
              stream: repo.watchCourses(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? const [];

                final filtered = _q.trim().isEmpty
                    ? all
                    : all.where((c) {
                        final q = _q.toLowerCase();
                        return c.name.toLowerCase().contains(q) ||
                            c.description.toLowerCase().contains(q) ||
                            c.idDoc.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: AppTheme.cardDeco(radius: 22),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No hay cursos (o tu búsqueda no encontró resultados).',
                        style: TextStyle(
                          color: AppTheme.ink.withOpacity(.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return CourseCard(
                      course: c,
                      onOpen: () => context.go('/courses/${c.id}'),
                      onEdit: () => _openCourseForm(context, c: c),
                      onDelete: () => _deleteCourse(context, c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCourse(BuildContext context, CourseEntity c) async {
    final ok = await confirmPro(
      context,
      title: 'Eliminar curso',
      message: 'Se eliminará "${c.name}" junto a sus temas y subtemas.',
      primary: 'Eliminar',
    );
    if (!ok) return;

    try {
      await ref.read(courseRepoProvider).deleteCourse(c.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
      );
      return;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Eliminado ✅')));
  }

  Future<void> _openCourseForm(BuildContext context, {CourseEntity? c}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => CourseFormSheet(course: c),
    );
  }
}

// ---------- UI atoms (igual estilo que tus otros módulos) ----------

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
