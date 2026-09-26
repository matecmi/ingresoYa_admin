import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ingresoya_admin/src/ui/screens/auth/admin_login_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/course/courses_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/question/questions_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/templates/exam_templates_screen.dart';

import 'ui/screens/dashboard_shell.dart';
import 'ui/screens/universities/universities_screen.dart';
import 'ui/theme/app_theme.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      // El enrutador real vive dentro del control de acceso. En web no se debe
      // intentar resolver `/courses` en este MaterialApp exterior.
      initialRoute: '/',
      home: const _AdminAccessGate(),
    );
  }
}

class _AdminAccessGate extends StatelessWidget {
  const _AdminAccessGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) return const AdminLoginScreen();

        return FutureBuilder<IdTokenResult>(
          future: user.getIdTokenResult(true),
          builder: (context, tokenSnapshot) {
            if (tokenSnapshot.connectionState != ConnectionState.done) {
              return const _LoadingScreen();
            }

            final isAdmin = tokenSnapshot.data?.claims?['admin'] == true;
            if (!isAdmin) {
              return _AccessDeniedScreen(email: user.email ?? user.uid);
            }
            return const _AdminRouter();
          },
        );
      },
    );
  }
}

class _AdminRouter extends StatelessWidget {
  const _AdminRouter();

  @override
  Widget build(BuildContext context) {
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
              path: '/courses',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CoursesScreen()),
            ),
            GoRoute(
              path: '/questions',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: QuestionsScreen()),
            ),
            GoRoute(
              path: '/exam-templates',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ExamTemplatesScreen()),
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

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.cardDeco(radius: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 52,
                    color: Color(0xFFFCA5A5),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Acceso no autorizado',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$email inició sesión, pero no tiene el permiso de administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
