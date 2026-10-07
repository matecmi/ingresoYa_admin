/// App progress synchronization, stored in `{config}/sync` and read by the
/// student app at startup. Same fields and limits as `SyncSettings` in
/// iya-app (`features/synchronization/domain/entities/sync_settings.dart`).
class SyncSettings {
  const SyncSettings({
    this.autoSyncEnabled = true,
    this.debounceSeconds = 45,
    this.maxWaitSeconds = 180,
    this.refreshEveryHours = 12,
  });

  static const defaults = SyncSettings();

  static const minDebounceSeconds = 5;
  static const maxDebounceSeconds = 600;
  static const maxMaxWaitSeconds = 3600;
  static const minRefreshEveryHours = 1;
  static const maxRefreshEveryHours = 168;

  /// Off: progress only goes up at sign-in, sign-out and profile saves.
  final bool autoSyncEnabled;

  /// Wait after the last change before uploading.
  final int debounceSeconds;

  /// Longest wait while the student keeps changing things.
  final int maxWaitSeconds;

  /// How often, at most, the app checks for changes from other devices.
  final int refreshEveryHours;

  factory SyncSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    return SyncSettings(
      autoSyncEnabled: data['autoSyncEnabled'] != false,
      debounceSeconds: number('debounceSeconds', defaults.debounceSeconds),
      maxWaitSeconds: number('maxWaitSeconds', defaults.maxWaitSeconds),
      refreshEveryHours: number(
        'refreshEveryHours',
        defaults.refreshEveryHours,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'autoSyncEnabled': autoSyncEnabled,
    'debounceSeconds': debounceSeconds,
    'maxWaitSeconds': maxWaitSeconds,
    'refreshEveryHours': refreshEveryHours,
  };

  /// The first problem found, in Spanish for the editor, or null when valid.
  String? validate() {
    if (debounceSeconds < minDebounceSeconds ||
        debounceSeconds > maxDebounceSeconds) {
      return 'La espera tras el último cambio debe estar entre '
          '$minDebounceSeconds y $maxDebounceSeconds segundos.';
    }
    if (maxWaitSeconds < debounceSeconds ||
        maxWaitSeconds > maxMaxWaitSeconds) {
      return 'La espera máxima debe estar entre la espera tras el último '
          'cambio ($debounceSeconds s) y $maxMaxWaitSeconds segundos.';
    }
    if (refreshEveryHours < minRefreshEveryHours ||
        refreshEveryHours > maxRefreshEveryHours) {
      return 'La revisión de otros dispositivos debe estar entre '
          '$minRefreshEveryHours y $maxRefreshEveryHours horas.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SyncSettings &&
      other.autoSyncEnabled == autoSyncEnabled &&
      other.debounceSeconds == debounceSeconds &&
      other.maxWaitSeconds == maxWaitSeconds &&
      other.refreshEveryHours == refreshEveryHours;

  @override
  int get hashCode => Object.hash(
    autoSyncEnabled,
    debounceSeconds,
    maxWaitSeconds,
    refreshEveryHours,
  );
}

/// A saved configuration plus who changed it and when.
class SyncSettingsRecord {
  const SyncSettingsRecord({
    required this.settings,
    required this.exists,
    this.updatedAt,
    this.updatedBy = '',
  });

  final SyncSettings settings;

  /// False until the first save: the app is using its built-in defaults.
  final bool exists;
  final DateTime? updatedAt;
  final String updatedBy;
}
