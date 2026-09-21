import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../shared/question_contract/question_contract.dart';
import '../../../domain/editor_document.dart';
import '../exam_question.dart';

Widget formulaPreview(String latex) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Math.tex(
    latex,
    textStyle: const TextStyle(fontSize: 18),
    onErrorFallback: (_) => const Text(
      'Revisa la fórmula: comprueba las llaves y los comandos LaTeX.',
      style: TextStyle(color: Colors.red),
    ),
  ),
);

class ContentPreview extends StatelessWidget {
  const ContentPreview({super.key, required this.document});
  final EditorDocument document;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: document.content.blocks
        .map(
          (block) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: switch (block) {
              TextBlock b => _paragraph([
                InlineSpanData.fromJson({'type': 'text', 'text': b.text}),
              ]),
              ParagraphBlock b => _paragraph(b.spans),
              FormulaBlock b => formulaPreview(b.latex),
              ImageBlock b => FractionallySizedBox(
                widthFactor: document.imageSizes[b.id] ?? 1,
                child: Column(
                  children: [
                    if (b.url != null)
                      _image(b.url!, b.altText)
                    else
                      FutureBuilder<String>(
                        future: FirebaseStorage.instance
                            .ref(b.storagePath!)
                            .getDownloadURL(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? _image(snapshot.data!, b.altText)
                            : Text(
                                snapshot.hasError
                                    ? 'No se pudo cargar la imagen'
                                    : 'Cargando imagen…',
                              ),
                      ),
                    if (b.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          b.caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              LegacyBlock b => ExamQuestion(raw: b.raw, useCard: false),
            },
          ),
        )
        .toList(),
  );

  Widget _image(String url, String alt) => Image.network(
    url,
    semanticLabel: alt,
    fit: BoxFit.contain,
    errorBuilder: (_, error, stack) => Text('Imagen no disponible: $alt'),
  );

  Widget _paragraph(List<InlineSpanData> spans) => Text.rich(
    TextSpan(
      children: spans.expand((span) {
        final style = TextStyle(
          fontWeight: span.marks.contains('bold')
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle: span.marks.contains('italic')
              ? FontStyle.italic
              : FontStyle.normal,
        );
        if (span.type == 'formula') {
          return <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                span.value,
                onErrorFallback: (_) => const Text('⚠ Fórmula inválida'),
              ),
            ),
          ];
        }
        // Plain-text blocks also support the documented inline \(...\) syntax.
        final parts = <InlineSpan>[];
        var start = 0;
        for (final match in RegExp(
          r'\\\((.*?)\\\)',
          dotAll: true,
        ).allMatches(span.value)) {
          parts.add(
            TextSpan(
              text: span.value.substring(start, match.start),
              style: style,
            ),
          );
          parts.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                match.group(1)!,
                onErrorFallback: (_) => const Text('⚠ Fórmula inválida'),
              ),
            ),
          );
          start = match.end;
        }
        parts.add(TextSpan(text: span.value.substring(start), style: style));
        return parts;
      }).toList(),
    ),
    style: const TextStyle(fontSize: 16, height: 1.6),
  );
}
