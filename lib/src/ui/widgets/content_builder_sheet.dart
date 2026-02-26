import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/exam_question.dart';

import 'content_builder_models.dart';


class ContentBuilderSheet extends StatefulWidget {
  const ContentBuilderSheet({
    super.key,
    this.initialRaw,
    this.title = 'Constructor de contenido',
  });

  final String? initialRaw;
  final String title;

  @override
  State<ContentBuilderSheet> createState() => _ContentBuilderSheetState();
}

class _ContentBuilderSheetState extends State<ContentBuilderSheet> {
  late List<ContentLine> lines;

  /// ✅ controllers cacheados por "segment key" (id estable)
  final Map<int, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    lines = _parseRawToLines(widget.initialRaw) ??
        [
          ContentLine(
            segments: [ContentSegment(type: ContentSegType.text, content: '')],
          )
        ];

    // asegura controllers iniciales
    _ensureControllers();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    super.dispose();
  }

  /// raw actual
  String get raw => buildRawFromLines(lines);

  /// 🔑 genera key estable por segmento (no depende de hashCode mutable)
  int _segKey(ContentSegment seg) => identityHashCode(seg);

  void _ensureControllers() {
    // crea controllers para todos los segmentos existentes
    for (final line in lines) {
      for (final seg in line.segments) {
        final k = _segKey(seg);
        _ctrls.putIfAbsent(k, () => TextEditingController(text: seg.content));
      }
    }

    // limpia controllers huérfanos
    final aliveKeys = <int>{};
    for (final line in lines) {
      for (final seg in line.segments) {
        aliveKeys.add(_segKey(seg));
      }
    }

    final toRemove = _ctrls.keys.where((k) => !aliveKeys.contains(k)).toList();
    for (final k in toRemove) {
      _ctrls[k]?.dispose();
      _ctrls.remove(k);
    }
  }

  TextEditingController _controllerFor(ContentSegment seg) {
    final k = _segKey(seg);
    return _ctrls.putIfAbsent(k, () => TextEditingController(text: seg.content));
  }

  void _touch() {
    _ensureControllers();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .94,
      minChildSize: .62,
      maxChildSize: .99,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.26),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final twoCols = c.maxWidth >= 980;

              if (!twoCols) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _topBar(context),
                    const SizedBox(height: 10),
                    _builderPanel(),
                    const SizedBox(height: 12),
                    _previewPanel(),
                    const SizedBox(height: 14),
                    _bottomActions(context),
                  ],
                );
              }

              // ✅ 2 columnas (editor + preview)
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _topBar(context),
                        const SizedBox(height: 10),
                        _builderPanel(),
                        const SizedBox(height: 14),
                        _bottomActions(context),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 14, 16),
                      child: _previewPanel(),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.85)),
        ),
      ],
    );
  }

  Widget _builderPanel() {
    return Container(
      decoration: AppTheme.cardDeco(
        radius: 22,
        color: Colors.white.withOpacity(.03),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(
            title: 'Estructura',
            subtitle: 'Líneas ( [%] ) • Bloques en misma línea ( [#] ) • Tipo ( [@] )',
            right: Row(
              children: [
                _miniBtn(
                  icon: Icons.add_rounded,
                  label: 'Línea',
                  onTap: () {
                    setState(() {
                      lines.add(
                        ContentLine(
                          segments: [ContentSegment(type: ContentSegType.text, content: '')],
                        ),
                      );
                    });
                    _ensureControllers();
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(width: 8),
                _miniBtn(
                  icon: Icons.cleaning_services_rounded,
                  label: 'Limpiar',
                  onTap: () {
                    setState(() {
                      lines = [
                        ContentLine(
                          segments: [ContentSegment(type: ContentSegType.text, content: '')],
                        ),
                      ];
                    });
                    _ensureControllers();
                    HapticFeedback.selectionClick();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          ...List.generate(lines.length, (i) {
            final line = lines[i];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LineEditor(
                index: i,
                line: line,
                controllerFor: _controllerFor,
                onChanged: _touch,
                onAddSegment: () {
                  setState(() {
                    line.segments.add(ContentSegment(type: ContentSegType.text, content: ''));
                  });
                  _ensureControllers();
                  HapticFeedback.selectionClick();
                },
                onRemoveLine: () {
                  setState(() {
                    if (lines.length == 1) {
                      lines = [
                        ContentLine(
                          segments: [ContentSegment(type: ContentSegType.text, content: '')],
                        )
                      ];
                    } else {
                      // limpia controllers de los segmentos de esa línea
                      for (final seg in line.segments) {
                        final k = _segKey(seg);
                        _ctrls[k]?.dispose();
                        _ctrls.remove(k);
                      }
                      lines.removeAt(i);
                    }
                  });
                  _ensureControllers();
                  HapticFeedback.selectionClick();
                },
                onMoveUp: i == 0
                    ? null
                    : () {
                        setState(() {
                          final tmp = lines[i - 1];
                          lines[i - 1] = lines[i];
                          lines[i] = tmp;
                        });
                        HapticFeedback.selectionClick();
                      },
                onMoveDown: i == lines.length - 1
                    ? null
                    : () {
                        setState(() {
                          final tmp = lines[i + 1];
                          lines[i + 1] = lines[i];
                          lines[i] = tmp;
                        });
                        HapticFeedback.selectionClick();
                      },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _previewPanel() {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ✅ shrink-wrap
        children: [
          _titleRow(
            title: 'Vista previa',
            subtitle: 'Así lo verá el usuario en la app',
            right: _miniBtn(
              icon: Icons.copy_rounded,
              label: 'Copiar raw',
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: raw));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Raw copiado ✅')),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ✅ sin Expanded (evita unbounded)
          SizedBox(
            height: 320,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ExamQuestion(raw: raw, useCard: true),
            ),
          ),

          const SizedBox(height: 10),
          _rawBox(raw),
        ],
      ),
    );
  }

  Widget _rawBox(String raw) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Text(
        raw.isEmpty ? '(vacío)' : raw,
        style: TextStyle(
          color: Colors.white.withOpacity(.86),
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          height: 1.25,
        ),
      ),
    );
  }

  Widget _bottomActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, raw),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Usar este contenido',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleRow({
    required String title,
    required String subtitle,
    required Widget right,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(.60),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        right,
      ],
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- PARSER (raw -> lines/segments) ----------------

  List<ContentLine>? _parseRawToLines(String? raw) {
    final r = raw?.trim();
    if (r == null || r.isEmpty) return null;

    final lineStrings = r.split('[%]');
    final out = <ContentLine>[];

    for (final ls in lineStrings) {
      final segStrings = ls.split('[#]');
      final segs = <ContentSegment>[];

      for (final ss in segStrings) {
        final clean = ss.trim();
        if (clean.isEmpty) continue;

        final parts = clean.split('[@]');
        if (parts.length < 2) {
          segs.add(ContentSegment(type: ContentSegType.text, content: clean));
          continue;
        }

        final content = parts[0].trim();
        final tag = parts[1].trim();
        segs.add(
          ContentSegment(
            type: ContentSegTypeX.fromTag(tag),
            content: content,
          ),
        );
      }

      if (segs.isEmpty) {
        segs.add(ContentSegment(type: ContentSegType.text, content: ''));
      }
      out.add(ContentLine(segments: segs));
    }

    return out.isEmpty ? null : out;
  }
}

/// ---------------- LINE EDITOR ----------------

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.index,
    required this.line,
    required this.controllerFor,
    required this.onChanged,
    required this.onAddSegment,
    required this.onRemoveLine,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final ContentLine line;
  final TextEditingController Function(ContentSegment) controllerFor;

  final VoidCallback onChanged;
  final VoidCallback onAddSegment;
  final VoidCallback onRemoveLine;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.02)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(.10)),
                ),
                child: Text(
                  'Línea ${index + 1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.90),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              _miniIconBtn(icon: Icons.arrow_upward_rounded, onTap: onMoveUp),
              const SizedBox(width: 8),
              _miniIconBtn(icon: Icons.arrow_downward_rounded, onTap: onMoveDown),
              const SizedBox(width: 8),
              _miniIconBtn(icon: Icons.delete_outline_rounded, onTap: onRemoveLine),
            ],
          ),
          const SizedBox(height: 10),

          // segments
          ...List.generate(line.segments.length, (j) {
            final seg = line.segments[j];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SegmentEditor(
                index: j,
                seg: seg,
                ctrl: controllerFor(seg),
                onChanged: onChanged,
                onRemove: () {
                  line.segments.removeAt(j);
                  if (line.segments.isEmpty) {
                    line.segments.add(ContentSegment(type: ContentSegType.text, content: ''));
                  }
                  HapticFeedback.selectionClick();
                  onChanged();
                },
              ),
            );
          }),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddSegment,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Agregar bloque en esta línea',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(.10),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(color: Colors.white.withOpacity(.14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniIconBtn({required IconData icon, required VoidCallback? onTap}) {
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: Material(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.90), size: 18),
          ),
        ),
      ),
    );
  }
}

class _SegmentEditor extends StatelessWidget {
  const _SegmentEditor({
    required this.index,
    required this.seg,
    required this.ctrl,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ContentSegment seg;
  final TextEditingController ctrl;

  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // ✅ asegura que el controller refleje el modelo si viene cambiado por parse/reset
    if (ctrl.text != seg.content) {
      ctrl.text = seg.content;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ContentSegType>(
                  value: seg.type,
                  items: ContentSegType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t.label,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.92),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    seg.type = v;
                    HapticFeedback.selectionClick();
                    onChanged();
                  },
                  dropdownColor: AppTheme.card,
                  decoration: InputDecoration(
                    labelText: 'Tipo (bloque ${index + 1})',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(.70)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.05),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(.10)),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white.withOpacity(.88),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            onChanged: (v) {
              seg.content = v;
              onChanged();
            },
            minLines: seg.type == ContentSegType.text ? 2 : 3,
            maxLines: seg.type == ContentSegType.text ? 6 : 10,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontWeight: FontWeight.w700,
              fontFamily: seg.type == ContentSegType.math ? 'monospace' : null,
            ),
            decoration: InputDecoration(
              hintText: seg.type == ContentSegType.text
                  ? 'Escribe el texto…'
                  : seg.type == ContentSegType.math
                      ? r'Escribe LaTeX (ej: \frac{a}{b})'
                      : 'Pega URL de imagen…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
              filled: true,
              fillColor: Colors.white.withOpacity(.05),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}