import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;

    final isUni = loc.startsWith('/universities');
    final isProf = loc.startsWith('/professions');
    final isCourse = loc.startsWith('/courses');
    final isQ = loc.startsWith('/questions');
    

    int bottomIndex() {
      if (isProf) return 1;
      if (isCourse) return 2;
      return 0; // default universidades
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ✅ Sidebar (web/tablet)
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                if (!wide) return const SizedBox.shrink();

                return Container(
                  width: 280,
                  decoration: AppTheme.cardDeco(color: AppTheme.card, radius: 0)
                      .copyWith(
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(.08),
                          ),
                        ),
                      ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: AppTheme.headerGradient(),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.14),
                                ),
                              ),
                              child: Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white.withOpacity(.92),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'IngresoYa Admin version jenkins 4343',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.92),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      _SideItem(
                        active: isUni,
                        icon: Icons.school_rounded,
                        label: 'Universidades',
                        onTap: () => context.go('/universities'),
                      ),

                      _SideItem(
                        active: isProf,
                        icon: Icons.work_rounded,
                        label: 'Profesiones',
                        onTap: () => context.go('/professions'),
                      ),

                      _SideItem(
                        active: isProf,
                        icon: Icons.menu_book_rounded,
                        label: 'Cursos',
                        onTap: () => context.go('/courses'),
                      ),
                      _SideItem(
  active: isQ,
  icon: Icons.quiz_rounded,
  label: 'Preguntas',
  onTap: () => context.go('/questions'),
),
                      

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Entorno: TEST',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.55),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ✅ Content
            Expanded(child: child),
          ],
        ),
      ),

      // ✅ Bottom bar (mobile)
bottomNavigationBar: LayoutBuilder(
  builder: (context, c) {
    final wide = c.maxWidth > 900;
    if (wide) return const SizedBox.shrink();

    int indexFromLocation(String loc) {
      // ✅ soporta rutas hijas: /courses/xyz, /questions/new, etc.
      if (loc.startsWith('/universities')) return 0;
      if (loc.startsWith('/professions')) return 1;
      if (loc.startsWith('/courses')) return 2;
      if (loc.startsWith('/questions')) return 3;
      return 0;
    }

    final loc = GoRouterState.of(context).matchedLocation;
    final currentIndex = indexFromLocation(loc);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/universities');
              break;
            case 1:
              context.go('/professions');
              break;
            case 2:
              context.go('/courses');
              break;
            case 3:
              context.go('/questions');
              break;
          }
        },
        backgroundColor: AppTheme.card,
        selectedItemColor: Colors.white.withOpacity(.92),
        unselectedItemColor: Colors.white.withOpacity(.55),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: 'Universidades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_rounded),
            label: 'Profesiones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Cursos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_rounded),
            label: 'Preguntas',
          ),
        ],
      ),
    );
  },
),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppTheme.accent.withOpacity(.18) : Colors.transparent;
    final border = active
        ? AppTheme.accent.withOpacity(.45)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white.withOpacity(.90)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
