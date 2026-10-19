import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/xp_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

/// A student found by the XP tool.
class XpStudent {
  const XpStudent({
    required this.uid,
    required this.name,
    required this.email,
    required this.career,
  });

  final String uid;
  final String name;
  final String email;
  final String career;
}

class XpStudentState {
  const XpStudentState({
    required this.total,
    required this.rankStep,
    required this.weekXp,
    required this.todayCapped,
  });

  final int total;
  final int rankStep;
  final int weekXp;
  final int todayCapped;

  static const empty = XpStudentState(
    total: 0,
    rankStep: 0,
    weekXp: 0,
    todayCapped: 0,
  );
}

class XpLedgerEvent {
  const XpLedgerEvent({
    required this.id,
    required this.type,
    required this.xp,
    required this.requested,
    required this.day,
    required this.atMs,
    required this.reverted,
    this.revertReason,
  });

  final String id;
  final String type;
  final int xp;
  final int requested;
  final String day;
  final int atMs;
  final bool reverted;
  final String? revertReason;
}

/// `{config}/xp` and the admin XP tool (docs/xp_contract.md §5).
class XpRepo {
  XpRepo(this.db);

  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> get _settings =>
      db.collection(AppEnv.configCollection).doc(AppEnv.xpSettingsDocument);

  Stream<XpSettings> watchSettings() => _settings.snapshots().map(
    (snapshot) => XpSettings.fromMap(snapshot.data()),
  );

  Future<XpSettings> readSettings() async =>
      XpSettings.fromMap((await _settings.get()).data());

  Future<void> saveSettings(
    XpSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _settings.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      db.collection(AppEnv.usersCollection).doc(uid);

  /// By exact e-mail of the profile, or by uid.
  Future<List<XpStudent>> findStudents(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
    if (text.contains('@')) {
      final byEmail = await db
          .collection(AppEnv.usersCollection)
          .where('profile.email', isEqualTo: text.toLowerCase())
          .limit(10)
          .get();
      docs.addAll(byEmail.docs);
      if (docs.isEmpty && text.toLowerCase() != text) {
        final exact = await db
            .collection(AppEnv.usersCollection)
            .where('profile.email', isEqualTo: text)
            .limit(10)
            .get();
        docs.addAll(exact.docs);
      }
    } else {
      final byUid = await _user(text).get();
      if (byUid.exists) docs.add(byUid);
    }
    return [
      for (final doc in docs)
        () {
          final profile = doc.data()?['profile'] is Map
              ? doc.data()!['profile'] as Map
              : const {};
          String field(String key) => (profile[key] ?? '').toString();
          return XpStudent(
            uid: doc.id,
            name: field('userName'),
            email: field('email'),
            career: [
              field('universityAcronym'),
              field('professionName'),
            ].where((s) => s.isNotEmpty).join(' · '),
          );
        }(),
    ];
  }

  Stream<XpStudentState> watchState(String uid) =>
      _user(uid).collection('xp').doc('current').snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return XpStudentState.empty;
        int number(Object? value) => value is num ? value.toInt() : 0;
        final week = data['week'] is Map ? data['week'] as Map : const {};
        final today = data['today'] is Map ? data['today'] as Map : const {};
        return XpStudentState(
          total: number(data['total']),
          rankStep: number(data['rankStep']),
          weekXp: number(week['xp']),
          todayCapped: number(today['capped']),
        );
      });

  Stream<List<XpLedgerEvent>> watchLedger(String uid, {int limit = 100}) =>
      _user(uid)
          .collection('xpEvents')
          .orderBy('atMs', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                XpLedgerEvent(
                  id: doc.id,
                  type: (doc.data()['type'] ?? '').toString(),
                  xp: (doc.data()['xp'] as num?)?.toInt() ?? 0,
                  requested: (doc.data()['requested'] as num?)?.toInt() ?? 0,
                  day: (doc.data()['day'] ?? '').toString(),
                  atMs: (doc.data()['atMs'] as num?)?.toInt() ?? 0,
                  reverted: doc.data()['reverted'] == true,
                  revertReason: doc.data()['revertReason'] as String?,
                ),
            ],
          );

  /// Takes the event's XP back. Its id stays in the ledger, so it is never
  /// granted again; the rank is recalculated with the new total.
  Future<void> revert(
    String uid,
    String eventId, {
    required String reason,
    required String editor,
  }) async {
    final why = reason.trim();
    if (why.length < 3) throw StateError('Escribe el motivo de la reversión.');
    final settings = await readSettings();
    final eventRef = _user(uid).collection('xpEvents').doc(eventId);
    final stateRef = _user(uid).collection('xp').doc('current');
    final entryRef = db.collection(AppEnv.leaderboardCollection).doc(uid);
    await db.runTransaction((transaction) async {
      final event = await transaction.get(eventRef);
      final state = await transaction.get(stateRef);
      final entry = await transaction.get(entryRef);
      final data = event.data();
      if (data == null) throw StateError('El evento ya no existe.');
      final memberRef = db
          .collection(AppEnv.leagueMembersCollection)
          .doc('${data['week']}_$uid');
      final member = await transaction.get(memberRef);
      if (data['reverted'] == true) {
        throw StateError('Este evento ya fue revertido.');
      }
      final xp = (data['xp'] as num?)?.toInt() ?? 0;
      final current = state.data() ?? <String, dynamic>{};
      final total = ((current['total'] as num?)?.toInt() ?? 0) - xp;
      final week = Map<String, dynamic>.from(
        current['week'] is Map ? current['week'] as Map : const {},
      );
      if (week['key'] == data['week']) {
        week['xp'] = ((week['xp'] as num?)?.toInt() ?? 0) - xp;
      }
      final today = Map<String, dynamic>.from(
        current['today'] is Map ? current['today'] as Map : const {},
      );
      const capped = {'simulator_session', 'correct_answers', 'streak_day'};
      if (today['day'] == data['day'] && capped.contains(data['type'])) {
        today['capped'] = ((today['capped'] as num?)?.toInt() ?? 0) - xp;
      }
      if (today['day'] == data['day'] && data['type'] == 'explanation_video') {
        today['explained'] = ((today['explained'] as num?)?.toInt() ?? 0) - xp;
      }
      transaction.update(eventRef, {
        'reverted': true,
        'revertedXp': xp,
        'revertReason': why,
        'revertedBy': editor,
        'revertedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      transaction.set(stateRef, {
        'total': total < 0 ? 0 : total,
        'rankStep': settings.rankStepFor(total < 0 ? 0 : total),
        'week': week,
        'today': today,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      // Keep the public card and the league seat in step
      // (docs/rankings_contract.md §4-§5).
      final newTotal = total < 0 ? 0 : total;
      int less(Object? value) {
        final left = ((value as num?)?.toInt() ?? 0) - xp;
        return left < 0 ? 0 : left;
      }

      final shown = {
        'rankStep': settings.rankStepFor(newTotal),
        'stars': settings.starsFor(newTotal),
      };
      final card = entry.data();
      if (card != null) {
        transaction.update(entryRef, {
          if (card['hidden'] != true) ...shown,
          if (card['weekKey'] == data['week']) 'weekXp': less(card['weekXp']),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
      final seat = member.data();
      if (seat != null) {
        transaction.update(memberRef, {
          if (seat['hidden'] != true) ...shown,
          'weekXp': less(seat['weekXp']),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }
}
