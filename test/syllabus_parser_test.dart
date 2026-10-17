import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/syllabus_parser.dart';

void main() {
  test('la sangría define tema, subtema y parte', () {
    final t = parseSyllabus(
      'Dinámica\n  Leyes de Newton\n    Primera ley\n'
      '    Segunda ley\n  Rozamiento\nEnergía\n  Trabajo',
    );
    expect(t.map((x) => x.name), ['Dinámica', 'Energía']);
    expect(t[0].children.map((x) => x.name), ['Leyes de Newton', 'Rozamiento']);
    expect(t[0].children[0].children.map((x) => x.name), [
      'Primera ley',
      'Segunda ley',
    ]);
    final c = countSyllabus(t);
    expect(c.summary, 'Se crearán 2 tema(s), 3 subtema(s) y 2 parte(s)');
  });

  test('también entiende numeración 1. / 1.1 / 1.1.1 y viñetas', () {
    final t = parseSyllabus(
      '1. Cinemática\n1.1 MRU\n1.1.1 Conceptos\n1.2 MRUV\n'
      '2. Dinámica\n- Fuerzas',
    );
    expect(t.length, 2);
    expect(t[0].children.length, 2);
    expect(t[0].children[0].children.single.name, 'Conceptos');
    expect(t[1].name, 'Dinámica');
  });

  test('tabs y texto vacío', () {
    expect(parseSyllabus('  \n'), isEmpty);
    final t = parseSyllabus('A\n\tB\n\t\tC');
    expect(t.single.children.single.children.single.name, 'C');
  });
}
