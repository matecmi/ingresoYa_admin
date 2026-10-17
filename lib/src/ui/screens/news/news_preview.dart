import 'package:flutter/material.dart';

import '../../../app_preview/app_exam_preview.dart';
import '../../../app_preview/gen/app_theme.g.dart' as app;
import '../../../app_preview/gen/news_visuals.g.dart';
import '../../../domain/news.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'news_format.dart';

enum _View { popup, home, list }

/// «Así la ve el alumno»: las piezas reales de la app (generadas con
/// tool/sync_app_preview.py) con los datos del formulario.
class NewsPreviewPanel extends StatefulWidget {
  const NewsPreviewPanel({super.key, required this.item});

  final NewsItem item;

  @override
  State<NewsPreviewPanel> createState() => _NewsPreviewPanelState();
}

class _NewsPreviewPanelState extends State<NewsPreviewPanel> {
  _View? _view;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final views = [
      if (item.priority == NewsPriority.urgent) _View.popup,
      if (item.priority != NewsPriority.normal || item.story) _View.home,
      _View.list,
    ];
    final view = views.contains(_view) ? _view! : views.first;
    final audience = item.isGeneral
        ? 'Todos los alumnos la ven así.'
        : 'Así la ven los alumnos de ${item.universityLabels.join(', ')}. '
              'Los demás solo la encuentran en «Otras universidades».';
    return SectionCard(
      title: 'Así la ve el alumno',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (views.length > 1) ...[
            SegmentedButton<_View>(
              showSelectedIcon: false,
              segments: [
                for (final v in views)
                  ButtonSegment(
                    value: v,
                    label: Text(switch (v) {
                      _View.popup => 'Ventana',
                      _View.home => 'Inicio',
                      _View.list => 'Lista',
                    }),
                  ),
              ],
              selected: {view},
              onSelectionChanged: (s) => setState(() => _view = s.single),
            ),
            const SizedBox(height: 12),
          ],
          Center(
            child: AppPhoneFrame(
              key: ValueKey('$view ${item.toMap()}'),
              width: 300,
              child: _Phone(item: item, view: view),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            audience,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.item, required this.view});

  final NewsItem item;
  final _View view;

  String get _title => item.title.trim().isEmpty ? 'Título de la noticia' : item.title;

  String get _audience => item.universityLabels.join(', ');

  @override
  Widget build(BuildContext context) {
    final colors = app.AppPaletteColors.forPalette(app.AppColorPalette.classic);
    final now = DateTime.now();
    final eventDays = item.eventAt == null ? null : daysUntil(item.eventAt!, now);
    return ColoredBox(
      color: colors.background,
      child: switch (view) {
        _View.popup => Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: .74)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
                child: NewsUrgentCard(
                  tag: item.isGeneral
                      ? 'AVISO IMPORTANTE'
                      : 'AVISO IMPORTANTE · $_audience',
                  title: _title,
                  body: item.body,
                  imageUrl: item.image?.url,
                  imageAspect: item.image == null || item.image!.height == 0
                      ? .8
                      : item.image!.width / item.image!.height,
                  countdownDays: eventDays,
                  countdownDate: item.eventAt == null
                      ? null
                      : [
                          if (item.eventLabel.trim().isNotEmpty) item.eventLabel,
                          formatNewsDate(item.eventAt!),
                        ].join(' · '),
                  footnote: 'Queda fijado en tu Inicio.',
                  onDetails: () {},
                  onDismiss: () {},
                ),
              ),
            ),
          ],
        ),
        _View.home => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.headerStart, colors.headerEnd],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                'Cabecera del Inicio',
                style: TextStyle(color: colors.onHeader.withValues(alpha: .7)),
              ),
            ),
            const SizedBox(height: 12),
            if (item.priority != NewsPriority.normal)
              NewsPinnedBanner(
                tag: item.isGeneral ? 'AVISO' : 'AVISO $_audience',
                title: _title,
                onTap: () {},
              ),
            if (item.story) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  NewsStoryBubble(
                    label: _title,
                    categoryKey: item.category.key,
                    colorKey: item.storyColor,
                    imageUrl: item.image?.url,
                  ),
                  const SizedBox(width: 6),
                  NewsBubbleFrame(
                    label: 'Ver todas',
                    seen: true,
                    child: ColoredBox(
                      color: colors.surface,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        _View.list => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              item.priority == NewsPriority.normal ? 'ESTA SEMANA' : 'FIJADO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 10),
            NewsListTile(
              categoryKey: item.category.key,
              title: _title,
              meta: [
                'Hace un momento',
                if (eventDays != null && eventDays >= 0)
                  eventDays == 0
                      ? 'es hoy'
                      : eventDays == 1
                      ? 'falta 1 día'
                      : 'faltan $eventDays días',
              ].join(' · '),
              unread: true,
              pinned: item.priority != NewsPriority.normal,
              imageUrl: item.image?.url,
              onTap: () {},
            ),
            if (!item.isGeneral) ...[
              const SizedBox(height: 16),
              Text(
                'OTRAS UNIVERSIDADES (lo que ven los demás)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 10),
              NewsListTile(
                categoryKey: item.category.key,
                title: _title,
                meta: 'Hace un momento · no es de tu universidad',
                onlyForLabel: 'Solo $_audience',
                imageUrl: item.image?.url,
                onTap: () {},
              ),
            ],
          ],
        ),
      },
    );
  }
}
