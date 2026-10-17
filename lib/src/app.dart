import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/staff.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/auth/admin_login_screen.dart';

import 'ui/admin_router.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_mode_provider.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppTheme.use(_brightness(ref.read(themeModeProvider)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Brightness _brightness(ThemeMode mode) => resolveBrightness(
    mode,
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  /// Cambia la paleta y reconstruye todo (las pantallas leen los colores de
  /// `AppTheme` directamente), sin perder el estado de formularios ni la ruta.
  void _apply(ThemeMode mode) {
    if (!AppTheme.use(_brightness(mode))) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
    setState(() {});
  }

  @override
  void didChangePlatformBrightness() => _apply(ref.read(themeModeProvider));

  @override
  Widget build(BuildContext context) {
    ref.listen(themeModeProvider, (_, mode) => _apply(mode));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current(),
      // El enrutador real vive dentro del control de acceso. En web no se debe
      // intentar resolver `/courses` en este MaterialApp exterior.
      initialRoute: '/',
      home: const _AdminAccessGate(),
    );
  }
}

class _AdminAccessGate extends ConsumerStatefulWidget {
  const _AdminAccessGate();

  @override
  ConsumerState<_AdminAccessGate> createState() => _AdminAccessGateState();
}

class _AdminAccessGateState extends ConsumerState<_AdminAccessGate> {
  String? _uid;
  Future<AdminSession?>? _access;

  /// Pide al servidor los permisos (activa una invitación pendiente o crea la
  /// ficha de un admin anterior a los perfiles) y lee los claims del token.
  Future<AdminSession?> _resolve(User user) async {
    try {
      final changed = await ref.read(staffRepoProvider).syncAccess();
      if (changed) await user.getIdToken(true);
    } catch (_) {
      // Sin la callable (p. ej. aún no desplegada) se usan los claims actuales.
    }
    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] != true) return null;
    final session = AdminSession.fromClaims(
      uid: user.uid,
      email: user.email ?? '',
      claims: token.claims,
    );
    ref.read(adminSessionProvider.notifier).set(session);
    return session;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          _uid = null;
          _access = null;
          return const AdminLoginScreen();
        }
        if (_uid != user.uid || _access == null) {
          _uid = user.uid;
          _access = _resolve(user);
        }

        return FutureBuilder<AdminSession?>(
          future: _access,
          builder: (context, access) {
            if (access.connectionState != ConnectionState.done) {
              return const _LoadingScreen();
            }
            if (access.data == null) {
              return _AccessDeniedScreen(email: user.email ?? user.uid);
            }
            return const _AdminRouter();
          },
        );
      },
    );
  }
}

class _AdminRouter extends StatefulWidget {
  const _AdminRouter();

  @override
  State<_AdminRouter> createState() => _AdminRouterState();
}

class _AdminRouterState extends State<_AdminRouter> {
  late final _router = buildAdminRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current(),
      routerConfig: _router,
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
                  Icon(Icons.block_rounded, size: 52, color: AppTheme.error),
                  const SizedBox(height: 18),
                  const Text(
                    'Acceso no autorizado',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$email inició sesión, pero no tiene acceso al admin. '
                    'Pide a un Dueño que te invite con este correo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.ink.withValues(alpha: .7)),
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
