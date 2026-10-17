// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.
// Copia fiel de iya-app/lib/config/theme/app_theme.dart (commit 783bb74) para que la vista
// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.
// ignore_for_file: type=lint, deprecated_member_use

import 'package:flutter/material.dart';

enum AppColorPalette {
  classic(Brightness.dark),
  light(Brightness.light);

  const AppColorPalette(this.brightness);

  final Brightness brightness;

  String get label => switch (this) {
    AppColorPalette.classic => 'Clásico',
    AppColorPalette.light => 'Claro',
  };

  String get description => switch (this) {
    AppColorPalette.classic => 'Fondo azul marino y acentos azules',
    AppColorPalette.light => 'Superficies claras y texto oscuro',
  };
}

class AppPaletteColors extends ThemeExtension<AppPaletteColors> {
  const AppPaletteColors({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primary,
    required this.primaryStrong,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.headerStart,
    required this.headerEnd,
    required this.onPrimary,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color primary;
  final Color primaryStrong;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color headerStart;
  final Color headerEnd;
  final Color onPrimary;

  bool get isDark => background.computeLuminance() < .5;
  Color get onSurface =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF172033);
  Color get muted => onSurface.withValues(alpha: .72);
  Color get outline => onSurface.withValues(alpha: .18);
  Color get onHeader => isDark ? onPrimary : onSurface;
  Color get link => isDark ? const Color(0xFF93C5FD) : primaryStrong;
  Color get error => isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
  Color get info => isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490);
  Color get shadow =>
      isDark ? const Color(0xFF000000) : const Color(0xFF94A3B8);
  Color get primaryContainer =>
      Color.alphaBlend(primary.withValues(alpha: .12), surface);
  Color get successContainer =>
      Color.alphaBlend(success.withValues(alpha: .12), surface);
  Color get warningContainer =>
      Color.alphaBlend(warning.withValues(alpha: .12), surface);
  Color get errorContainer =>
      Color.alphaBlend(error.withValues(alpha: .12), surface);

  /// Gold is reserved for «Dominio del subtema»; no other state may use it.
  Color get mastery =>
      isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207);
  List<Color> get masteryGradient => isDark
      ? const [Color(0xFFFDE68A), Color(0xFFF59E0B)]
      : const [Color(0xFFFCD34D), Color(0xFFD97706)];
  Color get onMasteryGradient => const Color(0xFF3B2600);
  Color get masteryContainer =>
      Color.alphaBlend(mastery.withValues(alpha: .14), surface);

  /// Silver marks a completed subtopic in the achievement collection.
  List<Color> get completedMedalGradient => isDark
      ? const [Color(0xFFF1F5F9), Color(0xFF94A3B8)]
      : const [Color(0xFFE5E7EB), Color(0xFF9CA3AF)];
  Color get onCompletedMedal => const Color(0xFF1F2937);

  /// Contraste para botones e insignias con fondos de estado.
  Color onColor(Color background) {
    final luminance = background.computeLuminance();
    const dark = Color(0xFF000000);
    return 1.05 / (luminance + .05) >=
            (luminance + .05) / (dark.computeLuminance() + .05)
        ? const Color(0xFFFFFFFF)
        : dark;
  }

  static AppPaletteColors forPalette(AppColorPalette palette) =>
      switch (palette) {
        AppColorPalette.classic => const AppPaletteColors(
          background: Color(0xFF0A0F2C),
          surface: Color(0xFF0F172A),
          elevatedSurface: Color(0xFF13213B),
          primary: Color(0xFF2563EB),
          primaryStrong: Color(0xFF1D4ED8),
          secondary: Color(0xFFA855F7),
          success: Color(0xFF34D399),
          warning: Color(0xFFFBBF24),
          headerStart: Color(0xFF5B21B6),
          headerEnd: Color(0xFF1E3A8A),
          onPrimary: Colors.white,
        ),
        AppColorPalette.light => const AppPaletteColors(
          background: Color(0xFFF5F7FC),
          surface: Color(0xFFFFFFFF),
          elevatedSurface: Color(0xFFE8EDF8),
          primary: Color(0xFF2563EB),
          primaryStrong: Color(0xFF1D4ED8),
          secondary: Color(0xFF7C3AED),
          success: Color(0xFF047857),
          warning: Color(0xFF92400E),
          headerStart: Color(0xFFEBE6FA),
          headerEnd: Color(0xFFE2EDFE),
          onPrimary: Colors.white,
        ),
      };

  @override
  AppPaletteColors copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? primary,
    Color? primaryStrong,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? headerStart,
    Color? headerEnd,
    Color? onPrimary,
  }) => AppPaletteColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    secondary: secondary ?? this.secondary,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    headerStart: headerStart ?? this.headerStart,
    headerEnd: headerEnd ?? this.headerEnd,
    onPrimary: onPrimary ?? this.onPrimary,
  );

  @override
  AppPaletteColors lerp(covariant AppPaletteColors? other, double t) {
    if (other == null) return this;
    return AppPaletteColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      headerStart: Color.lerp(headerStart, other.headerStart, t)!,
      headerEnd: Color.lerp(headerEnd, other.headerEnd, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

extension AppPaletteBuildContext on BuildContext {
  AppPaletteColors get appColors =>
      Theme.of(this).extension<AppPaletteColors>() ??
      AppPaletteColors.forPalette(
        Theme.of(this).brightness == Brightness.dark
            ? AppColorPalette.classic
            : AppColorPalette.light,
      );
}

class AppTheme {
  static ThemeData dark() => forPalette(AppColorPalette.classic);
  static ThemeData light() => forPalette(AppColorPalette.light);

  static ThemeData forPalette(AppColorPalette palette) {
    final brightness = palette.brightness;
    final colors = AppPaletteColors.forPalette(palette);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
    final isDark = brightness == Brightness.dark;
    final onSurface = colors.onSurface;

    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.secondary,
        onSecondary: colors.onColor(colors.secondary),
        surface: colors.surface,
        onSurface: onSurface,
        onSurfaceVariant: colors.muted,
        primaryContainer: colors.primaryContainer,
        onPrimaryContainer: onSurface,
        secondaryContainer: colors.elevatedSurface,
        onSecondaryContainer: onSurface,
        surfaceContainerLowest: colors.background,
        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.elevatedSurface,
        surfaceContainerHigh: colors.elevatedSurface,
        surfaceContainerHighest: colors.elevatedSurface,
        outline: colors.outline,
        outlineVariant: colors.outline,
        error: colors.error,
        onError: colors.onColor(colors.error),
        errorContainer: colors.errorContainer,
        onErrorContainer: colors.error,
      ),
      extensions: [colors],
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      iconTheme: IconThemeData(color: onSurface),
      dividerColor: colors.outline,
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: onSurface),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colors.muted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colors.outline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        textStyle: TextStyle(color: onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevatedSurface,
        hintStyle: TextStyle(color: colors.muted),
        labelStyle: TextStyle(color: colors.muted),
        prefixIconColor: colors.muted,
        suffixIconColor: colors.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.link),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.elevatedSurface,
        contentTextStyle: TextStyle(color: onSurface),
        actionTextColor: colors.link,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.elevatedSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        indicatorColor: colors.primary.withValues(alpha: isDark ? .28 : .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? onSurface : onSurface.withValues(alpha: .58),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? onSurface : onSurface.withValues(alpha: .58),
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: .28),
          disabledForegroundColor: colors.onSurface.withValues(alpha: .45),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withValues(alpha: .28)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(colors.onPrimary),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : onSurface.withValues(alpha: .22),
        ),
      ),
    );
  }
}
