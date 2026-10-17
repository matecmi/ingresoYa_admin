import 'package:cloud_firestore/cloud_firestore.dart';

import '../../env/app_env.dart';
import 'rankings_repo.dart';
import 'xp_repo.dart';

/// Lo que se ve de un alumno en su ficha (tablero 10).
class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.university,
    required this.career,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String university;
  final String career;
  final DateTime? createdAt;

  String get displayName =>
      name.isNotEmpty ? name : (email.isNotEmpty ? email : uid);
}

class StudentRanking {
  const StudentRanking({
    this.alias,
    this.hidden = false,
    this.stage = 0,
    this.moderatedReason,
  });

  final String? alias;
  final bool hidden;
  final int stage;
  final String? moderatedReason;
}

class SimulatorResultRow {
  const SimulatorResultRow({
    required this.id,
    required this.title,
    required this.purpose,
    required this.correct,
    required this.total,
    required this.percentage,
    required this.atMs,
  });

  final String id;
  final String title;
  final String purpose;
  final int correct;
  final int total;
  final double percentage;
  final int atMs;
}

/// Datos de un alumno para la ficha; las escrituras (revertir XP, retirar el
/// nombre de usuario) van por `XpRepo` y `RankingsRepo`.
class StudentRepo {
  StudentRepo(this._db, this._xp, this._rankings);

  final FirebaseFirestore _db;
  final XpRepo _xp;
  final RankingsRepo _rankings;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(AppEnv.usersCollection).doc(uid);

  /// Por correo, uid o nombre de usuario (con o sin tildes).
  Future<List<XpStudent>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final direct = await _xp.findStudents(text);
    if (direct.isNotEmpty || text.contains('@')) return direct;
    final card = await _rankings.findUsername(text);
    if (card == null) return const [];
    return _xp.findStudents(card.uid);
  }

  Stream<StudentProfile?> watchProfile(String uid) =>
      _user(uid).snapshots().map((s) {
        if (!s.exists) return null;
        final data = s.data() ?? const {};
        final p = data['profile'] is Map ? data['profile'] as Map : const {};
        String f(String k) => '${p[k] ?? ''}';
        final created = data['createdAt'] ?? p['createdAt'];
        return StudentProfile(
          uid: uid,
          name: f('userName'),
          email: f('email'),
          university: f('universityAcronym'),
          career: f('professionName'),
          createdAt: created is Timestamp ? created.toDate() : null,
        );
      });

  Stream<StudentRanking> watchRanking(String uid) =>
      _user(uid).collection('ranking').doc('current').snapshots().map((s) {
        final d = s.data() ?? const {};
        return StudentRanking(
          alias: d['alias'] as String?,
          hidden: d['hidden'] == true,
          stage: (d['stage'] as num?)?.toInt() ?? 0,
          moderatedReason: d['moderatedReason'] as String?,
        );
      });

  /// Partes de la guía que el servidor dio por aprobadas.
  Future<int> approvedParts(String uid) async {
    final doc = await _user(
      uid,
    ).collection('learningProgress').doc('current').get();
    final map = doc.data()?['partProgress'];
    if (map is! Map) return 0;
    return map.values
        .whereType<Map>()
        .where((p) => p['completed'] == true || p['verified'] == true)
        .length;
  }

  Stream<List<SimulatorResultRow>> watchResults(String uid, {int limit = 50}) =>
      _user(uid)
          .collection('simulatorResults')
          .orderBy('submittedAtMs', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs)
                SimulatorResultRow(
                  id: d.id,
                  title: '${d.data()['title'] ?? 'Examen'}',
                  purpose: '${d.data()['purpose'] ?? ''}',
                  correct: (d.data()['correct'] as num?)?.toInt() ?? 0,
                  total: (d.data()['total'] as num?)?.toInt() ?? 0,
                  percentage: (d.data()['percentage'] as num?)?.toDouble() ?? 0,
                  atMs: (d.data()['submittedAtMs'] as num?)?.toInt() ?? 0,
                ),
            ],
          );
}
