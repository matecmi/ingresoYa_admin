import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/app_preview/app_exam_preview.dart';

import 'shot_harness.dart';

QuestionContent text(String id, String value) => QuestionContent.fromJson([
  {'id': id, 'type': 'text', 'text': value},
]);

void main() {
  setUpAll(loadShotFonts);

  testWidgets('igual a la captura del teléfono', (t) async {
    await shotWidget(
      t,
      name: 'f3_vs_telefono',
      size: const Size(420, 900),
      child: AppPhoneFrame(
        width: 376,
        child: AppExamQuestionScreen(
          statement: text(
            's',
            '¿Cuántos términos tiene la sucesión 4, 9, 14, ..., 99?',
          ),
          alternatives: [
            for (final (l, v) in [
              ('A', '19'),
              ('B', '20'),
              ('C', '21'),
              ('D', '22'),
              ('E', '23'),
            ])
              QuestionAlternative.fromJson({
                'id': l,
                'label': l,
                'content': text('a$l', v).toJson(),
              }),
          ],
          questionCount: 4,
          sourceLabel: 'UNPRG - EXAMEN DE ADMISIÓN ORDINARIO 2026 I',
          sourceType: 'admission_exam',
          remaining: '09:56',
        ),
      ),
    );
  });
}
