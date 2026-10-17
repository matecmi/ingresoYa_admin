import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/staff.dart';

void main() {
  test('sin role en el token la sesión es de Dueño', () {
    final s = AdminSession.fromClaims(
      uid: 'u',
      email: 'e',
      claims: {'admin': true},
    );
    expect(s.isOwner, isTrue);
    expect(s.can(StaffSection.staff, StaffAction.archive), isTrue);
  });

  test('un editor no publica ni ve alumnos', () {
    final s = AdminSession.fromClaims(
      uid: 'u',
      email: 'e',
      claims: {
        'admin': true,
        'role': 'editor',
        'p': {'questions': 've', 'courses': 've'},
        'cs': ['qa-fis'],
      },
    );
    expect(s.can(StaffSection.questions, StaffAction.edit), isTrue);
    expect(s.can(StaffSection.questions, StaffAction.publish), isFalse);
    expect(s.can(StaffSection.students, StaffAction.view), isFalse);
    expect(s.scope.courseIds, ['qa-fis']);
  });

  test('marcar una acción suma ver; quitar ver vacía la sección', () {
    var p = const StaffPerms.none();
    p = p.toggled(StaffSection.questions, StaffAction.publish, true);
    expect(p.letters(StaffSection.questions), 'vp');
    p = p.toggled(StaffSection.questions, StaffAction.view, false);
    expect(p.letters(StaffSection.questions), '');
    expect(StaffPerms.normalize('pae'), 'vepa');
  });

  test('los perfiles de fábrica coinciden con las Functions', () {
    final editor = builtinStaffRoles.firstWhere((r) => r.id == 'editor');
    expect(editor.perms.toJson(), {
      'questions': 've',
      'courses': 've',
      'universities': 've',
      'settings': 'v',
      'history': 'v',
    });
  });
}
