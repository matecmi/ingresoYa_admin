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
  var _saving = false;
  var _error = '';

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
                    'Ingresa con Google. Solo las cuentas autorizadas pueden acceder al panel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFFCA5A5)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (kIsWeb) ...[
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _signInWithGoogle,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: Text(
                        _saving ? 'Abriendo Google...' : 'Continuar con Google',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'El acceso administrativo con Google está disponible en la versión web.',
                      textAlign: TextAlign.center,
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
