import 'package:flutter/material.dart';

import '../../shared/question_contract/question_contract.dart';
import 'gen/app_theme.g.dart';
import 'gen/part_exam_widgets.g.dart';
import 'gen/question_content_renderer.g.dart';

/// Dónde aparece la pregunta en la app (cambia la cabecera y la pestaña).
enum AppExamPlace {
  partExam('Examen de la parte', 'Tu examen', 1),
  simulator('Simulador', 'Simulador', 2);

  const AppExamPlace(this.label, this.appBarTitle, this.tabIndex);

  final String label;
  final String appBarTitle;
  final int tabIndex;
}

/// Pantalla «Tu examen» de la app con una pregunta del admin.
///
/// Es la misma composición que `_buildQuestionFlow` de
/// `iya-app/.../exam_view/part_exam_attempt_screen.dart` y la barra de
/// `iya-app/lib/app/routing/app_shell.dart`, armada con las piezas copiadas
/// por `tool/sync_app_preview.py` (tema, renderizador y widgets del examen).
/// Si cambia esa pantalla en la app, actualizar también esta composición.
class AppExamQuestionScreen extends StatelessWidget {
  const AppExamQuestionScreen({
    super.key,
    required this.statement,
    required this.alternatives,
    this.place = AppExamPlace.partExam,
    this.questionIndex = 0,
    this.questionCount = 10,
    this.answeredCount = 0,
    this.sourceLabel = '',
    this.sourceType = 'unknown',
    this.selectedAlternativeId,
    this.remaining,
  });

  final QuestionContent statement;
  final List<QuestionAlternative> alternatives;
  final AppExamPlace place;
  final int questionIndex;
  final int questionCount;
  final int answeredCount;
  final String sourceLabel;
  final String sourceType;
  final String? selectedAlternativeId;
  final String? remaining;

  static const _tabs = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.menu_book_rounded, 'Cursos'),
    (Icons.play_circle_rounded, 'Simulador'),
    (Icons.bar_chart_rounded, 'Stats'),
    (Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final simulator = place == AppExamPlace.simulator;
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackButton(),
        title: Text(place.appBarTitle),
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.onSurface,
        actions: [
          if (simulator)
            IconButton(
              tooltip: 'Pizarra',
              onPressed: () {},
              icon: const Icon(Icons.draw_outlined),
            ),
          IconButton(
            tooltip: 'Resumen de preguntas',
            onPressed: () {},
            icon: const Icon(Icons.grid_view_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            PartExamProgressHeader(
              questionIndex: questionIndex,
              questionCount: questionCount,
              answeredCount: answeredCount,
              remaining: remaining,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  if (sourceLabel.isNotEmpty) ...[
                    PartExamSourceCard(
                      sourceLabel: sourceLabel,
                      sourceType: sourceType,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: context.appColors.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREGUNTA ${questionIndex + 1}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: context.appColors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            container: true,
                            label: 'Enunciado',
                            child: QuestionContentRenderer(content: statement),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Selecciona una respuesta',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final alternative in alternatives) ...[
                    PartExamAlternativeTile(
                      alternative: alternative,
                      selectedAlternativeId: selectedAlternativeId,
                      enabled: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                border: Border(
                  top: BorderSide(color: context.appColors.outline),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: questionIndex == 0 ? null : () {},
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      child: Text(
                        questionIndex == questionCount - 1
                            ? 'Entregar'
                            : 'Siguiente',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AppShellBar(selected: place.tabIndex),
    );
  }
}

/// Barra inferior de `AppShell` (mismos colores, alto e indicador).
class _AppShellBar extends StatelessWidget {
  const _AppShellBar({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.onSurface.withValues(alpha: .08)),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colors.surface,
          elevation: 0,
          height: 72,
          indicatorColor: colors.primary.withValues(alpha: .22),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final on = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: onSurface.withValues(alpha: on ? .95 : .55),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final on = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              color: onSurface.withValues(alpha: on ? .92 : .55),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          destinations: [
            for (final (icon, label) in AppExamQuestionScreen._tabs)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
      ),
    );
  }
}

/// Teléfono con la app real dentro: tema de la app (oscuro clásico, el que
/// usan los alumnos por defecto) y tamaño lógico de un Android común
/// (360 × 780), escalado al ancho disponible.
class AppPhoneFrame extends StatelessWidget {
  const AppPhoneFrame({
    super.key,
    required this.child,
    this.width = 300,
    this.palette = AppColorPalette.classic,
  });

  final Widget child;
  final double width;
  final AppColorPalette palette;

  static const logicalSize = Size(360, 780);

  @override
  Widget build(BuildContext context) {
    final scale = (width - 16) / logicalSize.width;
    final base = AppTheme.forPalette(palette);
    // La app usa la fuente del sistema de Android (Roboto), incluida en el
    // admin para que la vista previa no dependa del navegador.
    TextStyle? roboto(TextStyle? s) => s?.copyWith(fontFamily: 'Roboto');
    ButtonStyle? withRoboto(ButtonStyle? style) => style?.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => roboto(style.textStyle?.resolve(states)),
      ),
    );
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: roboto(base.appBarTheme.titleTextStyle),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: withRoboto(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withRoboto(base.outlinedButtonTheme.style),
      ),
    );
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(34),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: SizedBox(
          width: logicalSize.width * scale,
          height: logicalSize.height * scale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(
              size: logicalSize,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: logicalSize,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  textScaler: TextScaler.noScaling,
                ),
                child: Theme(
                  data: theme,
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!,
                    child: Navigator(
                      onGenerateRoute: (_) => PageRouteBuilder<void>(
                        pageBuilder: (_, _, _) => child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
