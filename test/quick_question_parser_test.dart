import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/domain/quick_question_parser.dart';

void main() {
  test('alternativas en una sola línea con a) b) c)', () {
    final p = parseQuickQuestion(
      'Un auto parte del reposo y acelera a razón de 3 m/s². ¿Qué rapidez '
      'tiene a los 4 s?\na) 7 m/s  b) 12 m/s  c) 9 m/s  d) 3/4 m/s  e) 15 m/s',
    );
    expect(p.statement, startsWith('Un auto parte'));
    expect(p.alternatives, ['7 m/s', '12 m/s', '9 m/s', '3/4 m/s', '15 m/s']);
    expect(p.correctIndex, isNull);
  });

  test('alternativas en líneas con A. B. y clave al final', () {
    final p = parseQuickQuestion(
      'Sinónimo de EFÍMERO\nA. eterno\nB. pasajero\nC. frágil\nD. leve\n'
      'E. breve\nClave: B',
    );
    expect(p.statement, 'Sinónimo de EFÍMERO');
    expect(p.alternatives.length, 5);
    expect(p.alternatives[1], 'pasajero');
    expect(p.correctIndex, 1);
  });

  test('una "a)" dentro del enunciado no corta la pregunta', () {
    final p = parseQuickQuestion(
      'Si x = 2, halla el valor de la expresión (a) del cuadro.\n'
      'A) 4\nB) 5\nC) 6\nD) 7',
    );
    expect(p.statement, contains('expresión (a) del cuadro'));
    expect(p.alternatives, ['4', '5', '6', '7']);
  });

  test('explicación y Rpta', () {
    final p = parseQuickQuestion(
      'Halla 2 + 2\n(a) 3 (b) 4 (c) 5\nRpta: (b)\nSolución: se suman.',
    );
    expect(p.alternatives, ['3', '4', '5']);
    expect(p.correctIndex, 1);
    expect(p.explanation, 'se suman.');
  });

  test('sin alternativas reconocibles queda todo como enunciado', () {
    final p = parseQuickQuestion('Solo un enunciado sin opciones');
    expect(p.statement, 'Solo un enunciado sin opciones');
    expect(p.alternatives, isEmpty);
  });

  test(r'el texto con $…$ se vuelve fórmula', () {
    final c = contentFromPlainText(r'Halla $x^2$ si x = 3', 's');
    final block = c.blocks.single as ParagraphBlock;
    expect(block.spans.map((s) => s.type), ['text', 'formula', 'text']);
    expect(block.spans[1].value, 'x^2');
    final plain = contentFromPlainText('Línea 1\n\nLínea 2', 's');
    expect(plain.blocks.length, 2);
  });

  test('parecido entre enunciados', () {
    final a = similarityTokens(
      'Un móvil parte del reposo con a = 2 m/s². ¿Qué distancia recorre en 5 s?',
    );
    final b = similarityTokens(
      'Un movil parte del reposo con a = 3 m/s². ¿Qué distancia recorre en 4 s?',
    );
    final c = similarityTokens('Sinónimo de la palabra efímero en el contexto');
    expect(statementSimilarity(a, b), greaterThan(.6));
    expect(statementSimilarity(a, c), lessThan(.2));
  });
}
