import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Piezas comunes del rediseño (tablero «6 · Sistema visual»).

enum Tone { neutral, brand, success, warn, error, info }

extension ToneColors on Tone {
  Color get fg => switch (this) {
    Tone.neutral => AppTheme.body,
    Tone.brand => AppTheme.brandInk,
    Tone.success => AppTheme.success,
    Tone.warn => AppTheme.warn,
    Tone.error => AppTheme.error,
    Tone.info => AppTheme.info,
  };

  Color get bg => switch (this) {
    Tone.neutral => const Color(0xFFF2F4F7),
    Tone.brand => AppTheme.brandSoft,
    Tone.success => AppTheme.successSoft,
    Tone.warn => AppTheme.warnSoft,
    Tone.error => AppTheme.errorSoft,
    Tone.info => AppTheme.infoSoft,
  };

  Color get border => switch (this) {
    Tone.neutral => AppTheme.line,
    Tone.brand => const Color(0xFFD9C8FF),
    Tone.success => const Color(0xFFABEFC6),
    Tone.warn => AppTheme.warnLine,
    Tone.error => AppTheme.errorLine,
    Tone.info => const Color(0xFFC7D7FE),
  };
}

/// Etiqueta redondeada de estado: «Lista», «Por revisar», «Bloquea»…
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de página: migas, título, subtítulo y acciones.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.crumbs = const [],
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<String> crumbs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              crumbs.join(' / '),
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta blanca con borde fino; opcionalmente con título.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.titleColor,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  final String? title;
  final Color? titleColor;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(color: color, borderColor: borderColor),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor ?? AppTheme.ink,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Indicador grande con franja de color arriba.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.tone = Tone.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;
  final Tone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: tone == Tone.neutral ? AppTheme.line : tone.fg,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso con fondo suave (azul de información por defecto).
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.tone = Tone.info, this.icon});

  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: tone.fg),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: tone.fg, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío amable con una acción opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.faint),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
