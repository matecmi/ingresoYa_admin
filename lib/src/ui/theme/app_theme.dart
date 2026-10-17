import 'package:flutter/material.dart';

/// Sistema visual del admin (tablero «6 · Sistema visual» del lienzo).
///
/// Tema claro: fondo gris muy suave, tarjetas blancas con borde fino, texto
/// casi negro y morado de marca para lo que se puede tocar. Los colores de
/// estado siempre van en pareja (texto fuerte + fondo suave).
class AppTheme {
  AppTheme._();

  static AdminPalette _p = AdminPalette.light;

  /// Tema activo (lo fija `AdminApp` según la preferencia del usuario).
  static AdminPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Cambia la paleta. Devuelve `true` si cambió (hay que reconstruir).
  static bool use(Brightness brightness) {
    final next = brightness == Brightness.dark
        ? AdminPalette.dark
        : AdminPalette.light;
    if (identical(next, _p)) return false;
    _p = next;
    return true;
  }

  /// Fondo y texto de avisos flotantes (snackbar, tooltip): invertidos.
  static Color get inverse => isDark ? const Color(0xFFE4E7EE) : _p.ink;
  static Color get onInverse => isDark ? const Color(0xFF101828) : Colors.white;

  // Superficies
  static Color get bg => _p.bg;
  static Color get card => _p.card;
  static Color get subtle => _p.subtle;
  static Color get line => _p.line;
  static Color get lineStrong => _p.lineStrong;

  // Texto
  static Color get ink => _p.ink;
  static Color get body => _p.body;
  static Color get muted => _p.muted;
  static Color get faint => _p.faint;

  // Marca
  static Color get brand => _p.brand;
  static Color get brandInk => _p.brandInk;
  static Color get brandSoft => _p.brandSoft;
  static Color get brandTint => _p.brandTint;

  // Estados (texto / fondo / borde)
  static Color get success => _p.success;
  static Color get successSoft => _p.successSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warnSoft;
  static Color get warnLine => _p.warnLine;
  static Color get error => _p.error;
  static Color get errorSoft => _p.errorSoft;
  static Color get errorLine => _p.errorLine;
  static Color get info => _p.info;
  static Color get infoInk => _p.infoInk;
  static Color get infoSoft => _p.infoSoft;

  /// Compatibilidad con pantallas anteriores: `accent` y `headerA` eran el
  /// azul y el morado del tema oscuro; ahora ambos son el morado de marca.
  static Color get rowLine => _p.rowLine;
  static Color get neutralSoft => _p.neutralSoft;
  static Color get brandLine => _p.brandLine;
  static Color get successLine => _p.successLine;
  static Color get infoLine => _p.infoLine;
  static Color get warnInk => _p.warnInk;
  static Color get bar => _p.bar;

  static Color get accent => brand;
  static Color get headerA => brand;

  static const fontFamily = 'PlusJakartaSans';
  static const monoFamily = 'monospace';

  static const radius = 12.0;
  static const radiusLg = 16.0;

  static final _cache = <Brightness, ThemeData>{};

  /// Tema de Material de la paleta activa (se arma una vez por paleta).
  static ThemeData current() => _cache[_p.brightness] ??= _build(_p.brightness);

  static ThemeData light() => of(Brightness.light);
  static ThemeData dark() => of(Brightness.dark);

  /// Tema de Material con la paleta pedida (y la deja activa).
  static ThemeData of(Brightness brightness) {
    use(brightness);
    return current();
  }

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
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
      brightness: brightness,
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
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      appBarTheme: AppBarTheme(
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
          side: BorderSide(color: line),
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
          side: BorderSide(color: lineStrong),
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
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(
          color: brand,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(color: faint),
        helperStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: brandSoft,
        side: BorderSide(color: lineStrong),
        labelStyle: TextStyle(
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
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: body,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: bg,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverse,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: onInverse,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      tabBarTheme: TabBarThemeData(
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
        thumbColor: WidgetStateProperty.all(const Color(0xFFFFFFFF)),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? success : faint,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : card,
        ),
        side: BorderSide(color: lineStrong, width: 1.5),
      ),
      listTileTheme: ListTileThemeData(iconColor: body, textColor: ink),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inverse,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: onInverse,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: line),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: line,
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
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandSoft, card],
      ),
      border: Border(bottom: BorderSide(color: line)),
    );
  }
}

/// Colores de un tema (claro u oscuro). Las pantallas los leen con
/// `AppTheme.ink`, `AppTheme.card`, … y cambian al cambiar de tema.
class AdminPalette {
  const AdminPalette({
    required this.bg,
    required this.card,
    required this.subtle,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.body,
    required this.muted,
    required this.faint,
    required this.brand,
    required this.brandInk,
    required this.brandSoft,
    required this.brandTint,
    required this.success,
    required this.successSoft,
    required this.warn,
    required this.warnSoft,
    required this.warnLine,
    required this.error,
    required this.errorSoft,
    required this.errorLine,
    required this.info,
    required this.infoInk,
    required this.infoSoft,
    required this.rowLine,
    required this.neutralSoft,
    required this.brandLine,
    required this.successLine,
    required this.infoLine,
    required this.warnInk,
    required this.bar,
    required this.brightness,
  });

  final Color bg;
  final Color card;
  final Color subtle;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color body;
  final Color muted;
  final Color faint;
  final Color brand;
  final Color brandInk;
  final Color brandSoft;
  final Color brandTint;
  final Color success;
  final Color successSoft;
  final Color warn;
  final Color warnSoft;
  final Color warnLine;
  final Color error;
  final Color errorSoft;
  final Color errorLine;
  final Color info;
  final Color infoInk;
  final Color infoSoft;
  final Color rowLine;
  final Color neutralSoft;
  final Color brandLine;
  final Color successLine;
  final Color infoLine;
  final Color warnInk;
  final Color bar;
  final Brightness brightness;

  static const light = AdminPalette(
    bg: Color(0xFFF5F6FA),
    card: Color(0xFFFFFFFF),
    subtle: Color(0xFFF9FAFB),
    line: Color(0xFFE4E7EE),
    lineStrong: Color(0xFFD0D5DD),
    ink: Color(0xFF101828),
    body: Color(0xFF344054),
    muted: Color(0xFF5B6474),
    faint: Color(0xFF98A2B3),
    brand: Color(0xFF5B21B6),
    brandInk: Color(0xFF3F1690),
    brandSoft: Color(0xFFEFE8FF),
    brandTint: Color(0xFFFAF7FF),
    success: Color(0xFF067647),
    successSoft: Color(0xFFECFDF3),
    warn: Color(0xFFB54708),
    warnSoft: Color(0xFFFFFAEB),
    warnLine: Color(0xFFFEDF89),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFFEF3F2),
    errorLine: Color(0xFFFECDCA),
    info: Color(0xFF1D4ED8),
    infoInk: Color(0xFF1E3A8A),
    infoSoft: Color(0xFFEFF4FF),
    rowLine: Color(0xFFF0F2F5),
    neutralSoft: Color(0xFFF2F4F7),
    brandLine: Color(0xFFD9C8FF),
    successLine: Color(0xFFABEFC6),
    infoLine: Color(0xFFC7D7FE),
    warnInk: Color(0xFF93370D),
    bar: Color(0xFF101828),
    brightness: Brightness.light,
  );

  static const dark = AdminPalette(
    bg: Color(0xFF0E1016),
    card: Color(0xFF171A23),
    subtle: Color(0xFF1C202B),
    line: Color(0xFF2A2F3C),
    lineStrong: Color(0xFF3B4252),
    ink: Color(0xFFF2F4F7),
    body: Color(0xFFD0D5DD),
    muted: Color(0xFFA4ACBA),
    faint: Color(0xFF6F7887),
    brand: Color(0xFF8B5CF6),
    brandInk: Color(0xFFC9B8FF),
    brandSoft: Color(0xFF2B2150),
    brandTint: Color(0xFF1C1830),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0F2A1C),
    warn: Color(0xFFFBBF24),
    warnSoft: Color(0xFF2D230F),
    warnLine: Color(0xFF6B5216),
    error: Color(0xFFF87171),
    errorSoft: Color(0xFF331A1A),
    errorLine: Color(0xFF6E2A2A),
    info: Color(0xFF7DA7FF),
    infoInk: Color(0xFFB3CCFF),
    infoSoft: Color(0xFF16213D),
    rowLine: Color(0xFF232733),
    neutralSoft: Color(0xFF232733),
    brandLine: Color(0xFF4C3A85),
    successLine: Color(0xFF1E5B3A),
    infoLine: Color(0xFF2C4074),
    warnInk: Color(0xFFFCD34D),
    bar: Color(0xFF2B3040),
    brightness: Brightness.dark,
  );
}
