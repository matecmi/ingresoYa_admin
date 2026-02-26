import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_details_sheet.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

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
                      color: Colors.white.withOpacity(.92),
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
            child: _SearchBar(
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
                          color: Colors.white.withOpacity(.75),
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
                    return _CourseCard(
                      c: c,
                      onOpen: () => _openCourseDetails(context, c),
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
    final ok = await _confirmPro(
      context,
      title: 'Eliminar curso',
      message: 'Se eliminará "${c.name}" junto a sus temas y subtemas.',
      primary: 'Eliminar',
    );
    if (!ok) return;

    await ref.read(courseRepoProvider).deleteCourse(c.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eliminado ✅')),
    );
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

  Future<void> _openCourseDetails(BuildContext context, CourseEntity c) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => CourseDetailsSheet(course: c),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.c,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final CourseEntity c;
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
                        c.name,
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
                          _Pill(text: c.idDoc.isEmpty ? '—' : c.idDoc),
                          _Pill(
                            text: c.description.isEmpty
                                ? 'Sin descripción'
                                : c.description,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit),
                const SizedBox(width: 8),
                _IconMiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- UI atoms (igual estilo que tus otros módulos) ----------

class _IconMiniBtn extends StatelessWidget {
  const _IconMiniBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.90), size: 18),
        ),
      ),
    );
  }
}

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
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 20),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withOpacity(.78)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, descripción, idDoc…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          _IconMiniBtn(icon: Icons.close_rounded, onTap: onClear),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(.90),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---- confirm PRO ----
Future<bool> _confirmPro(
  BuildContext context, {
  required String title,
  required String message,
  required String primary,
}) async {
  if (!context.mounted) return false;

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(.80),
            height: 1.25,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(false);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withOpacity(.78)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              primary,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    },
  );

  return res == true;
}
