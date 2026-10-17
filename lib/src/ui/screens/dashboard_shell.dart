import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/staff.dart';
import '../../env/app_env.dart';
import '../../providers/providers.dart';
import '../shell/admin_nav.dart';
import '../shell/help_panel.dart';
import '../shell/nav_badges.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_provider.dart';
import '../widgets/admin_ui.dart';

/// Marco del admin: aviso de entorno, menú por tareas y barra superior con
/// la ayuda de la sección (tableros 7 y 22 del lienzo).
class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.child, this.userLabel});

  final Widget child;

  /// Para pruebas: evita leer FirebaseAuth.
  final String? userLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final current = navItemFor(location);
    final badges = ref.watch(navBadgesProvider);
    final session = ref.watch(effectiveSessionProvider);
    final preview = ref.watch(staffPreviewProvider);
    final items = [
      for (final item in adminNav)
        if (session.perms.canKey(item.permission, StaffAction.view)) item,
    ];
    final allowed =
        current == null ||
        session.perms.canKey(current.permission, StaffAction.view);
    final readOnly =
        allowed &&
        current != null &&
        current.permission != 'home' &&
        !session.perms.canKey(current.permission, StaffAction.edit);
    Widget content = allowed
        ? child
        : const Center(
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Tu perfil no tiene acceso a esta sección',
              message: 'Pide a un Dueño que te dé permiso para verla.',
            ),
          );
    if (preview != null) content = IgnorePointer(child: content);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        final menu = _SideMenu(
          items: items,
          location: location,
          badges: badges,
          userLabel: userLabel,
          onNavigate: (route) {
            if (!wide) Navigator.of(context).maybePop();
            context.go(route);
          },
        );
        return Scaffold(
          backgroundColor: AppTheme.bg,
          drawer: wide ? null : Drawer(width: 260, child: menu),
          body: Column(
            children: [
              if (preview != null)
                _PreviewBanner(
                  roleName: preview.name,
                  onExit: () {
                    ref.read(staffPreviewProvider.notifier).preview(null);
                    context.go('/staff');
                  },
                ),
              const EnvBanner(),
              Expanded(
                child: Row(
                  children: [
                    if (wide) SizedBox(width: 244, child: menu),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(current: current, showMenuButton: !wide),
                          if (readOnly) const _ReadOnlyStrip(),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Franja fija que recuerda en qué entorno se trabaja.
class EnvBanner extends StatelessWidget {
  const EnvBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isProd = AppEnv.environment == AdminEnvironment.production;
    final text = isProd
        ? 'Estás en PRODUCCIÓN: lo que cambies lo ven todos los alumnos.'
        : 'Estás en PRUEBAS (TEST): los cambios solo los ven las cuentas de '
              'prueba.';
    return Semantics(
      container: true,
      label: text,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: isProd ? AppTheme.errorSoft : AppTheme.warnSoft,
          border: Border(
            bottom: BorderSide(
              color: isProd ? AppTheme.errorLine : AppTheme.warnLine,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isProd ? AppTheme.error : AppTheme.warnInk,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.roleName, required this.onExit});

  final String roleName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppTheme.infoSoft,
        border: Border(bottom: BorderSide(color: AppTheme.infoLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Estás viendo el admin como «$roleName». Puedes moverte por el '
              'menú; nada de lo que veas se puede tocar ni se guarda.',
              style: TextStyle(
                color: AppTheme.infoInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onExit,
            child: const Text('Salir de la vista previa'),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyStrip extends StatelessWidget {
  const _ReadOnlyStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: AppTheme.neutralSoft,
      child: Text(
        'Solo lectura: tu perfil puede ver esta sección, pero no cambiarla.',
        style: TextStyle(color: AppTheme.body, fontSize: 13),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.current, required this.showMenuButton});

  final AdminNavItem? current;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final item = current;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              tooltip: 'Menú',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const SizedBox(width: 8),
          if (item != null && item.group.isNotEmpty) ...[
            Text(
              _groupLabel(item.group),
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            Text(
              '  /  ',
              style: TextStyle(color: AppTheme.faint, fontSize: 13),
            ),
          ],
          Expanded(
            child: Text(
              item?.label ?? '',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (item != null)
            Tooltip(
              message: '¿Para qué sirve esta sección?',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showHelpPanel(context, item),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '?',
                    semanticsLabel: 'Ayuda de esta sección',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          const _ThemeMenu(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  static String _groupLabel(String group) =>
      group[0] + group.substring(1).toLowerCase();
}

/// Selector de tema: automático (el del sistema), claro u oscuro.
class _ThemeMenu extends ConsumerWidget {
  const _ThemeMenu();

  static const _options = [
    (
      ThemeMode.system,
      'Automático (como el sistema)',
      Icons.brightness_auto_rounded,
    ),
    (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tema claro u oscuro',
      initialValue: mode,
      onSelected: ref.read(themeModeProvider.notifier).set,
      icon: Icon(
        AppTheme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: AppTheme.body,
      ),
      itemBuilder: (_) => [
        for (final (value, label, icon) in _options)
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.body),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
                if (value == mode)
                  Icon(Icons.check_rounded, size: 18, color: AppTheme.brand),
              ],
            ),
          ),
      ],
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.items,
    required this.location,
    required this.badges,
    required this.onNavigate,
    this.userLabel,
  });

  final List<AdminNavItem> items;
  final String location;
  final Map<String, NavBadge> badges;
  final ValueChanged<String> onNavigate;
  final String? userLabel;

  @override
  Widget build(BuildContext context) {
    final current = navItemFor(location);
    final children = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: _Brand(),
      ),
    ];
    for (final group in adminGroups) {
      final inGroup = items.where((i) => i.group == group).toList();
      if (inGroup.isEmpty) continue;
      if (group.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
            child: Text(
              group,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
                color: AppTheme.muted,
              ),
            ),
          ),
        );
      }
      for (final item in inGroup) {
        children.add(
          _MenuItem(
            item: item,
            active: identical(item, current),
            badge: badges[item.route],
            onTap: () => onNavigate(item.route),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(right: BorderSide(color: AppTheme.line)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: children,
            ),
          ),
          const Divider(height: 1),
          _UserFooter(userLabel: userLabel),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.brand,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'I',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'IngresoYa',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        Text(
          'Admin',
          style: TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final AdminNavItem item;
  final bool active;
  final VoidCallback onTap;
  final NavBadge? badge;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: active ? AppTheme.brandSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: active ? AppTheme.brandInk : AppTheme.body,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: active ? AppTheme.brandInk : AppTheme.ink,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (b != null) _BadgeChip(badge: b),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final NavBadge badge;

  @override
  Widget build(BuildContext context) {
    final blocking = badge.blocking;
    return Tooltip(
      message: badge.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: blocking ? AppTheme.error : AppTheme.warnSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${badge.count}',
          style: TextStyle(
            color: blocking ? Colors.white : AppTheme.warn,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({this.userLabel});

  final String? userLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        userLabel ??
        FirebaseAuth.instance.currentUser?.email ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppTheme.brandSoft,
            child: Text(
              label.isEmpty ? '?' : label[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.brandInk,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppTheme.body),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded, size: 19),
            onPressed: userLabel != null
                ? null
                : () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }
}
