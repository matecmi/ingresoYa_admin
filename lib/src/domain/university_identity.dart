/// Identidad de la universidad para el alumno (`identity` del documento de la
/// universidad, docs/universities_contract.md): colores de la bufanda del
/// búho, cómo llamar al ingresante, la frase al subir de rango y si el
/// resultado de un examen pasado dice «¿habrías ingresado?». La app la lee
/// con el documento que ya baja una vez por sesión.
class UniversityIdentity {
  const UniversityIdentity({
    this.primaryColor = '',
    this.secondaryColor = '',
    this.freshmanName = '',
    this.rankUpPhrase = '',
    this.showWouldHaveEntered = true,
  });

  static const empty = UniversityIdentity();

  static const maxFreshmanName = 24;
  static const maxRankUpPhrase = 90;

  /// Colores sugeridos para empezar (el admin elige los reales).
  static const presets = <String, String>{
    '#15803D': 'Verde',
    '#9F1239': 'Granate',
    '#1E3A8A': 'Azul',
    '#B91C1C': 'Rojo',
    '#0F766E': 'Turquesa',
    '#F8FAFC': 'Blanco',
    '#7DD3FC': 'Celeste',
    '#0F172A': 'Negro',
  };

  /// `#RRGGBB`; vacío = sin bufanda.
  final String primaryColor;
  final String secondaryColor;
  final String freshmanName;
  final String rankUpPhrase;
  final bool showWouldHaveEntered;

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  factory UniversityIdentity.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    String text(String key) => raw[key] is String ? (raw[key] as String) : '';
    return UniversityIdentity(
      primaryColor: text('primaryColor'),
      secondaryColor: text('secondaryColor'),
      freshmanName: text('freshmanName'),
      rankUpPhrase: text('rankUpPhrase'),
      showWouldHaveEntered: raw['showWouldHaveEntered'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    if (primaryColor.trim().isNotEmpty)
      'primaryColor': primaryColor.trim().toUpperCase(),
    if (secondaryColor.trim().isNotEmpty)
      'secondaryColor': secondaryColor.trim().toUpperCase(),
    if (freshmanName.trim().isNotEmpty) 'freshmanName': freshmanName.trim(),
    if (rankUpPhrase.trim().isNotEmpty) 'rankUpPhrase': rankUpPhrase.trim(),
    'showWouldHaveEntered': showWouldHaveEntered,
  };

  UniversityIdentity copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? freshmanName,
    String? rankUpPhrase,
    bool? showWouldHaveEntered,
  }) => UniversityIdentity(
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    freshmanName: freshmanName ?? this.freshmanName,
    rankUpPhrase: rankUpPhrase ?? this.rankUpPhrase,
    showWouldHaveEntered: showWouldHaveEntered ?? this.showWouldHaveEntered,
  );

  /// El primer problema, en español, o null si está bien.
  String? validate() {
    final primary = primaryColor.trim();
    final secondary = secondaryColor.trim();
    if (primary.isNotEmpty && !_hex.hasMatch(primary)) {
      return 'El color principal debe ser #RRGGBB (por ejemplo #15803D).';
    }
    if (secondary.isNotEmpty && !_hex.hasMatch(secondary)) {
      return 'El color secundario debe ser #RRGGBB (por ejemplo #F8FAFC).';
    }
    if (primary.isEmpty && secondary.isNotEmpty) {
      return 'Elige primero el color principal.';
    }
    if (freshmanName.trim().length > maxFreshmanName) {
      return 'El nombre del ingresante tiene hasta $maxFreshmanName letras.';
    }
    if (rankUpPhrase.trim().length > maxRankUpPhrase) {
      return 'La frase tiene hasta $maxRankUpPhrase letras.';
    }
    return null;
  }
}
