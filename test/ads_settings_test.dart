import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/ads_settings.dart';

/// Fase 5A de costos: `{config}/ads` (docs/ads_contract.md).
void main() {
  test('de fábrica está apagado, banner en las siete pantallas y el '
      'intersticial al terminar cada examen', () {
    const d = AdsSettings.defaults;
    expect(d.enabled, isFalse);
    expect(d.bannerScreens.keys, AdsSettings.bannerScreenIds);
    expect(d.bannerScreens.values.every((on) => on), isTrue);
    expect(AdsSettings.bannerScreenIds, [
      'home',
      'courses',
      'simulator',
      'stats',
      'profile',
      'news',
      'rankings',
    ]);
    expect(d.interstitialMinMinutes, 0);
    expect(d.firstExamOfDayFree, isFalse);
    expect(d.rewardedEnabled, isTrue);
    expect(d.validate(), isNull);
  });

  test('lee el mapa con tolerancia y lo devuelve normalizado', () {
    final s = AdsSettings.fromMap({
      'enabled': true,
      'bannerScreens': {'home': false, 'news': true, 'extra': true},
      'interstitialMinMinutes': 15.0,
      'firstExamOfDayFree': true,
      'rewardedEnabled': false,
    });
    expect(s.enabled, isTrue);
    expect(s.bannerScreens, {
      'home': false,
      'courses': false,
      'simulator': false,
      'stats': false,
      'profile': false,
      'news': true,
      'rankings': false,
    });
    expect(s.interstitialMinMinutes, 15);
    expect(s.firstExamOfDayFree, isTrue);
    expect(s.rewardedEnabled, isFalse);
    expect(s.toMap()['bannerScreens'], s.bannerScreens);
    expect(AdsSettings.fromMap(s.toMap()).toMap(), s.toMap());
  });

  test('acepta 0 minutos (siempre) y rechaza fuera de rango', () {
    expect(
      AdsSettings.fromMap({'interstitialMinMinutes': 0}).validate(),
      isNull,
    );
    expect(
      AdsSettings.fromMap({'interstitialMinMinutes': -1}).validate(),
      contains('entre 0 y 240'),
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
