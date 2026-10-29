// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.
// Copia fiel de iya-app/lib/app/widgets/owl_mascot.dart (commit b8be648) para que la vista
// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.
// ignore_for_file: type=lint, deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Expressions of the IngresoYa owl. Each one has a clear moment of use:
/// neutral in avatars, happy on the home header, thinking while an exam is
/// prepared, celebrating on mastery and cheering on empty or retry states.
enum OwlMood { neutral, happy, thinking, celebrating, cheering }

/// Bufanda del búho con los colores de la universidad del alumno.
class OwlOutfit {
  const OwlOutfit({required this.scarf, required this.stripe});

  final Color scarf;
  final Color stripe;

  @override
  bool operator ==(Object other) =>
      other is OwlOutfit && other.scarf == scarf && other.stripe == stripe;

  @override
  int get hashCode => Object.hash(scarf, stripe);
}

/// Viste a todos los búhos de debajo con [outfit] (la raíz de la app la pone
/// con la universidad del alumno); null = el búho de siempre.
class OwlOutfitScope extends InheritedWidget {
  const OwlOutfitScope({super.key, required this.outfit, required super.child});

  final OwlOutfit? outfit;

  static OwlOutfit? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwlOutfitScope>()?.outfit;

  @override
  bool updateShouldNotify(OwlOutfitScope old) => old.outfit != outfit;
}

/// Vector owl drawn in the app palette, with light motion: it blinks, floats,
/// tilts its head while thinking and hops when celebrating. It stays still
/// when the system asks to reduce motion or [OwlMascot.animationsEnabled] is
/// off (widget tests turn it off so `pumpAndSettle` can finish).
class OwlMascot extends StatefulWidget {
  const OwlMascot({
    super.key,
    this.size = 80,
    this.mood = OwlMood.neutral,
    this.semanticLabel,
    this.cap = false,
    this.plain = false,
  });

  final double size;
  final OwlMood mood;

  /// Birrete de graduado (celebraciones y la tarjeta para compartir).
  final bool cap;

  /// Sin la bufanda de la universidad aunque haya [OwlOutfitScope].
  final bool plain;

  /// Null keeps the owl decorative for screen readers.
  final String? semanticLabel;

  static bool animationsEnabled = true;

  @override
  State<OwlMascot> createState() => _OwlMascotState();
}

class _OwlMascotState extends State<OwlMascot>
    with SingleTickerProviderStateMixin {
  // One loop drives every motion so they stay in step.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !OwlMascot.animationsEnabled ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still) {
      _loop.stop();
      _loop.value = .5;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owl = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (_, __) => CustomPaint(
          painter: _OwlPainter(
            mood: widget.mood,
            t: _loop.value,
            outfit: widget.plain ? null : OwlOutfitScope.of(context),
            cap: widget.cap,
          ),
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: owl)
        : Semantics(label: label, image: true, child: owl);
  }
}

class _OwlPainter extends CustomPainter {
  _OwlPainter({
    required this.mood,
    required this.t,
    this.outfit,
    this.cap = false,
  });

  final OwlMood mood;
  final OwlOutfit? outfit;
  final bool cap;

  /// Position in the 4 s loop, 0..1.
  final double t;

  static const _ears = Color(0xFF4C1D95);
  static const _body = Color(0xFF6D28D9);
  static const _face = Color(0xFFC4B5FD);
  static const _ink = Color(0xFF1E1B4B);
  static const _beak = Color(0xFFFB923C);
  static const _thought = Color(0xFF93C5FD);

  double get _wave => math.sin(t * 2 * math.pi);

  /// Eyes close for a moment twice per loop.
  bool get _blinking => (t > .30 && t < .335) || (t > .80 && t < .835);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    final hop = mood == OwlMood.celebrating
        ? -6 * math.sin(t * 4 * math.pi).abs()
        : 2.5 * _wave;
    canvas.translate(0, hop);
    if (mood == OwlMood.thinking) {
      canvas.translate(50, 60);
      canvas.rotate(.09 * _wave);
      canvas.translate(-50, -60);
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _ink;

    // Ear tufts, body and face disc.
    fill.color = _ears;
    canvas.drawPath(
      Path()
        ..moveTo(18, 34)
        ..lineTo(24, 8)
        ..lineTo(40, 24)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(82, 34)
        ..lineTo(76, 8)
        ..lineTo(60, 24)
        ..close(),
      fill,
    );
    fill.color = _body;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 56), width: 80, height: 76),
      fill,
    );
    fill.color = _face;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 62), width: 60, height: 54),
      fill,
    );

    // Eye whites.
    fill.color = Colors.white;
    canvas.drawCircle(const Offset(36, 52), 12, fill);
    canvas.drawCircle(const Offset(64, 52), 12, fill);

    _eye(canvas, const Offset(36, 52), left: true, fill: fill, stroke: stroke);
    _eye(canvas, const Offset(64, 52), left: false, fill: fill, stroke: stroke);

    // Glasses and bridge.
    stroke.strokeWidth = 3;
    canvas.drawCircle(const Offset(36, 52), 14, stroke);
    canvas.drawCircle(const Offset(64, 52), 14, stroke);
    canvas.drawLine(const Offset(49, 51), const Offset(51, 51), stroke);

    // Beak.
    fill.color = _beak;
    canvas.drawPath(
      Path()
        ..moveTo(45, 66)
        ..lineTo(55, 66)
        ..lineTo(50, 75)
        ..close(),
      fill,
    );
    if (outfit case final outfit?) _scarf(canvas, outfit, fill, stroke);
    if (cap) _cap(canvas, fill, stroke);
    canvas.restore();

    if (mood == OwlMood.thinking) _thoughtDots(canvas, s);
  }

  void _eye(
    Canvas canvas,
    Offset c, {
    required bool left,
    required Paint fill,
    required Paint stroke,
  }) {
    stroke.strokeWidth = 3.5;
    if (mood == OwlMood.cheering && !left) {
      // Wink.
      canvas.drawLine(c.translate(-7, 1), c.translate(7, 1), stroke);
      return;
    }
    if (mood == OwlMood.happy || mood == OwlMood.celebrating) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 7, c.dy + 2)
          ..quadraticBezierTo(c.dx, c.dy - 7, c.dx + 7, c.dy + 2),
        stroke,
      );
      return;
    }
    if (_blinking) {
      canvas.drawLine(c.translate(-7, 0), c.translate(7, 0), stroke);
      return;
    }
    final look = mood == OwlMood.thinking
        ? const Offset(4, -5)
        : const Offset(1, 0);
    fill.color = _ink;
    canvas.drawCircle(c + look, 6, fill);
    fill.color = Colors.white;
    canvas.drawCircle(c + look + const Offset(2, -2), 2, fill);
  }

  /// Bufanda al cuello con una raya y la punta colgando.
  void _scarf(Canvas canvas, OwlOutfit outfit, Paint fill, Paint stroke) {
    fill.color = outfit.scarf;
    canvas.drawPath(
      Path()
        ..moveTo(16, 76)
        ..quadraticBezierTo(50, 90, 84, 76)
        ..lineTo(84, 86)
        ..quadraticBezierTo(50, 100, 16, 86)
        ..close(),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(60, 84, 13, 14),
        const Radius.circular(3),
      ),
      fill,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = outfit.stripe;
    canvas.drawPath(
      Path()
        ..moveTo(17, 81)
        ..quadraticBezierTo(50, 95, 83, 81),
      line,
    );
    fill.color = outfit.stripe;
    canvas.drawRect(const Rect.fromLTWH(60, 89, 13, 2.5), fill);
    canvas.drawRect(const Rect.fromLTWH(60, 94, 13, 2.5), fill);
  }

  /// Birrete con la borla del color de la universidad (o naranja).
  void _cap(Canvas canvas, Paint fill, Paint stroke) {
    fill.color = _ink;
    canvas.drawPath(
      Path()
        ..moveTo(20, 18)
        ..lineTo(50, 5)
        ..lineTo(80, 18)
        ..lineTo(50, 31)
        ..close(),
      fill,
    );
    canvas.drawRect(const Rect.fromLTWH(37, 20, 26, 8), fill);
    final tassel = outfit?.stripe ?? _beak;
    final cord = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = tassel;
    canvas.drawPath(
      Path()
        ..moveTo(50, 18)
        ..lineTo(76, 21)
        ..lineTo(76, 33),
      cord,
    );
    fill.color = tassel;
    canvas.drawCircle(const Offset(76, 35), 3, fill);
  }

  /// Two dots that appear one after the other, like a thought forming.
  void _thoughtDots(Canvas canvas, double s) {
    final phase = (t * 2) % 1;
    final paint = Paint()..color = _thought;
    if (phase > .25) {
      canvas.drawCircle(Offset(86 * s, 22 * s), 3 * s, paint);
    }
    if (phase > .55) {
      canvas.drawCircle(Offset(93 * s, 11 * s), 4.5 * s, paint);
    }
  }

  @override
  bool shouldRepaint(_OwlPainter old) =>
      old.t != t || old.mood != mood || old.outfit != outfit || old.cap != cap;
}

/// Places the owl peeking at the lower right of [child] (a medal, a trophy)
/// so the main element keeps its meaning and the owl adds the emotion.
class OwlCompanion extends StatelessWidget {
  const OwlCompanion({
    super.key,
    required this.child,
    required this.mood,
    this.owlSize = 56,
  });

  final Widget child;
  final OwlMood mood;
  final double owlSize;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned(
        right: -owlSize * .5,
        bottom: -owlSize * .12,
        child: OwlMascot(size: owlSize, mood: mood),
      ),
    ],
  );
}
