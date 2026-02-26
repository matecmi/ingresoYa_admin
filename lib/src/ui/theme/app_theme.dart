import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const bg = Color(0xFF0A0F2C);
  static const card = Color(0xFF0F172A);
  static const accent = Color(0xFF1E3A8A);
  static const headerA = Color(0xFF5B21B6);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static BoxDecoration cardDeco({
    Color? color,
    double radius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(.08),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.22),
          blurRadius: 18,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration headerGradient() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [headerA, accent],
      ),
      border: Border(
        bottom: BorderSide(color: Colors.white24, width: .2),
      ),
    );
  }
}
