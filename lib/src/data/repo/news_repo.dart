import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../domain/news.dart';
import '../../env/app_env.dart';

/// Noticias del alumno (docs/news_contract.md). Su configuración
/// `{config}/news` está en [AppConfigRepo].
class NewsRepo {
  NewsRepo(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection(AppEnv.newsCollection);

  /// Todas las noticias, de la más nueva a la más antigua.
  Stream<List<NewsItem>> watchAll() => _col
      .orderBy('publishAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => [for (final d in s.docs) NewsItem.fromMap(d.id, d.data())]);

  String newId() => _col.doc().id;

  /// Crea o reemplaza la noticia. `publishedAt` se fija la primera vez que
  /// pasa a publicada (el envío de la notificación depende de eso).
  Future<void> save(
    NewsItem item, {
    required String editor,
    required bool isNew,
  }) async {
    if (item.status == NewsStatus.published) {
      final problem = item.validateForPublish();
      if (problem != null) throw StateError(problem);
    }
    await _col.doc(item.id).set({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdBy': editor,
      // El servidor la busca con `pushSentAt == null` para enviarla.
      if (isNew) 'pushSentAt': null,
    }, SetOptions(merge: true));
  }

  Future<void> setStatus(
    String id,
    NewsStatus status, {
    required String editor,
  }) => _col.doc(id).update({
    'status': status.key,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': editor,
  });

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Sube la imagen de una noticia a `news-public/` y devuelve sus datos.
  /// Se guarda la URL de descarga porque la noticia es pública para todos los
  /// alumnos y la app no usa Firebase Storage.
  static Future<NewsImage> uploadImage(Uint8List bytes, String name) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FormatException('Elige una imagen de hasta 2 MB.');
    }
    final ext = name.split('.').last.toLowerCase();
    final mime = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    }[ext];
    if (mime == null) throw const FormatException('Usa PNG, JPG o WebP.');
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    final ref = FirebaseStorage.instance.ref(
      'news-public/${const Uuid().v4()}.$ext',
    );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: mime, cacheControl: 'public,max-age=604800'),
    );
    return NewsImage(
      storagePath: ref.fullPath,
      url: await ref.getDownloadURL(),
      width: width,
      height: height,
    );
  }

  static const maxImageBytes = 2 * 1024 * 1024;
}
