import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Reglas compartidas por el editor y la persistencia del contrato de partes.
abstract final class PartLearningContract {
  static const difficulties = {'basic', 'intermediate', 'advanced'};
  static const collectionKeys = {
    'formulas',
    'examples',
    'exercises',
    'images',
    'externalLinks',
    'flashcards',
    'quizQuestions',
  };

  static bool validHttpUrl(String value, {bool allowEmpty = true}) {
    final raw = value.trim();
    if (raw.isEmpty) return allowEmpty;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Acepta un objeto JSON puro o copiado con cercas ```json ... ```.
  static Map<String, dynamic> decodeJsonObject(String source) {
    var raw = source.trim().replaceFirst('\ufeff', '');
    if (raw.startsWith('```')) {
      final firstLineEnd = raw.indexOf('\n');
      final closingFence = raw.lastIndexOf('```');
      if (firstLineEnd < 0 || closingFence <= firstLineEnd) {
        throw const FormatException('El bloque JSON está incompleto.');
      }
      raw = raw.substring(firstLineEnd + 1, closingFence).trim();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('La parte debe ser un objeto JSON { }.');
    }
    return Map<String, dynamic>.from(_normaliseImportedValue(decoded) as Map);
  }

  static dynamic _normaliseImportedValue(dynamic value, [String? key]) {
    if (value is Map) {
      return value.map(
        (nestedKey, nestedValue) => MapEntry(
          nestedKey.toString(),
          _normaliseImportedValue(nestedValue, nestedKey.toString()),
        ),
      );
    }
    if (value is List) {
      return value.map((item) => _normaliseImportedValue(item)).toList();
    }
    if (value is String && {'url', 'linkVideo', 'linkPdf'}.contains(key)) {
      return unwrapMarkdownUrl(value);
    }
    return value;
  }

  /// Convierte `[https://destino](https://destino)` en una URL normal.
  static String unwrapMarkdownUrl(String value) {
    final raw = value.trim();
    final match = RegExp(
      r'^\[https?://[^\]]+\]\((https?://.+)\)$',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1)?.trim() ?? raw;
  }

  static String singleBackslashes(String value) =>
      value.replaceAll(RegExp(r'\\{2,}'), '\\');

  static List<Map<String, dynamic>> normaliseEntries(
    Iterable<Map<String, dynamic>> source, {
    String Function()? idFactory,
  }) {
    final createId = idFactory ?? () => const Uuid().v4();
    return source.map((entry) {
      final result = <String, dynamic>{};
      for (final MapEntry(:key, :value) in entry.entries) {
        result[key] = _normaliseValue(value);
      }
      final id = result['id']?.toString().trim() ?? '';
      result['id'] = id.isEmpty ? createId() : id;
      return result;
    }).toList();
  }

  static dynamic _normaliseValue(dynamic value) {
    if (value is String) return singleBackslashes(value.trim());
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _normaliseValue(nested)),
      );
    }
    if (value is List) return value.map(_normaliseValue).toList();
    return value;
  }

  static String? validateCollections({
    required List<Map<String, dynamic>> images,
    required List<Map<String, dynamic>> externalLinks,
    required List<Map<String, dynamic>> exercises,
    required List<Map<String, dynamic>> quizQuestions,
  }) {
    for (final image in images) {
      if (!validHttpUrl((image['url'] ?? '').toString(), allowEmpty: false)) {
        return 'Cada imagen debe tener una URL http(s) válida';
      }
    }
    for (final link in externalLinks) {
      if (!validHttpUrl((link['url'] ?? '').toString(), allowEmpty: false)) {
        return 'Cada enlace externo debe tener una URL http(s) válida';
      }
    }
    for (final exercise in exercises) {
      if (!difficulties.contains(exercise['difficulty'])) {
        return 'La dificultad de cada ejercicio debe ser basic, intermediate o advanced';
      }
    }
    for (final quiz in quizQuestions) {
      final options = (quiz['options'] as List? ?? const [])
          .map((option) => option.toString())
          .where((option) => option.trim().isNotEmpty)
          .toList();
      final correctIndex = quiz['correctIndex'];
      if (correctIndex is! int ||
          correctIndex < 0 ||
          correctIndex >= options.length) {
        return 'Cada pregunta debe tener correctIndex dentro de sus opciones';
      }
    }
    return null;
  }
}
