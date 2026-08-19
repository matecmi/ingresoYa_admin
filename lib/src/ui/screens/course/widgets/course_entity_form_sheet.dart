import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Marco compartido para los formularios que administran el contenido de un
/// curso. Mantiene el mismo patrón visual y de interacción en temas, subtemas
/// y partes.
class CourseEntityFormSheet extends StatelessWidget {
  const CourseEntityFormSheet({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
    required this.onSave,
    this.saving = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;
  final Future<void> Function() onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Container(
      width: screen.width < 800 ? screen.width - 48 : 720,
      height: screen.height * .72,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(.09)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.30),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(.30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: _titleStyle),
                          const SizedBox(height: 2),
                          Text(description, style: _descriptionStyle),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: Colors.white.withOpacity(.82)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(.08)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FormSection(child: child),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(.88),
                          side: BorderSide(color: Colors.white.withOpacity(.18)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 19),
                        label: Text(saving ? 'Guardando...' : 'Guardar',
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _titleStyle = TextStyle(
    color: Colors.white.withOpacity(.94),
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );
  static final _descriptionStyle = TextStyle(
    color: Colors.white.withOpacity(.62),
    fontWeight: FontWeight.w600,
  );
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDeco(
          radius: 20,
          color: Colors.white.withOpacity(.035),
        ),
        child: child,
      );
}
