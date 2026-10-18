import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/news.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'news_format.dart';

final newsListProvider = StreamProvider.autoDispose<List<NewsItem>>(
  (ref) => ref.watch(newsRepoProvider).watchAll(),
);

enum _Filter {
  all('Todas'),
  live('Publicadas'),
  scheduled('Programadas'),
  draft('Borradores'),
  expired('Vencidas'),
  archived('Archivadas');

  const _Filter(this.label);

  final String label;

  bool matches(NewsItem n, DateTime now) => switch (this) {
    _Filter.all => n.status != NewsStatus.archived,
    _Filter.live => n.stateLabel(now) == 'Publicada',
    _Filter.scheduled => n.stateLabel(now) == 'Programada',
    _Filter.draft => n.status == NewsStatus.draft,
    _Filter.expired => n.stateLabel(now) == 'Vencida',
    _Filter.archived => n.status == NewsStatus.archived,
  };
}

/// Noticias que ven los alumnos (lienzo «Admin · Publicar noticia»).
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(newsListProvider);
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.news, StaffAction.edit);
    final all = async.value ?? const <NewsItem>[];
    final now = DateTime.now();
    final shown = all.where((n) => _filter.matches(n, now)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          crumbs: const ['Alumnos'],
          title: 'Noticias',
          subtitle:
              'Avisos, novedades y consejos para los alumnos. Una noticia '
              'urgente sale en una ventana al abrir la app; una fijada queda '
              'arriba del Inicio; cualquiera puede salir también como historia. '
              'Si eliges universidades, solo esos alumnos la ven como principal.',
          actions: [
            if (canEdit)
              FilledButton.icon(
                onPressed: () => context.go('/news/new'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva noticia'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _Filter.values)
              ChoiceChip(
                label: Text(
                  '${f.label} · ${all.where((n) => f.matches(n, now)).length}',
                ),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (async.isLoading && all.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (async.hasError)
          InfoNote(
            'No se pudieron cargar las noticias. Revisa tu conexión o tus '
            'permisos.',
            tone: Tone.error,
          )
        else if (shown.isEmpty)
          SectionCard(
            child: EmptyState(
              icon: Icons.campaign_outlined,
              title: all.isEmpty
                  ? 'Todavía no hay noticias'
                  : 'No hay noticias en esta lista',
              message: all.isEmpty
                  ? 'Publica la primera: un aviso de tu universidad, una '
                        'novedad de la app o un consejo.'
                  : null,
              action: canEdit && all.isEmpty
                  ? FilledButton(
                      onPressed: () => context.go('/news/new'),
                      child: const Text('Nueva noticia'),
                    )
                  : null,
            ),
          )
        else
          for (final n in shown) ...[
            _NewsRow(item: n, now: now),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, required this.now});

  final NewsItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = item.stateLabel(now);
    final stateTone = switch (state) {
      'Publicada' => Tone.success,
      'Programada' => Tone.info,
      'Vencida' || 'Archivada' => Tone.neutral,
      _ => Tone.warn,
    };
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => context.go('/news/${item.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 70,
                  child: item.image == null
                      ? ColoredBox(
                          color: AppTheme.subtle,
                          child: Icon(
                            _categoryIcon(item.category),
                            color: AppTheme.muted,
                          ),
                        )
                      : Image.network(
                          item.image!.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: AppTheme.subtle,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(state, tone: stateTone),
                        if (item.priority != NewsPriority.normal)
                          StatusPill(
                            item.priority.label,
                            tone: item.priority == NewsPriority.urgent
                                ? Tone.error
                                : Tone.brand,
                            icon: item.priority == NewsPriority.urgent
                                ? Icons.campaign_outlined
                                : Icons.push_pin_outlined,
                          ),
                        if (item.story)
                          const StatusPill(
                            'Historia',
                            icon: Icons.amp_stories_outlined,
                          ),
                        if (item.push)
                          StatusPill(
                            item.pushSentAt == null
                                ? 'Notificación'
                                : 'Notificación enviada',
                            icon: Icons.notifications_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title.isEmpty ? '(sin título)' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category.label} · ${item.audienceLabel} · '
                      '${formatNewsDate(item.publishAt)}'
                      '${item.expiresAt == null ? '' : ' → vence ${formatShortDate(item.expiresAt!)}'}',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.faint),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(NewsCategory c) => switch (c) {
  NewsCategory.notice => Icons.campaign_outlined,
  NewsCategory.admission => Icons.event_outlined,
  NewsCategory.appUpdate => Icons.auto_awesome_outlined,
  NewsCategory.tip => Icons.lightbulb_outline,
};
