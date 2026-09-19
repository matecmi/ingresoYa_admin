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
      'question-editor/${const Uuid().v4()}.$ext',
    );
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    return {
      'url': await ref.getDownloadURL(),
      'width': width,
      'height': height,
    };
  }
}
