import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../env/app_env.dart';
import '../shell/admin_nav.dart';
import '../shell/help_panel.dart';
import '../shell/nav_badges.dart';
import '../theme/app_theme.dart';

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

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        final menu = _SideMenu(
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
              const EnvBanner(),
              Expanded(
                child: Row(
                  children: [
                    if (wide) SizedBox(width: 244, child: menu),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(current: current, showMenuButton: !wide),
                          Expanded(child: child),
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
            color: isProd ? AppTheme.error : const Color(0xFF93370D),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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
      decoration: const BoxDecoration(
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
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            const Text(
              '  /  ',
              style: TextStyle(color: AppTheme.faint, fontSize: 13),
            ),
          ],
          Expanded(
            child: Text(
              item?.label ?? '',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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
                  decoration: const BoxDecoration(
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
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  static String _groupLabel(String group) =>
      group[0] + group.substring(1).toLowerCase();
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.location,
    required this.badges,
    required this.onNavigate,
    this.userLabel,
  });

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
      final items = adminNav.where((i) => i.group == group).toList();
      if (items.isEmpty) continue;
      if (group.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
            child: Text(
              group,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
                color: AppTheme.muted,
              ),
            ),
          ),
        );
      }
      for (final item in items) {
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
      decoration: const BoxDecoration(
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
        const Text(
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
              style: const TextStyle(
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
              style: const TextStyle(fontSize: 12.5, color: AppTheme.body),
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
