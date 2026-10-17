import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'content_health_section.dart';

/// Inicio del admin (tableros 7 y 14): accesos rápidos y salud del contenido.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        const AdminPageHeader(
          title: 'Inicio',
          subtitle:
              'Lo que necesita atención primero y los accesos a lo que más se '
              'usa.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final cards = [
              _QuickCard(
                primary: true,
                title: 'Cargar preguntas',
                text: 'Pega o escribe, y sigue con la siguiente',
                icon: Icons.bolt_rounded,
                onTap: () => context.go('/questions'),
              ),
              _QuickCard(
                title: 'Armar un curso',
                text: 'Temas, subtemas y partes',
                icon: Icons.account_tree_outlined,
                onTap: () => context.go('/courses'),
              ),
              _QuickCard(
                title: 'Exámenes pasados',
                text: 'Universidades y exámenes del Simulador',
                icon: Icons.account_balance_outlined,
                onTap: () => context.go('/universities'),
              ),
            ];
            return _Grid(columns: cols, children: cards);
          },
        ),
        const SizedBox(height: 22),
        const ContentHealthSection(),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(child: j < slice.length ? slice[j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.title,
    required this.text,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppTheme.ink;
    return Material(
      color: primary ? AppTheme.brand : AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: primary ? null : Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: primary ? Colors.white : AppTheme.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: TextStyle(
                        color: primary
                            ? Colors.white.withValues(alpha: .85)
                            : AppTheme.muted,
                        fontSize: 13,
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
}
