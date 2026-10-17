import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/quality_settings.dart';
import 'package:ingresoya_admin/src/domain/question_signals.dart';

QuestionStat stat(Map<String, int> picks, String correct) => QuestionStat(
  id: 'q_1',
  questionId: 'q',
  version: 1,
  answered: picks.values.fold(0, (a, b) => a + b),
  blank: 0,
  correct: picks[correct] ?? 0,
  byAlternative: picks,
  labels: const {'a': 'A', 'b': 'B', 'c': 'C', 'd': 'D'},
  correctAlternativeId: correct,
);

void main() {
  const q = QualitySettings.defaults;

  test('clave sospechosa cuando una incorrecta se lleva la mayoría', () {
    final s = signalsFor(stat({'a': 3, 'b': 4, 'c': 32, 'd': 2}, 'a'), q);
    expect(s.single.kind, SignalKind.wrongKey);
    expect(s.single.message, contains('elige C'));
    expect(s.single.message, contains('clave marcada (A)'));
  });

  test('difícil cuando falla casi todo pero se reparten', () {
    final s = signalsFor(stat({'a': 2, 'b': 9, 'c': 8, 'd': 9}, 'a'), q);
    expect(s.single.kind, SignalKind.hard);
  });

  test('fácil y alternativas que nadie elige', () {
    final kinds = signalsFor(
      stat({'a': 98, 'b': 2, 'c': 0, 'd': 0}, 'a'),
      q,
    ).map((x) => x.kind).toList();
    expect(kinds, [SignalKind.easy, SignalKind.deadAlternative]);
  });

  test('con pocas respuestas no opina', () {
    expect(signalsFor(stat({'a': 0, 'b': 10}, 'a'), q), isEmpty);
  });

  test('los umbrales se leen del documento con límites', () {
    final s = QualitySettings.fromMap({'minAnswers': 3, 'failPercent': 80});
    expect(s.minAnswers, 20, reason: 'fuera de rango vuelve al de fábrica');
    expect(s.failPercent, 80);
    expect(QualitySettings.defaults.validate(), isNull);
  });
}
