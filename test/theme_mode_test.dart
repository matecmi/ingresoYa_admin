import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/theme/theme_mode_provider.dart';

void main() {
  tearDown(() => AppTheme.use(Brightness.light));

  test('automático sigue al sistema; claro y oscuro lo ignoran', () {
    expect(
      resolveBrightness(ThemeMode.system, Brightness.dark),
      Brightness.dark,
    );
    expect(
      resolveBrightness(ThemeMode.light, Brightness.dark),
      Brightness.light,
    );
    expect(
      resolveBrightness(ThemeMode.dark, Brightness.light),
      Brightness.dark,
    );
  });

  test('cambiar de paleta cambia los colores y el tema de Material', () {
    AppTheme.use(Brightness.light);
    final lightCard = AppTheme.card;
    expect(AppTheme.use(Brightness.dark), isTrue);
    expect(AppTheme.use(Brightness.dark), isFalse);
    expect(AppTheme.isDark, isTrue);
    expect(AppTheme.card, isNot(lightCard));
    expect(AppTheme.current().brightness, Brightness.dark);
    expect(AppTheme.current().scaffoldBackgroundColor, AppTheme.bg);
  });

  test('la preferencia se recuerda', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(themeModeProvider.notifier).set(ThemeMode.dark);
    final again = ProviderContainer();
    addTearDown(again.dispose);
    expect(again.read(themeModeProvider), ThemeMode.dark);
  });

  test('el texto principal contrasta con las tarjetas en ambos temas', () {
    for (final b in Brightness.values) {
      AppTheme.use(b);
      final l1 = AppTheme.ink.computeLuminance();
      final l2 = AppTheme.card.computeLuminance();
      final ratio = (l1 > l2
          ? (l1 + .05) / (l2 + .05)
          : (l2 + .05) / (l1 + .05));
      expect(ratio, greaterThan(7), reason: '$b');
    }
  });
}
