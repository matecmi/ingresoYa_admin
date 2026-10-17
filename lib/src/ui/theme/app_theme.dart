import 'package:flutter/material.dart';

/// Sistema visual del admin (tablero «6 · Sistema visual» del lienzo).
///
/// Tema claro: fondo gris muy suave, tarjetas blancas con borde fino, texto
/// casi negro y morado de marca para lo que se puede tocar. Los colores de
/// estado siempre van en pareja (texto fuerte + fondo suave).
class AppTheme {
  AppTheme._();

  // Superficies
  static const bg = Color(0xFFF5F6FA);
  static const card = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF9FAFB);
  static const line = Color(0xFFE4E7EE);
  static const lineStrong = Color(0xFFD0D5DD);

  // Texto
  static const ink = Color(0xFF101828);
  static const body = Color(0xFF344054);
  static const muted = Color(0xFF5B6474);
  static const faint = Color(0xFF98A2B3);

  // Marca
  static const brand = Color(0xFF5B21B6);
  static const brandInk = Color(0xFF3F1690);
  static const brandSoft = Color(0xFFEFE8FF);
  static const brandTint = Color(0xFFFAF7FF);

  // Estados (texto / fondo / borde)
  static const success = Color(0xFF067647);
  static const successSoft = Color(0xFFECFDF3);
  static const warn = Color(0xFFB54708);
  static const warnSoft = Color(0xFFFFFAEB);
  static const warnLine = Color(0xFFFEDF89);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFEF3F2);
  static const errorLine = Color(0xFFFECDCA);
  static const info = Color(0xFF1D4ED8);
  static const infoInk = Color(0xFF1E3A8A);
  static const infoSoft = Color(0xFFEFF4FF);

  /// Compatibilidad con pantallas anteriores: `accent` y `headerA` eran el
  /// azul y el morado del tema oscuro; ahora ambos son el morado de marca.
  static const accent = brand;
  static const headerA = brand;

  static const fontFamily = 'PlusJakartaSans';
  static const monoFamily = 'monospace';

  static const radius = 12.0;
  static const radiusLg = 16.0;

  /// Se mantiene el nombre por compatibilidad: la app entera usa este tema.
  static ThemeData dark() => light();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand,
          onPrimary: Colors.white,
          primaryContainer: brandSoft,
          onPrimaryContainer: brandInk,
          secondary: brandInk,
          surface: card,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: lineStrong,
          outlineVariant: line,
          error: error,
          errorContainer: errorSoft,
          surfaceContainerLowest: card,
          surfaceContainerLow: subtle,
          surfaceContainer: subtle,
          surfaceContainerHigh: bg,
          surfaceContainerHighest: line,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      brightness: Brightness.light,
    );
    // Roboto como respaldo: letras griegas y símbolos (α, π, √) que Plus
    // Jakarta Sans no trae y aparecen en enunciados.
    final text = base.textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
      fontFamilyFallback: const ['Roboto'],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    const label = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: text,
      dividerColor: line,
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          padding: pad,
          shape: shape,
          textStyle: label,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          elevation: 0,
          padding: pad,
          shape: shape,
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: card,
          side: const BorderSide(color: lineStrong),
          padding: pad,
          shape: shape,
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          shape: shape,
          textStyle: label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: body),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(
          color: brand,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: faint),
        helperStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: brandSoft,
        side: const BorderSide(color: lineStrong),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: body,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: bg,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: brandInk,
        unselectedLabelColor: muted,
        indicatorColor: brand,
        dividerColor: line,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? success : faint,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : card,
        ),
        side: const BorderSide(color: lineStrong, width: 1.5),
      ),
      listTileTheme: const ListTileThemeData(iconColor: body, textColor: ink),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: Color(0xFFF2F4F7),
      ),
    );
  }

  static BoxDecoration cardDeco({
    Color? color,
    double radius = radiusLg,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? line),
    );
  }

  /// Cabecera de hojas y paneles: antes era un degradado oscuro; ahora es una
  /// franja clara con el morado de marca apenas insinuado.
  static BoxDecoration headerGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandSoft, card],
      ),
      border: Border(bottom: BorderSide(color: line)),
    );
  }
}
