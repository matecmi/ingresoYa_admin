import 'dart:convert';
import '../../shared/question_contract/question_contract.dart';

/// Editorial envelope. Content itself uses the shared v2 wire contract.
class EditorDocument {
  EditorDocument(this.content, [Map<String, double> sizes = const {}])
    : imageSizes = Map.unmodifiable(sizes);
  final QuestionContent content;
  final Map<String, double> imageSizes;

  bool get hasContent => content.blocks.any(
    (block) => switch (block) {
      TextBlock b => b.text.trim().isNotEmpty,
      ParagraphBlock b => b.spans.any((span) => span.value.trim().isNotEmpty),
      FormulaBlock b => b.latex.trim().isNotEmpty,
      LegacyBlock b => b.raw.trim().isNotEmpty,
      ImageBlock _ => true,
    },
  );

  factory EditorDocument.read(Map<String, dynamic> data, String legacy) {
    return EditorDocument(
      data['content'] == null
          ? QuestionContent.fromJson(
              legacy.isEmpty
                  ? []
                  : [
                      {'id': 'legacy-1', 'type': 'legacy', 'raw': legacy},
                    ],
            )
          : QuestionContent.fromJson(data['content']),
      (data['contentPresentation'] as Map? ?? {}).map(
        (key, value) =>
            MapEntry(key.toString(), (value as num).toDouble().clamp(.25, 1)),
      ),
    );
  }

  Map<String, dynamic> toFields() => {
    'contentSchemaVersion': 2,
    'content': content.toJson(),
    'contentPresentation': imageSizes,
  };

  /// Compatibility projection for clients still using the old renderer.
  /// Rich typography is retained in content, but flattened in this projection.
  String get legacy => content.blocks
      .map(
        (block) => switch (block) {
          LegacyBlock b => b.raw,
          TextBlock b => '${b.text}[@]TEXT',
          ParagraphBlock b =>
            b.spans
                .map(
                  (s) =>
                      '${s.value}[@]${s.type == 'formula' ? 'MATH' : 'TEXT'}',
                )
                .join('[#]'),
          FormulaBlock b => '${b.latex}[@]MATH',
          ImageBlock b =>
            b.url == null ? '${b.altText}[@]TEXT' : '${b.url}[@]URL',
        },
      )
      .join('[%]');
}

/// Bounded snapshots include presentation and content; IDs survive all moves.
class EditorHistory {
  final List<String> _undo = [];
  void remember(EditorDocument document) {
    _undo.add(jsonEncode(document.toFields()));
    if (_undo.length > 50) _undo.removeAt(0);
  }

  bool get canUndo => _undo.isNotEmpty;
  EditorDocument undo() => EditorDocument.read(
    Map<String, dynamic>.from(jsonDecode(_undo.removeLast())),
    '',
  );
}
