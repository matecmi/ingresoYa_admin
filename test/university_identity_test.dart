import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/university_identity.dart';
import 'package:ingresoya_admin/src/domain/university_profile.dart';

void main() {
  test('identity validates colors and lengths and saves only what is set', () {
    const ok = UniversityIdentity(
      primaryColor: '#15803d',
      secondaryColor: '#F8FAFC',
      freshmanName: ' cachimbo ',
    );
    expect(ok.validate(), isNull);
    expect(ok.toMap(), {
      'primaryColor': '#15803D',
      'secondaryColor': '#F8FAFC',
      'freshmanName': 'cachimbo',
      'showWouldHaveEntered': true,
    });
    expect(
      const UniversityIdentity(primaryColor: 'verde').validate(),
      isNotNull,
    );
    expect(
      const UniversityIdentity(secondaryColor: '#FFFFFF').validate(),
      'Elige primero el color principal.',
    );
    expect(
      UniversityIdentity(freshmanName: 'x' * 25).validate(),
      isNotNull,
    );
    expect(UniversityIdentity.empty.toMap(), {'showWouldHaveEntered': true});
  });

  test('the student data reads the identity of the university document', () {
    final data = UniversityStudentData.fromDoc('unprg', {
      'acronym': 'UNPRG',
      'identity': {
        'primaryColor': '#15803D',
        'showWouldHaveEntered': false,
      },
    });
    expect(data.identity.primaryColor, '#15803D');
    expect(data.identity.showWouldHaveEntered, isFalse);
    expect(
      UniversityStudentData.fromDoc('x', {}).identity.primaryColor,
      isEmpty,
    );
  });
}
