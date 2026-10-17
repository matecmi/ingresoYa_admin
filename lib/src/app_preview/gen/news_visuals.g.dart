// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.
// Copia fiel de iya-app/lib/features/news/presentation/widgets/news_visuals.dart (commit c92d18f) para que la vista
// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.
// ignore_for_file: type=lint, deprecated_member_use

import 'package:flutter/material.dart';
import 'owl_mascot.g.dart';
import 'app_theme.g.dart';

// Piezas visuales de las noticias. Solo reciben datos simples (no el
// dominio) porque el admin las copia para su vista previa con
// `tool/sync_app_preview.py`: así la vista previa es idéntica a la app.

/// Color, ícono y nombre de una categoría (`notice`, `admission`,
/// `appUpdate`, `tip`).
(Color, IconData, String) newsCategoryStyle(
  BuildContext context,
  String categoryKey,
) {
  final colors = context.appColors;
  return switch (categoryKey) {
    'admission' => (
      colors.link,
      Icons.event_outlined,
      'Examen de admisión',
    ),
    'appUpdate' => (
      colors.secondary,
      Icons.auto_awesome_rounded,
      'Novedad de la app',
    ),
    'tip' => (
      colors.success,
      Icons.lightbulb_outline_rounded,
      'Consejo',
    ),
    _ => (colors.error, Icons.campaign_outlined, 'Aviso'),
  };
}

/// Fondo de la portada de una historia sin imagen.
Color newsStoryColor(String key) => switch (key) {
  'blue' => const Color(0xFF1E3A8A),
  'red' => const Color(0xFF7F1D1D),
  'green' => const Color(0xFF064E3B),
  'amber' => const Color(0xFF78350F),
  _ => const Color(0xFF3B1880),
};

/// Imagen de una noticia desde su URL, con fondo mientras carga.
class NewsNetworkImage extends StatelessWidget {
  const NewsNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(color: colors.elevatedSurface),
      errorBuilder: (context, error, stack) => ColoredBox(
        color: colors.elevatedSurface,
        child: Icon(Icons.image_not_supported_outlined, color: colors.muted),
      ),
    );
  }
}

/// Fila de la lista «Noticias».
class NewsListTile extends StatelessWidget {
  const NewsListTile({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.meta,
    this.onlyForLabel,
    this.unread = false,
    this.pinned = false,
    this.dimmed = false,
    this.imageUrl,
    this.onTap,
  });

  final String categoryKey;
  final String title;

  /// «Hace 3 días», «Hoy, 9:00 · faltan 3 días».
  final String meta;

  /// «Solo UNPRG» en noticias de otra universidad.
  final String? onlyForLabel;
  final bool unread;
  final bool pinned;
  final bool dimmed;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (color, icon, label) = newsCategoryStyle(context, categoryKey);
    final tag = pinned && categoryKey == 'notice'
        ? 'AVISO IMPORTANTE'
        : label.toUpperCase();
    return Opacity(
      opacity: dimmed ? .85 : 1,
      child: Material(
        color: pinned ? colors.errorContainer : colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: pinned
                    ? colors.error.withValues(alpha: .38)
                    : colors.onSurface.withValues(alpha: .08),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 48,
                    child: imageUrl != null
                        ? NewsNetworkImage(url: imageUrl!)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .16),
                              border: Border.all(
                                color: color.withValues(alpha: .4),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              pinned ? Icons.push_pin_rounded : icon,
                              color: color,
                              size: 22,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                          ),
                          if (onlyForLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.onSurface.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                onlyForLabel!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: unread || pinned
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Franja del aviso fijado arriba del Inicio.
class NewsPinnedBanner extends StatelessWidget {
  const NewsPinnedBanner({
    super.key,
    required this.tag,
    required this.title,
    this.onTap,
  });

  /// «AVISO UNPRG», «AVISO».
  final String tag;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.error.withValues(alpha: .38)),
          ),
          child: Row(
            children: [
              Icon(Icons.push_pin_rounded, size: 20, color: colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido de la ventana del aviso urgente (sin la capa oscura).
class NewsUrgentCard extends StatelessWidget {
  const NewsUrgentCard({
    super.key,
    required this.tag,
    required this.title,
    this.body = '',
    this.imageUrl,
    this.imageAspect = .8,
    this.imageAlt,
    this.countdownDays,
    this.countdownDate,
    this.footnote,
    this.onDetails,
    this.onDismiss,
    this.onImageTap,
  });

  /// «AVISO IMPORTANTE · UNPRG».
  final String tag;
  final String title;
  final String body;
  final String? imageUrl;
  final double imageAspect;
  final String? imageAlt;

  /// Días hasta la fecha del evento (null sin cuenta regresiva).
  final int? countdownDays;

  /// «vie 24 oct · 23:59».
  final String? countdownDate;
  final String? footnote;
  final VoidCallback? onDetails;
  final VoidCallback? onDismiss;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasImage = imageUrl != null;
    final tagChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .16),
        border: Border.all(color: colors.error.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
          color: colors.error,
        ),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage) ...[
          Row(
            children: [
              tagChip,
              const Spacer(),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: colors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GestureDetector(
              onTap: onImageTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: imageAspect,
                      child: NewsNetworkImage(
                        url: imageUrl!,
                        semanticLabel: imageAlt,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: colors.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Toca para ampliar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Center(child: tagChip),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          textAlign: hasImage ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: hasImage ? 18 : 23,
            fontWeight: FontWeight.w900,
            height: 1.2,
            color: colors.onSurface,
          ),
        ),
        if (!hasImage && body.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, height: 1.45, color: colors.muted),
          ),
        ],
        if (countdownDays != null && countdownDays! >= 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: .1),
              border: Border.all(color: colors.error.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$countdownDays',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (switch (countdownDays!) { 0 => 'es hoy', 1 => 'día para el cierre', _ => 'días para el cierre' }),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      if (countdownDate != null)
                        Text(
                          countdownDate!,
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onDetails,
            child: Text('Ver detalles'),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 44,
          child: TextButton(
            onPressed: onDismiss,
            child: Text(
              'Entendido',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (footnote != null && !hasImage)
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
      ],
    );
    final card = Container(
      padding: EdgeInsets.fromLTRB(
        hasImage ? 14 : 20,
        hasImage ? 8 : 62,
        hasImage ? 14 : 20,
        12,
      ),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.error.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .5),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: content,
    );
    if (hasImage) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 48), child: card),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.alphaBlend(
                  colors.secondary.withValues(alpha: .22),
                  colors.elevatedSurface,
                ),
                border: Border.all(color: colors.elevatedSurface, width: 4),
              ),
              alignment: Alignment.center,
              child: const OwlMascot(size: 72),
            ),
          ),
        ),
      ],
    );
  }
}

/// Círculo de una historia en el Inicio.
class NewsStoryBubble extends StatelessWidget {
  const NewsStoryBubble({
    super.key,
    required this.label,
    required this.categoryKey,
    this.colorKey = 'violet',
    this.imageUrl,
    this.seen = false,
    this.onTap,
  });

  final String label;
  final String categoryKey;
  final String colorKey;
  final String? imageUrl;
  final bool seen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (color, icon, _) = newsCategoryStyle(context, categoryKey);
    return NewsBubbleFrame(
      label: label,
      seen: seen,
      onTap: onTap,
      child: imageUrl != null
          ? NewsNetworkImage(url: imageUrl!)
          : ColoredBox(
              color: newsStoryColor(colorKey),
              child: Icon(icon, size: 22, color: Color.lerp(color, colors.onPrimary, .6)),
            ),
    );
  }
}

/// Marco común de los círculos: anillo de color (o gris si ya se vio).
class NewsBubbleFrame extends StatelessWidget {
  const NewsBubbleFrame({
    super.key,
    required this.label,
    required this.child,
    this.seen = false,
    this.onTap,
  });

  final String label;
  final Widget child;
  final bool seen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seen ? colors.onSurface.withValues(alpha: .25) : null,
                  gradient: seen
                      ? null
                      : SweepGradient(
                          colors: [
                            colors.error,
                            colors.secondary,
                            colors.primary,
                            colors.error,
                          ],
                        ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 3),
                  ),
                  child: ClipOval(child: child),
                ),
              ),
              const SizedBox(height: 5),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
