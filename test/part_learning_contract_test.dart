import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/domain/part_learning_contract.dart';

void main() {
  group('PartLearningContract', () {
    test('asigna IDs faltantes y conserva IDs estables', () {
      var sequence = 0;
      final first = PartLearningContract.normaliseEntries([
        {'title': 'Nueva'},
        {'id': 'stable-id', 'title': 'Existente'},
      ], idFactory: () => 'generated-${++sequence}');
      final second = PartLearningContract.normaliseEntries(
        first,
        idFactory: () => 'unexpected-${++sequence}',
      );

      expect(first[0]['id'], 'generated-1');
      expect(second[0]['id'], 'generated-1');
      expect(second[1]['id'], 'stable-id');
    });

    test('normaliza barras invertidas también en listas y mapas', () {
      final result = PartLearningContract.normaliseEntries([
        {
          'id': 'formula-1',
          'latex': r'\\frac{1}{2}',
          'nested': [r'\\alpha'],
        },
      ]);

      expect(result.single['latex'], r'\frac{1}{2}');
      expect(result.single['nested'], [r'\alpha']);
    });

    test('valida URLs HTTP y HTTPS', () {
      expect(
        PartLearningContract.validHttpUrl('https://example.com/a'),
        isTrue,
      );
      expect(PartLearningContract.validHttpUrl('ftp://example.com/a'), isFalse);
      expect(PartLearningContract.validHttpUrl('', allowEmpty: false), isFalse);
    });

    test('importa un objeto JSON con o sin cerca markdown', () {
      expect(
        PartLearningContract.decodeJsonObject('{"name":"Parte"}')['name'],
        'Parte',
      );
      expect(
        PartLearningContract.decodeJsonObject(
          '```json\n{"name":"Parte cercada"}\n```',
        )['name'],
        'Parte cercada',
      );
    });

    test('limpia enlaces markdown de todos los campos URL', () {
      final result = PartLearningContract.decodeJsonObject(r'''
        {
          "linkVideo": "[https://youtube.com/watch?v=1](https://youtube.com/watch?v=1)",
          "linkPdf": "[https://example.com/a.pdf](https://example.com/a.pdf)",
          "images": [{"url":"[https://example.com/a.png](https://example.com/a.png)"}],
          "externalLinks": [{"url":"[https://example.com](https://example.com)"}]
        }
      ''');

      expect(result['linkVideo'], 'https://youtube.com/watch?v=1');
      expect(result['linkPdf'], 'https://example.com/a.pdf');
      expect(
        (result['images'] as List).single['url'],
        'https://example.com/a.png',
      );
      expect(
        (result['externalLinks'] as List).single['url'],
        'https://example.com',
      );
    });

    test('rechaza listas y JSON incompleto al importar', () {
      expect(
        () => PartLearningContract.decodeJsonObject('[]'),
        throwsFormatException,
      );
      expect(
        () => PartLearningContract.decodeJsonObject('{"name":'),
        throwsFormatException,
      );
    });

    test('rechaza correctIndex fuera de las opciones', () {
      final error = PartLearningContract.validateCollections(
        images: const [],
        externalLinks: const [],
        exercises: const [],
        quizQuestions: const [
          {
            'question': 'Pregunta',
            'options': ['A', 'B'],
            'correctIndex': 2,
          },
        ],
      );
      expect(error, contains('correctIndex'));
    });

    test('acepta partes antiguas sin contenido enriquecido', () {
      const legacy = SubtopicPartEntity(
        id: 'legacy',
        name: 'Parte antigua',
        idSubtopic: 'subtopic',
        idTopic: 'topic',
        content: 'Contenido',
        order: '1',
        linkVideo: '',
        linkPdf: '',
      );

      expect(legacy.summary, isEmpty);
      expect(legacy.formulas, isEmpty);
      expect(legacy.estimatedMinutes, isNull);
      expect(legacy.difficulty, 'basic');
    });
  });
}
