import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class ExamQuestion extends StatelessWidget {
  final String raw;

  /// Si quieres, puedes activar esto cuando lo pongas dentro de una card
  final bool useCard;

  const ExamQuestion({
    super.key,
    required this.raw,
    this.useCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final lines = raw.split('[%]');

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lines.length; i++) ...[
          _LineBlock(line: lines[i]),
          if (i != lines.length - 1) const SizedBox(height: 10), // 👈 orden visual
        ],
      ],
    );

    if (!useCard) return content;

    // Si quieres que el enunciado sea una “card” elegante
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _LineBlock extends StatelessWidget {
  const _LineBlock({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final parts = line.split('[#]');

    final widgets = <Widget>[];

    for (final part in parts) {
      final clean = part.trim();
      if (clean.isEmpty) continue;

      final segs = clean.split('[@]');
      if (segs.length < 2) {
        widgets.add(_TextSpan(clean));
        continue;
      }

      final content = segs[0].trim();
      final type = segs[1].trim().toUpperCase();

      switch (type) {
        case "TEXT":
          widgets.add(_TextSpan(content));
          break;

case "MATH":
  widgets.add(
    LayoutBuilder(
      builder: (context, c) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: c.maxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Math.tex(
              content,
              textStyle: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    ),
  );
  break;



        case "URL":
          widgets.add(_ImageSpan(content));
          break;

        default:
          widgets.add(_TextSpan(content));
      }
    }

    // 👇 Si hay varios bloques en la misma línea, usamos Wrap “bonito”
    if (widgets.length > 1) {
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: widgets,
      );
    }

    return widgets.isNotEmpty ? widgets.first : const SizedBox.shrink();
  }
}

class _TextSpan extends StatelessWidget {
  const _TextSpan(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // Tip: usa opacidad suave para verse premium en dark
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.5,
        height: 1.35,
        color: Colors.white.withOpacity(.86),
        fontWeight: FontWeight.w700,
      ),
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }
}

class _ImageSpan extends StatelessWidget {
  const _ImageSpan(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    // ✅ Imagen con radius/borde para que no “rompa” el diseño
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            "Error cargando imagen",
            style: TextStyle(color: Colors.white.withOpacity(.70)),
          ),
        ),
      ),
    );
  }
}
