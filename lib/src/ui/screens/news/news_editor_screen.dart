import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repo/news_repo.dart';
import '../../../domain/entities/university_entities.dart';
import '../../../domain/news.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'news_format.dart';
import 'news_preview.dart';
import 'news_screen.dart';

final _universitiesProvider =
    StreamProvider.autoDispose<List<UniversityEntity>>(
      (ref) => ref.watch(universityRepoProvider).watchUniversities(),
    );
final _settingsProvider = StreamProvider.autoDispose<NewsSettings>(
  (ref) => ref.watch(appConfigRepoProvider).watchNewsSettings(),
);

/// Crear o editar una noticia (`/news/new`, `/news/:id`).
class NewsEditorScreen extends ConsumerStatefulWidget {
  const NewsEditorScreen({super.key, required this.newsId});

  /// `new` para crear.
  final String newsId;

  @override
  ConsumerState<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends ConsumerState<NewsEditorScreen> {
  NewsItem? _item;
  bool _isNew = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  bool _scheduled = false;

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _eventLabel = TextEditingController();
  final _alt = TextEditingController();
  final _actionLabel = TextEditingController();
  final _actionUrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _title,
      _body,
      _eventLabel,
      _alt,
      _actionLabel,
      _actionUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(List<NewsItem> all) {
    if (_item != null) return;
    final found = all.where((n) => n.id == widget.newsId).firstOrNull;
    _isNew = found == null;
    final item =
        found ??
        NewsItem(
          id: ref.read(newsRepoProvider).newId(),
          title: '',
          publishAt: DateTime.now(),
        );
    _item = item;
    _scheduled = !_isNew && item.publishAt.isAfter(DateTime.now());
    _title.text = item.title;
    _body.text = item.body;
    _eventLabel.text = item.eventLabel;
    _alt.text = item.image?.alt ?? '';
    _actionLabel.text = item.action?.label ?? '';
    _actionUrl.text = item.action?.type == NewsActionType.url
        ? item.action!.target
        : '';
  }

  /// La noticia con lo escrito en los campos de texto.
  NewsItem get _current {
    final item = _item!;
    final action = item.action;
    return item.copyWith(
      title: _title.text,
      body: _body.text,
      eventLabel: _eventLabel.text,
      image: () => item.image?.copyWith(alt: _alt.text),
      action: () => action == null
          ? null
          : NewsAction(
              label: _actionLabel.text,
              type: action.type,
              target: action.type == NewsActionType.url
                  ? _actionUrl.text
                  : action.target,
            ),
    );
  }

  void _set(NewsItem Function(NewsItem n) change) =>
      setState(() => _item = change(_current));

  Future<void> _pickImage() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > NewsRepo.maxImageBytes) {
        setState(
          () => _error =
              'La imagen pesa ${(file.size / 1024 / 1024).toStringAsFixed(1)} MB; '
              'el máximo es 2 MB. Redúcela (por ejemplo, a 1080 px de ancho en '
              'JPG) y vuelve a subirla.',
        );
        return;
      }
      setState(() => _uploading = true);
      final bytes = file.bytes ?? await result.xFiles.single.readAsBytes();
      final image = await NewsRepo.uploadImage(bytes, file.name);
      if (!mounted) return;
      _set(
        (n) => n.copyWith(
          image: () => image.copyWith(
            alt: _alt.text,
            onlyImage: n.image?.onlyImage ?? false,
          ),
        ),
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo subir la imagen. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save(NewsStatus status) async {
    var item = _current.copyWith(status: status);
    if (status == NewsStatus.published && !_scheduled && _isNewPublish) {
      item = item.copyWith(publishAt: DateTime.now());
    }
    if (status == NewsStatus.published) {
      final problem = item.validateForPublish() ?? _urgentProblem(item);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(newsRepoProvider)
          .save(
            item,
            editor: ref.read(adminSessionProvider).email,
            isNew: _isNew,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            NewsStatus.published =>
              item.publishAt.isAfter(DateTime.now())
                  ? 'Programada para ${formatNewsDate(item.publishAt)}.'
                  : 'Publicada: los alumnos ya la ven.',
            NewsStatus.draft => 'Borrador guardado.',
            NewsStatus.archived => 'Archivada: ya no la ven los alumnos.',
          }),
        ),
      );
      context.go('/news');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'No se pudo guardar. Revisa tus permisos o tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Publicar una que aún no lo estaba (fija la hora al publicar ahora).
  bool get _isNewPublish => _item!.status != NewsStatus.published;

  String? _urgentProblem(NewsItem item) {
    if (item.priority != NewsPriority.urgent) return null;
    final limit = (ref.read(_settingsProvider).value ?? NewsSettings.defaults)
        .urgentPerWeek;
    final used = urgentInWeek(
      ref.read(newsListProvider).value ?? const [],
      item.publishAt,
      universityIds: item.universityIds,
      exceptId: item.id,
    );
    if (used < limit) return null;
    return limit == 0
        ? 'Los avisos urgentes están desactivados en Configuración.'
        : 'Ya hay $used aviso(s) urgente(s) para esta audiencia en la misma '
              'semana (máximo $limit, en Configuración). Publícala como '
              '«Fijada» o espera unos días.';
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: const Text(
          'Desaparece para todos los alumnos. Si solo quieres sacarla, mejor '
          'archívala (se puede recuperar desde el Historial).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(newsRepoProvider).delete(_item!.id);
    if (mounted) context.go('/news');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(newsListProvider);
    if (_item == null) {
      if (!async.hasValue) {
        return const Center(child: CircularProgressIndicator());
      }
      _load(async.value!);
    }
    final session = ref.watch(effectiveSessionProvider);
    final canEdit = session.can(StaffSection.news, StaffAction.edit);
    final canPublish = session.can(StaffSection.news, StaffAction.publish);
    final canDelete = session.can(StaffSection.news, StaffAction.archive);
    final item = _current;
    final locked = !canEdit || (item.status == NewsStatus.published && !canPublish);

    final form = AbsorbPointer(
      absorbing: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _contentCard(item),
          const SizedBox(height: 14),
          _imageCard(item),
          const SizedBox(height: 14),
          _priorityCard(item),
          const SizedBox(height: 14),
          _audienceCard(item),
          const SizedBox(height: 14),
          _datesCard(item),
          const SizedBox(height: 14),
          _extrasCard(item),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          crumbs: const ['Alumnos', 'Noticias'],
          title: _isNew ? 'Nueva noticia' : 'Editar noticia',
          subtitle: _isNew
              ? null
              : '${item.stateLabel(DateTime.now())} · última edición '
                    '${item.updatedAt == null ? '—' : formatNewsDate(item.updatedAt!)}'
                    '${item.updatedBy.isEmpty ? '' : ' por ${item.updatedBy}'}',
          actions: [
            OutlinedButton(
              onPressed: () => context.go('/news'),
              child: const Text('Volver'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InfoNote(
              canEdit
                  ? 'Esta noticia ya está publicada: cambiarla pide permiso de '
                        'publicar.'
                  : 'Solo puedes ver esta noticia.',
              tone: Tone.warn,
            ),
          ),
        LayoutBuilder(
          builder: (context, c) {
            final preview = NewsPreviewPanel(item: item);
            if (c.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, const SizedBox(height: 18), preview],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: 24),
                SizedBox(width: 360, child: preview),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          InfoNote(_error!, tone: Tone.error, icon: Icons.error_outline),
        ],
        const SizedBox(height: 18),
        if (!locked)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canPublish)
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _save(NewsStatus.published),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    item.status == NewsStatus.published
                        ? 'Guardar cambios'
                        : _scheduled
                        ? 'Programar'
                        : 'Publicar ahora',
                  ),
                ),
              if (item.status != NewsStatus.published)
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(NewsStatus.draft),
                  child: const Text('Guardar borrador'),
                ),
              if (!_isNew && item.status == NewsStatus.published && canPublish)
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(NewsStatus.archived),
                  child: const Text('Archivar'),
                ),
              if (!_isNew && canDelete)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ),
            ],
          ),
        if (!locked && !canPublish)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Guárdala como borrador y pide a alguien con permiso de publicar '
              'que la revise.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _contentCard(NewsItem item) => SectionCard(
    title: 'Contenido',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in NewsCategory.values)
              ChoiceChip(
                label: Text(c.label),
                selected: item.category == c,
                onSelected: (_) => _set((n) => n.copyWith(category: c)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: 90,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'Las inscripciones cierran este viernes',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _body,
          minLines: 4,
          maxLines: 12,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: item.image?.onlyImage == true
                ? 'Texto (opcional con «Solo imagen»)'
                : 'Texto',
            alignLabelWithHint: true,
            helperText: 'Escribe como le hablarías a un alumno: corto y claro.',
          ),
        ),
      ],
    ),
  );

  Widget _imageCard(NewsItem item) {
    final image = item.image;
    return SectionCard(
      title: 'Imagen (opcional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Un comunicado, afiche o foto. Mejor vertical (4:5, por ejemplo '
            '1080 × 1350), PNG, JPG o WebP de hasta 2 MB.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    image.url,
                    width: 96,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickImage,
                          icon: _uploading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined, size: 18),
                          label: Text(
                            _uploading
                                ? 'Subiendo…'
                                : image == null
                                ? 'Subir imagen'
                                : 'Cambiar imagen',
                          ),
                        ),
                        if (image != null)
                          TextButton(
                            onPressed: () =>
                                _set((n) => n.copyWith(image: () => null)),
                            child: const Text('Quitar'),
                          ),
                      ],
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _alt,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Describe la imagen (obligatorio)',
                          hintText:
                              'Comunicado N.° 031-2026 de la UNPRG sobre su nueva '
                              'página de Facebook',
                          helperText:
                              'Lo escucha quien usa lector de pantalla.',
                        ),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: image.onlyImage,
                        onChanged: (v) => _set(
                          (n) => n.copyWith(
                            image: () => n.image?.copyWith(onlyImage: v),
                          ),
                        ),
                        title: const Text('Solo imagen'),
                        subtitle: const Text(
                          'La imagen ya trae todo el texto (un comunicado). '
                          'El texto de la noticia queda opcional.',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityCard(NewsItem item) {
    final limit =
        (ref.watch(_settingsProvider).value ?? NewsSettings.defaults)
            .urgentPerWeek;
    return SectionCard(
      title: 'Prioridad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<NewsPriority>(
            segments: [
              for (final p in NewsPriority.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {item.priority},
            onSelectionChanged: (s) => _set(
              (n) => n.copyWith(
                priority: s.single,
                expiresAt: s.single != NewsPriority.normal && n.expiresAt == null
                    ? () => n.publishAt.add(const Duration(days: 7))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.priority.hint,
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          if (item.priority == NewsPriority.urgent) ...[
            const SizedBox(height: 8),
            InfoNote(
              'Úsalo solo para lo que el alumno no se puede perder (cambio de '
              'fecha, cierre de inscripciones). Máximo $limit por semana para '
              'la misma audiencia; se cambia en Configuración.',
              tone: Tone.warn,
            ),
          ],
        ],
      ),
    );
  }

  Widget _audienceCard(NewsItem item) {
    final universities = ref.watch(_universitiesProvider).value ?? const [];
    final byId = {for (final u in universities) u.id: u};
    void setUnis(List<String> ids) => _set(
      (n) => n.copyWith(
        universityIds: ids,
        universityLabels: [
          for (final id in ids)
            byId[id]?.acronym.isNotEmpty == true ? byId[id]!.acronym : id,
        ],
      ),
    );
    final general = item.isGeneral && !_pickingUnis;
    return SectionCard(
      title: '¿A quién va dirigida?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('General (todos)')),
              ButtonSegment(value: false, label: Text('Por universidad')),
            ],
            selected: {general},
            onSelectionChanged: (s) {
              setState(() => _pickingUnis = !s.single);
              if (s.single) setUnis(const []);
            },
          ),
          if (!general) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in universities.where((u) => u.active))
                  FilterChip(
                    label: Text(u.acronym.isEmpty ? u.name : u.acronym),
                    tooltip: u.name,
                    selected: item.universityIds.contains(u.id),
                    onSelected: (on) => setUnis(
                      on
                          ? [...item.universityIds, u.id]
                          : item.universityIds.where((x) => x != u.id).toList(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            InfoNote(
              item.universityIds.isEmpty
                  ? 'Elige una o más universidades.'
                  : 'Los alumnos de ${item.universityLabels.join(', ')} la ven '
                        'como principal (ventana, fijada, historia y '
                        'notificación). Los demás solo la encuentran en '
                        'Noticias › «Otras universidades», con la etiqueta '
                        '«Solo ${item.universityLabels.join(', ')}».',
            ),
          ],
        ],
      ),
    );
  }

  bool _pickingUnis = false;

  Widget _datesCard(NewsItem item) {
    Future<void> pick(
      DateTime initial,
      void Function(DateTime d) apply,
    ) async {
      final picked = await pickDateTime(context, initial: initial);
      if (picked != null) setState(() => apply(picked));
    }

    final isLive = item.status == NewsStatus.published &&
        !item.publishAt.isAfter(DateTime.now());
    return SectionCard(
      title: 'Fechas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLive) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _scheduled,
              onChanged: (v) => setState(() {
                _scheduled = v;
                if (v && !_item!.publishAt.isAfter(DateTime.now())) {
                  _item = _current.copyWith(
                    publishAt: DateTime.now().add(const Duration(hours: 1)),
                  );
                }
              }),
              title: const Text('Programar la publicación'),
              subtitle: Text(
                _scheduled
                    ? 'Se publica el ${formatNewsDate(item.publishAt)}.'
                    : 'Se publica apenas toques «Publicar ahora».',
              ),
            ),
            if (_scheduled)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => pick(
                    item.publishAt,
                    (d) => _item = _current.copyWith(publishAt: d),
                  ),
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text('Publicar el ${formatNewsDate(item.publishAt)}'),
                ),
              ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => pick(
                  item.expiresAt ?? item.publishAt.add(const Duration(days: 7)),
                  (d) => _item = _current.copyWith(expiresAt: () => d),
                ),
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: Text(
                  item.expiresAt == null
                      ? 'Poner fecha de vencimiento'
                      : 'Vence el ${formatNewsDate(item.expiresAt!)}',
                ),
              ),
              if (item.expiresAt != null && item.priority == NewsPriority.normal)
                TextButton(
                  onPressed: () =>
                      _set((n) => n.copyWith(expiresAt: () => null)),
                  child: const Text('Sin vencimiento'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Al vencer sale del Inicio y de las historias; sigue en la lista '
            '(«Anteriores»).',
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Cuenta regresiva (opcional)',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => pick(
                  item.eventAt ?? item.publishAt.add(const Duration(days: 3)),
                  (d) => _item = _current.copyWith(eventAt: () => d),
                ),
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: Text(
                  item.eventAt == null
                      ? 'Fecha del evento'
                      : formatNewsDate(item.eventAt!),
                ),
              ),
              if (item.eventAt != null)
                TextButton(
                  onPressed: () => _set((n) => n.copyWith(eventAt: () => null)),
                  child: const Text('Quitar'),
                ),
            ],
          ),
          if (item.eventAt != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _eventLabel,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '¿Qué pasa ese día?',
                hintText: 'Cierre de inscripciones',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _keyDates(item),
        ],
      ),
    );
  }

  Widget _keyDates(NewsItem item) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Fechas clave (opcional)',
        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
      ),
      const SizedBox(height: 6),
      for (final (i, k) in item.keyDates.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.event_note_outlined),
          title: Text(k.label),
          subtitle: Text(formatNewsDate(k.at)),
          trailing: IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _set(
              (n) => n.copyWith(keyDates: [...n.keyDates]..removeAt(i)),
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: item.keyDates.length >= 6 ? null : _addKeyDate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar fecha clave'),
        ),
      ),
    ],
  );

  Future<void> _addKeyDate() async {
    final label = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fecha clave'),
        content: TextField(
          controller: label,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '¿Qué pasa?',
            hintText: 'Examen · 8:00 a. m.',
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
    if (name == null || name.isEmpty || !mounted) return;
    final at = await pickDateTime(context, initial: DateTime.now());
    if (at == null) return;
    _set(
      (n) => n.copyWith(
        keyDates: [...n.keyDates, NewsKeyDate(label: name, at: at)]
          ..sort((a, b) => a.at.compareTo(b.at)),
      ),
    );
  }

  Widget _extrasCard(NewsItem item) {
    final action = item.action;
    return SectionCard(
      title: 'Historia, botón y notificación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: item.story,
            onChanged: (v) => _set((n) => n.copyWith(story: v)),
            title: const Text('Mostrar también como historia en el Inicio'),
            subtitle: const Text(
              'Sale en la fila de historias durante los días que digas en '
              'Configuración.',
            ),
          ),
          if (item.story && item.image == null)
            Wrap(
              spacing: 6,
              children: [
                for (final e in newsStoryColors.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: item.storyColor == e.key,
                    onSelected: (_) =>
                        _set((n) => n.copyWith(storyColor: e.key)),
                  ),
              ],
            ),
          const Divider(height: 28),
          Text(
            'Botón de acción (opcional)',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 8),
          SegmentedButton<NewsActionType?>(
            segments: [
              const ButtonSegment(value: null, label: Text('Sin botón')),
              for (final t in NewsActionType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {action?.type},
            onSelectionChanged: (s) => _set(
              (n) => n.copyWith(
                action: () => s.single == null
                    ? null
                    : NewsAction(
                        label: _actionLabel.text,
                        type: s.single!,
                        target: s.single == NewsActionType.route
                            ? newsAppRoutes.first.$1
                            : _actionUrl.text,
                      ),
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _actionLabel,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Texto del botón',
                hintText: 'Inscribirme en la web oficial',
              ),
            ),
            const SizedBox(height: 8),
            if (action.type == NewsActionType.url)
              TextField(
                controller: _actionUrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Enlace',
                  hintText: 'https://admision.unprg.edu.pe',
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: newsAppRoutes.any((r) => r.$1 == action.target)
                    ? action.target
                    : newsAppRoutes.first.$1,
                decoration: const InputDecoration(labelText: 'Abre'),
                items: [
                  for (final (route, label) in newsAppRoutes)
                    DropdownMenuItem(value: route, child: Text(label)),
                ],
                onChanged: (v) => _set(
                  (n) => n.copyWith(
                    action: () => NewsAction(
                      label: _actionLabel.text,
                      type: NewsActionType.route,
                      target: v ?? newsAppRoutes.first.$1,
                    ),
                  ),
                ),
              ),
          ],
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: item.push,
            onChanged: item.pushSentAt != null
                ? null
                : (v) => _set((n) => n.copyWith(push: v)),
            title: const Text('Enviar notificación al teléfono'),
            subtitle: Text(
              item.pushSentAt != null
                  ? 'Ya se envió el ${formatNewsDate(item.pushSentAt!)}.'
                  : 'Llega una sola vez, al publicarse, y solo a los alumnos '
                        'de la audiencia elegida.',
            ),
          ),
        ],
      ),
    );
  }
}
