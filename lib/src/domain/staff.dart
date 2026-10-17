/// Perfiles y permisos del admin (docs/admin_staff_contract.md).
///
/// La seguridad real está en las reglas y en las Functions; esto solo decide
/// qué se muestra y qué botones se habilitan.
enum StaffSection {
  questions(
    'questions',
    'Banco de preguntas',
    'Preguntas, claves y explicaciones',
  ),
  courses(
    'courses',
    'Cursos y partes',
    'Cursos, temas, subtemas, partes y plantillas',
  ),
  universities(
    'universities',
    'Universidades y exámenes',
    'Universidades, carreras y exámenes pasados',
  ),
  students(
    'students',
    'Alumnos y XP',
    'Ficha del alumno, XP y nombres de usuario',
  ),
  news(
    'news',
    'Noticias',
    'Avisos, novedades e historias que ven los alumnos',
  ),
  settings('settings', 'Configuración', 'XP, rankings, simulador, guía'),
  staff(
    'staff',
    'Perfiles y permisos',
    'Quién entra al admin y qué puede hacer',
  ),
  history('history', 'Historial de cambios', 'Ver y restaurar cambios'),
  production('production', 'Producción', 'Pasar cambios de TEST a producción');

  const StaffSection(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;

  static StaffSection? fromKey(String key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

enum StaffAction {
  view('v', 'Ver'),
  edit('e', 'Crear y editar'),
  publish('p', 'Publicar'),
  archive('a', 'Archivar / borrar');

  const StaffAction(this.letter, this.label);

  final String letter;
  final String label;
}

/// Letras por sección: `{"questions": "vep"}`.
class StaffPerms {
  const StaffPerms(this.bySection, {this.owner = false});

  const StaffPerms.none() : bySection = const {}, owner = false;

  const StaffPerms.all() : bySection = const {}, owner = true;

  final Map<String, String> bySection;
  final bool owner;

  bool can(StaffSection section, StaffAction action) =>
      owner || (bySection[section.key] ?? '').contains(action.letter);

  bool canKey(String sectionKey, StaffAction action) {
    final section = StaffSection.fromKey(sectionKey);
    return section == null ? true : can(section, action);
  }

  String letters(StaffSection section) =>
      owner ? 'vepa' : (bySection[section.key] ?? '');

  static String normalize(String letters) {
    final set = letters.split('').where('vepa'.contains).toSet();
    if (set.isNotEmpty) set.add('v');
    return 'vepa'.split('').where(set.contains).join();
  }

  static StaffPerms fromJson(Object? json) {
    if (json is! Map) return const StaffPerms.none();
    return StaffPerms({
      for (final e in json.entries)
        if (e.value is String && normalize(e.value as String).isNotEmpty)
          '${e.key}': normalize(e.value as String),
    });
  }

  Map<String, String> toJson() => Map.of(bySection);

  StaffPerms toggled(StaffSection section, StaffAction action, bool on) {
    var letters = bySection[section.key] ?? '';
    if (on) {
      letters = normalize(letters + action.letter);
    } else if (action == StaffAction.view) {
      letters = '';
    } else {
      letters = normalize(letters.replaceAll(action.letter, ''));
    }
    final next = Map.of(bySection);
    if (letters.isEmpty) {
      next.remove(section.key);
    } else {
      next[section.key] = letters;
    }
    return StaffPerms(next);
  }
}

class StaffRole {
  const StaffRole({
    required this.id,
    required this.name,
    required this.description,
    required this.perms,
    required this.builtIn,
  });

  final String id;
  final String name;
  final String description;
  final StaffPerms perms;
  final bool builtIn;

  bool get isOwner => id == 'owner';

  factory StaffRole.fromJson(String id, Map<String, dynamic> json) {
    return StaffRole(
      id: id,
      name: (json['name'] as String?) ?? id,
      description: (json['description'] as String?) ?? '',
      perms: id == 'owner'
          ? const StaffPerms.all()
          : StaffPerms.fromJson(json['perms']),
      builtIn: json['builtIn'] == true,
    );
  }
}

/// Copia de los perfiles de fábrica de `functions/src/staff.ts`; se muestran
/// mientras las Functions aún no los guardaron en Firestore.
const builtinStaffRoles = <StaffRole>[
  StaffRole(
    id: 'owner',
    name: 'Dueño',
    description: 'Todo, incluido perfiles y producción. No se puede borrar.',
    perms: StaffPerms.all(),
    builtIn: true,
  ),
  StaffRole(
    id: 'editor',
    name: 'Editor de contenido',
    description:
        'Crea y edita preguntas, cursos y exámenes. Publicar pide revisión.',
    perms: StaffPerms({
      'questions': 've',
      'courses': 've',
      'universities': 've',
      'news': 've',
      'settings': 'v',
      'history': 'v',
    }),
    builtIn: true,
  ),
  StaffRole(
    id: 'reviewer',
    name: 'Revisor',
    description: 'Revisa y publica lo que cargan los editores. No borra.',
    perms: StaffPerms({
      'questions': 'vep',
      'courses': 'vep',
      'universities': 'vep',
      'news': 'vep',
      'settings': 'v',
      'history': 'v',
    }),
    builtIn: true,
  ),
  StaffRole(
    id: 'support',
    name: 'Soporte a alumnos',
    description: 'Busca alumnos, ve su ficha y corrige XP con motivo.',
    perms: StaffPerms({
      'students': 've',
      'questions': 'v',
      'courses': 'v',
      'history': 'v',
    }),
    builtIn: true,
  ),
  StaffRole(
    id: 'readonly',
    name: 'Solo lectura',
    description: 'Ve todo, no cambia nada. Útil para socios o auditoría.',
    perms: StaffPerms({
      'questions': 'v',
      'courses': 'v',
      'universities': 'v',
      'students': 'v',
      'news': 'v',
      'settings': 'v',
      'history': 'v',
    }),
    builtIn: true,
  ),
];

class StaffScope {
  const StaffScope({this.courseIds = const [], this.universityIds = const []});

  final List<String> courseIds;
  final List<String> universityIds;

  bool get isEmpty => courseIds.isEmpty && universityIds.isEmpty;

  factory StaffScope.fromJson(Object? json) {
    if (json is! Map) return const StaffScope();
    List<String> read(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    return StaffScope(
      courseIds: read(json['courseIds']),
      universityIds: read(json['universityIds']),
    );
  }

  Map<String, Object> toJson() => {
    'courseIds': courseIds,
    'universityIds': universityIds,
  };
}

class StaffMember {
  const StaffMember({
    required this.uid,
    required this.email,
    required this.name,
    required this.roleId,
    required this.extra,
    required this.scope,
    required this.active,
    this.lastSeenAt,
  });

  final String uid;
  final String email;
  final String name;
  final String roleId;
  final StaffPerms extra;
  final StaffScope scope;
  final bool active;
  final DateTime? lastSeenAt;

  String get displayName => name.isNotEmpty ? name : email;

  factory StaffMember.fromJson(
    String uid,
    Map<String, dynamic> json, {
    DateTime? lastSeenAt,
  }) {
    return StaffMember(
      uid: uid,
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      roleId: (json['roleId'] as String?) ?? '',
      extra: StaffPerms.fromJson(json['extra']),
      scope: StaffScope.fromJson(json['scope']),
      active: json['status'] != 'revoked',
      lastSeenAt: lastSeenAt,
    );
  }
}

class StaffInvite {
  const StaffInvite({
    required this.email,
    required this.roleId,
    this.expiresAt,
  });

  final String email;
  final String roleId;
  final DateTime? expiresAt;
}

/// Quién está usando el admin y qué puede hacer (de los claims del token).
class AdminSession {
  const AdminSession({
    required this.uid,
    required this.email,
    required this.roleId,
    required this.perms,
    this.scope = const StaffScope(),
  });

  /// Sesión de pruebas o sin claims de perfil: Dueño.
  const AdminSession.owner({this.uid = '', this.email = ''})
    : roleId = 'owner',
      perms = const StaffPerms.all(),
      scope = const StaffScope();

  final String uid;
  final String email;
  final String roleId;
  final StaffPerms perms;
  final StaffScope scope;

  bool get isOwner => roleId == 'owner';

  bool can(StaffSection section, StaffAction action) =>
      perms.can(section, action);

  /// Claims del token: `{admin, role, p, cs, us}`. Sin `role` = Dueño.
  factory AdminSession.fromClaims({
    required String uid,
    required String email,
    required Map<String, dynamic>? claims,
  }) {
    final role = claims?['role'];
    if (role is! String || role == 'owner') {
      return AdminSession.owner(uid: uid, email: email);
    }
    return AdminSession(
      uid: uid,
      email: email,
      roleId: role,
      perms: StaffPerms.fromJson(claims?['p']),
      scope: StaffScope.fromJson({
        'courseIds': claims?['cs'],
        'universityIds': claims?['us'],
      }),
    );
  }
}
