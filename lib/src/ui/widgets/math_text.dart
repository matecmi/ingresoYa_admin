import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Text with inline formulas written between dollar signs, drawn as the
/// student app does (iya-app `math_text.dart`):
/// `Suma de los naturales: $\frac{n(n+1)}{2}$`. Text without `$…$` is drawn
/// as plain text; a formula that does not parse stays as its source.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final _formula = RegExp(r'\$([^$]+)\$');

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    if (!_formula.hasMatch(text)) {
      return Text(text, style: base, textAlign: textAlign);
    }
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _formula.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final source = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            source,
            mathStyle: MathStyle.text,
            textStyle: base.copyWith(fontSize: (base.fontSize ?? 14) * 1.12),
            onErrorFallback: (_) => Text(match.group(0)!, style: base),
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      textAlign: textAlign,
    );
  }
}
