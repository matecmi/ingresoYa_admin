import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/news_repo.dart';
import 'package:ingresoya_admin/src/domain/news.dart';

NewsItem _item({
  String id = 'n1',
  NewsPriority priority = NewsPriority.normal,
  NewsStatus status = NewsStatus.published,
  List<String> unis = const [],
  DateTime? publishAt,
  DateTime? expiresAt,
}) => NewsItem(
  id: id,
  title: 'Las inscripciones cierran',
  body: 'Inscríbete en la web.',
  priority: priority,
  status: status,
  universityIds: unis,
  publishAt: publishAt ?? DateTime(2026, 10, 20, 9),
  expiresAt: expiresAt,
);

void main() {
  test('el mapa ida y vuelta conserva los campos que lee la app', () {
    final item =
        _item(
          priority: NewsPriority.urgent,
          unis: const ['unprg'],
          expiresAt: DateTime(2026, 10, 25),
        ).copyWith(
          universityLabels: const ['UNPRG'],
          eventAt: () => DateTime(2026, 10, 24, 23, 59),
          eventLabel: 'Cierre de inscripciones',
          image: () => const NewsImage(
            storagePath: 'news-public/a.jpg',
            url: 'https://x/a.jpg',
            width: 1080,
            height: 1350,
            alt: 'Comunicado',
            onlyImage: true,
          ),
          story: true,
          storyColor: 'red',
          action: () => const NewsAction(
            label: 'Inscribirme',
            type: NewsActionType.url,
            target: 'https://admision.unprg.edu.pe',
          ),
          push: true,
        );
    final map = item.toMap();
    expect(map['audience'], 'universities');
    expect(map['image']['mode'], 'only');
    final back = NewsItem.fromMap('n1', map);
    expect(back.priority, NewsPriority.urgent);
    expect(back.universityIds, ['unprg']);
    expect(back.universityLabels, ['UNPRG']);
    expect(back.eventLabel, 'Cierre de inscripciones');
    expect(back.image!.onlyImage, isTrue);
    expect(back.story, isTrue);
    expect(back.storyColor, 'red');
    expect(back.action!.target, 'https://admision.unprg.edu.pe');
    expect(back.push, isTrue);
    expect(back.audienceLabel, 'Solo UNPRG');
  });

  test(
    'para publicar: fijada o urgente necesita vencimiento; imagen, descripción',
    () {
      expect(_item().validateForPublish(), isNull);
      expect(
        _item(priority: NewsPriority.pinned).validateForPublish(),
        contains('vencimiento'),
      );
      expect(
        _item().copyWith(title: 'Ho').validateForPublish(),
        contains('título'),
      );
      final withImage = _item().copyWith(
        body: '',
        image: () => const NewsImage(
          storagePath: 'p',
          url: 'https://x',
          width: 1,
          height: 1,
          onlyImage: true,
        ),
      );
      expect(withImage.validateForPublish(), contains('Describe la imagen'));
      expect(
        withImage
            .copyWith(image: () => withImage.image!.copyWith(alt: 'Comunicado'))
            .validateForPublish(),
        isNull,
      );
      expect(
        _item()
            .copyWith(
              action: () => const NewsAction(
                label: 'Ir',
                type: NewsActionType.url,
                target: 'ftp://x',
              ),
            )
            .validateForPublish(),
        contains('https'),
      );
    },
  );

  test('estado para el editor: programada, publicada y vencida', () {
    final now = DateTime(2026, 10, 21);
    expect(
      _item(publishAt: DateTime(2026, 10, 22)).stateLabel(now),
      'Programada',
    );
    expect(_item().stateLabel(now), 'Publicada');
    expect(
      _item(expiresAt: DateTime(2026, 10, 20, 12)).stateLabel(now),
      'Vencida',
    );
    expect(_item(status: NewsStatus.draft).stateLabel(now), 'Borrador');
  });

  test('urgentes en la semana: solo cuentan las de la misma audiencia', () {
    final at = DateTime(2026, 10, 21);
    final all = [
      _item(id: 'a', priority: NewsPriority.urgent, unis: const ['unprg']),
      _item(id: 'b', priority: NewsPriority.urgent, unis: const ['uni']),
      _item(id: 'c', priority: NewsPriority.pinned, unis: const ['unprg']),
      _item(
        id: 'd',
        priority: NewsPriority.urgent,
        publishAt: DateTime(2026, 9, 1),
      ),
    ];
    expect(urgentInWeek(all, at, universityIds: const ['unprg']), 1);
    expect(urgentInWeek(all, at, universityIds: const []), 2);
    expect(
      urgentInWeek(all, at, universityIds: const ['unprg'], exceptId: 'a'),
      0,
    );
  });

  test('la configuración se acota a sus límites', () {
    final s = NewsSettings.fromMap({
      'urgentPerWeek': 99,
      'storyDays': 3,
      'maxStories': 0,
    });
    expect(s.urgentPerWeek, 1);
    expect(s.storyDays, 3);
    expect(s.maxStories, 5);
    expect(const NewsSettings(storyDays: 40).validate(), isNotNull);
  });

  test(
    'guardar escribe la noticia y no deja publicar una incompleta',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = NewsRepo(db);
      await repo.save(_item(), editor: 'kevin@x', isNew: true);
      final doc = await db.collection('iya-news-test').doc('n1').get();
      expect(doc.data()!['status'], 'published');
      expect(doc.data()!['createdBy'], 'kevin@x');
      expect(doc.data()!['publishAt'], isA<Timestamp>());
      await expectLater(
        repo.save(
          _item(id: 'n2', priority: NewsPriority.urgent),
          editor: 'kevin@x',
          isNew: true,
        ),
        throwsStateError,
      );
    },
  );

  test('el nombre en la historia viaja en story.label y tiene tope', () {
    final item = _item().copyWith(
      story: true,
      storyLabel: 'Inscripciones 2026-II',
    );
    final map = item.toMap();
    expect((map['story'] as Map)['label'], 'Inscripciones 2026-II');
    expect(item.validateForPublish(), isNull);
    expect(
      item
          .copyWith(storyLabel: 'Un nombre demasiado largo de verdad')
          .validateForPublish(),
      contains('nombre en la historia'),
    );
  });
}
