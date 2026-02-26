import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/entities/profession_entity.dart';
import 'package:uuid/uuid.dart';
import '../../env/app_env.dart';

class ProfessionRepo {
  ProfessionRepo(this.db);
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection(AppEnv.professionsCollection);

  Stream<List<ProfessionEntity>> watchProfessions() {
    return _col.orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) {
        final x = d.data();
        return ProfessionEntity(
          id: d.id,
          idDoc: (x['idDoc'] ?? d.id).toString(),
          name: (x['name'] ?? '').toString(),
          acronym: (x['acronym'] ?? '').toString(),
          active: (x['active'] ?? true) == true,
        );
      }).toList();
    });
  }

  Future<String> create({
    required String name,
    required String acronym,
    required bool active,
  }) async {
    final id = const Uuid().v4();
    await _col.doc(id).set({
      'idDoc': id,
      'name': name.trim(),
      'acronym': acronym.trim(),
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _col.doc(id).update({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
