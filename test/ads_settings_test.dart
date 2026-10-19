import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/ads_settings.dart';

/// Fase 5A de costos: `{config}/ads` (docs/ads_contract.md).
void main() {
  test('de fábrica está apagado y con el banner en las tres pantallas', () {
    const d = AdsSettings.defaults;
    expect(d.enabled, isFalse);
    expect(d.bannerScreens, {'home': true, 'news': true, 'rankings': true});
    expect(d.interstitialMinMinutes, 10);
    expect(d.firstExamOfDayFree, isTrue);
    expect(d.rewardedEnabled, isTrue);
    expect(d.validate(), isNull);
  });

  test('lee el mapa con tolerancia y lo devuelve normalizado', () {
    final s = AdsSettings.fromMap({
      'enabled': true,
      'bannerScreens': {'home': false, 'news': true, 'extra': true},
      'interstitialMinMinutes': 15.0,
      'rewardedEnabled': false,
    });
    expect(s.enabled, isTrue);
    expect(s.bannerScreens, {'home': false, 'news': true, 'rankings': false});
    expect(s.interstitialMinMinutes, 15);
    expect(s.firstExamOfDayFree, isTrue);
    expect(s.rewardedEnabled, isFalse);
    expect(s.toMap()['bannerScreens'], {
      'home': false,
      'news': true,
      'rankings': false,
    });
    expect(AdsSettings.fromMap(s.toMap()).toMap(), s.toMap());
  });

  test('rechaza minutos fuera de rango', () {
    expect(
      AdsSettings.fromMap({'interstitialMinMinutes': 0}).validate(),
      contains('entre 1 y 240'),
    );
    expect(
      AdsSettings.fromMap({'interstitialMinMinutes': 241}).validate(),
      isNotNull,
    );
    expect(
      AdsSettings.fromMap({'interstitialMinMinutes': 240}).validate(),
      isNull,
    );
  });
}
