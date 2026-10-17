// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.
// Copia fiel de iya-app/lib/features/questions/presentation/widgets/question_content_renderer.dart (commit 783bb74) para que la vista
// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.
// ignore_for_file: type=lint, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';

/// Resolves a Storage-backed image without coupling the renderer to Firebase.
///
/// For regular HTTP(S) images the renderer uses [ImageBlock.url] directly.
/// Callers that render [ImageBlock.storagePath] provide this resolver with the
/// app's authenticated image provider.
typedef QuestionImageProviderResolver =
    ImageProvider<Object>? Function(ImageBlock image);

/// Renders the public v2 content contract in statements, alternatives and
/// post-grading explanations. It deliberately treats every remote value as
/// text, LaTex or an image source; it never evaluates remote HTML.
class QuestionContentRenderer extends StatelessWidget {
  const QuestionContentRenderer({
    super.key,
    required this.content,
    this.imageProviderResolver,
    this.textStyle,
    this.blockSpacing = 12,
  });

  final QuestionContent content;
  final QuestionImageProviderResolver? imageProviderResolver;
  final TextStyle? textStyle;
  final double blockSpacing;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.bodyLarge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < content.blocks.length; index++) ...[
          KeyedSubtree(
            key: ValueKey('question-content-${content.blocks[index].id}'),
            child: _ContentBlockRenderer(
              block: content.blocks[index],
              textStyle: style,
              imageProviderResolver: imageProviderResolver,
            ),
          ),
          if (index < content.blocks.length - 1) SizedBox(height: blockSpacing),
        ],
      ],
    );
  }
}

/// Semantic wrapper for a question statement.
class QuestionStatementRenderer extends StatelessWidget {
  const QuestionStatementRenderer({
    super.key,
    required this.question,
    this.imageProviderResolver,
    this.textStyle,
  });

  final QuestionDocument question;
  final QuestionImageProviderResolver? imageProviderResolver;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Enunciado de la pregunta',
    child: QuestionContentRenderer(
      content: question.content,
      imageProviderResolver: imageProviderResolver,
      textStyle: textStyle,
    ),
  );
}

/// Semantic wrapper for a public alternative. It has no correctness state.
class QuestionAlternativeRenderer extends StatelessWidget {
  const QuestionAlternativeRenderer({
    super.key,
    required this.alternative,
    this.imageProviderResolver,
    this.textStyle,
  });

  final QuestionAlternative alternative;
  final QuestionImageProviderResolver? imageProviderResolver;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Alternativa ${alternative.label}',
    child: QuestionContentRenderer(
      content: alternative.content,
      imageProviderResolver: imageProviderResolver,
      textStyle: textStyle,
    ),
  );
}

/// Renders an explanation only after a server result has authorized showing it.
class QuestionExplanationRenderer extends StatelessWidget {
  const QuestionExplanationRenderer({
    super.key,
    required this.explanation,
    this.imageProviderResolver,
    this.textStyle,
  });

  final QuestionContent explanation;
  final QuestionImageProviderResolver? imageProviderResolver;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Explicación de la respuesta',
    child: QuestionContentRenderer(
      content: explanation,
      imageProviderResolver: imageProviderResolver,
      textStyle: textStyle,
    ),
  );
}

class _ContentBlockRenderer extends StatelessWidget {
  const _ContentBlockRenderer({
    required this.block,
    required this.textStyle,
    required this.imageProviderResolver,
  });

  final ContentBlock block;
  final TextStyle textStyle;
  final QuestionImageProviderResolver? imageProviderResolver;

  @override
  Widget build(BuildContext context) => switch (block) {
    TextBlock(:final text) => Text(text, style: textStyle, softWrap: true),
    ParagraphBlock(:final spans) => _ParagraphRenderer(
      spans: spans,
      textStyle: textStyle,
    ),
    FormulaBlock(:final latex) => _BlockFormula(
      latex: latex,
      textStyle: textStyle,
    ),
    ImageBlock() => _QuestionImage(
      image: block as ImageBlock,
      imageProviderResolver: imageProviderResolver,
      textStyle: textStyle,
    ),
    LegacyBlock(:final raw) => _LegacyRenderer(
      raw: raw,
      textStyle: textStyle,
      imageProviderResolver: imageProviderResolver,
    ),
  };
}

class _ParagraphRenderer extends StatelessWidget {
  const _ParagraphRenderer({required this.spans, required this.textStyle});

  final List<InlineSpanData> spans;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: textStyle,
      children: [
        for (final span in spans)
          if (span.type == 'text')
            TextSpan(
              text: span.value,
              style: _markedStyle(textStyle, span.marks),
            )
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _InlineFormula(latex: span.value, textStyle: textStyle),
              ),
            ),
      ],
    ),
    softWrap: true,
  );
}

TextStyle _markedStyle(TextStyle source, List<String> marks) => source.copyWith(
  fontWeight: marks.contains('bold') ? FontWeight.bold : source.fontWeight,
  fontStyle: marks.contains('italic') ? FontStyle.italic : source.fontStyle,
);

class _InlineFormula extends StatelessWidget {
  const _InlineFormula({required this.latex, required this.textStyle});

  final String latex;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fórmula: ${latex}',
    child: ExcludeSemantics(
      child: Math.tex(
        latex,
        mathStyle: MathStyle.text,
        textStyle: textStyle,
        onErrorFallback: (_) => _FormulaFallback(textStyle: textStyle),
      ),
    ),
  );
}

class _BlockFormula extends StatelessWidget {
  const _BlockFormula({required this.latex, required this.textStyle});

  final String latex;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fórmula: ${latex}',
    child: ExcludeSemantics(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          latex,
          mathStyle: MathStyle.display,
          textStyle: textStyle,
          onErrorFallback: (_) => _FormulaFallback(textStyle: textStyle),
        ),
      ),
    ),
  );
}

class _FormulaFallback extends StatelessWidget {
  const _FormulaFallback({required this.textStyle});

  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Text(
    'Fórmula no disponible',
    style: textStyle.copyWith(fontStyle: FontStyle.italic),
  );
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({
    required this.image,
    required this.imageProviderResolver,
    required this.textStyle,
  });

  final ImageBlock image;
  final QuestionImageProviderResolver? imageProviderResolver;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final provider = imageProviderResolver != null
        ? imageProviderResolver!(image)
        : (image.url == null ? null : NetworkImage(image.url!));
    final label = image.altText.isNotEmpty
        ? image.altText
        : image.caption.isNotEmpty
        ? image.caption
        : 'Imagen de la pregunta';
    final visual = provider == null
        ? _ImageFallback(textStyle: textStyle)
        : Image(
            image: provider,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _ImageFallback(textStyle: textStyle),
          );
    final proportioned = image.width == null
        ? visual
        : AspectRatio(aspectRatio: image.width! / image.height!, child: visual);
    return Semantics(
      image: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: proportioned,
                ),
              ),
            ),
          ),
          if (image.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(image.caption, style: textStyle.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.textStyle});

  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Imagen no disponible',
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text('Imagen no disponible', style: textStyle),
        ],
      ),
    ),
  );
}

class _LegacyRenderer extends StatelessWidget {
  const _LegacyRenderer({
    required this.raw,
    required this.textStyle,
    required this.imageProviderResolver,
  });

  final String raw;
  final TextStyle textStyle;
  final QuestionImageProviderResolver? imageProviderResolver;

  @override
  Widget build(BuildContext context) {
    final lines = raw.split('[%]');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) ...[
          _LegacyLine(
            raw: lines[lineIndex],
            textStyle: textStyle,
            imageProviderResolver: imageProviderResolver,
          ),
          if (lineIndex < lines.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LegacyLine extends StatelessWidget {
  const _LegacyLine({
    required this.raw,
    required this.textStyle,
    required this.imageProviderResolver,
  });

  final String raw;
  final TextStyle textStyle;
  final QuestionImageProviderResolver? imageProviderResolver;

  @override
  Widget build(BuildContext context) {
    final segments = raw.split('[#]').map(_LegacySegment.parse).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          switch (segment.type) {
            'MATH' => _BlockFormula(latex: segment.value, textStyle: textStyle),
            'URL' => _legacyImage(segment.value),
            _ => Text(segment.value, style: textStyle, softWrap: true),
          },
      ],
    );
  }

  Widget _legacyImage(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return Text(value, style: textStyle, softWrap: true);
    }
    return _QuestionImage(
      image: ImageBlock.fromJson({
        'id': 'legacy-image-$value',
        'type': 'image',
        'url': value,
        'altText': '',
      }),
      imageProviderResolver: imageProviderResolver,
      textStyle: textStyle,
    );
  }
}

class _LegacySegment {
  const _LegacySegment(this.value, this.type);

  factory _LegacySegment.parse(String raw) {
    final marker = raw.lastIndexOf('[@]');
    if (marker < 0) return _LegacySegment(raw, 'TEXT');
    return _LegacySegment(
      raw.substring(0, marker),
      raw.substring(marker + 3).trim().toUpperCase(),
    );
  }

  final String value;
  final String type;
}
