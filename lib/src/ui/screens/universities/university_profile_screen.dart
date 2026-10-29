import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/staff.dart';
import '../../../domain/university_profile.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import '../news/news_format.dart';
import 'widgets/exam_areas_card.dart';
import 'widgets/university_identity_card.dart';
import 'widgets/university_next_exam_card.dart';
import 'widgets/university_profile_dialogs.dart';

final _dataProvider = StreamProvider.autoDispose
    .family<UniversityStudentData, String>(
      (ref, id) => ref.watch(universityRepoProvider).watchStudentData(id),
    );

/// «Ficha para el alumno» de una universidad (`/universities/:id/ficha`):
/// lo que verá en la sección Universidades de la app. Los datos se cargan
/// desde fuentes oficiales; la ficha guarda su fuente y fecha de revisión.
class UniversityProfileScreen extends ConsumerStatefulWidget {
  const UniversityProfileScreen({super.key, required this.universityId});

  final String universityId;

  @override
  ConsumerState<UniversityProfileScreen> createState() =>
      _UniversityProfileScreenState();
}

class _UniversityProfileScreenState
    extends ConsumerState<UniversityProfileScreen> {
  UniversityProfile? _draft;
  UniversityProfile? _saved;
  bool _saving = false;
  final _summary = TextEditingController();
  final _founded = TextEditingController();
  final _admissionInfo = TextEditingController();
  final _source = TextEditingController();

  @override
  void dispose() {
    for (final c in [_summary, _founded, _admissionInfo, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync(UniversityProfile p) {
    if (_saved != null && _draft != null && _dirty) return;
    _saved = p;
    _draft = p;
    _summary.text = p.summary;
    _founded.text = p.foundedYear?.toString() ?? '';
    _admissionInfo.text = p.admissionInfo;
    _source.text = p.source;
  }

  UniversityProfile get _current => _draft!.copyWith(
    summary: _summary.text,
    foundedYear: () => int.tryParse(_founded.text.trim()),
    admissionInfo: _admissionInfo.text,
    source: _source.text,
  );

  bool get _dirty =>
      _draft != null &&
      _saved != null &&
      _current.toMap().toString() != _saved!.toMap().toString();

  void _set(UniversityProfile Function(UniversityProfile p) change) =>
      setState(() => _draft = change(_current));

  Future<void> _save() async {
    final profile = _current;
    final problem = profile.validate();
    if (problem != null) {
      _snack(problem);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(universityRepoProvider)
          .saveProfile(widget.universityId, profile);
      _saved = profile;
      _draft = profile;
      _snack(
        profile.visible
            ? 'Ficha guardada: los alumnos ya la ven.'
            : 'Ficha guardada (todavía oculta para los alumnos).',
      );
    } catch (e) {
      _snack(e is StateError ? e.message : 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_dataProvider(widget.universityId));
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.universities, StaffAction.edit);
    final data = async.value;
    if (data == null) {
      return Center(
        child: async.hasError
            ? const Text('No se pudo cargar la universidad.')
            : const CircularProgressIndicator(),
      );
    }
    _sync(data.profile);
    final missing = data.missing();
    final profile = _current;

    return DefaultTabController(
      length: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
            child: AdminPageHeader(
              crumbs: const ['Contenido', 'Universidades'],
              title:
                  'Ficha para el alumno · ${data.acronym.isEmpty ? data.name : data.acronym}',
              subtitle: missing.isEmpty
                  ? 'Completa. Lo que pongas aquí lo ve el alumno en la sección '
                        'Universidades de la app.'
                  : 'Falta: ${missing.join(', ')}. Usa solo datos de fuentes '
                        'oficiales (prospecto, web de admisión).',
              actions: [
                OutlinedButton(
                  onPressed: () => context.go('/universities'),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
            child: Material(
              color: profile.visible ? AppTheme.successSoft : AppTheme.subtle,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: SwitchListTile(
                value: profile.visible,
                onChanged: canEdit
                    ? (v) => _set((p) => p.copyWith(visible: v))
                    : null,
                title: const Text('Mostrar la ficha a los alumnos'),
                subtitle: Text(
                  profile.visible
                      ? 'Visible en la app. Pide indicar la fuente de los datos.'
                      : 'Oculta: en la app solo aparece el nombre en el directorio.',
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Resumen y enlaces'),
                Tab(text: 'Facultades'),
                Tab(text: 'Carreras'),
                Tab(text: 'Admisión'),
                Tab(text: 'Áreas del examen'),
                Tab(text: 'Identidad'),
              ],
            ),
          ),
          Expanded(
            child: AbsorbPointer(
              absorbing: !canEdit,
              child: TabBarView(
                children: [
                  _page([_summaryCard(profile), _linksCard(profile), _sourceCard(profile)]),
                  _page([_facultiesCard(data)]),
                  _page([_careersCard(data)]),
                  _page([
                    UniversityNextExamCard.raw(
                      universityId: data.universityId,
                      acronym: data.acronym,
                      nextExam: data.nextExam,
                    ),
                    _admissionCard(profile),
                  ]),
                  _page([ExamAreasCard(data: data)]),
                  _page([
                    UniversityIdentityCard(
                      key: ValueKey('identity-${data.universityId}'),
                      data: data,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          if (canEdit)
            Container(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dirty
                          ? 'Tienes cambios sin guardar en el resumen, los enlaces, la fuente o la admisión.'
                          : 'Facultades y carreras se guardan al aceptar cada ventana.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving || !_dirty ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Guardando…' : 'Guardar ficha'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
    children: [
      for (final c in children) ...[c, const SizedBox(height: 14)],
    ],
  );

  Widget _summaryCard(UniversityProfile p) => SectionCard(
    title: 'Presentación',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _summary,
          minLines: 3,
          maxLines: 6,
          maxLength: 600,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Resumen',
            alignLabelWithHint: true,
            hintText: 'Dos o tres líneas: qué es, dónde está y qué la distingue.',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<UniversityType>(
              segments: [
                for (final t in UniversityType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {p.type},
              onSelectionChanged: (s) => _set((x) => x.copyWith(type: s.single)),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _founded,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Año de fundación'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _linksCard(UniversityProfile p) => SectionCard(
    title: 'Enlaces oficiales',
    trailing: TextButton.icon(
      onPressed: () async {
        final link = await showOfficialLinkDialog(context);
        if (link != null) _set((x) => x.copyWith(links: [...x.links, link]));
      },
      icon: const Icon(Icons.add_link_rounded, size: 18),
      label: const Text('Agregar'),
    ),
    child: p.links.isEmpty
        ? Text(
            'Sin enlaces. Agrega al menos la web oficial y la de admisión.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          )
        : Column(
            children: [
              for (final (i, l) in p.links.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(linkIcon(l.kind), color: AppTheme.brand),
                  title: Text(l.title),
                  subtitle: Text(l.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final edited = await showOfficialLinkDialog(context, initial: l);
                          if (edited != null) {
                            _set((x) => x.copyWith(links: [...x.links]..[i] = edited));
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            _set((x) => x.copyWith(links: [...x.links]..removeAt(i))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _sourceCard(UniversityProfile p) => SectionCard(
    title: 'Fuente de los datos',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _source,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '¿De dónde salen los datos?',
            hintText: 'Prospecto de admisión 2026-I y web oficial de admisión',
            helperText: 'El alumno lo ve al final de la ficha. No inventes cifras.',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                p.sourceCheckedAt == null
                    ? 'Nunca revisada.'
                    : 'Revisada el ${formatNewsDate(p.sourceCheckedAt!)}.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  _set((x) => x.copyWith(sourceCheckedAt: () => DateTime.now())),
              child: const Text('Marcar revisada hoy'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _facultiesCard(UniversityStudentData data) {
    final repo = ref.read(universityRepoProvider);
    int careersOf(String facultyId) => data.careers
        .where((c) => data.detailsOf(c.id).facultyId == facultyId)
        .length;
    Future<void> save(List<Faculty> list) async {
      try {
        await repo.setFaculties(data.universityId, list);
      } catch (e) {
        _snack(e is StateError ? e.message : 'No se pudo guardar.');
      }
    }

    return SectionCard(
      title: 'Facultades · ${data.faculties.length}',
      trailing: TextButton.icon(
        onPressed: () async {
          final f = await showFacultyDialog(context, id: repo.newFacultyId());
          if (f != null) await save([...data.faculties, f]);
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Agregar facultad'),
      ),
      child: data.faculties.isEmpty
          ? const EmptyState(
              icon: Icons.domain_outlined,
              title: 'Sin facultades',
              message:
                  'Agrega cada facultad con su nombre y sigla (por ejemplo, '
                  '«Facultad de Ingeniería Civil, de Sistemas y de '
                  'Arquitectura» · FICSA). Luego asigna cada carrera a su '
                  'facultad en la pestaña Carreras.',
            )
          : Column(
              children: [
                for (final (i, f) in data.faculties.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.brandSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.acronym.isEmpty ? '—' : f.acronym,
                        style: TextStyle(
                          color: AppTheme.brandInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    title: Text(f.name),
                    subtitle: Text(
                      '${careersOf(f.id)} carrera(s)${f.active ? '' : ' · inactiva'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final edited = await showFacultyDialog(
                              context,
                              id: f.id,
                              initial: f,
                            );
                            if (edited != null) {
                              await save([...data.faculties]..[i] = edited);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final n = careersOf(f.id);
                            final ok = await confirmDialog(
                              context,
                              title: 'Quitar ${f.acronym.isEmpty ? f.name : f.acronym}',
                              message: n == 0
                                  ? 'Se quita de la ficha.'
                                  : 'Sus $n carrera(s) quedan sin facultad.',
                            );
                            if (ok) {
                              await repo.deleteFaculty(data.universityId, data, f.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _careersCard(UniversityStudentData data) {
    final byId = {for (final f in data.faculties) f.id: f};
    return SectionCard(
      title: 'Carreras · ${data.careers.length}',
      child: data.careers.isEmpty
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: 'Sin carreras',
              message:
                  'Primero elige las carreras de esta universidad en '
                  'Universidades → ficha → Profesiones.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Toca una carrera para poner su facultad, área del examen, '
                  'vacantes, puntajes de ingreso (con el proceso al que '
                  'corresponden), duración, título y enlace oficial.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (final c in data.careers)
                  Builder(
                    builder: (context) {
                      final d = data.detailsOf(c.id);
                      final faculty = byId[d.facultyId];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final edited = await showCareerDetailsDialog(
                            context,
                            careerName: c.name,
                            faculties: data.faculties,
                            areas: data.examAreas,
                            initial: d,
                          );
                          if (edited == null) return;
                          try {
                            await ref
                                .read(universityRepoProvider)
                                .setCareerDetails(data.universityId, c.id, edited);
                          } catch (e) {
                            _snack(e is StateError ? e.message : 'No se pudo guardar.');
                          }
                        },
                        title: Text(c.name),
                        subtitle: Text(
                          [
                            faculty?.acronym.isNotEmpty == true
                                ? faculty!.acronym
                                : 'Sin facultad',
                            if (d.vacancies != null) '${d.vacancies} vacantes',
                            if (d.minScore != null) 'mín. ${fmtScore(d.minScore!)}',
                            if (d.scorePeriod.isNotEmpty) d.scorePeriod,
                            if (data.areaOf(c.id) case final area?) 'área ${area.id}',
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!c.active) const StatusPill('Inactiva'),
                            if (d.facultyId.isEmpty || d.minScore == null)
                              const StatusPill('Incompleta', tone: Tone.warn)
                            else
                              const StatusPill('Completa', tone: Tone.success),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: AppTheme.faint),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _admissionCard(UniversityProfile p) => SectionCard(
    title: 'Admisión',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _admissionInfo,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Cómo es su admisión',
            alignLabelWithHint: true,
            hintText:
                'Modalidades (ordinario, CEPRE, extraordinario), requisitos y '
                'cuántas veces al año hay examen.',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Calendario de admisión',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final d = await showAdmissionDateDialog(context);
                if (d != null) {
                  _set(
                    (x) => x.copyWith(
                      admissionDates: [...x.admissionDates, d]
                        ..sort((a, b) => a.at.compareTo(b.at)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar fecha'),
            ),
          ],
        ),
        if (p.admissionDates.isEmpty)
          Text(
            'Sin fechas (inscripciones, examen, resultados).',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        for (final (i, d) in p.admissionDates.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.event_note_outlined),
            title: Text(d.label),
            subtitle: Text(formatNewsDate(d.at)),
            trailing: IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _set(
                (x) => x.copyWith(admissionDates: [...x.admissionDates]..removeAt(i)),
              ),
            ),
          ),
      ],
    ),
  );
}
