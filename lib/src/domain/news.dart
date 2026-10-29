import 'package:cloud_firestore/cloud_firestore.dart';

/// Noticias que ve el alumno (docs/news_contract.md). Una sola colección:
/// la app decide si una noticia sale como ventana al abrir, fijada en el
/// Inicio, historia o solo en la lista, según [priority], [universityIds] y
/// la universidad del alumno.

enum NewsCategory {
  notice('notice', 'Aviso'),
  admission('admission', 'Examen de admisión'),
  appUpdate('appUpdate', 'Novedad de la app'),
  tip('tip', 'Consejo');

  const NewsCategory(this.key, this.label);

  final String key;
  final String label;

  static NewsCategory fromKey(Object? key) =>
      values.firstWhere((c) => c.key == key, orElse: () => NewsCategory.notice);
}

enum NewsPriority {
  normal('normal', 'Normal', 'Sale en la lista de Noticias.'),
  pinned(
    'pinned',
    'Fijada',
    'Además queda fijada arriba del Inicio hasta que venza.',
  ),
  urgent(
    'urgent',
    'Urgente',
    'Además sale en una ventana al abrir la app (una sola vez) y queda fijada.',
  );

  const NewsPriority(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;

  static NewsPriority fromKey(Object? key) =>
      values.firstWhere((p) => p.key == key, orElse: () => NewsPriority.normal);
}

enum NewsStatus {
  draft('draft', 'Borrador'),
  published('published', 'Publicada'),
  archived('archived', 'Archivada');

  const NewsStatus(this.key, this.label);

  final String key;
  final String label;

  static NewsStatus fromKey(Object? key) =>
      values.firstWhere((s) => s.key == key, orElse: () => NewsStatus.draft);
}

/// Qué hace el botón de acción de la noticia.
enum NewsActionType {
  url('url', 'Abrir una web'),
  route('route', 'Abrir una sección de la app');

  const NewsActionType(this.key, this.label);

  final String key;
  final String label;

  static NewsActionType fromKey(Object? key) =>
      values.firstWhere((t) => t.key == key, orElse: () => NewsActionType.url);
}

/// Secciones de la app que puede abrir el botón (ruta de go_router en la app).
const newsAppRoutes = <(String, String)>[
  ('/simulators', 'Simulador'),
  ('/admission_exams', 'Exámenes pasados'),
  ('/study_guide', 'Guía de estudio'),
  ('/rankings', 'Rankings'),
  ('/practice?mode=mistakes', 'Practicar mis errores'),
  ('/profile', 'Perfil'),
];

/// Colores de portada de la historia (los mismos tonos que usa la app).
const newsStoryColors = <String, String>{
  'violet': 'Morado',
  'blue': 'Azul',
  'red': 'Rojo',
  'green': 'Verde',
  'amber': 'Ámbar',
};

class NewsImage {
  const NewsImage({
    required this.storagePath,
    required this.url,
    required this.width,
    required this.height,
    this.alt = '',
    this.onlyImage = false,
    this.thumbPath = '',
    this.thumbUrl = '',
  });

  final String storagePath;

  /// Miniatura JPEG de ~480 px (`news-public/thumbs/`), Fase 2D de costos:
  /// la app la usa en historias, lista y aviso en vez de la imagen completa.
  final String thumbPath;
  final String thumbUrl;

  /// URL de descarga; la app la muestra sin pedir permisos de Storage.
  final String url;
  final int width;
  final int height;

  /// Texto alternativo para lectores de pantalla (obligatorio al publicar).
  final String alt;

  /// «Solo imagen»: el comunicado ya trae todo el texto.
  final bool onlyImage;

  static NewsImage? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final url = '${raw['url'] ?? ''}';
    if (url.isEmpty) return null;
    return NewsImage(
      storagePath: '${raw['storagePath'] ?? ''}',
      url: url,
      width: (raw['width'] as num?)?.toInt() ?? 0,
      height: (raw['height'] as num?)?.toInt() ?? 0,
      alt: '${raw['alt'] ?? ''}',
      onlyImage: raw['mode'] == 'only',
      thumbPath: '${raw['thumbPath'] ?? ''}',
      thumbUrl: '${raw['thumbUrl'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
    'storagePath': storagePath,
    'url': url,
    'width': width,
    'height': height,
    'alt': alt.trim(),
    'mode': onlyImage ? 'only' : 'withText',
    if (thumbUrl.isNotEmpty) 'thumbPath': thumbPath,
    if (thumbUrl.isNotEmpty) 'thumbUrl': thumbUrl,
  };

  NewsImage copyWith({String? alt, bool? onlyImage}) => NewsImage(
    storagePath: storagePath,
    url: url,
    width: width,
    height: height,
    alt: alt ?? this.alt,
    onlyImage: onlyImage ?? this.onlyImage,
    thumbPath: thumbPath,
    thumbUrl: thumbUrl,
  );
}

class NewsAction {
  const NewsAction({
    required this.label,
    required this.type,
    required this.target,
  });

  final String label;
  final NewsActionType type;
  final String target;

  static NewsAction? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final label = '${raw['label'] ?? ''}'.trim();
    final target = '${raw['target'] ?? ''}'.trim();
    if (label.isEmpty || target.isEmpty) return null;
    return NewsAction(
      label: label,
      type: NewsActionType.fromKey(raw['type']),
      target: target,
    );
  }

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'type': type.key,
    'target': target.trim(),
  };
}

class NewsKeyDate {
  const NewsKeyDate({required this.label, required this.at});

  final String label;
  final DateTime at;

  static NewsKeyDate? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final at = _date(raw['at']);
    final label = '${raw['label'] ?? ''}'.trim();
    if (at == null || label.isEmpty) return null;
    return NewsKeyDate(label: label, at: at);
  }

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'at': Timestamp.fromDate(at),
  };
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    this.body = '',
    this.category = NewsCategory.notice,
    this.priority = NewsPriority.normal,
    this.status = NewsStatus.draft,
    this.universityIds = const [],
    this.universityLabels = const [],
    required this.publishAt,
    this.expiresAt,
    this.eventAt,
    this.eventLabel = '',
    this.keyDates = const [],
    this.image,
    this.story = false,
    this.storyColor = 'violet',
    this.storyLabel = '',
    this.action,
    this.push = false,
    this.pushSentAt,
    this.updatedAt,
    this.updatedBy = '',
  });

  final String id;
  final String title;
  final String body;
  final NewsCategory category;
  final NewsPriority priority;
  final NewsStatus status;

  /// Vacía = para todos los alumnos (General).
  final List<String> universityIds;

  /// Siglas de [universityIds] («UNPRG»), para la etiqueta «Solo UNPRG».
  final List<String> universityLabels;
  final DateTime publishAt;
  final DateTime? expiresAt;

  /// Fecha del evento (cuenta regresiva) y qué pasa ese día.
  final DateTime? eventAt;
  final String eventLabel;
  final List<NewsKeyDate> keyDates;
  final NewsImage? image;

  /// Mostrar también como historia en el Inicio.
  final bool story;
  final String storyColor;

  /// «Nombre en la historia»: lo que dice el círculo del Inicio (máx.
  /// [storyLabelMax]). Vacío = la app usa el titular.
  final String storyLabel;

  static const storyLabelMax = 24;
  final NewsAction? action;

  /// Enviar notificación al publicar (la envía el servidor una sola vez).
  final bool push;
  final DateTime? pushSentAt;
  final DateTime? updatedAt;
  final String updatedBy;

  bool get isGeneral => universityIds.isEmpty;

  String get audienceLabel => isGeneral
      ? 'General (todos los alumnos)'
      : 'Solo ${universityLabels.isEmpty ? '${universityIds.length} universidad(es)' : universityLabels.join(', ')}';

  /// Estado que ve el editor: una publicada puede estar programada o vencida.
  String stateLabel(DateTime now) {
    if (status != NewsStatus.published) return status.label;
    if (publishAt.isAfter(now)) return 'Programada';
    if (expiresAt != null && !expiresAt!.isAfter(now)) return 'Vencida';
    return 'Publicada';
  }

  factory NewsItem.fromMap(String id, Map<String, dynamic> d) {
    List<String> strings(Object? v) =>
        v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : [];
    return NewsItem(
      id: id,
      title: '${d['title'] ?? ''}',
      body: '${d['body'] ?? ''}',
      category: NewsCategory.fromKey(d['category']),
      priority: NewsPriority.fromKey(d['priority']),
      status: NewsStatus.fromKey(d['status']),
      universityIds: strings(d['universityIds']),
      universityLabels: strings(d['universityLabels']),
      publishAt: _date(d['publishAt']) ?? DateTime(2000),
      expiresAt: _date(d['expiresAt']),
      eventAt: _date(d['eventAt']),
      eventLabel: '${d['eventLabel'] ?? ''}',
      keyDates: [
        for (final k in (d['keyDates'] as List? ?? const []))
          ?NewsKeyDate.fromMap(k),
      ],
      image: NewsImage.fromMap(d['image']),
      story: d['story'] is Map && (d['story'] as Map)['enabled'] == true,
      storyColor: d['story'] is Map
          ? '${(d['story'] as Map)['color'] ?? 'violet'}'
          : 'violet',
      storyLabel: d['story'] is Map
          ? '${(d['story'] as Map)['label'] ?? ''}'.trim()
          : '',
      action: NewsAction.fromMap(d['action']),
      push: d['push'] == true,
      pushSentAt: _date(d['pushSentAt']),
      updatedAt: _date(d['updatedAt']),
      updatedBy: '${d['updatedBy'] ?? ''}',
    );
  }

  /// Campos que escribe el admin (sin marcas de tiempo del servidor).
  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'body': body.trim(),
    'category': category.key,
    'priority': priority.key,
    'status': status.key,
    'audience': isGeneral ? 'all' : 'universities',
    'universityIds': universityIds,
    'universityLabels': universityLabels,
    'publishAt': Timestamp.fromDate(publishAt),
    'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
    'eventAt': eventAt == null ? null : Timestamp.fromDate(eventAt!),
    'eventLabel': eventLabel.trim(),
    'keyDates': [for (final k in keyDates) k.toMap()],
    'image': image?.toMap(),
    'story': {
      'enabled': story,
      'color': storyColor,
      'label': storyLabel.trim(),
    },
    'action': action?.toMap(),
    'push': push,
  };

  /// Lo que falta para publicar; null si está lista.
  String? validateForPublish() {
    if (title.trim().length < 4) return 'Escribe un título (mínimo 4 letras).';
    if (title.trim().length > 90) return 'El título es muy largo (máx. 90).';
    final onlyImage = image?.onlyImage ?? false;
    if (!onlyImage && body.trim().isEmpty) {
      return 'Escribe el texto de la noticia o marca «Solo imagen».';
    }
    if (image != null && image!.alt.trim().isEmpty) {
      return 'Describe la imagen (texto alternativo) para quien no puede verla.';
    }
    if (expiresAt != null && !expiresAt!.isAfter(publishAt)) {
      return 'La fecha de vencimiento debe ser después de la publicación.';
    }
    if (priority != NewsPriority.normal && expiresAt == null) {
      return 'Una noticia fijada o urgente necesita fecha de vencimiento.';
    }
    if (story && storyLabel.trim().length > storyLabelMax) {
      return 'El nombre en la historia es muy largo (máx. $storyLabelMax).';
    }
    if (eventAt != null && eventLabel.trim().isEmpty) {
      return 'Di qué pasa en la fecha del evento (p. ej. «Cierre de inscripciones»).';
    }
    if (action != null && action!.type == NewsActionType.url) {
      final uri = Uri.tryParse(action!.target);
      if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
        return 'El enlace del botón debe empezar con https://';
      }
    }
    return null;
  }

  NewsItem copyWith({
    String? title,
    String? body,
    NewsCategory? category,
    NewsPriority? priority,
    NewsStatus? status,
    List<String>? universityIds,
    List<String>? universityLabels,
    DateTime? publishAt,
    DateTime? Function()? expiresAt,
    DateTime? Function()? eventAt,
    String? eventLabel,
    List<NewsKeyDate>? keyDates,
    NewsImage? Function()? image,
    bool? story,
    String? storyColor,
    String? storyLabel,
    NewsAction? Function()? action,
    bool? push,
  }) => NewsItem(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    universityIds: universityIds ?? this.universityIds,
    universityLabels: universityLabels ?? this.universityLabels,
    publishAt: publishAt ?? this.publishAt,
    expiresAt: expiresAt != null ? expiresAt() : this.expiresAt,
    eventAt: eventAt != null ? eventAt() : this.eventAt,
    eventLabel: eventLabel ?? this.eventLabel,
    keyDates: keyDates ?? this.keyDates,
    image: image != null ? image() : this.image,
    story: story ?? this.story,
    storyColor: storyColor ?? this.storyColor,
    storyLabel: storyLabel ?? this.storyLabel,
    action: action != null ? action() : this.action,
    push: push ?? this.push,
    pushSentAt: pushSentAt,
    updatedAt: updatedAt,
    updatedBy: updatedBy,
  );
}

/// `{config}/news`: reglas de las noticias que se cambian en Configuración.
class NewsSettings {
  const NewsSettings({
    this.urgentPerWeek = 1,
    this.storyDays = 7,
    this.maxStories = 5,
    this.feedLimit = 20,
  });

  static const defaults = NewsSettings();

  /// Avisos urgentes (ventana al abrir) permitidos en 7 días.
  final int urgentPerWeek;

  /// Días que una historia queda en el Inicio desde que se publica.
  final int storyDays;

  /// Historias que caben en la fila del Inicio.
  final int maxStories;

  /// Noticias que la app baja al abrir el Inicio (las más nuevas). Menos =
  /// menos lecturas por sesión; las demás siguen en la lista al refrescar.
  final int feedLimit;

  static int _bounded(Object? v, int fallback, int min, int max) =>
      v is num && v == v.roundToDouble() && v >= min && v <= max
      ? v.toInt()
      : fallback;

  factory NewsSettings.fromMap(Map<String, dynamic>? map) {
    final d = map ?? const <String, dynamic>{};
    const f = defaults;
    return NewsSettings(
      urgentPerWeek: _bounded(d['urgentPerWeek'], f.urgentPerWeek, 0, 7),
      storyDays: _bounded(d['storyDays'], f.storyDays, 1, 30),
      maxStories: _bounded(d['maxStories'], f.maxStories, 1, 10),
      feedLimit: _bounded(d['feedLimit'], f.feedLimit, 5, 80),
    );
  }

  Map<String, dynamic> toMap() => {
    'urgentPerWeek': urgentPerWeek,
    'storyDays': storyDays,
    'maxStories': maxStories,
    'feedLimit': feedLimit,
  };

  String? validate() {
    if (urgentPerWeek < 0 || urgentPerWeek > 7) {
      return 'Avisos urgentes por semana: entre 0 y 7.';
    }
    if (storyDays < 1 || storyDays > 30) {
      return 'Días de una historia en el Inicio: entre 1 y 30.';
    }
    if (maxStories < 1 || maxStories > 10) {
      return 'Historias en el Inicio: entre 1 y 10.';
    }
    if (feedLimit < 5 || feedLimit > 80) {
      return 'Noticias que baja la app: entre 5 y 80.';
    }
    return null;
  }
}

/// Urgentes publicadas para la misma audiencia en los 7 días antes de [at]
/// (sin contar [exceptId]). Sirve para respetar `urgentPerWeek`.
int urgentInWeek(
  Iterable<NewsItem> all,
  DateTime at, {
  required List<String> universityIds,
  String? exceptId,
}) {
  final from = at.subtract(const Duration(days: 7));
  bool overlaps(NewsItem n) =>
      n.isGeneral ||
      universityIds.isEmpty ||
      n.universityIds.any(universityIds.contains);
  return all
      .where(
        (n) =>
            n.id != exceptId &&
            n.status == NewsStatus.published &&
            n.priority == NewsPriority.urgent &&
            n.publishAt.isAfter(from) &&
            !n.publishAt.isAfter(at.add(const Duration(days: 7))) &&
            overlaps(n),
      )
      .length;
}

DateTime? _date(Object? v) => switch (v) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  String s => DateTime.tryParse(s),
  _ => null,
};
