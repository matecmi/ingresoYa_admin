enum ContentSegType { text, math, url }

extension ContentSegTypeX on ContentSegType {
  String get tag {
    switch (this) {
      case ContentSegType.text:
        return 'TEXT';
      case ContentSegType.math:
        return 'MATH';
      case ContentSegType.url:
        return 'URL';
    }
  }

  String get label {
    switch (this) {
      case ContentSegType.text:
        return 'Texto';
      case ContentSegType.math:
        return 'Math (LaTeX)';
      case ContentSegType.url:
        return 'Imagen (URL)';
    }
  }

  static ContentSegType fromTag(String tag) {
    final t = tag.trim().toUpperCase();
    if (t == 'MATH') return ContentSegType.math;
    if (t == 'URL') return ContentSegType.url;
    return ContentSegType.text;
  }
}

class ContentSegment {
  ContentSegType type;
  String content;

  ContentSegment({required this.type, required this.content});

  String toRaw() => '${content.trim()}[@]${type.tag}';
}

class ContentLine {
  final List<ContentSegment> segments;
  ContentLine({required this.segments});

  String toRaw() => segments.map((s) => s.toRaw()).join('[#]');
}

/// Convierte líneas -> raw final con [%]
String buildRawFromLines(List<ContentLine> lines) {
  return lines.map((l) => l.toRaw()).join('[%]');
}
