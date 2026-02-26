import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/university_entities.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';

import '../../../../ui/theme/app_theme.dart';

class UniversityFormSheet extends ConsumerStatefulWidget {
  const UniversityFormSheet({this.university});
  final UniversityEntity? university;

  @override
  ConsumerState<UniversityFormSheet> createState() =>
      _UniversityFormSheetState();
}

class _UniversityFormSheetState extends ConsumerState<UniversityFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController name;
  late final TextEditingController acronym;
  late final TextEditingController slogan;
  late final TextEditingController address;
  late final TextEditingController urlImage;
  late final TextEditingController location;
  late final TextEditingController ubigeo;
  late final TextEditingController department;
  late final TextEditingController province;
  late final TextEditingController district;

  bool active = true;
  final List<String> links = [];
  final _linkCtrl = TextEditingController();

  // JSON import
  bool _showJson = false;
  final _jsonCtrl = TextEditingController();
  int _jsonValidCount = 0;
  String? _jsonError;

  @override
  void initState() {
    final u = widget.university;

    name = TextEditingController(text: u?.name ?? '');
    acronym = TextEditingController(text: u?.acronym ?? '');
    slogan = TextEditingController(text: u?.slogan ?? '');
    address = TextEditingController(text: u?.address ?? '');
    urlImage = TextEditingController(text: u?.urlImage ?? '');
    location = TextEditingController(text: u?.location ?? '');
    ubigeo = TextEditingController(text: u?.ubigeo ?? '');
    department = TextEditingController(text: u?.department ?? '');
    province = TextEditingController(text: u?.province ?? '');
    district = TextEditingController(text: u?.district ?? '');

    active = u?.active ?? true;
    links.addAll(u?.links ?? const []);

    super.initState();
  }

  @override
  void dispose() {
    name.dispose();
    acronym.dispose();
    slogan.dispose();
    address.dispose();
    urlImage.dispose();
    location.dispose();
    ubigeo.dispose();
    department.dispose();
    province.dispose();
    district.dispose();
    _linkCtrl.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.university != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .62,
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
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            physics: const BouncingScrollPhysics(),
            children: [
              _topBar(isEdit),
              const SizedBox(height: 10),

              // ✅ Compact sections
              _sectionTitle('Datos principales'),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 720; // web/tablet
                  if (!twoCols) {
                    return Column(
                      children: [
                        _tf(name, 'Nombre *', requiredField: true),
                        _row2(
                          _tf(acronym, 'Sigla', requiredField: false),
                          _activePill(),
                        ),
                        _tf(slogan, 'Slogan'),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _tf(name, 'Nombre *', requiredField: true),
                            _tf(slogan, 'Slogan'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _tf(acronym, 'Sigla'),
                            _activePill(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),
              _sectionTitle('Ubicación'),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 720;
                  if (!twoCols) {
                    return Column(
                      children: [
                        _tf(department, 'Departamento'),
                        _tf(province, 'Provincia'),
                        _tf(district, 'Distrito'),
                        _tf(ubigeo, 'Ubigeo'),
                        _tf(location, 'Location'),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _row2(_tf(department, 'Departamento'), _tf(province, 'Provincia')),
                      _row2(_tf(district, 'Distrito'), _tf(ubigeo, 'Ubigeo')),
                      _tf(location, 'Location'),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),
              _sectionTitle('Contacto / Media'),
              const SizedBox(height: 10),
              _tf(address, 'Dirección'),
              _tf(urlImage, 'URL Imagen'),

              const SizedBox(height: 12),
              _linksEditor(),

              const SizedBox(height: 16),
              _primaryActions(isEdit),

              const SizedBox(height: 18),
              _jsonImportSection(isEdit),
            ],
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
            isEdit ? 'Editar universidad' : 'Nueva universidad',
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
          isDense: true, // ✅ compacto
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: (v) {
          if (!requiredField) return null;
          if (v == null || v.trim().isEmpty) return 'Requerido';
          return null;
        },
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _activePill() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: active
                ? const Color(0xFF22C55E).withOpacity(.90)
                : const Color(0xFFEF4444).withOpacity(.90),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              active ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: active,
            onChanged: (v) {
              setState(() => active = v);
              HapticFeedback.selectionClick();
            },
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _linksEditor() {
    return Container(
      decoration: AppTheme.cardDeco(radius: 20, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Links'),
          const SizedBox(height: 10),

          if (links.isEmpty)
            Text(
              'Aún no agregaste links.',
              style: TextStyle(
                color: Colors.white.withOpacity(.60),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links.map((l) {
                return Chip(
                  backgroundColor: Colors.white.withOpacity(.06),
                  shape: StadiumBorder(
                    side: BorderSide(color: Colors.white.withOpacity(.10)),
                  ),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      l,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.90),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  deleteIconColor: Colors.white.withOpacity(.75),
                  onDeleted: () {
                    setState(() => links.remove(l));
                    HapticFeedback.selectionClick();
                  },
                );
              }).toList(),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _linkCtrl,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Agregar link (https://...)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.05),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _miniIconBtn(
                icon: Icons.add_rounded,
                onTap: () {
                  final v = _linkCtrl.text.trim();
                  if (v.isEmpty) return;
                  if (!links.contains(v)) {
                    setState(() => links.add(v));
                    _linkCtrl.clear();
                    HapticFeedback.selectionClick();
                  }
                },
              ),
            ],
          ),
        ],
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
              isEdit ? 'Guardar cambios' : 'Crear universidad',
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

  Widget _miniIconBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.90)),
        ),
      ),
    );
  }

  Widget _jsonImportSection(bool isEdit) {
    if (isEdit) {
      // En edición no tiene sentido el bulk import dentro del mismo sheet.
      return const SizedBox.shrink();
    }

    return Container(
      decoration: AppTheme.cardDeco(radius: 20, color: Colors.white.withOpacity(.03)),
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
              'Activa para pegar una lista de universidades y subirlas a Firestore.',
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Text(
              'Formato esperado: una LISTA JSON de objetos. Ej:\n'
              '[{"idDoc":"uni-1","name":"UNMSM","acronym":"UNMSM","active":true,"links":["https://..."]}]',
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
                // reset estado validación
                setState(() {
                  _jsonValidCount = 0;
                  _jsonError = null;
                });
              },
            ),
            const SizedBox(height: 10),

            if (_jsonError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(.35)),
                ),
                child: Text(
                  _jsonError!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (_jsonValidCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(.35)),
                ),
                child: Text(
                  'JSON válido ✅ Items: $_jsonValidCount',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w900,
                  ),
                ),
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

      // Validación mínima: name
      for (final u in list) {
        final name = (u['name'] ?? '').toString().trim();
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
      await ref.read(universityRepoProvider).bulkUpsertUniversitiesFromJsonList(list);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importadas/actualizadas: ${list.length} ✅'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _jsonError = 'Error importando: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(universityRepoProvider);

    if (widget.university == null) {
      await repo.createUniversity(
        name: name.text,
        acronym: acronym.text,
        active: active,
        slogan: slogan.text,
        address: address.text,
        urlImage: urlImage.text,
        location: location.text,
        ubigeo: ubigeo.text,
        department: department.text,
        province: province.text,
        district: district.text,
        links: links,
      );
    } else {
      await repo.updateUniversity(widget.university!.id, patch: {
        'name': name.text.trim(),
        'acronym': acronym.text.trim(),
        'active': active,
        'slogan': slogan.text.trim(),
        'address': address.text.trim(),
        'urlImage': urlImage.text.trim(),
        'location': location.text.trim(),
        'ubigeo': ubigeo.text.trim(),
        'department': department.text.trim(),
        'province': province.text.trim(),
        'district': district.text.trim(),
        'links': links,
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
