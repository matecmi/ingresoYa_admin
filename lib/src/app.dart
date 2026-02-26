import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingresoya_admin/src/ui/screens/course/courses_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/professions/professions_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/question/questions_screen.dart';

import 'ui/theme/app_theme.dart';
import 'ui/screens/dashboard_shell.dart';
import 'ui/screens/universities/universities_screen.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/universities',
      routes: [
        ShellRoute(
          builder: (context, state, child) => DashboardShell(child: child),
          routes: [
            GoRoute(
              path: '/universities',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: UniversitiesScreen()),
            ),
            GoRoute(
  path: '/professions',
  pageBuilder: (context, state) =>
      const NoTransitionPage(child: ProfessionsScreen()),
),

            GoRoute(
  path: '/courses',
  pageBuilder: (context, state) =>
      const NoTransitionPage(child: CoursesScreen()),
),

GoRoute(
  path: '/questions',
  builder: (_, __) => const QuestionsScreen(),
),

            
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
