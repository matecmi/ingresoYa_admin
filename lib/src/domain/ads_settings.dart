/// `{config}/ads`: dónde y cada cuánto la app muestra anuncios de AdMob
/// (docs/ads_contract.md, Fase 5A de la reestructuración de costos). Mismos
/// campos y límites que `AdsSettings` en iya-app. Apagar `enabled` quita todos
/// los anuncios sin publicar una versión nueva.
class AdsSettings {
  const AdsSettings({
    this.enabled = false,
    this.bannerScreens = defaultBannerScreens,
    this.interstitialMinMinutes = 10,
    this.firstExamOfDayFree = true,
    this.rewardedEnabled = true,
  });

  static const defaults = AdsSettings();

  /// Pantallas donde puede ir el banner al pie. Nunca en lección, examen,
  /// simulador ni historias.
  static const bannerScreenIds = ['home', 'news', 'rankings'];
  static const bannerScreenLabels = {
    'home': 'Inicio',
    'news': 'Lista de noticias',
    'rankings': 'Rankings',
  };
  static const defaultBannerScreens = {
    'home': true,
    'news': true,
    'rankings': true,
  };

  static const minInterstitialMinutes = 1;
  static const maxInterstitialMinutes = 240;

  /// Interruptor general: en false la app no carga ningún anuncio.
  final bool enabled;

  /// Pantalla → si lleva banner (`home`, `news`, `rankings`).
  final Map<String, bool> bannerScreens;

  /// Minutos mínimos entre dos intersticiales (al salir de un resultado).
  final int interstitialMinMinutes;

  /// El primer examen del día (hora del Perú) no muestra intersticial.
  final bool firstExamOfDayFree;

  /// Videos recompensados (ver la explicación de una pregunta fallada).
  final bool rewardedEnabled;

  factory AdsSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final rawScreens = data['bannerScreens'];
    final screens = <String, bool>{
      for (final id in bannerScreenIds)
        id: rawScreens is Map
            ? rawScreens[id] == true
            : defaultBannerScreens[id] ?? false,
    };
    final minutes = data['interstitialMinMinutes'];
    return AdsSettings(
      enabled: data['enabled'] == true,
      bannerScreens: screens,
      interstitialMinMinutes: minutes is num
          ? minutes.toInt()
          : defaults.interstitialMinMinutes,
      firstExamOfDayFree: data.containsKey('firstExamOfDayFree')
          ? data['firstExamOfDayFree'] == true
          : defaults.firstExamOfDayFree,
      rewardedEnabled: data.containsKey('rewardedEnabled')
          ? data['rewardedEnabled'] == true
          : defaults.rewardedEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'enabled': enabled,
    'bannerScreens': {
      for (final id in bannerScreenIds) id: bannerScreens[id] == true,
    },
    'interstitialMinMinutes': interstitialMinMinutes,
    'firstExamOfDayFree': firstExamOfDayFree,
    'rewardedEnabled': rewardedEnabled,
  };

  /// El primer problema, en español para el editor, o `null` si está bien.
  String? validate() {
    if (interstitialMinMinutes < minInterstitialMinutes ||
        interstitialMinMinutes > maxInterstitialMinutes) {
      return 'Minutos entre anuncios de pantalla completa: entre '
          '$minInterstitialMinutes y $maxInterstitialMinutes.';
    }
    for (final id in bannerScreens.keys) {
      if (!bannerScreenIds.contains(id)) {
        return 'Pantalla de banner desconocida: $id.';
      }
    }
    return null;
  }
}
