import 'package:flutter/material.dart';

/// Menú del admin agrupado por tarea (tablero «7 · Inicio v2»).
///
/// Cada entrada lleva su ayuda («?» en la barra superior): para qué sirve la
/// sección y los atajos más usados. La clave `permission` es la sección de
/// permisos que la protege (docs/admin_staff_contract.md).
class AdminNavItem {
  const AdminNavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.group,
    required this.permission,
    required this.help,
  });

  final String route;
  final String label;
  final IconData icon;
  final String group;
  final String permission;
  final AdminHelp help;

  bool matches(String location) =>
      route == '/' ? location == '/' : location.startsWith(route);
}

class AdminHelp {
  const AdminHelp({
    required this.purpose,
    this.shortcuts = const [],
    this.guideAnchor,
  });

  /// Dos o tres líneas: qué se hace aquí y qué cambia en la app.
  final String purpose;

  /// Atajos «Lo más usado»: (texto, ruta).
  final List<(String, String)> shortcuts;

  /// Ancla de la sección del admin en la Guía publicada.
  final String? guideAnchor;
}

const adminGroups = ['', 'CONTENIDO', 'ALUMNOS', 'CALIDAD', 'AJUSTES'];

const adminNav = <AdminNavItem>[
  AdminNavItem(
    route: '/',
    label: 'Inicio',
    icon: Icons.space_dashboard_outlined,
    group: '',
    permission: 'home',
    help: AdminHelp(
      purpose:
          'El estado del contenido de un vistazo: lo que hoy bloquea al alumno, '
          'lo que le resta calidad y los accesos a lo que más se usa.',
      shortcuts: [
        ('Cargar preguntas una tras otra', '/questions/quick'),
        ('Ver los cursos', '/courses'),
      ],
      guideAnchor: 'admin-inicio',
    ),
  ),
  AdminNavItem(
    route: '/courses',
    label: 'Cursos',
    icon: Icons.menu_book_outlined,
    group: 'CONTENIDO',
    permission: 'courses',
    help: AdminHelp(
      purpose:
          'Cursos, temas, subtemas y partes de la Guía de estudio. Cada parte '
          'tiene video, lección, ejemplos y su examen; si falta algo, el alumno '
          'no puede completarla.',
      shortcuts: [('Cargar preguntas para una parte', '/questions')],
      guideAnchor: 'admin-cursos',
    ),
  ),
  AdminNavItem(
    route: '/questions',
    label: 'Banco de preguntas',
    icon: Icons.quiz_outlined,
    group: 'CONTENIDO',
    permission: 'questions',
    help: AdminHelp(
      purpose:
          'Todas las preguntas que usa la app: exámenes de cada parte, '
          'Simulador y reto del día. Puedes buscarlas, editarlas o cargar '
          'nuevas.',
      shortcuts: [
        ('Cargar preguntas una tras otra', '/questions/quick'),
        ('Importar un examen completo', '/import-exam'),
      ],
      guideAnchor: 'admin-preguntas',
    ),
  ),
  AdminNavItem(
    route: '/import-exam',
    label: 'Importar examen pasado',
    icon: Icons.upload_file_outlined,
    group: 'CONTENIDO',
    permission: 'questions',
    help: AdminHelp(
      purpose:
          'Pega el texto completo de un examen de admisión: separamos las '
          'preguntas numeradas, sus alternativas y la tabla de claves; '
          'sugerimos curso y parte; y las creas todas de una vez.',
      guideAnchor: 'admin-importar',
    ),
  ),
  AdminNavItem(
    route: '/exam-templates',
    label: 'Plantillas de examen',
    icon: Icons.assignment_outlined,
    group: 'CONTENIDO',
    permission: 'courses',
    help: AdminHelp(
      purpose:
          'Cuántas preguntas tiene cada examen de parte o de dominio y con '
          'qué nota se aprueba. Si una plantilla pide más preguntas de las que '
          'hay publicadas, el alumno ve un error.',
      guideAnchor: 'admin-plantillas',
    ),
  ),
  AdminNavItem(
    route: '/universities',
    label: 'Universidades y exámenes',
    icon: Icons.account_balance_outlined,
    group: 'CONTENIDO',
    permission: 'universities',
    help: AdminHelp(
      purpose:
          'Universidades, sus modalidades y los exámenes de admisión pasados '
          'que usa el Simulador. Un examen pasado solo aparece cuando está '
          'completo.',
      guideAnchor: 'admin-universidades',
    ),
  ),
  AdminNavItem(
    route: '/professions',
    label: 'Carreras',
    icon: Icons.work_outline,
    group: 'CONTENIDO',
    permission: 'universities',
    help: AdminHelp(
      purpose:
          'Las carreras que el alumno elige en el registro. Se usan para su '
          'plan de estudio y para la tabla «Mi carrera» del reto del día.',
      guideAnchor: 'admin-carreras',
    ),
  ),
  AdminNavItem(
    route: '/students',
    label: 'Buscar alumno',
    icon: Icons.person_search_outlined,
    group: 'ALUMNOS',
    permission: 'students',
    help: AdminHelp(
      purpose:
          'La ficha de un alumno en un solo lugar: su avance en la guía, sus '
          'exámenes, su XP con el libro de movimientos (revertir con motivo) '
          'y su nombre de usuario (retirarlo si es inapropiado).',
      guideAnchor: 'admin-alumnos',
    ),
  ),
  AdminNavItem(
    route: '/news',
    label: 'Noticias',
    icon: Icons.campaign_outlined,
    group: 'ALUMNOS',
    permission: 'news',
    help: AdminHelp(
      purpose:
          'Avisos, novedades y consejos para los alumnos, con imagen si hace '
          'falta. Elige si es para todos o solo para algunas universidades y '
          'su prioridad: urgente (ventana al abrir), fijada (arriba del '
          'Inicio) o normal; también puede salir como historia.',
      shortcuts: [('Publicar una noticia', '/news/new')],
      guideAnchor: 'admin-noticias',
    ),
  ),
  AdminNavItem(
    route: '/quality',
    label: 'Preguntas a revisar',
    icon: Icons.fact_check_outlined,
    group: 'CALIDAD',
    permission: 'questions',
    help: AdminHelp(
      purpose:
          'Preguntas sospechosas según lo que respondieron los alumnos: casi '
          'todos fallan y eligen otra alternativa (la clave puede estar mal), '
          'demasiado fáciles o con alternativas que nadie elige. Los umbrales '
          'se cambian en Configuración.',
      guideAnchor: 'admin-calidad',
    ),
  ),
  AdminNavItem(
    route: '/settings',
    label: 'Configuración',
    icon: Icons.tune_outlined,
    group: 'AJUSTES',
    permission: 'settings',
    help: AdminHelp(
      purpose:
          'Las reglas de la app: cómo gana XP el alumno, rankings y ligas, '
          'reto del día, Simulador y Guía de estudio. Cada cambio dice qué '
          'efecto tiene y se puede volver atrás.',
      guideAnchor: 'admin-configuracion',
    ),
  ),
  AdminNavItem(
    route: '/history',
    label: 'Historial de cambios',
    icon: Icons.history_rounded,
    group: 'AJUSTES',
    permission: 'history',
    help: AdminHelp(
      purpose:
          'Quién cambió qué y cuándo, con el valor anterior y el nuevo. Puedes '
          'restaurar un cambio o recuperar algo archivado o eliminado; '
          'restaurar también queda anotado.',
      guideAnchor: 'admin-historial',
    ),
  ),
  AdminNavItem(
    route: '/staff',
    label: 'Perfiles y permisos',
    icon: Icons.admin_panel_settings_outlined,
    group: 'AJUSTES',
    permission: 'staff',
    help: AdminHelp(
      purpose:
          'Quién entra al admin y qué puede hacer. Un perfil es un conjunto de '
          'permisos (ver, crear y editar, publicar, archivar) por sección; a '
          'una persona le puedes sumar una excepción o limitarla a ciertos '
          'cursos.',
      guideAnchor: 'admin-perfiles',
    ),
  ),
];

AdminNavItem? navItemFor(String location) {
  AdminNavItem? best;
  for (final item in adminNav) {
    if (!item.matches(location)) continue;
    if (best == null || item.route.length > best.route.length) best = item;
  }
  return best;
}
