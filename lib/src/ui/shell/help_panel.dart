import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'admin_nav.dart';

/// Guía publicada de IngresoYa (incluye la sección del panel de administración).
const adminGuideUrl = 'https://claude.ai/artifact/PN2pWRaUDno4DxxR7hHW1k';

/// Ayuda de la sección actual (tablero «22 · Ayuda en cada sección»).
Future<void> showHelpPanel(BuildContext context, AdminNavItem item) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => HelpPanel(
      item: item,
      onShortcut: (route) {
        Navigator.of(dialogContext).pop();
        context.go(route);
      },
    ),
  );
}

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key, required this.item, required this.onShortcut});

  final AdminNavItem item;
  final ValueChanged<String> onShortcut;

  @override
  Widget build(BuildContext context) {
    final help = item.help;
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brand,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Text(
                '¿Para qué sirve esta sección?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                help.purpose,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.body,
                  height: 1.6,
                ),
              ),
              if (help.shortcuts.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Lo más usado',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                for (final (label, route) in help.shortcuts)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => onShortcut(route),
                    child: Text('→ $label'),
                  ),
              ],
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Abrir la guía completa'),
                  onPressed: () => launchUrl(
                    Uri.parse(
                      help.guideAnchor == null
                          ? adminGuideUrl
                          : '$adminGuideUrl#${help.guideAnchor}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
