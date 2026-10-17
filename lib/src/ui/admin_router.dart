import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/course/course_structure_screen.dart';
import 'screens/course/courses_screen.dart';
import 'screens/course/part_editor_screen.dart';
import 'screens/dashboard_shell.dart';
import 'screens/home/home_screen.dart';
import 'screens/professions/professions_screen.dart';
import 'screens/question/questions_screen.dart';
import 'screens/question/quick_load_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/staff/staff_screen.dart';
import 'screens/templates/exam_templates_screen.dart';
import 'screens/universities/universities_screen.dart';

Page<void> _page(Widget child) => NoTransitionPage(child: child);

/// Rutas del admin dentro del marco con menú. `userLabel` solo se usa en
/// pruebas (evita leer FirebaseAuth).
GoRouter buildAdminRouter({String initialLocation = '/', String? userLabel}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(userLabel: userLabel, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, _) => _page(const HomeScreen())),
          GoRoute(
            path: '/universities',
            pageBuilder: (_, _) => _page(const UniversitiesScreen()),
          ),
          GoRoute(
            path: '/courses',
            pageBuilder: (_, _) => _page(const CoursesScreen()),
          ),
          GoRoute(
            path: '/courses/:courseId',
            pageBuilder: (_, state) => _page(
              CourseStructureScreen(
                courseId: state.pathParameters['courseId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/courses/:courseId/part/:partId',
            pageBuilder: (_, state) => _page(
              PartEditorScreen(
                courseId: state.pathParameters['courseId']!,
                partId: state.pathParameters['partId']!,
                topicId: state.uri.queryParameters['topic'] ?? '',
                subtopicId: state.uri.queryParameters['subtopic'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/professions',
            pageBuilder: (_, _) => _page(const ProfessionsScreen()),
          ),
          GoRoute(
            path: '/questions',
            pageBuilder: (_, _) => _page(const QuestionsScreen()),
          ),
          GoRoute(
            path: '/questions/quick',
            pageBuilder: (_, state) => _page(
              QuickLoadScreen(
                initialCourseId: state.uri.queryParameters['course'],
                initialTopicId: state.uri.queryParameters['topic'],
                initialSubtopicId: state.uri.queryParameters['subtopic'],
                initialPartId: state.uri.queryParameters['part'],
              ),
            ),
          ),
          GoRoute(
            path: '/exam-templates',
            pageBuilder: (_, _) => _page(const ExamTemplatesScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, _) => _page(const SettingsScreen()),
          ),
          GoRoute(
            path: '/staff',
            pageBuilder: (_, _) => _page(const StaffScreen()),
          ),
        ],
      ),
    ],
  );
}
