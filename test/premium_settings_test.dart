import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/premium_settings.dart';

/// Fase 5B de costos: `{config}/premium` (docs/premium_contract.md).
void main() {
  test('de fábrica está apagado con 3 exámenes pasados gratis por día', () {
    const d = PremiumSettings.defaults;
    expect(d.enabled, isFalse);
    expect(d.freePastExamsPerDay, 3);
    expect(d.validate(), isNull);
    expect(PremiumSettings.monthlyProductId, 'premium_monthly');
    expect(PremiumSettings.yearlyProductId, 'premium_yearly');
  });

  test('lee el mapa con tolerancia y lo devuelve normalizado', () {
    final s = PremiumSettings.fromMap({
      'enabled': true,
      'freePastExamsPerDay': 5.0,
    });
    expect(s.enabled, isTrue);
    expect(s.freePastExamsPerDay, 5);
    expect(PremiumSettings.fromMap(s.toMap()).toMap(), s.toMap());
    expect(PremiumSettings.fromMap({'enabled': 'yes'}).enabled, isFalse);
    expect(PremiumSettings.fromMap(null), same(PremiumSettings.defaults));
  });

  test('rechaza límites fuera de rango; 0 significa sin límite', () {
    expect(
      PremiumSettings.fromMap({'freePastExamsPerDay': -1}).validate(),
      contains('entre 0 y 20'),
    );
    expect(
      PremiumSettings.fromMap({'freePastExamsPerDay': 21}).validate(),
      isNotNull,
    );
    expect(
      PremiumSettings.fromMap({'freePastExamsPerDay': 0}).validate(),
      isNull,
    );
  });
}
