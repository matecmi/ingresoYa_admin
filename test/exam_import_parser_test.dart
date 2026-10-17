import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/exam_import_parser.dart';

const exam = '''
UNIVERSIDAD NACIONAL PEDRO RUIZ GALLO
25. Halle el valor de x si 3x - 7 = 11
A) 4   B) 5   C) 6   D) 7   E) 8
26. En la figura, AB = BC. Halle el ángulo α.
A) 30°   B) 40°   C) 50°   D) 60°
27. Sinónimo de EFÍMERO
A) eterno
B) pasajero
C) frágil
D) leve
E) breve
28. Si 2) es la segunda opción, ¿cuánto es 2 + 2?
A) 3 B) 4 C) 5 D) 6 E) 7

CLAVES
25. C   26. B   27. B
''';

void main() {
  test('reconoce preguntas numeradas, alternativas y la tabla de claves', () {
    final r = parseExam(exam);
    expect(r.questions.map((q) => q.number), [25, 26, 27, 28]);
    expect(r.keyFound, isTrue);
    expect(r.expectedAlternatives, 5);
    final q25 = r.questions.first;
    expect(q25.parsed.statement, 'Halle el valor de x si 3x - 7 = 11');
    expect(q25.parsed.correctIndex, 2);
    expect(q25.ready, isTrue);
  });

  test('marca lo que hay que revisar', () {
    final r = parseExam(exam);
    final q26 = r.questions[1];
    expect(q26.issues.any((i) => i.contains('falta la E')), isTrue);
    expect(q26.issues.any((i) => i.contains('figura')), isTrue);
    final q28 = r.questions[3];
    expect(q28.parsed.alternatives.length, 5);
    expect(q28.issues.single, startsWith('Falta la clave'));
    expect(r.ready, 2);
    expect(r.toReview, 2);
    expect(q28.withCorrect(1).ready, isTrue);
  });

  test('sin tabla de claves todas piden la clave', () {
    final r = parseExam('1. Uno\na) x b) y\n2. Dos\na) x b) y');
    expect(r.keyFound, isFalse);
    expect(r.questions.every((q) => !q.ready), isTrue);
  });
}
