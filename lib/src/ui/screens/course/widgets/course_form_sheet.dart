import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

class CourseFormSheet extends ConsumerStatefulWidget {
  const CourseFormSheet({super.key, this.course});
  final CourseEntity? course;

  @override
  ConsumerState<CourseFormSheet> createState() => _CourseFormSheetState();
}

class _CourseFormSheetState extends ConsumerState<CourseFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController name;
  late final TextEditingController description;

  // JSON import
  bool _showJson = false;
  final _jsonCtrl = TextEditingController();
  int _jsonValidCount = 0;
  String? _jsonError;

  @override
  void initState() {
    final c = widget.course;
    name = TextEditingController(text: c?.name ?? '');
    description = TextEditingController(text: c?.description ?? '');
    super.initState();
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.course != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .90,
      minChildSize: .60,
      maxChildSize: .97,
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
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              physics: const BouncingScrollPhysics(),
              children: [
                _topBar(isEdit),
                const SizedBox(height: 10),

                _sectionTitle('Datos del curso'),
                const SizedBox(height: 10),

                _tf(name, 'Nombre *', requiredField: true),
                _tf(description, 'Descripción'),

                const SizedBox(height: 14),
                _primaryActions(isEdit),

                const SizedBox(height: 18),
                _jsonImportSection(isEdit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isEdit ? 'Editar curso' : 'Nuevo curso',
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

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: TextStyle(
        color: Colors.white.withOpacity(.92),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.70)),
          filled: true,
          fillColor: Colors.white.withOpacity(.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: (v) {
          if (!requiredField) return null;
          if (v == null || v.trim().isEmpty) return 'Requerido';
          return null;
        },
      ),
    );
  }

  Widget _primaryActions(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(
              isEdit ? 'Guardar cambios' : 'Crear curso',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- JSON IMPORT ----------------

  Widget _jsonImportSection(bool isEdit) {
    if (isEdit) return const SizedBox.shrink();

    return Container(
      decoration: AppTheme.cardDeco(
        radius: 20,
        color: Colors.white.withOpacity(.03),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Importar por JSON')),
              Switch(
                value: _showJson,
                onChanged: (v) => setState(() => _showJson = v),
                activeColor: AppTheme.accent,
              ),
            ],
          ),
          if (!_showJson)
            Text(
              'Activa para pegar una lista de cursos y subirlos a Firestore.',
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Text(
              'Formato esperado: LISTA JSON\n'
              '[{"idDoc":"course-1","name":"Álgebra","description":"..."}]',
              style: TextStyle(
                color: Colors.white.withOpacity(.60),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _jsonCtrl,
              minLines: 7,
              maxLines: 12,
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Pega aquí el JSON…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
                filled: true,
                fillColor: Colors.white.withOpacity(.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                ),
              ),
              onChanged: (_) {
                setState(() {
                  _jsonValidCount = 0;
                  _jsonError = null;
                });
              },
            ),
            const SizedBox(height: 10),
            if (_jsonError != null)
              _StateBox(
                tone: _StateTone.bad,
                text: _jsonError!,
              )
            else if (_jsonValidCount > 0)
              _StateBox(
                tone: _StateTone.good,
                text: 'JSON válido ✅ Items: $_jsonValidCount',
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _validateJson,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Validar JSON',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(.10),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: BorderSide(color: Colors.white.withOpacity(.14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _jsonValidCount > 0 ? _importJson : null,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text(
                      'Importar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseJsonListOrThrow(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw Exception('El JSON debe ser una LISTA []');
    final list = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) throw Exception('Cada item debe ser un objeto {}');
      list.add(Map<String, dynamic>.from(item as Map));
    }
    return list;
  }

  void _validateJson() {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _jsonValidCount = 0;
        _jsonError = 'Pega un JSON primero.';
      });
      return;
    }

    try {
      final list = _parseJsonListOrThrow(raw);
      for (final c in list) {
        final name = (c['name'] ?? '').toString().trim();
        if (name.isEmpty) throw Exception('Un item no tiene "name".');
      }
      setState(() {
        _jsonValidCount = list.length;
        _jsonError = null;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      setState(() {
        _jsonValidCount = 0;
        _jsonError = 'JSON inválido: $e';
      });
    }
  }

  Future<void> _importJson() async {
    try {
      final list = _parseJsonListOrThrow(_jsonCtrl.text.trim());
      await ref.read(courseRepoProvider).bulkUpsertCoursesFromJsonList(list);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importados/actualizados: ${list.length} ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _jsonError = 'Error importando: $e');
    }
  }

  // ---------------- SAVE ----------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(courseRepoProvider);

    if (widget.course == null) {
      await repo.createCourse(
        name: name.text,
        description: description.text,
      );
    } else {
      await repo.updateCourse(widget.course!.id, patch: {
        'name': name.text.trim(),
        'description': description.text.trim(),
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}

enum _StateTone { good, bad }

class _StateBox extends StatelessWidget {
  const _StateBox({required this.tone, required this.text});
  final _StateTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _StateTone.good
        ? const Color(0xFF22C55E).withOpacity(.12)
        : const Color(0xFFEF4444).withOpacity(.12);

    final border = tone == _StateTone.good
        ? const Color(0xFF22C55E).withOpacity(.35)
        : const Color(0xFFEF4444).withOpacity(.35);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
