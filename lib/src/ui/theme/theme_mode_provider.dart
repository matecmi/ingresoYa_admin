import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_pref_store.dart';

/// Tema elegido en la barra superior: automático (el del sistema), claro u
/// oscuro. Se recuerda en este navegador.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => switch (readThemePref()) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  void set(ThemeMode mode) {
    writeThemePref(mode.name);
    state = mode;
  }
}

Brightness resolveBrightness(ThemeMode mode, Brightness platform) =>
    switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    };
