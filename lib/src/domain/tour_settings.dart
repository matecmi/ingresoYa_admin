/// Recorridos del búho (`{config}/tours`, docs/tours_contract.md): guías que
/// se abren la primera vez en la app y en cada sección.

/// Un paso con su texto de fábrica (igual al de la app, `tour…` del ARB).
class TourStepInfo {
  const TourStepInfo(this.id, this.title, this.text, this.pose);

  final String id;
  final String title;
  final String text;
  final String pose;
}

class TourInfo {
  const TourInfo(this.id, this.label, this.steps);

  final String id;
  final String label;
  final List<TourStepInfo> steps;
}

const tourPoses = {
  'wave': 'Saluda',
  'point': 'Señala',
  'explain': 'Explica',
  'celebrate': 'Celebra',
};

/// Las guías que conoce la app; lo que señala cada paso lo fija la app.
const tourCatalog = [
  TourInfo('welcome', 'Bienvenida (primera vez en la app)', [
    TourStepInfo('intro', '¡Hola, {nombre}! Soy tu búho guía.', 'Te muestro la app en menos de un minuto. Puedes saltarlo cuando quieras.', 'wave'),
    TourStepInfo('home', 'Tu día empieza aquí', 'Tu plan de hoy, lo que tienes pendiente y las novedades de tu universidad.', 'point'),
    TourStepInfo('guide', 'Estudia por partes', 'Cada parte trae lección, ejemplos y un examen corto. Al aprobarlo, avanzas.', 'point'),
    TourStepInfo('simulator', 'Practica como el examen real', 'Exámenes pasados de tu universidad, prácticas por curso y el reto del día.', 'point'),
    TourStepInfo('progress', 'Mira cuánto te falta', 'Cuánto te acercas a ingresar, tus cursos fuertes y tu racha de días.', 'point'),
    TourStepInfo('profile', '¡Listo, a estudiar!', 'Aquí están tu rango, tu liga y tus ajustes. Te acompaño en cada sección.', 'celebrate'),
  ]),
  TourInfo('guide', 'Guía de estudio', [
    TourStepInfo('courses', 'Tus cursos', 'Los que más pesan en tu examen van primero. Toca uno para ver sus temas y partes.', 'point'),
    TourStepInfo('course', 'Avanza parte por parte', 'Cada curso muestra tu avance. Aprueba el examen de cada parte para completarlo.', 'explain'),
  ]),
  TourInfo('simulator', 'Simulador', [
    TourStepInfo('summary', 'Tus simulacros', 'Cuántos exámenes llevas y tu historial. Tócalo para ver tu progreso.', 'point'),
    TourStepInfo('challenge', 'El reto del día', 'Las mismas 10 preguntas para toda tu universidad. Un solo intento y XP extra.', 'point'),
    TourStepInfo('exams', 'Elige tu examen', 'Practica por curso, mezcla cursos, al azar o rinde un examen pasado completo.', 'celebrate'),
  ]),
  TourInfo('mistakes', 'Mis errores', [
    TourStepInfo('mission', 'Tu misión del día', 'Cada día te pido corregir unos errores. Al cumplirla ganas XP y sumas a tu racha.', 'point'),
    TourStepInfo('stats', 'Tus números', 'Cuántos te faltan repasar, cuántos ya corregiste y cuántos días seguidos cumples la misión.', 'point'),
    TourStepInfo('courses', 'Repasa por curso', 'Toca un curso para practicar solo sus errores. Cuando aciertes uno, sale de la lista.', 'celebrate'),
  ]),
  TourInfo('rankings', 'Rankings', [
    TourStepInfo('tabs', 'Tu liga y el reto', 'Cambia entre tu liga de la semana y la tabla del reto de hoy.', 'point'),
    TourStepInfo('league', 'Tu liga semanal', 'Ganas puntos con todo lo que estudias. Los primeros suben de etapa el domingo y tu búho evoluciona.', 'celebrate'),
  ]),
  TourInfo('progress', 'Progreso', [
    TourStepInfo('tabs', 'Tu progreso', 'Resumen, avance de la guía y tus números. Todo sale de tus exámenes.', 'point'),
    TourStepInfo('path', '¿Cuánto te falta?', 'Qué tan cerca estás de ingresar a tu carrera y qué cursos te acercan más.', 'celebrate'),
  ]),
  TourInfo('profile', 'Perfil', [
    TourStepInfo('rank', 'Tu rango', 'Subes de rango con el XP que ganas. Tócalo para ver todo el camino.', 'point'),
    TourStepInfo('tours', '¿Quieres verlo otra vez?', 'Aquí repites la bienvenida o vuelves a ver la guía de cada sección.', 'celebrate'),
  ]),
];

/// El texto que el admin puso a un paso; vacío = el de fábrica.
class TourStepText {
  const TourStepText({this.title = '', this.text = '', this.pose = ''});

  final String title;
  final String text;
  final String pose;

  bool get isEmpty => title.isEmpty && text.isEmpty && pose.isEmpty;

  static TourStepText fromMap(Object? raw) {
    if (raw is! Map) return const TourStepText();
    String s(String k) => raw[k] is String ? (raw[k] as String) : '';
    return TourStepText(title: s('title'), text: s('text'), pose: s('pose'));
  }

  Map<String, dynamic> toMap() => {
    if (title.trim().isNotEmpty) 'title': title.trim(),
    if (text.trim().isNotEmpty) 'text': text.trim(),
    if (tourPoses.containsKey(pose)) 'pose': pose,
  };
}

class TourSettings {
  const TourSettings({
    this.enabled = true,
    this.animate = true,
    this.maxPerSession = 1,
    this.version = 1,
    this.tourEnabled = const {},
    this.steps = const {},
  });

  static const defaults = TourSettings();
  static const maxTitle = 60;
  static const maxText = 160;

  final bool enabled;
  final bool animate;
  final int maxPerSession;
  final int version;

  /// Guía → encendida (ausente = encendida).
  final Map<String, bool> tourEnabled;

  /// `guía.paso` → texto del admin.
  final Map<String, TourStepText> steps;

  bool isOn(String tourId) => tourEnabled[tourId] ?? true;

  TourStepText stepOf(String tourId, String stepId) =>
      steps['$tourId.$stepId'] ?? const TourStepText();

  factory TourSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    final tours = data['tours'] is Map ? data['tours'] as Map : const {};
    final enabled = <String, bool>{};
    final steps = <String, TourStepText>{};
    for (final info in tourCatalog) {
      final raw = tours[info.id];
      if (raw is! Map) continue;
      enabled[info.id] = raw['enabled'] != false;
      final rawSteps = raw['steps'] is Map ? raw['steps'] as Map : const {};
      for (final step in info.steps) {
        final text = TourStepText.fromMap(rawSteps[step.id]);
        if (!text.isEmpty) steps['${info.id}.${step.id}'] = text;
      }
    }
    return TourSettings(
      enabled: data['enabled'] != false,
      animate: data['animate'] != false,
      maxPerSession: number('maxPerSession', defaults.maxPerSession),
      version: number('version', defaults.version),
      tourEnabled: enabled,
      steps: steps,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'animate': animate,
    'maxPerSession': maxPerSession,
    'version': version,
    'tours': {
      for (final info in tourCatalog)
        info.id: {
          'enabled': isOn(info.id),
          'steps': {
            for (final step in info.steps)
              if (!stepOf(info.id, step.id).isEmpty)
                step.id: stepOf(info.id, step.id).toMap(),
          },
        },
    },
  };

  TourSettings copyWith({Map<String, TourStepText>? steps}) => TourSettings(
    enabled: enabled,
    animate: animate,
    maxPerSession: maxPerSession,
    version: version,
    tourEnabled: tourEnabled,
    steps: steps ?? this.steps,
  );

  String? validate() {
    if (maxPerSession < 1 || maxPerSession > 5) {
      return 'Las guías por sesión van de 1 a 5.';
    }
    if (version < 1 || version > 100) {
      return 'La versión de los recorridos va de 1 a 100.';
    }
    for (final MapEntry(key: id, value: step) in steps.entries) {
      if (step.title.trim().length > maxTitle) {
        return 'El título de «$id» tiene hasta $maxTitle letras.';
      }
      if (step.text.trim().length > maxText) {
        return 'El texto de «$id» tiene hasta $maxText letras.';
      }
    }
    return null;
  }
}
