/// `{config}/premium`: el plan premium (docs/premium_contract.md, Fase 5B de
/// la reestructuración de costos). Mismos campos y límites que
/// `PremiumSettings` en iya-app y `parsePremiumSettings` en Functions. Apagado
/// de fábrica: la app no ofrece Premium ni limita a la cuenta gratuita.
class PremiumSettings {
  const PremiumSettings({this.enabled = false, this.freePastExamsPerDay = 3});

  static const defaults = PremiumSettings();

  /// Mismos ID que en Play Console y en la app (no se configuran: son
  /// identificadores, como las unidades de AdMob).
  static const monthlyProductId = 'premium_monthly';
  static const yearlyProductId = 'premium_yearly';

  static const minFreePastExamsPerDay = 0;
  static const maxFreePastExamsPerDay = 20;

  /// Interruptor general: en false nadie compra, no hay límites de cuenta
  /// gratuita y la app no muestra la pantalla Premium.
  final bool enabled;

  /// Exámenes pasados por día (hora del Perú) para la cuenta gratuita;
  /// 0 = sin límite.
  final int freePastExamsPerDay;

  factory PremiumSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final limit = data['freePastExamsPerDay'];
    return PremiumSettings(
      enabled: data['enabled'] == true,
      freePastExamsPerDay: limit is num
          ? limit.toInt()
          : defaults.freePastExamsPerDay,
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'enabled': enabled,
    'freePastExamsPerDay': freePastExamsPerDay,
  };

  /// El primer problema, en español para el editor, o `null` si está bien.
  String? validate() {
    if (freePastExamsPerDay < minFreePastExamsPerDay ||
        freePastExamsPerDay > maxFreePastExamsPerDay) {
      return 'Exámenes pasados gratis por día: entre '
          '$minFreePastExamsPerDay y $maxFreePastExamsPerDay.';
    }
    return null;
  }
}
