import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class QuestionImageStore {
  static Future<Map<String, dynamic>> upload(
    Uint8List bytes,
    String name,
  ) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Elige una imagen de hasta 5 MB.');
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
      // Persist a Storage path in v2 content. Download URLs carry a token and
      // would bypass Storage Rules if copied into a public question document.
      'question-public/drafts/${const Uuid().v4()}.$ext',
    );
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    return {
      'storagePath': ref.fullPath,
      'width': width,
      'height': height,
    };
  }
}
