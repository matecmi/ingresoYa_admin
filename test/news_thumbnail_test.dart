import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ingresoya_admin/src/data/repo/news_repo.dart';
import 'package:ingresoya_admin/src/domain/news.dart';

/// Fase 2D de costos: cada imagen de noticia sube con una miniatura JPEG.
void main() {
  test('la miniatura es un JPEG de 480 px de ancho como máximo', () {
    final wide = img.Image(width: 1600, height: 900);
    img.fill(wide, color: img.ColorRgb8(30, 120, 200));
    final png = Uint8List.fromList(img.encodePng(wide));

    final thumb = NewsRepo.thumbnailJpeg(png, width: 1600);
    expect(thumb, isNotNull);
    expect(thumb![0], 0xFF, reason: 'cabecera JPEG');
    expect(thumb[1], 0xD8);
    final decoded = img.decodeJpg(thumb);
    expect(decoded!.width, NewsRepo.thumbWidth);
    expect(decoded.height, 270);
    expect(thumb.length, lessThan(png.length));

    final small = img.Image(width: 300, height: 200);
    final smallPng = Uint8List.fromList(img.encodePng(small));
    final smallThumb = NewsRepo.thumbnailJpeg(smallPng, width: 300);
    expect(img.decodeJpg(smallThumb!)!.width, 300, reason: 'no se agranda');

    expect(NewsRepo.thumbnailJpeg(Uint8List(0), width: 0), isNull);
  });

  test('NewsImage conserva la miniatura solo si existe', () {
    final withThumb = NewsImage(
      storagePath: 'news-public/a.png',
      url: 'https://x/a.png',
      width: 1000,
      height: 800,
      thumbPath: 'news-public/thumbs/a.jpg',
      thumbUrl: 'https://x/thumbs/a.jpg',
    );
    expect(withThumb.toMap()['thumbUrl'], 'https://x/thumbs/a.jpg');
    expect(
      NewsImage.fromMap(withThumb.toMap())!.thumbPath,
      'news-public/thumbs/a.jpg',
    );
    expect(
      withThumb.copyWith(alt: 'Afiche').thumbUrl,
      'https://x/thumbs/a.jpg',
    );

    final legacy = NewsImage.fromMap({
      'url': 'https://x/b.png',
      'width': 1,
      'height': 1,
    });
    expect(legacy!.thumbUrl, '');
    expect(legacy.toMap().containsKey('thumbUrl'), isFalse);
  });
}
