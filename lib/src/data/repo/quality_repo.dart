import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/question_signals.dart';
import '../../env/app_env.dart';

/// Estadísticas por pregunta para «Preguntas a revisar»
/// (docs/question_stats_contract.md).
class QualityRepo {
  QualityRepo(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions? _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppEnv.questionStatsCollection);

  /// Preguntas con al menos [minAnswers] respuestas (las más respondidas).
  Stream<List<QuestionStat>> watch({required int minAnswers, int limit = 500}) {
    return _col
        .where('answered', isGreaterThanOrEqualTo: minAnswers)
        .orderBy('answered', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs)
              if (d.id != '_cursor') QuestionStat.fromMap(d.id, d.data()),
          ],
        );
  }

  /// Hasta cuándo están sumadas las respuestas.
  Stream<DateTime?> watchUpdatedAt() => _col.doc('_cursor').snapshots().map((s) {
    final at = s.data()?['updatedAt'];
    return at is Timestamp ? at.toDate() : null;
  });

  /// «Está bien así»: se oculta hasta que lleguen bastantes respuestas nuevas.
  Future<void> markReviewed(
    QuestionStat stat, {
    required String editor,
    String note = '',
  }) => _col.doc(stat.id).update({
    'review': {
      'answered': stat.answered,
      'by': editor,
      'note': note,
      'atMs': DateTime.now().millisecondsSinceEpoch,
    },
  });

  /// Suma ya las respuestas nuevas (además de la suma de cada noche).
  Future<int> refreshNow() async {
    final functions = _functions;
    if (functions == null) throw StateError('Functions not available');
    final res = await functions
        .httpsCallable(
          'refreshQuestionStats',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<String, dynamic>>({});
    final attempts = res.data['attempts'];
    return attempts is num ? attempts.toInt() : 0;
  }
}
