import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/plain_text.dart';

void main() {
  test('quita las marcas del formato de compatibilidad', () {
    expect(plainStatement('¿Cuánto es?[@]TEXT'), '¿Cuánto es?');
    expect(
      plainStatement('Halla[@]TEXT[#]x^2[@]MATH[%]https://a/b.png[@]URL'),
      'Halla x^2 [imagen]',
    );
    expect(plainStatement('texto suelto'), 'texto suelto');
    expect(plainStatement(''), '');
  });
}
