/// Shared wire contract v2. Keep this directory identical in app and admin.
typedef Json = Map<String, dynamic>;

String stringField(Json json, String key, {String? fallback}) {
  final value = json[key] ?? fallback;
  if (value is! String) throw FormatException('$key must be a string');
  return value;
}

String idField(Json json, String key) {
  final value = stringField(json, key);
  if (value.trim().isEmpty) throw FormatException('$key must not be empty');
  return value;
}

int intField(Json json, String key, {int? fallback, int min = 0}) {
  final value = json[key] ?? fallback;
  if (value is! int || value < min) {
    throw FormatException('$key must be an integer >= $min');
  }
  return value;
}

String enumField(Json json, String key, List<String> values) {
  final value = stringField(json, key);
  if (!values.contains(value)) throw FormatException('Unknown $key: $value');
  return value;
}

Json objectField(dynamic value) {
  if (value is! Map) throw const FormatException('Expected an object');
  return Map<String, dynamic>.from(value);
}

List<T> listField<T>(dynamic value, T Function(dynamic) decode) {
  if (value is! List) throw const FormatException('Expected an array');
  return List<T>.unmodifiable(value.map(decode));
}

List<String> idsField(dynamic value) {
  final result = listField(value, (v) {
    if (v is! String || v.trim().isEmpty) {
      throw const FormatException('Expected a nonempty identifier');
    }
    return v;
  });
  uniqueIds(result);
  return result;
}

void uniqueIds(Iterable<String> ids) {
  final values = ids.toList();
  if (values.toSet().length != values.length) {
    throw const FormatException('Duplicate identifiers');
  }
}

/// A paragraph contains ordered text/formula spans; images remain blocks.
class InlineSpanData {
  InlineSpanData.fromJson(Json json)
    : type = enumField(json, 'type', ['text', 'formula']),
      value = stringField(json, json['type'] == 'formula' ? 'latex' : 'text'),
      marks = listField(json['marks'] ?? [], (v) {
        if (v != 'bold' && v != 'italic') {
          throw const FormatException('Unknown text mark');
        }
        return v as String;
      });

  final String type;
  final String value;
  final List<String> marks;
  Json toJson() => {
    'type': type,
    type == 'formula' ? 'latex' : 'text': value,
    if (marks.isNotEmpty) 'marks': marks,
  };
}

sealed class ContentBlock {
  ContentBlock(this.id);
  final String id;
  Json toJson();

  factory ContentBlock.fromJson(Json json) {
    return switch (json['type']) {
      'text' => TextBlock.fromJson(json),
      'paragraph' => ParagraphBlock.fromJson(json),
      'formula' => FormulaBlock.fromJson(json),
      'image' => ImageBlock.fromJson(json),
      'legacy' => LegacyBlock.fromJson(json),
      _ => throw FormatException('Unknown content type: ${json['type']}'),
    };
  }
}

class TextBlock extends ContentBlock {
  TextBlock.fromJson(Json json)
    : text = stringField(json, 'text'),
      super(idField(json, 'id'));
  final String text;
  @override
  Json toJson() => {'id': id, 'type': 'text', 'text': text};
}

class ParagraphBlock extends ContentBlock {
  ParagraphBlock.fromJson(Json json)
    : spans = listField(
        json['spans'],
        (v) => InlineSpanData.fromJson(objectField(v)),
      ),
      super(idField(json, 'id'));
  final List<InlineSpanData> spans;
  @override
  Json toJson() => {
    'id': id,
    'type': 'paragraph',
    'spans': spans.map((s) => s.toJson()).toList(),
  };
}

class FormulaBlock extends ContentBlock {
  FormulaBlock.fromJson(Json json)
    : latex = stringField(json, 'latex'),
      displayMode = enumField(json, 'displayMode', ['block']),
      super(idField(json, 'id'));
  final String latex;
  final String displayMode;
  @override
  Json toJson() => {
    'id': id,
    'type': 'formula',
    'latex': latex,
    'displayMode': displayMode,
  };
}

class ImageBlock extends ContentBlock {
  ImageBlock.fromJson(Json json)
    : storagePath = json['storagePath'] == null
          ? null
          : idField(json, 'storagePath'),
      url = json['url'] == null ? null : idField(json, 'url'),
      altText = stringField(json, 'altText', fallback: ''),
      caption = stringField(json, 'caption', fallback: ''),
      width = json['width'] == null ? null : intField(json, 'width', min: 1),
      height = json['height'] == null ? null : intField(json, 'height', min: 1),
      super(idField(json, 'id')) {
    if ((storagePath == null) == (url == null)) {
      throw const FormatException(
        'Image requires exactly one of storagePath or url',
      );
    }
    if (storagePath != null &&
        (storagePath!.startsWith('/') ||
            storagePath!.contains('..') ||
            storagePath!.contains('://'))) {
      throw const FormatException('Expected a relative Storage path');
    }
    if (url != null) {
      final uri = Uri.tryParse(url!);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Expected an HTTP(S) image URL');
      }
    }
    if ((width == null) != (height == null)) {
      throw const FormatException('Provide both image dimensions');
    }
  }
  final String? storagePath;
  final String? url;
  final String altText;
  final String caption;
  final int? width;
  final int? height;
  @override
  Json toJson() => {
    'id': id,
    'type': 'image',
    if (storagePath != null) 'storagePath': storagePath,
    if (url != null) 'url': url,
    'altText': altText,
    'caption': caption,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };
}

/// Lossless bridge for old [@]/[%]/[#] content, pending editorial conversion.
class LegacyBlock extends ContentBlock {
  LegacyBlock.fromJson(Json json)
    : raw = stringField(json, 'raw'),
      super(idField(json, 'id'));
  final String raw;
  @override
  Json toJson() => {'id': id, 'type': 'legacy', 'raw': raw};
}

class QuestionContent {
  QuestionContent.fromJson(dynamic value)
    : blocks = listField(value, (v) => ContentBlock.fromJson(objectField(v))) {
    uniqueIds(blocks.map((b) => b.id));
  }
  factory QuestionContent.legacy(String raw) => QuestionContent.fromJson([
    {'id': 'legacy-1', 'type': 'legacy', 'raw': raw},
  ]);
  final List<ContentBlock> blocks;
  List<Json> toJson() => blocks.map((b) => b.toJson()).toList();
}
