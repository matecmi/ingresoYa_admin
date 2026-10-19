import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ads_settings.dart';
import 'exam_settings.dart';
import 'plan_settings.dart';
import 'news.dart';
import 'quality_settings.dart';
import 'rankings_settings.dart';
import 'simulator_settings.dart';
import 'study_review_rules.dart';
import 'sync_settings.dart';
import 'xp_settings.dart';

/// Configuración en lenguaje simple (tableros 18 y 20 del lienzo).
///
/// Cada ajuste es una pregunta con su explicación, sus límites (los mismos que
/// valida el dominio y el servidor), qué pasa «en la práctica» y la pantalla
/// real de la app donde lo ve el alumno.

/// Documentos de `{config}` que edita esta pantalla.
enum SettingsDoc {
  rankings,
  xp,
  simulator,
  plan,
  study,
  sync,
  quality,
  news,
  exam,
  ads,
}

enum SettingKind { integer, toggle, choice, time }

/// Captura real del teléfono con zonas marcadas (coordenadas de 0 a 1).
class AppScreenShot {
  const AppScreenShot({
    required this.asset,
    required this.path,
    this.zones = const [],
  });

  final String asset;

  /// «Perfil → Rankings → Mi liga».
  final String path;
  final List<Rect> zones;
}

typedef SettingsValues = Map<SettingsDoc, Map<String, dynamic>>;

class SettingSpec {
  const SettingSpec({
    required this.doc,
    required this.path,
    required this.question,
    this.help = '',
    this.kind = SettingKind.integer,
    this.min,
    this.max,
    this.unit = '',
    this.choices = const {},
    this.inPractice,
    this.screen,
    this.advanced = false,
    this.keywords = '',
    this.label,
  });

  final SettingsDoc doc;
  final List<String> path;

  /// La pregunta que ve el administrador («¿Cuántos suben de liga?»).
  final String question;

  /// Nombre corto para el resumen de cambios («Suben de liga»).
  final String? label;
  final String help;
  final SettingKind kind;
  final int? min;
  final int? max;
  final String unit;
  final Map<Object, String> choices;

  /// Frase con el efecto real, armada con los valores actuales.
  final String Function(SettingsValues v)? inPractice;
  final AppScreenShot? screen;
  final bool advanced;
  final String keywords;

  String get id => '${doc.name}.${path.join('.')}';

  String get shortLabel => label ?? question;

  Object? read(SettingsValues v) => readPath(v[doc], path);

  /// Problema del valor, o `null` si está bien.
  String? check(Object? value) {
    switch (kind) {
      case SettingKind.integer:
        if (value is! int) return 'Escribe un número entero.';
        if (min != null && value < min!) return 'Mínimo $min$unitSuffix.';
        if (max != null && value > max!) return 'Máximo $max$unitSuffix.';
        return null;
      case SettingKind.time:
        if (value is! String ||
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
          return 'Usa el formato HH:mm (24 h), por ejemplo 19:00.';
        }
        return null;
      case SettingKind.toggle:
      case SettingKind.choice:
        return null;
    }
  }

  String get unitSuffix => unit.isEmpty ? '' : ' $unit';

  String format(Object? value) => switch (kind) {
    SettingKind.toggle => value == true ? 'Sí' : 'No',
    SettingKind.choice => choices[value] ?? '$value',
    _ => '$value$unitSuffix',
  };
}

Object? readPath(Map<String, dynamic>? map, List<String> path) {
  Object? cur = map;
  for (final key in path) {
    if (cur is! Map) return null;
    cur = cur[key];
  }
  return cur;
}

Map<String, dynamic> writePath(
  Map<String, dynamic> map,
  List<String> path,
  Object? value,
) {
  final out = Map<String, dynamic>.from(map);
  if (path.length == 1) {
    out[path.first] = value;
    return out;
  }
  final child = out[path.first] is Map
      ? Map<String, dynamic>.from(out[path.first] as Map)
      : <String, dynamic>{};
  out[path.first] = writePath(child, path.sublist(1), value);
  return out;
}

/// Combinación lista para elegir de un toque.
class SettingsPreset {
  const SettingsPreset(this.label, this.values, {this.recommended = false});

  final String label;
  final Map<String, Object> values;
  final bool recommended;
}

class SettingsTopic {
  const SettingsTopic({
    required this.id,
    required this.label,
    required this.icon,
    required this.intro,
    required this.specs,
    this.presets = const [],
    this.presetQuestion,
    this.screen,
    this.fullEditor,
  });

  final String id;
  final String label;
  final IconData icon;
  final String intro;
  final List<SettingSpec> specs;
  final String? presetQuestion;
  final List<SettingsPreset> presets;
  final AppScreenShot? screen;

  /// Clave del editor completo anterior (listas largas: rangos, etapas,
  /// palabras prohibidas, tamaños de práctica…).
  final String? fullEditor;
}

// ------------------------------------------------------------- capturas

const _miLiga = 'assets/app_screens/rk-mi-liga.jpg';
const _retoIntro = 'assets/app_screens/rk-reto-intro.jpg';
const _xpResultado = 'assets/app_screens/xp-resultado.jpg';
const _xpCamino = 'assets/app_screens/xp-camino.jpg';
const _simPractica = 'assets/app_screens/sim-practica.jpg';
const _simMeta = 'assets/app_screens/sim-meta.jpg';
const _estVideo = 'assets/app_screens/est-video.jpg';
const _estLeccion = 'assets/app_screens/est-leccion.jpg';

const _ligaPath = 'Perfil → Rankings → Mi liga';
const _ligaBanda = AppScreenShot(
  asset: _miLiga,
  path: _ligaPath,
  zones: [
    Rect.fromLTRB(.04, .312, .96, .404),
    Rect.fromLTRB(.04, .146, .96, .293),
  ],
);
const _ligaGrupo = AppScreenShot(
  asset: _miLiga,
  path: _ligaPath,
  zones: [Rect.fromLTRB(.04, .146, .96, .293)],
);
const _ligaSemana = AppScreenShot(
  asset: _miLiga,
  path: '$_ligaPath → «Esta semana»',
  zones: [Rect.fromLTRB(.04, .557, .96, .633)],
);
const _ligaReto = AppScreenShot(
  asset: _miLiga,
  path: '$_ligaPath → «Reto del día»',
  zones: [Rect.fromLTRB(.04, .423, .96, .542)],
);
const _ligaPuntos = AppScreenShot(
  asset: _miLiga,
  path: '$_ligaPath → «Cómo ganas puntos»',
  zones: [Rect.fromLTRB(.04, .647, .96, .789)],
);
const _retoPreguntas = AppScreenShot(
  asset: _retoIntro,
  path: 'Simulador → Reto del día',
  zones: [Rect.fromLTRB(.065, .483, .935, .546)],
);
const _retoDuracion = AppScreenShot(
  asset: _retoIntro,
  path: 'Simulador → Reto del día',
  zones: [Rect.fromLTRB(.065, .558, .935, .621)],
);
const _retoReglas = AppScreenShot(
  asset: _retoIntro,
  path: 'Simulador → Reto del día',
  zones: [Rect.fromLTRB(.065, .644, .935, .762)],
);
const _xpGanaste = AppScreenShot(
  asset: _xpResultado,
  path: 'Al terminar un examen → «Ganaste XP»',
  zones: [Rect.fromLTRB(.044, .407, .956, .655)],
);
const _xpTope = AppScreenShot(
  asset: _xpResultado,
  path: 'Al terminar un examen → «Ganaste XP»',
  zones: [Rect.fromLTRB(.07, .59, .93, .642)],
);
const _rangos = AppScreenShot(
  asset: _xpCamino,
  path: 'Perfil → Tu camino de rangos',
  zones: [Rect.fromLTRB(.04, .108, .96, .858)],
);
const _practicaBoton = AppScreenShot(
  asset: _simPractica,
  path: 'Simulador → Arma tu práctica',
  zones: [Rect.fromLTRB(.04, .783, .96, .846)],
);
const _practica = AppScreenShot(
  asset: _simPractica,
  path: 'Simulador → Arma tu práctica',
  zones: [Rect.fromLTRB(.04, .212, .96, .271)],
);
const _metaSesiones = AppScreenShot(
  asset: _simMeta,
  path: 'Simulador → Tu meta',
  zones: [Rect.fromLTRB(.046, .52, .954, .613)],
);
const _metaDia = AppScreenShot(
  asset: _simMeta,
  path: 'Simulador → Tu meta',
  zones: [Rect.fromLTRB(.046, .658, .954, .718)],
);
const _video = AppScreenShot(
  asset: _estVideo,
  path: 'Cursos → subtema → Video',
  zones: [Rect.fromLTRB(.083, .32, .917, .53)],
);
const _leccion = AppScreenShot(
  asset: _estLeccion,
  path: 'Cursos → subtema → Lección',
  zones: [Rect.fromLTRB(.04, .233, .96, .78)],
);

// ------------------------------------------------------------- ayudas

bool _on(SettingsValues v, SettingsDoc d, List<String> p, bool f) {
  final x = readPath(v[d], p);
  return x is bool ? x : f;
}

int _int(SettingsValues v, SettingsDoc d, List<String> p, int f) {
  final x = readPath(v[d], p);
  return x is num ? x.toInt() : f;
}

/// Igual que `movesFor` de Functions (functions/src/league.ts).
(int, int) leagueMoves(int size, int promote, int demote, int minForDemotion) {
  final up = size == 0 ? 0 : math.max(1, (size * promote / 100).round());
  final rawDown = size < minForDemotion ? 0 : (size * demote / 100).round();
  return (up, math.max(0, math.min(rawDown, size - up)));
}

String _leaguePractice(SettingsValues v) {
  final size = _int(v, SettingsDoc.rankings, ['league', 'groupSize'], 30);
  final up = _int(v, SettingsDoc.rankings, ['league', 'promotePercent'], 15);
  final down = _int(v, SettingsDoc.rankings, ['league', 'demotePercent'], 15);
  final min = _int(v, SettingsDoc.rankings, [
    'league',
    'minGroupForDemotion',
  ], 5);
  final (u, d) = leagueMoves(size, up, down, min);
  return 'En un grupo de $size, los $u primeros suben de etapa y los $d '
      'últimos bajan; los otros ${size - u - d} se quedan. En la primera etapa '
      'nadie baja y en la última nadie sube.';
}

// ------------------------------------------------------------- temas

final List<SettingsTopic> settingsTopics = [
  SettingsTopic(
    id: 'rankings',
    label: 'Rankings y ligas',
    icon: Icons.emoji_events_outlined,
    intro:
        'Liga semanal por etapas (Aspirante → Postulante → Finalista → '
        'Ingresante) y la tabla «Esta semana» por universidad y carrera.',
    screen: _ligaBanda,
    fullEditor: 'rankings',
    presetQuestion: '¿Cuántos suben y bajan de liga cada semana?',
    presets: const [
      SettingsPreset('Suave', {
        'league.promotePercent': 10,
        'league.demotePercent': 10,
        'league.groupSize': 30,
      }),
      SettingsPreset('Recomendado', {
        'league.promotePercent': 15,
        'league.demotePercent': 15,
        'league.groupSize': 30,
      }, recommended: true),
      SettingsPreset('Competitivo', {
        'league.promotePercent': 25,
        'league.demotePercent': 20,
        'league.groupSize': 20,
      }),
    ],
    specs: [
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['tableSize'],
        question:
            '¿Cuántas filas muestran las tablas «Esta semana» y del reto?',
        label: 'Filas de las tablas',
        min: 10,
        max: 100,
        unit: 'filas',
        help:
            'Cada fila es una lectura cuando un alumno abre la tabla. Su '
            'posición se calcula aparte, no depende de este número.',
        keywords: 'lecturas costo tabla top',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['tableCacheMinutes'],
        question:
            '¿Cuántos minutos guarda la app una tabla antes de volver a pedirla?',
        label: 'Minutos de caché de las tablas',
        min: 0,
        max: 60,
        unit: 'minutos',
        help: 'Tirar para refrescar la pide de nuevo. 0 = siempre fresca.',
        keywords: 'lecturas costo cache tabla',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['enabled'],
        kind: SettingKind.toggle,
        question: '¿Están encendidos los rankings?',
        label: 'Rankings encendidos',
        help:
            'Los alumnos ven su liga, «Esta semana» y el reto del día. Al '
            'encenderlos, la liga empieza el próximo lunes (semana completa).',
        inPractice: (v) {
          final on = readPath(v[SettingsDoc.rankings], ['enabled']) == true;
          final start = readPath(v[SettingsDoc.rankings], ['startWeek']);
          return on
              ? 'Encendidos${start is String && start.isNotEmpty ? ': la liga corre desde la semana del $start' : ''}.'
              : 'Apagados: el Perfil no muestra «Rankings» y no hay reto del día.';
        },
        screen: _ligaGrupo,
        keywords: 'activar apagar liga ranking',
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'groupSize'],
        question: '¿Cuántos alumnos compiten en cada grupo?',
        label: 'Alumnos por grupo',
        min: 5,
        max: 100,
        unit: 'alumnos',
        help: 'Cada semana el alumno compite con un grupo de su misma etapa.',
        inPractice: _leaguePractice,
        screen: _ligaGrupo,
        keywords: 'grupo tamaño liga',
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'promotePercent'],
        question: '¿Qué porcentaje del grupo sube de etapa?',
        label: 'Suben de liga',
        min: 0,
        max: 50,
        unit: '%',
        help: 'Se cuenta al cierre del domingo a medianoche.',
        inPractice: _leaguePractice,
        screen: _ligaBanda,
        keywords: 'cuantos suben ascenso promoción',
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'demotePercent'],
        question: '¿Qué porcentaje del grupo baja de etapa?',
        label: 'Bajan de liga',
        min: 0,
        max: 50,
        unit: '%',
        inPractice: _leaguePractice,
        screen: _ligaBanda,
        keywords: 'cuantos bajan descenso',
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'minGroupForDemotion'],
        question: '¿Desde cuántos alumnos en el grupo puede bajar alguien?',
        label: 'Mínimo para bajar',
        min: 1,
        max: 100,
        unit: 'alumnos',
        help: 'En grupos más chicos nadie baja, para no castigar a pocos.',
        inPractice: _leaguePractice,
        advanced: true,
        screen: _ligaBanda,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'preferSameUniversity'],
        kind: SettingKind.toggle,
        question: '¿Agrupar con alumnos de la misma universidad?',
        label: 'Grupos por universidad',
        help: 'Si no hay suficientes de su universidad, se completa con otros.',
        advanced: true,
        screen: _ligaGrupo,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'showWeekPositions'],
        kind: SettingKind.toggle,
        question:
            '¿Mostrar «Esta semana» (posición por universidad y carrera)?',
        label: '«Esta semana»',
        screen: _ligaSemana,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['league', 'minCareerPlayers'],
        question:
            '¿Cuántos alumnos de una carrera hacen falta para mostrar su tabla?',
        label: 'Mínimo por carrera (semana)',
        min: 1,
        max: 1000,
        unit: 'alumnos',
        help: 'Con menos, la app muestra «Aún hay pocos».',
        advanced: true,
        screen: _ligaSemana,
      ),
    ],
  ),
  SettingsTopic(
    id: 'challenge',
    label: 'Reto del día',
    icon: Icons.bolt_outlined,
    intro:
        'Las mismas preguntas para todos los alumnos de una universidad, un '
        'solo intento y tabla del día. Las respuestas se ven al día siguiente.',
    screen: _retoReglas,
    fullEditor: 'rankings',
    specs: [
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'enabled'],
        kind: SettingKind.toggle,
        question: '¿Hay reto del día?',
        label: 'Reto del día',
        help: 'Solo funciona con los rankings encendidos.',
        screen: _ligaReto,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'questionCount'],
        question: '¿Cuántas preguntas tiene el reto?',
        label: 'Preguntas del reto',
        min: 3,
        max: 30,
        unit: 'preguntas',
        inPractice: (v) {
          final n = _int(v, SettingsDoc.rankings, [
            'challenge',
            'questionCount',
          ], 10);
          final own = _int(v, SettingsDoc.rankings, [
            'challenge',
            'ownPastExamQuestions',
          ], 6);
          final m = _int(v, SettingsDoc.rankings, ['challenge', 'minutes'], 15);
          return '$n preguntas en $m minutos; al menos ${math.min(own, n)} '
              'salen de exámenes pasados de su universidad.';
        },
        screen: _retoPreguntas,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'minutes'],
        question: '¿Cuántos minutos dura?',
        label: 'Minutos del reto',
        min: 3,
        max: 120,
        unit: 'min',
        screen: _retoDuracion,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'bonusXp'],
        question: '¿Cuánto XP extra da terminarlo?',
        label: 'Bono del reto',
        min: 0,
        max: 1000,
        unit: 'XP',
        help: 'Se suma a lo que da una sesión normal.',
        inPractice: (v) =>
            'Al terminar: sesión normal + ${_int(v, SettingsDoc.rankings, ['challenge', 'bonusXp'], 20)} XP '
            '(«Reto del día +${_int(v, SettingsDoc.rankings, ['challenge', 'bonusXp'], 20)}»).',
        screen: _ligaPuntos,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'ownPastExamQuestions'],
        question:
            '¿Cuántas preguntas, como mínimo, salen de exámenes pasados de su universidad?',
        label: 'Preguntas de exámenes propios',
        min: 0,
        max: 30,
        unit: 'preguntas',
        help:
            'El resto se completa con otros exámenes y preguntas de IngresoYa.',
        advanced: true,
        screen: _retoPreguntas,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'noRepeatDays'],
        question: '¿Cuántos días sin repetir una pregunta en el reto?',
        label: 'Días sin repetir (reto)',
        min: 0,
        max: 365,
        unit: 'días',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.rankings,
        path: const ['challenge', 'minCareerPlayers'],
        question:
            '¿Cuántos alumnos de una carrera hacen falta para su tabla del día?',
        label: 'Mínimo por carrera (reto)',
        min: 1,
        max: 1000,
        unit: 'alumnos',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'xp',
    label: 'Cómo gana XP el alumno',
    icon: Icons.stars_outlined,
    intro:
        'Puntos por estudiar: secciones, partes, subtemas, sesiones del '
        'Simulador, aciertos nuevos y racha. 0 desactiva un evento.',
    screen: _xpGanaste,
    specs: [
      for (final (key, label, _) in xpAmountFields)
        SettingSpec(
          doc: SettingsDoc.xp,
          path: ['amounts', key],
          question: '¿Cuánto XP da: ${label.toLowerCase()}?',
          label: label,
          min: 0,
          max: 1000,
          unit: 'XP',
          screen: _xpGanaste,
          keywords: 'xp puntos $label',
        ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['dailyCap'],
        question:
            '¿Cuánto XP como máximo por día (sesiones, respuestas y racha)?',
        label: 'Tope diario',
        min: 0,
        max: 100000,
        unit: 'XP',
        help: '0 = sin tope. La guía de estudio no cuenta para el tope.',
        inPractice: (v) {
          final cap = _int(v, SettingsDoc.xp, ['dailyCap'], 300);
          return cap == 0
              ? 'Sin tope diario.'
              : 'La app muestra «Hoy llevas N de $cap XP posibles por día».';
        },
        screen: _xpTope,
      ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['minQuestionsPerSession'],
        question: '¿Cuántas preguntas como mínimo para que una sesión dé XP?',
        label: 'Mínimo por sesión (XP)',
        min: 1,
        max: 300,
        unit: 'preguntas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['repeatWindowDays'],
        question:
            '¿Cuántos días para que una respuesta correcta vuelva a dar XP?',
        label: 'Días para no repetir (XP)',
        min: 0,
        max: 365,
        unit: 'días',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['minSecondsPerQuestion'],
        question: '¿Cuántos segundos por pregunta como mínimo para dar XP?',
        label: 'Segundos mínimos por pregunta',
        min: 0,
        max: 600,
        unit: 's',
        help: 'Evita que alguien gane XP marcando al azar muy rápido.',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['pastExamEveryDays'],
        question: '¿Cada cuántos días un mismo examen pasado vuelve a dar XP?',
        label: 'Examen pasado cada',
        min: 0,
        max: 365,
        unit: 'días',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'levels',
    label: 'Niveles e insignias',
    icon: Icons.military_tech_outlined,
    intro:
        'La escalera de rangos del Perfil (Bronce I → …) y las estrellas que '
        'se ganan después del último rango.',
    screen: _rangos,
    fullEditor: 'xp',
    specs: [
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['starsEnabled'],
        kind: SettingKind.toggle,
        question: '¿Se ganan estrellas después del último rango?',
        label: 'Estrellas',
        screen: _rangos,
      ),
      SettingSpec(
        doc: SettingsDoc.xp,
        path: const ['xpPerStar'],
        question: '¿Cuánto XP cuesta cada estrella?',
        label: 'XP por estrella',
        min: 100,
        max: 100000,
        unit: 'XP',
        screen: _rangos,
      ),
    ],
  ),
  SettingsTopic(
    id: 'simulator',
    label: 'Simulador de examen',
    icon: Icons.play_circle_outline,
    intro:
        'Cómo arma el alumno su práctica: tamaños, reloj, penalidad, origen y '
        'dificultad de las preguntas, y qué exámenes pasados ve.',
    screen: _practicaBoton,
    fullEditor: 'simulator',
    specs: [
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['resultsLimit'],
        question: '¿Cuántos resultados recientes baja la app?',
        label: 'Resultados que baja la app',
        min: SimulatorSettings.minResultsLimit,
        max: SimulatorSettings.maxResultsLimit,
        unit: 'resultados',
        help:
            'Alimentan el historial, las estadísticas y «Hoy te toca». Cada '
            'resultado es una lectura por sesión.',
        keywords: 'lecturas costo historial estadisticas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['topicStatsLimit'],
        question: '¿Cuántos temas con estadística baja la app para el plan?',
        label: 'Temas con estadística',
        min: SimulatorSettings.minTopicStatsLimit,
        max: SimulatorSettings.maxTopicStatsLimit,
        unit: 'temas',
        help: 'Los más practicados. «Hoy te toca» elige entre ellos.',
        keywords: 'lecturas costo plan temas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['practiceTimerDefault'],
        kind: SettingKind.toggle,
        question: '¿La práctica viene con reloj?',
        label: 'Reloj en la práctica',
        help: 'El alumno puede cambiarlo antes de empezar.',
        screen: _practicaBoton,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['practicePenalty'],
        kind: SettingKind.toggle,
        question: '¿Las incorrectas restan en la práctica?',
        label: 'Penalidad',
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['defaultSource'],
        kind: SettingKind.choice,
        choices: SimulatorSettings.sources,
        question: '¿De dónde salen las preguntas por defecto?',
        label: 'Origen de las preguntas',
        screen: _practica,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['defaultDifficulty'],
        kind: SettingKind.choice,
        choices: SimulatorSettings.difficulties,
        question: '¿Qué dificultad por defecto?',
        label: 'Dificultad',
        screen: _practica,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['repeatWindowDays'],
        question: '¿Cuántos días sin repetir una pregunta ya vista?',
        label: 'Días sin repetir (Simulador)',
        min: 0,
        max: SimulatorSettings.maxRepeatWindowDays,
        unit: 'días',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['showOtherUniversities'],
        kind: SettingKind.toggle,
        question: '¿Mostrar exámenes pasados de otras universidades?',
        label: 'Otras universidades',
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['onlyCompleteExams'],
        kind: SettingKind.toggle,
        question: '¿Ocultar los exámenes pasados incompletos?',
        label: 'Ocultar incompletos',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.simulator,
        path: const ['showExplanations'],
        kind: SettingKind.toggle,
        question: '¿Mostrar la explicación al revisar?',
        label: 'Explicaciones',
      ),
    ],
  ),
  SettingsTopic(
    id: 'plan',
    label: 'Plan de entrenamiento',
    icon: Icons.event_available_outlined,
    intro:
        '«Hoy te toca»: sesiones por semana, tamaño de la sesión diaria, '
        'cuánto pesan los temas débiles, diagnóstico, simulacro y racha.',
    screen: _metaSesiones,
    fullEditor: 'plan',
    specs: [
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['dailyQuestions'],
        question: '¿Cuántas preguntas tiene la sesión del día?',
        label: 'Preguntas por sesión',
        min: 5,
        max: 40,
        unit: 'preguntas',
        screen: _metaSesiones,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['dailyMinutes'],
        question: '¿Cuántos minutos dura la sesión del día?',
        label: 'Minutos por sesión',
        min: 5,
        max: 120,
        unit: 'min',
        inPractice: (v) =>
            'La app dice «Cada sesión: unos ${_int(v, SettingsDoc.plan, ['dailyMinutes'], 15)} minutos».',
        screen: _metaSesiones,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['weakSharePercent'],
        question: '¿Qué parte de la sesión va a sus temas débiles?',
        label: 'Temas débiles en la sesión',
        min: 0,
        max: 100,
        unit: '%',
        inPractice: (v) {
          final n = _int(v, SettingsDoc.plan, ['dailyQuestions'], 10);
          final p = _int(v, SettingsDoc.plan, ['weakSharePercent'], 60);
          return 'De $n preguntas, unas ${(n * p / 100).round()} son de sus '
              'temas más flojos.';
        },
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['weakThresholdPercent'],
        question: '¿Por debajo de qué % de acierto un tema es débil?',
        label: 'Umbral de tema débil',
        min: 1,
        max: 99,
        unit: '%',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['minAnswersToJudge'],
        question: '¿Cuántas respuestas hacen falta para juzgar un tema?',
        label: 'Respuestas para juzgar',
        min: 1,
        max: 50,
        unit: 'respuestas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['diagnosticPerCourse'],
        question: '¿Cuántas preguntas por curso tiene el diagnóstico?',
        label: 'Diagnóstico por curso',
        min: 1,
        max: 10,
        unit: 'preguntas',
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['diagnosticMinutes'],
        question: '¿Cuántos minutos dura el diagnóstico?',
        label: 'Minutos del diagnóstico',
        min: 5,
        max: 180,
        unit: 'min',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['defaultMockDay'],
        kind: SettingKind.choice,
        choices: PlanSettings.weekDays,
        question: '¿Qué día se sugiere el simulacro completo?',
        label: 'Día del simulacro',
        screen: _metaDia,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['defaultReminderTime'],
        kind: SettingKind.time,
        question: '¿A qué hora se sugiere el recordatorio?',
        label: 'Hora del recordatorio',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['showWhy'],
        kind: SettingKind.toggle,
        question: '¿Explicar «¿Por qué esta sesión?»?',
        label: '«¿Por qué?»',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['minQuestionsPerSession'],
        question: '¿Cuántas preguntas respondidas hacen que la sesión cuente?',
        label: 'Mínimo para contar la sesión',
        min: 1,
        max: 100,
        unit: 'preguntas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['streakGraceDays'],
        question: '¿Cuántos días puede faltar sin perder la racha?',
        label: 'Gracia de la racha',
        min: 0,
        max: 7,
        unit: 'días',
      ),
      SettingSpec(
        doc: SettingsDoc.plan,
        path: const ['freeExamsCount'],
        kind: SettingKind.toggle,
        question: '¿Los exámenes libres cuentan para la meta de la semana?',
        label: 'Exámenes libres cuentan',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'study',
    label: 'Guía de estudio',
    icon: Icons.menu_book_outlined,
    intro:
        'Cuándo una sección de una parte (Video, Lección, Ejemplos, Repasar, '
        'Recursos) queda «Revisada». Con todas revisadas se habilita el examen '
        'de la parte.',
    screen: _video,
    specs: [
      SettingSpec(
        doc: SettingsDoc.study,
        path: const ['strict'],
        kind: SettingKind.toggle,
        question: '¿Exigir tiempo mínimo y porcentaje de video?',
        label: 'Exigir tiempo y video',
        help: 'Apagado: basta con entrar a la sección (y reproducir el video).',
        screen: _video,
      ),
      SettingSpec(
        doc: SettingsDoc.study,
        path: const ['videoMinPercent'],
        question: '¿Qué porcentaje del video debe ver?',
        label: '% mínimo de video',
        min: 1,
        max: 100,
        unit: '%',
        help: 'Solo cuenta la reproducción real; adelantar no suma.',
        screen: _video,
      ),
      SettingSpec(
        doc: SettingsDoc.study,
        path: const ['sectionMinSeconds'],
        question: '¿Cuántos segundos mínimo debe quedarse en cada sección?',
        label: 'Segundos por sección',
        min: 0,
        max: 300,
        unit: 's',
        screen: _leccion,
      ),
      SettingSpec(
        doc: SettingsDoc.sync,
        path: const ['autoSyncEnabled'],
        kind: SettingKind.toggle,
        question: '¿Sincronizar el avance automáticamente?',
        label: 'Sincronización automática',
        help: 'Siempre sube al salir de la app y al aprobar un examen.',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.sync,
        path: const ['debounceSeconds'],
        question:
            '¿Cuántos segundos espera tras el último cambio para subirlo?',
        label: 'Espera tras el último cambio',
        min: 5,
        max: 600,
        unit: 's',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.sync,
        path: const ['maxWaitSeconds'],
        question: '¿Cuánto espera como máximo si el alumno sigue estudiando?',
        label: 'Espera máxima',
        min: 5,
        max: 3600,
        unit: 's',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.sync,
        path: const ['refreshEveryHours'],
        question: '¿Cada cuántas horas revisa cambios de otros dispositivos?',
        label: 'Revisar otros dispositivos',
        min: 1,
        max: 168,
        unit: 'h',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'exam',
    label: 'Exámenes',
    icon: Icons.save_outlined,
    intro:
        'Cómo guarda la app las respuestas mientras el alumno rinde un examen '
        'y cuántas preguntas revisa el servidor para armar cada examen. Las '
        'respuestas nunca se pierden en el teléfono; esto decide cada cuánto '
        'viajan y cuánto cuesta cada examen en lecturas.',
    presetQuestion: '¿Cuánta variedad quieres al armar los exámenes?',
    presets: const [
      SettingsPreset('Económico', {
        'candidateStartsPerBlock': 1,
        'maxCandidatesPerStart': 20,
        'recentQuestionLimit': 30,
        'simulatorSeenLimit': 50,
      }),
      SettingsPreset('Recomendado', {
        'candidateStartsPerBlock': 2,
        'maxCandidatesPerStart': 40,
        'recentQuestionLimit': 60,
        'simulatorSeenLimit': 100,
      }, recommended: true),
      SettingsPreset('Variado', {
        'candidateStartsPerBlock': 4,
        'maxCandidatesPerStart': 80,
        'recentQuestionLimit': 200,
        'simulatorSeenLimit': 300,
      }),
    ],
    specs: [
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['saveEveryAnswers'],
        question: '¿Cada cuántas respuestas se guardan en el servidor?',
        label: 'Respuestas por guardado',
        min: ExamSettings.minSaveEveryAnswers,
        max: ExamSettings.maxSaveEveryAnswers,
        unit: 'respuestas',
        help:
            '1 = una llamada por respuesta (como antes). Al pausar, salir o '
            'enviar siempre se guarda todo.',
        keywords: 'guardar respuestas costo llamadas examen',
        inPractice: (v) {
          final n = _int(v, SettingsDoc.exam, ['saveEveryAnswers'], 5);
          final s = _int(v, SettingsDoc.exam, ['saveEverySeconds'], 30);
          return 'Un examen de 10 preguntas hace unas ${(10 / n).ceil()} '
              'llamadas de guardado (o una cada $s s si responde despacio), más '
              'el envío.';
        },
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['saveEverySeconds'],
        question:
            '¿Cuántos segundos como máximo entre un cambio y su guardado?',
        label: 'Segundos entre guardados',
        min: ExamSettings.minSaveEverySeconds,
        max: ExamSettings.maxSaveEverySeconds,
        unit: 's',
        help: 'Aunque no se llegue al número de respuestas.',
        keywords: 'guardar respuestas costo segundos examen',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['candidateStartsPerBlock'],
        question: '¿Cuántos escaneos del banco hace el servidor por bloque?',
        label: 'Escaneos por bloque',
        min: ExamSettings.minCandidateStarts,
        max: ExamSettings.maxCandidateStarts,
        unit: 'escaneos',
        help:
            'Cada escaneo trae candidatas desde un punto aleatorio del banco. '
            'Más escaneos = más variedad y más lecturas por examen.',
        keywords: 'lecturas costo variedad seleccion banco',
        advanced: true,
        inPractice: (v) {
          final starts = _int(v, SettingsDoc.exam, [
            'candidateStartsPerBlock',
          ], 2);
          final per = _int(v, SettingsDoc.exam, ['maxCandidatesPerStart'], 40);
          final recent = _int(v, SettingsDoc.exam, ['recentQuestionLimit'], 60);
          return 'Un examen de parte de 10 preguntas lee hasta '
              '${starts * per} candidatas y $recent preguntas recientes del '
              'alumno (más unas 10 lecturas fijas).';
        },
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['maxCandidatesPerStart'],
        question: '¿Cuántas candidatas trae cada escaneo?',
        label: 'Candidatas por escaneo',
        min: ExamSettings.candidatesPerStartMin,
        max: ExamSettings.candidatesPerStartMax,
        unit: 'preguntas',
        help: 'También es el tope de cada pool por curso del Simulador.',
        keywords: 'lecturas costo candidatas seleccion',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['recentQuestionLimit'],
        question:
            '¿Cuántas preguntas recientes del alumno se revisan para no repetir (guía)?',
        label: 'Recientes revisadas (guía)',
        min: ExamSettings.minRecentQuestions,
        max: ExamSettings.maxRecentQuestions,
        unit: 'preguntas',
        help: 'Las más recientes. Cada una es una lectura al crear el examen.',
        keywords: 'lecturas costo repetir recientes',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['simulatorSeenLimit'],
        question:
            '¿Cuántas preguntas vistas revisa el Simulador en su ventana de repetición?',
        label: 'Vistas revisadas (Simulador)',
        min: ExamSettings.minSimulatorSeen,
        max: ExamSettings.maxSimulatorSeen,
        unit: 'preguntas',
        help:
            'Dentro de los «días sin repetir» del Simulador. Cada una es una '
            'lectura al crear la práctica o «Hoy te toca».',
        keywords: 'lecturas costo repetir simulador vistas',
        advanced: true,
      ),
      SettingSpec(
        doc: SettingsDoc.exam,
        path: const ['attemptRetentionDays'],
        question:
            '¿Cuántos días se guarda cada examen rendido con sus preguntas?',
        label: 'Días que se guarda un intento',
        min: ExamSettings.minRetentionDays,
        max: ExamSettings.maxRetentionDays,
        unit: 'días',
        help:
            'Después Firestore lo borra solo. El historial, las estadísticas y '
            'los mejores puntajes del alumno no se borran: viven en resúmenes '
            'aparte. Un intento ocupa de 25 a 250 KB con sus preguntas.',
        keywords: 'almacenamiento costo borrar intentos ttl',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'quality',
    label: 'Preguntas a revisar',
    icon: Icons.fact_check_outlined,
    intro:
        'Cuándo una pregunta aparece en Calidad → «Preguntas a revisar», '
        'según lo que respondieron los alumnos. Solo lo usa el admin.',
    specs: [
      SettingSpec(
        doc: SettingsDoc.quality,
        path: const ['minAnswers'],
        question:
            '¿Cuántas respuestas hacen falta para opinar sobre una pregunta?',
        label: 'Respuestas mínimas',
        min: 5,
        max: 500,
        unit: 'respuestas',
        help: 'Con menos, no se saca ninguna conclusión.',
      ),
      SettingSpec(
        doc: SettingsDoc.quality,
        path: const ['failPercent'],
        question: '¿Desde qué porcentaje de error «casi todos fallan»?',
        label: '«Casi todos fallan»',
        min: 50,
        max: 100,
        unit: '%',
      ),
      SettingSpec(
        doc: SettingsDoc.quality,
        path: const ['dominantWrongPercent'],
        question:
            '¿Qué parte de las respuestas debe llevarse una alternativa incorrecta para sospechar de la clave?',
        label: 'Alternativa que atrae',
        min: 20,
        max: 100,
        unit: '%',
      ),
      SettingSpec(
        doc: SettingsDoc.quality,
        path: const ['easyPercent'],
        question: '¿Desde qué porcentaje de acierto es «demasiado fácil»?',
        label: '«Demasiado fácil»',
        min: 50,
        max: 100,
        unit: '%',
      ),
      SettingSpec(
        doc: SettingsDoc.quality,
        path: const ['deadAlternativeAnswers'],
        question:
            '¿Con cuántas respuestas se avisa de una alternativa que nadie elige?',
        label: '«Nadie la elige»',
        min: 10,
        max: 1000,
        unit: 'respuestas',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'news',
    label: 'Noticias',
    icon: Icons.campaign_outlined,
    intro:
        'Cuántos avisos urgentes se permiten y cuánto duran las historias en '
        'el Inicio de la app. Las noticias se publican en Alumnos → Noticias.',
    specs: [
      SettingSpec(
        doc: SettingsDoc.news,
        path: const ['feedLimit'],
        question: '¿Cuántas noticias baja la app al abrir el Inicio?',
        label: 'Noticias que baja la app',
        min: 5,
        max: 80,
        unit: 'noticias',
        help:
            'Las más nuevas. Cada noticia es una lectura por alumno y sesión; '
            'con 20 alcanza para las historias y la lista.',
        keywords: 'lecturas costo inicio lista',
        advanced: true,
        inPractice: (v) =>
            'Cada vez que un alumno abre la app se bajan como máximo '
            '${_int(v, SettingsDoc.news, ['feedLimit'], 20)} noticias.',
      ),
      SettingSpec(
        doc: SettingsDoc.news,
        path: const ['urgentPerWeek'],
        question:
            '¿Cuántos avisos urgentes (ventana al abrir la app) se permiten por semana?',
        label: 'Avisos urgentes por semana',
        min: 0,
        max: 7,
        unit: 'avisos',
        help:
            'Para la misma audiencia. Abusar de la ventana hace que los '
            'alumnos dejen de leerla. 0 la desactiva.',
        keywords: 'urgente ventana aviso importante',
        inPractice: (v) =>
            switch (_int(v, SettingsDoc.news, ['urgentPerWeek'], 1)) {
              0 => 'No se pueden publicar avisos urgentes.',
              1 => 'Un alumno ve como máximo una ventana de aviso por semana.',
              final n =>
                'Un alumno ve como máximo $n ventanas de aviso por semana.',
            },
      ),
      SettingSpec(
        doc: SettingsDoc.news,
        path: const ['storyDays'],
        question: '¿Cuántos días queda una historia en el Inicio?',
        label: 'Días de una historia',
        min: 1,
        max: 30,
        unit: 'días',
        help: 'Después sigue en la lista de Noticias, pero sale de la fila.',
        keywords: 'historias stories inicio',
      ),
      SettingSpec(
        doc: SettingsDoc.news,
        path: const ['maxStories'],
        question: '¿Cuántas historias caben en la fila del Inicio?',
        label: 'Historias en el Inicio',
        min: 1,
        max: 10,
        unit: 'historias',
        help: 'Se muestran las más nuevas primero.',
        keywords: 'historias stories inicio',
        advanced: true,
      ),
    ],
  ),
  SettingsTopic(
    id: 'ads',
    label: 'Anuncios',
    icon: Icons.ads_click_outlined,
    intro:
        'Anuncios de AdMob en la app: dónde va el banner, cada cuánto sale un '
        'anuncio de pantalla completa y si hay videos a cambio de una ayuda. '
        'Los alumnos premium no ven ninguno. Nunca hay anuncios dentro de una '
        'lección, un examen, el simulador ni las historias.',
    specs: [
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['enabled'],
        question: '¿Se muestran anuncios en la app?',
        label: 'Anuncios encendidos',
        kind: SettingKind.toggle,
        help:
            'Apagado, la app no carga ningún anuncio (sin publicar una versión '
            'nueva). Enciéndelo cuando la cuenta de AdMob esté aprobada.',
        keywords: 'admob publicidad encender apagar monetizar',
        inPractice: (v) => _on(v, SettingsDoc.ads, ['enabled'], false)
            ? 'Los alumnos sin premium ven anuncios donde se indica abajo.'
            : 'Nadie ve anuncios. Lo demás de esta sección no tiene efecto.',
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['bannerScreens', 'home'],
        question: '¿Banner al pie del Inicio?',
        label: 'Banner en Inicio',
        kind: SettingKind.toggle,
        help: 'Una franja pequeña sobre la barra de pestañas.',
        keywords: 'banner inicio franja',
        inPractice: (v) => _bannerPractice(v),
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['bannerScreens', 'news'],
        question: '¿Banner al pie de la lista de noticias?',
        label: 'Banner en Noticias',
        kind: SettingKind.toggle,
        help: 'Solo en la lista; nunca dentro de una noticia ni en historias.',
        keywords: 'banner noticias franja',
        inPractice: (v) => _bannerPractice(v),
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['bannerScreens', 'rankings'],
        question: '¿Banner al pie de Rankings?',
        label: 'Banner en Rankings',
        kind: SettingKind.toggle,
        help: 'En «Mi liga» y las tablas.',
        keywords: 'banner rankings liga franja',
        inPractice: (v) => _bannerPractice(v),
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['interstitialMinMinutes'],
        question:
            '¿Cuántos minutos como mínimo pasan entre dos anuncios de pantalla '
            'completa?',
        label: 'Minutos entre anuncios completos',
        min: AdsSettings.minInterstitialMinutes,
        max: AdsSettings.maxInterstitialMinutes,
        unit: 'min',
        help:
            'El anuncio de pantalla completa sale al cerrar el resultado de un '
            'examen o simulacro. Con 10, un alumno que encadena simulacros ve '
            'uno cada 10 minutos como mucho.',
        keywords: 'intersticial pantalla completa frecuencia resultado',
        inPractice: (v) =>
            'Tras cerrar un resultado, el siguiente anuncio de pantalla '
            'completa espera al menos '
            '${_int(v, SettingsDoc.ads, ['interstitialMinMinutes'], 10)} '
            'minutos'
            '${_on(v, SettingsDoc.ads, ['firstExamOfDayFree'], true) ? '; el primer examen del día nunca lo muestra.' : '.'}',
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['firstExamOfDayFree'],
        question:
            '¿El primer examen del día va sin anuncio de pantalla completa?',
        label: 'Primer examen del día sin anuncio',
        kind: SettingKind.toggle,
        help:
            'Recomendado: el alumno que entra a estudiar no se topa con un '
            'anuncio en su primer resultado del día.',
        keywords: 'primer examen día gratis intersticial',
      ),
      SettingSpec(
        doc: SettingsDoc.ads,
        path: const ['rewardedEnabled'],
        question:
            '¿Se ofrecen videos a cambio de ver la explicación de una pregunta fallada?',
        label: 'Videos recompensados',
        kind: SettingKind.toggle,
        help:
            'En la revisión de un examen, la explicación de una pregunta '
            'fallada se abre tras un video corto (las acertadas se ven '
            'directo). Si el video no carga, la explicación se abre igual.',
        keywords: 'video recompensado explicación fallada rewarded',
        inPractice: (v) => _on(v, SettingsDoc.ads, ['rewardedEnabled'], true)
            ? 'Explicación de una pregunta fallada: tras un video corto.'
            : 'Las explicaciones se ven directo, sin video.',
      ),
    ],
  ),
];

String _bannerPractice(SettingsValues v) {
  final on = AdsSettings.bannerScreenIds
      .where((id) => _on(v, SettingsDoc.ads, ['bannerScreens', id], false))
      .map((id) => AdsSettings.bannerScreenLabels[id] ?? id)
      .toList();
  return on.isEmpty ? 'Ningún banner.' : 'Banner al pie de: ${on.join(', ')}.';
}

List<SettingSpec> get allSettingSpecs => [
  for (final t in settingsTopics) ...t.specs,
];

SettingSpec? specById(String id) =>
    allSettingSpecs.where((s) => s.id == id).firstOrNull;

/// Búsqueda sin tildes en preguntas, ayuda y palabras clave.
List<(SettingsTopic, SettingSpec)> searchSettings(String query) {
  String fold(String s) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  final words = fold(query).split(RegExp(r'\s+')).where((w) => w.length >= 2);
  if (words.isEmpty) return const [];
  return [
    for (final t in settingsTopics)
      for (final s in t.specs)
        if (words.every(
          (w) => fold(
            '${s.question} ${s.help} ${s.keywords} ${s.label ?? ''} ${t.label}',
          ).contains(w),
        ))
          (t, s),
  ];
}

/// Valores de fábrica de cada documento.
Map<String, dynamic> factoryValues(SettingsDoc doc) => switch (doc) {
  SettingsDoc.rankings => RankingsSettings.defaults.toMap(),
  SettingsDoc.xp => XpSettings.defaults.toMap(),
  SettingsDoc.simulator => SimulatorSettings.defaults.toMap(),
  SettingsDoc.plan => PlanSettings.defaults.toMap(),
  SettingsDoc.study => StudyReviewRules.defaults.toMap(),
  SettingsDoc.sync => SyncSettings.defaults.toMap(),
  SettingsDoc.quality => QualitySettings.defaults.toMap(),
  SettingsDoc.news => NewsSettings.defaults.toMap(),
  SettingsDoc.exam => ExamSettings.defaults.toMap(),
  SettingsDoc.ads => AdsSettings.defaults.toMap(),
};

/// Pasa el mapa por el dominio (mismas reglas que la app y Functions) y
/// devuelve el primer problema, o `null`.
String? validateDoc(SettingsDoc doc, Map<String, dynamic> map) => switch (doc) {
  SettingsDoc.rankings => RankingsSettings.fromMap(map).validate(),
  SettingsDoc.xp => XpSettings.fromMap(map).validate(),
  SettingsDoc.simulator => SimulatorSettings.fromMap(map).validate(),
  SettingsDoc.plan => PlanSettings.fromMap(map).validate(),
  SettingsDoc.study => StudyReviewRules.fromMap(map).validate(),
  SettingsDoc.sync => SyncSettings.fromMap(map).validate(),
  SettingsDoc.quality => QualitySettings.fromMap(map).validate(),
  SettingsDoc.news => NewsSettings.fromMap(map).validate(),
  SettingsDoc.exam => ExamSettings.fromMap(map).validate(),
  SettingsDoc.ads => AdsSettings.fromMap(map).validate(),
};

/// El mapa tal como lo dejaría el dominio al leerlo (para detectar valores que
/// el dominio cambiaría en silencio).
Map<String, dynamic> validateMapRoundTrip(
  SettingsDoc doc,
  Map<String, dynamic> map,
) => switch (doc) {
  SettingsDoc.rankings => RankingsSettings.fromMap(map).toMap(),
  SettingsDoc.xp => XpSettings.fromMap(map).toMap(),
  SettingsDoc.simulator => SimulatorSettings.fromMap(map).toMap(),
  SettingsDoc.plan => PlanSettings.fromMap(map).toMap(),
  SettingsDoc.study => StudyReviewRules.fromMap(map).toMap(),
  SettingsDoc.sync => SyncSettings.fromMap(map).toMap(),
  SettingsDoc.quality => QualitySettings.fromMap(map).toMap(),
  SettingsDoc.news => NewsSettings.fromMap(map).toMap(),
  SettingsDoc.exam => ExamSettings.fromMap(map).toMap(),
  SettingsDoc.ads => AdsSettings.fromMap(map).toMap(),
};
