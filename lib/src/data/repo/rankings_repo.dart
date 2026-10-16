import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/rankings_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

/// Lower case without accents, as Functions keys `{aliases}/{key}`.
String foldAlias(String alias) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final lower = alias.trim().toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    out.write(index < 0 ? char : to[index]);
  }
  return out.toString();
}

/// A student's public card, for moderation.
class UsernameCard {
  const UsernameCard({
    required this.uid,
    required this.alias,
    required this.hidden,
    required this.weekXp,
    required this.career,
  });

  final String uid;
  final String? alias;
  final bool hidden;
  final int weekXp;
  final String career;
}

/// Today's challenge of a university.
class ChallengeDay {
  const ChallengeDay({
    required this.id,
    required this.day,
    required this.universityId,
    required this.questionIds,
    required this.ownPastExamCount,
  });

  final String id;
  final String day;
  final String universityId;
  final List<String> questionIds;
  final int ownPastExamCount;
}

/// `{config}/rankings` and the admin tools of the rankings
/// (docs/rankings_contract.md).
class RankingsRepo {
  RankingsRepo(this.db);

  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> get _settings => db
      .collection(AppEnv.configCollection)
      .doc(AppEnv.rankingsSettingsDocument);

  Stream<RankingsSettings> watchSettings() => _settings.snapshots().map(
    (snapshot) => RankingsSettings.fromMap(snapshot.data()),
  );

  /// Turning rankings on starts the league next Monday (a full week).
  Future<void> saveSettings(
    RankingsSettings settings, {
    required String editor,
    DateTime? now,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    final previous = RankingsSettings.fromMap((await _settings.get()).data());
    final turningOn = settings.enabled && !previous.enabled;
    final toSave = turningOn
        ? settings.copyWith(startWeek: nextPeruMonday(now ?? DateTime.now()))
        : settings.copyWith(startWeek: previous.startWeek);
    await _settings.set({
      ...toSave.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  /// Students who earned XP this Peru week: to decide when to turn it on.
  Future<int> activeStudents(String week) async =>
      (await db
              .collection(AppEnv.leaderboardCollection)
              .where('weekKey', isEqualTo: week)
              .where('weekXp', isGreaterThan: 0)
              .count()
              .get())
          .count ??
      0;

  UsernameCard _card(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final alias = data['alias'];
    return UsernameCard(
      uid: doc.id,
      alias: alias is String && alias.isNotEmpty ? alias : null,
      hidden: data['hidden'] == true,
      weekXp: (data['weekXp'] as num?)?.toInt() ?? 0,
      career: [
        (data['universityAcronym'] ?? '').toString(),
        (data['professionName'] ?? '').toString(),
      ].where((s) => s.isNotEmpty).join(' · '),
    );
  }

  /// By username (any accents or case) or uid.
  Future<UsernameCard?> findUsername(String query) async {
    final text = query.trim();
    if (text.isEmpty) return null;
    final reserved = await db
        .collection(AppEnv.aliasesCollection)
        .doc(foldAlias(text))
        .get();
    final uid = reserved.data()?['uid'] as String? ?? text;
    final card = await db
        .collection(AppEnv.leaderboardCollection)
        .doc(uid)
        .get();
    return card.exists ? _card(card) : null;
  }

  /// Students who chose «Ocultarme de los rankings».
  Future<List<UsernameCard>> hiddenStudents({int limit = 50}) async {
    final snapshot = await db
        .collection(AppEnv.leaderboardCollection)
        .where('hidden', isEqualTo: true)
        .limit(limit)
        .get();
    return [for (final doc in snapshot.docs) _card(doc)];
  }

  /// Removes an inappropriate username: the app gives the student a random
  /// one and shows [reason] until they choose another.
  Future<void> removeUsername(
    String uid,
    String alias, {
    required String reason,
    required String editor,
  }) async {
    final why = reason.trim();
    if (why.length < 3) throw StateError('Escribe el motivo.');
    final batch = db.batch()
      ..delete(db.collection(AppEnv.aliasesCollection).doc(foldAlias(alias)))
      ..update(
        db
            .collection(AppEnv.usersCollection)
            .doc(uid)
            .collection('ranking')
            .doc('current'),
        {
          'alias': null,
          'moderatedReason': why,
          'moderatedBy': editor,
          'moderatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      )
      ..update(db.collection(AppEnv.leaderboardCollection).doc(uid), {
        'alias': null,
      });
    await batch.commit();
  }

  /// The challenges of [day], one per university that played.
  Future<List<ChallengeDay>> challenges(String day) async {
    final snapshot = await db
        .collection(AppEnv.dailyChallengesCollection)
        .where('day', isEqualTo: day)
        .get();
    return [
      for (final doc in snapshot.docs)
        ChallengeDay(
          id: doc.id,
          day: day,
          universityId: (doc.data()['universityId'] ?? '').toString(),
          questionIds: [
            for (final id in (doc.data()['questionIds'] as List? ?? const []))
              if (id is String) id,
          ],
          ownPastExamCount:
              (doc.data()['ownPastExamCount'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// Replaces a question of a challenge nobody has submitted yet.
  Future<void> swapChallengeQuestion(
    ChallengeDay challenge,
    String oldId,
    String newId,
  ) async {
    final replacement = newId.trim();
    if (challenge.questionIds.contains(replacement)) {
      throw StateError('Esa pregunta ya está en el reto.');
    }
    final question = await db
        .collection(AppEnv.questionsCollection)
        .doc(replacement)
        .get();
    if (question.data()?['status'] != 'published') {
      throw StateError('La pregunta no existe o no está publicada.');
    }
    final played =
        (await db
                .collection(AppEnv.challengeEntriesCollection)
                .where('day', isEqualTo: challenge.day)
                .where('universityId', isEqualTo: challenge.universityId)
                .count()
                .get())
            .count ??
        0;
    if (played > 0) {
      throw StateError('Ya hay alumnos que entregaron este reto.');
    }
    await db
        .collection(AppEnv.dailyChallengesCollection)
        .doc(challenge.id)
        .update({
          'questionIds': [
            for (final id in challenge.questionIds)
              id == oldId ? replacement : id,
          ],
        });
  }
}
