import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/ui/shell/admin_nav.dart';

void main() {
  test('cada ruta del menú se reconoce a sí misma y a sus rutas hijas', () {
    for (final item in adminNav) {
      expect(navItemFor(item.route), same(item));
    }
    expect(navItemFor('/questions/quick')?.route, '/questions');
    expect(navItemFor('/')?.label, 'Inicio');
  });

  test('cada sección tiene ayuda y pertenece a un grupo conocido', () {
    for (final item in adminNav) {
      expect(item.help.purpose.length, greaterThan(40), reason: item.label);
      expect(adminGroups, contains(item.group));
    }
  });
}
