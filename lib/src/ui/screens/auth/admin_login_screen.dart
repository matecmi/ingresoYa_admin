import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _saving = false;
  var _error = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y contraseña.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _messageFor(error));
    } catch (_) {
      setState(
        () => _error = 'No fue posible iniciar sesión. Inténtalo otra vez.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      if (!kIsWeb) {
        throw UnsupportedError(
          'El inicio con Google está habilitado en la versión web.',
        );
      }
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});

      try {
        // Una ventana superior independiente evita que la página de Google
        // quede dentro del navegador integrado, donde el campo de correo puede
        // no aceptar foco o Google puede bloquear el inicio de sesión.
        await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'popup-blocked') rethrow;
        // Respaldo para navegadores que bloquean explícitamente ventanas nuevas.
        await FirebaseAuth.instance.signInWithRedirect(provider);
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _messageFor(error));
    } catch (error) {
      setState(
        () => _error = error.toString().replaceFirst(
          'Unsupported operation: ',
          '',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'El correo o la contraseña son incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo otra vez.';
      case 'popup-closed-by-user':
        return 'Se cerró la ventana de Google antes de completar el acceso.';
      case 'unauthorized-domain':
        return 'Este dominio no está autorizado en Firebase Authentication.';
      case 'operation-not-allowed':
        return 'El proveedor de Google no está habilitado en Firebase Authentication.';
      default:
        return 'No fue posible iniciar sesión (${error.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.cardDeco(radius: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'IngresoYa Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sesión con una cuenta administradora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _saving ? null : _signIn(),
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFFCA5A5)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _signIn,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(_saving ? 'Ingresando...' : 'Ingresar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continuar con Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
