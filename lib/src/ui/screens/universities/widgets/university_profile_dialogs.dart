import 'package:flutter/material.dart';

import '../../../../domain/university_profile.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_ui.dart';
import '../../news/news_format.dart';

IconData linkIcon(LinkKind kind) => switch (kind) {
  LinkKind.website => Icons.language_rounded,
  LinkKind.admission => Icons.how_to_reg_outlined,
  LinkKind.facebook => Icons.facebook_rounded,
  LinkKind.instagram => Icons.photo_camera_outlined,
  LinkKind.tiktok => Icons.music_note_outlined,
  LinkKind.youtube => Icons.smart_display_outlined,
  LinkKind.map => Icons.place_outlined,
  LinkKind.other => Icons.link_rounded,
};

/// 702.5 → «702.5»; 702.0 → «702».
String fmtScore(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    ) ??
    false;

Future<Faculty?> showFacultyDialog(
  BuildContext context, {
  required String id,
  Faculty? initial,
}) => showDialog<Faculty>(
  context: context,
  builder: (_) => _FacultyDialog(id: id, initial: initial),
);

class _FacultyDialog extends StatefulWidget {
  const _FacultyDialog({required this.id, this.initial});

  final String id;
  final Faculty? initial;

  @override
  State<_FacultyDialog> createState() => _FacultyDialogState();
}

class _FacultyDialogState extends State<_FacultyDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _acronym = TextEditingController(
    text: widget.initial?.acronym ?? '',
  );
  late bool _active = widget.initial?.active ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _acronym.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Nueva facultad' : 'Editar facultad'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Facultad de Ingeniería Civil, de Sistemas y de Arquitectura',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _acronym,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Sigla', hintText: 'FICSA'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Activa'),
          ),
          if (_error != null) InfoNote(_error!, tone: Tone.error),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final f = Faculty(
            id: widget.id,
            name: _name.text,
            acronym: _acronym.text,
            active: _active,
          );
          final problem = f.validate();
          if (problem != null) return setState(() => _error = problem);
          Navigator.pop(context, f);
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

Future<OfficialLink?> showOfficialLinkDialog(
  BuildContext context, {
  OfficialLink? initial,
}) => showDialog<OfficialLink>(
  context: context,
  builder: (_) => _LinkDialog(initial: initial),
);

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({this.initial});

  final OfficialLink? initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late LinkKind _kind = widget.initial?.kind ?? LinkKind.website;
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enlace oficial'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<LinkKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final k in LinkKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Enlace',
              hintText: 'https://www.unprg.edu.pe',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Texto (opcional)',
              hintText: 'Prospecto 2026-I',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoNote(_error!, tone: Tone.error),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final url = _url.text.trim();
          final uri = Uri.tryParse(url);
          if (uri == null ||
              !(uri.isScheme('https') || uri.isScheme('http')) ||
              uri.host.isEmpty) {
            return setState(() => _error = 'El enlace debe empezar con https://');
          }
          Navigator.pop(
            context,
            OfficialLink(kind: _kind, url: url, label: _label.text),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

Future<AdmissionDate?> showAdmissionDateDialog(BuildContext context) async {
  final label = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Fecha de admisión'),
      content: TextField(
        controller: label,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '¿Qué pasa?',
          hintText: 'Cierre de inscripciones',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, label.text.trim()),
          child: const Text('Elegir fecha'),
        ),
      ],
    ),
  );
  label.dispose();
  if (name == null || name.isEmpty || !context.mounted) return null;
  final at = await pickDateTime(context, initial: DateTime.now());
  return at == null ? null : AdmissionDate(label: name, at: at);
}

Future<CareerDetails?> showCareerDetailsDialog(
  BuildContext context, {
  required String careerName,
  required List<Faculty> faculties,
  required CareerDetails initial,
}) => showDialog<CareerDetails>(
  context: context,
  builder: (_) => _CareerDialog(
    careerName: careerName,
    faculties: faculties,
    initial: initial,
  ),
);

class _CareerDialog extends StatefulWidget {
  const _CareerDialog({
    required this.careerName,
    required this.faculties,
    required this.initial,
  });

  final String careerName;
  final List<Faculty> faculties;
  final CareerDetails initial;

  @override
  State<_CareerDialog> createState() => _CareerDialogState();
}

class _CareerDialogState extends State<_CareerDialog> {
  late String _faculty = widget.faculties.any((f) => f.id == widget.initial.facultyId)
      ? widget.initial.facultyId
      : '';
  late final _vacancies = TextEditingController(
    text: widget.initial.vacancies?.toString() ?? '',
  );
  late final _min = TextEditingController(
    text: widget.initial.minScore == null ? '' : fmtScore(widget.initial.minScore!),
  );
  late final _max = TextEditingController(
    text: widget.initial.maxScore == null ? '' : fmtScore(widget.initial.maxScore!),
  );
  late final _period = TextEditingController(text: widget.initial.scorePeriod);
  late final _duration = TextEditingController(
    text: widget.initial.durationYears?.toString() ?? '',
  );
  late final _degree = TextEditingController(text: widget.initial.degree);
  late final _url = TextEditingController(text: widget.initial.officialUrl);
  late final _description = TextEditingController(text: widget.initial.description);
  String? _error;

  @override
  void dispose() {
    for (final c in [_vacancies, _min, _max, _period, _duration, _degree, _url, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _field(TextEditingController c, String label, {String? hint, double width = 200, bool number = false}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: c,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.careerName),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _faculty,
              decoration: const InputDecoration(labelText: 'Facultad'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Sin facultad')),
                for (final f in widget.faculties)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text(f.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _faculty = v ?? ''),
            ),
            if (widget.faculties.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Primero agrega las facultades en su pestaña.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Último proceso de admisión (fuente oficial)',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _field(_period, 'Proceso', hint: '2026-I', width: 120),
                _field(_vacancies, 'Vacantes', width: 120, number: true),
                _field(_min, 'Puntaje mínimo', width: 150, number: true),
                _field(_max, 'Puntaje máximo', width: 150, number: true),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _field(_duration, 'Duración (años)', width: 150, number: true),
                _field(_degree, 'Título que otorga', hint: 'Ingeniero Civil', width: 300),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Enlace oficial de la carrera (opcional)',
                hintText: 'https://…',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción breve (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              InfoNote(_error!, tone: Tone.error),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final d = CareerDetails(
            facultyId: _faculty,
            vacancies: _int(_vacancies),
            minScore: _num(_min),
            maxScore: _num(_max),
            scorePeriod: _period.text,
            durationYears: _int(_duration),
            degree: _degree.text,
            officialUrl: _url.text,
            description: _description.text,
          );
          final problem = d.validate();
          if (problem != null) return setState(() => _error = problem);
          Navigator.pop(context, d);
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
