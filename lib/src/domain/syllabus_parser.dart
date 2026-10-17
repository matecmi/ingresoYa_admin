/// Temario pegado: la sangría define el nivel (tema → subtema → parte).
class SyllabusNode {
  const SyllabusNode(this.name, this.children);

  final String name;
  final List<SyllabusNode> children;
}

class SyllabusCounts {
  const SyllabusCounts(this.topics, this.subtopics, this.parts);

  final int topics;
  final int subtopics;
  final int parts;

  String get summary =>
      'Se crearán $topics tema(s), $subtopics subtema(s) y $parts parte(s)';
}

final _bullet = RegExp(r'^(?:[-*•·]|\d+[.)]|[a-z][.)])\s+', caseSensitive: false);

/// Lee un índice copiado del sílabo. Cuenta como nivel la sangría (tab = 4
/// espacios); también vale numerar «1.», «1.1», «1.1.1».
List<SyllabusNode> parseSyllabus(String text) {
  final lines = <(int, String)>[];
  int? lastNumbered;
  for (final raw in text.replaceAll('\r', '').split('\n')) {
    if (raw.trim().isEmpty) continue;
    final expanded = raw.replaceAll('\t', '    ');
    final indent = expanded.length - expanded.trimLeft().length;
    var name = expanded.trim();
    final numbered = RegExp(r'^(\d+(?:\.\d+)*)\.?\s+').firstMatch(name);
    int? level;
    if (numbered != null) {
      level = numbered.group(1)!.split('.').length - 1;
      name = name.substring(numbered.end).trim();
      lastNumbered = level;
    } else {
      final bullet = _bullet.hasMatch(name);
      name = name.replaceFirst(_bullet, '').trim();
      // Viñeta sin sangría bajo un título numerado: es su hijo.
      if (bullet && indent == 0 && lastNumbered != null) {
        level = (lastNumbered + 1).clamp(0, 2);
      }
    }
    if (name.isEmpty) continue;
    lines.add((level ?? -indent - 1, name));
  }
  if (lines.isEmpty) return const [];

  // Sangrías: convertir los anchos distintos en niveles 0, 1, 2.
  final indents = lines.where((l) => l.$1 < 0).map((l) => -l.$1 - 1).toSet().toList()
    ..sort();
  int levelOf((int, String) l) {
    if (l.$1 >= 0) return l.$1.clamp(0, 2);
    return indents.indexOf(-l.$1 - 1).clamp(0, 2);
  }

  final topics = <(String, List<(String, List<String>)>)>[];
  for (final l in lines) {
    final level = levelOf(l);
    if (level == 0 || topics.isEmpty) {
      topics.add((l.$2, []));
    } else if (level == 1 || topics.last.$2.isEmpty) {
      topics.last.$2.add((l.$2, []));
    } else {
      topics.last.$2.last.$2.add(l.$2);
    }
  }
  return [
    for (final t in topics)
      SyllabusNode(t.$1, [
        for (final s in t.$2)
          SyllabusNode(s.$1, [for (final p in s.$2) SyllabusNode(p, const [])]),
      ]),
  ];
}

SyllabusCounts countSyllabus(List<SyllabusNode> topics) => SyllabusCounts(
  topics.length,
  topics.fold(0, (n, t) => n + t.children.length),
  topics.fold(
    0,
    (n, t) => n + t.children.fold(0, (m, s) => m + s.children.length),
  ),
);
