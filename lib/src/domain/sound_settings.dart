/// Sonidos de logro (`{config}/sounds`, docs/sounds_contract.md): la app
/// suena solo al completar algo, en 4 niveles (familia A · Campanita).

/// Los niveles que conoce la app.
const soundLevels = {
  1: 'Nivel 1 · Pequeño (ganar XP, corregir errores)',
  2: 'Nivel 2 · Medio (misión del día, parte o subtema completados)',
  3: 'Nivel 3 · Grande (subir de rango, completar un tema, ascender de liga)',
  4: 'Nivel 4 · Dominio (dominar un subtema, llegar a Maestro)',
};

class SoundSettings {
  const SoundSettings({
    this.enabled = true,
    this.volume = 70,
    this.levels = const {1: true, 2: true, 3: true, 4: true},
    this.smallCooldownSeconds = 3,
    this.vibrate = true,
  });

  static const defaults = SoundSettings();

  final bool enabled;

  /// 0-100, relativo al volumen del celular.
  final int volume;

  /// Nivel → encendido (ausente = encendido).
  final Map<int, bool> levels;

  /// Pausa mínima entre dos sonidos del nivel 1.
  final int smallCooldownSeconds;

  /// Pulso corto al celebrar (lo único que se siente en modo vibración).
  final bool vibrate;

  bool isOn(int level) => levels[level] ?? true;

  factory SoundSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    final raw = data['levels'] is Map ? data['levels'] as Map : const {};
    return SoundSettings(
      enabled: data['enabled'] != false,
      volume: number('volume', defaults.volume),
      levels: {
        for (final level in soundLevels.keys) level: raw['$level'] != false,
      },
      smallCooldownSeconds: number(
        'smallCooldownSeconds',
        defaults.smallCooldownSeconds,
      ),
      vibrate: data['vibrate'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'volume': volume,
    'levels': {for (final level in soundLevels.keys) '$level': isOn(level)},
    'smallCooldownSeconds': smallCooldownSeconds,
    'vibrate': vibrate,
  };

  String? validate() {
    if (volume < 0 || volume > 100) return 'El volumen va de 0 a 100.';
    if (smallCooldownSeconds < 0 || smallCooldownSeconds > 60) {
      return 'La pausa del nivel 1 va de 0 a 60 segundos.';
    }
    return null;
  }
}
