import 'package:cloud_firestore/cloud_firestore.dart';

import '../../env/app_env.dart';

/// Validates the academic hierarchy using the source catalog, never names
/// copied into a question for display. It is deliberately reusable from the
/// legacy editor and the v2 publication transaction.
class AcademicContextValidator {
  AcademicContextValidator._();

  static Future<void> validate(
    FirebaseFirestore db,
    Transaction transaction, {
    required String courseId,
    required String topicId,
    required String subtopicId,
    required List<String> partIds,
    required bool requireComplete,
  }) async {
    final values = [courseId, topicId, subtopicId];
    if (!requireComplete && values.every((value) => value.isEmpty)) return;
    // A draft can be classified progressively. Once it has the complete
    // hierarchy, validate any selected parts; publication always requires the
    // full context below.
    if (!requireComplete && values.any((value) => value.isEmpty)) return;
    if (values.any((value) => value.isEmpty)) {
      throw StateError('Selecciona curso, tema y subtema compatibles.');
    }
    if (partIds.isEmpty && requireComplete) {
      throw StateError('Selecciona al menos una parte compatible.');
    }
    if (partIds.any((id) => id.trim().isEmpty) ||
        partIds.toSet().length != partIds.length) {
      throw StateError('Las partes deben ser IDs únicos y no vacíos.');
    }

    final course = db.collection(AppEnv.coursesCollection).doc(courseId);
    final courseSnapshot = await transaction.get(course);
    _requireActive(courseSnapshot.data(), 'El curso seleccionado');

    final topic = course.collection(AppEnv.topicsSubcollection).doc(topicId);
    final topicSnapshot = await transaction.get(topic);
    _requireActive(topicSnapshot.data(), 'El tema seleccionado');

    final subtopic = topic
        .collection(AppEnv.subtopicsSubcollection)
        .doc(subtopicId);
    final subtopicSnapshot = await transaction.get(subtopic);
    final data = subtopicSnapshot.data();
    _requireActive(data, 'El subtema seleccionado');

    final compatibleParts = <String, Map<String, dynamic>>{
      for (final raw in (data?['listPart'] as List? ?? const []))
        if (raw is Map && raw['id']?.toString().trim().isNotEmpty == true)
          raw['id'].toString(): Map<String, dynamic>.from(raw),
    };
    for (final id in partIds) {
      final part = compatibleParts[id];
      if (part == null || !_isActive(part)) {
        throw StateError(
          'La parte seleccionada no existe, está inactiva o pertenece a otro subtema.',
        );
      }
    }
  }

  static void _requireActive(Map<String, dynamic>? data, String label) {
    if (data == null || !_isActive(data)) {
      throw StateError('$label ya no existe o está inactivo.');
    }
  }

  static bool _isActive(Map<String, dynamic> data) {
    final value = data['active'];
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized != 'false' && normalized != 'n' && normalized != '0';
  }
}
