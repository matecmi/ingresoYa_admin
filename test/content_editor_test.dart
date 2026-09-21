import 'dart:convert';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/domain/editor_document.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_editor/content_editor.dart';

EditorDocument longQuestion() => EditorDocument.read({
  'content': [
    {
      'id': 'text-1',
      'type': 'paragraph',
      'spans': [
        {
          'type': 'text',
          'text': 'Observa el triángulo.\nCalcula su área. ',
          'marks': ['bold', 'italic'],
        },
        {'type': 'formula', 'latex': r'x^2=25'},
      ],
    },
    {
      'id': 'image-1',
      'type': 'image',
      'url': 'https://example.com/figure.png',
      'altText': 'Triángulo de base ocho',
      'caption': 'Figura 1',
      'width': 1000,
      'height': 700,
    },
    {
      'id': 'formula-1',
      'type': 'formula',
      'latex': r'A=\frac{8x}{2}',
      'displayMode': 'block',
    },
    {
      'id': 'text-2',
      'type': 'text',
      'text': 'Explica cómo obtuviste la solución.\nSegunda línea.',
    },
  ],
  'contentPresentation': {'image-1': .7},
}, '');

void main() {
  testWidgets(
    'Dropped image retries after an upload error and retains display size',
    (tester) async {
      EditorDocument? result;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir'),
                onPressed: () async {
                  result = await showDialog<EditorDocument>(
                    context: context,
                    builder: (_) => ContentEditor(
                      initial: EditorDocument.read({}, ''),
                      uploadImage: (bytes, name) async {
                        calls++;
                        if (calls == 1) throw StateError('offline');
                        return {
                          'url': 'https://example.com/image.png',
                          'width': 1000,
                          'height': 700,
                        };
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final drop = DropDoneDetails(
        files: [
          DropItemFile.fromData(Uint8List.fromList([1, 2]), name: 'figure.png'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      );
      tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(drop);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se pudo cargar la imagen'),
        findsOneWidget,
      );
      tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(drop);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mediana'));
      await tester.tap(find.text('Mediana'));
      await tester.pump();
      await tester.tap(find.text('Aplicar contenido'));
      await tester.pumpAndSettle();
      expect(result!.content.blocks, hasLength(1));
      expect(result!.imageSizes.values.single, .7);
      expect(result!.content.toJson().single['width'], 1000);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mobile preview of mixed content and block moves do not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: ContentEditor(initial: longQuestion())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bajar bloque').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Deshacer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vista móvil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('VISTA PREVIA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'JSON preserves ordered rich content, accents, formulas and image sizing',
    () {
      final original = longQuestion();
      final reopened = EditorDocument.read(
        jsonDecode(jsonEncode(original.toFields())),
        '',
      );
      expect(reopened.toFields(), original.toFields());
      expect(reopened.content.blocks.map((b) => b.id), [
        'text-1',
        'image-1',
        'formula-1',
        'text-2',
      ]);
      expect(reopened.legacy, contains(r'A=\frac{8x}{2}[@]MATH'));
    },
  );

  test(
    'Firestore save and reopen statement, alternative and private explanation',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = QuestionRepo(db);
      final original = longQuestion();
      final id = await repo.createQuestion(
        number: 1,
        statementText: original.legacy,
        editorContent: original,
        active: 'N',
        topicId: 'geometry',
        topicName: 'Geometría',
        courseId: 'math',
        courseName: 'Matemática',
        examId: 'unprg-2026',
      );
      final reopened = (await repo.watchQuestions().first).single;
      expect(reopened.editorContent!.toFields(), original.toFields());
      final first = await repo.upsertAlternative(
        questionId: id,
        value: 'A',
        descriptionText: original.legacy,
        editorContent: original,
        isCorrect: 'Y',
      );
      final second = await repo.upsertAlternative(
        questionId: id,
        value: 'B',
        descriptionText: original.legacy,
        editorContent: original,
        isCorrect: 'Y',
      );
      final alts = await repo.watchAlternatives(id).first;
      expect(alts.firstWhere((a) => a.id == first).correct, false);
      expect(alts.firstWhere((a) => a.id == second).correct, true);
      expect(alts.last.editorContent!.toFields(), original.toFields());
      await repo.saveExplanation(id, original);
      expect((await repo.readExplanation(id)).toFields(), original.toFields());
      final publicQuestion =
          (await db.collection(AppEnv.questionsCollection).doc(id).get())
              .data()!;
      expect(publicQuestion.containsKey('explanation'), false);
      await repo.deleteQuestion(id);
      expect((await repo.readExplanation(id)).content.blocks, isEmpty);
    },
  );

  test('Legacy strings remain byte-for-byte compatible', () {
    const raw = 'Área\n[@]TEXT[#]x^2[@]MATH[%]final[@]TEXT';
    final document = EditorDocument.read({}, raw);
    expect(EditorDocument.read(document.toFields(), '').legacy, raw);
  });

  test('Undo restores full content and image presentation independently', () {
    final original = longQuestion();
    final history = EditorHistory()..remember(original);
    final serialized = original.toFields();
    (serialized['content'] as List).removeAt(1);
    expect(history.undo().toFields(), original.toFields());
    expect(history.canUndo, false);
  });

  testWidgets('Edit, duplicate, undo and reopen using the editor result', (
    tester,
  ) async {
    EditorDocument? result;
    final initial = EditorDocument.read({
      'content': [
        {
          'id': 'first',
          'type': 'paragraph',
          'spans': [
            {'type': 'text', 'text': 'Inicial'},
          ],
        },
      ],
    }, '');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await editContent(context, initial: result ?? initial);
              },
              child: const Text('Abrir editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Álgebra\nSegunda línea',
    );
    await tester.tap(find.byTooltip('Negrita'));
    await tester.pump();
    await tester.tap(find.byTooltip('Duplicar bloque').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pump();
    await tester.tap(find.text('Aplicar contenido'));
    await tester.pumpAndSettle();
    expect(result!.content.blocks, hasLength(1));
    final span = (result!.content.toJson().first['spans'] as List).first;
    expect(span['text'], 'Álgebra\nSegunda línea');
    expect(span['marks'], ['bold']);
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    expect(find.text('Álgebra\nSegunda línea'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid LaTeX remains editable and displays an error', (
    tester,
  ) async {
    final original = EditorDocument.read({
      'content': [
        {
          'id': 'math',
          'type': 'formula',
          'latex': r'\frac{',
          'displayMode': 'block',
        },
      ],
    }, '');
    await tester.pumpWidget(
      MaterialApp(home: ContentEditor(initial: original)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisa la fórmula'), findsOneWidget);
    expect(find.text(r'\frac{'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, r'\frac{1}{2}');
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisa la fórmula'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
