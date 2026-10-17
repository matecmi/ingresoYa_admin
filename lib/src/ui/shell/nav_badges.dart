import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

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

/// Ruta del menú → contador, a partir de la salud del contenido.
final navBadgesProvider = Provider<Map<String, NavBadge>>((ref) {
  final report = ref.watch(contentHealthProvider).value;
  if (report == null) return const {};
  final blocking = report.blocking.length;
  final quality = report.quality.length;
  return {
    if (blocking > 0)
      '/courses': NavBadge(
        count: blocking,
        blocking: true,
        tooltip: '$blocking problema(s) bloquean al alumno',
      )
    else if (quality > 0)
      '/courses': NavBadge(
        count: quality,
        blocking: false,
        tooltip: '$quality cosa(s) le restan calidad',
      ),
  };
});
