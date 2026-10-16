import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contador junto a una entrada del menú («Cursos 3»). Rojo si algo bloquea al
/// alumno; ámbar si solo le resta calidad.
class NavBadge {
  const NavBadge({
    required this.count,
    required this.blocking,
    required this.tooltip,
  });

  final int count;
  final bool blocking;
  final String tooltip;
}

/// Ruta del menú → contador. Lo alimenta la revisión de salud del contenido.
final navBadgesProvider = Provider<Map<String, NavBadge>>((ref) => const {});
