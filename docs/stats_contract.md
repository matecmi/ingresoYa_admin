# Contrato de Estadísticas

Compartido por el admin, Functions y la app (`iya-app/docs/stats_contract.md`
es una copia). Diseño: lienzo «Estadísticas · propuestas», versión unificada
(https://claude.ai/artifact/SzGq25RdwKBtEniJi1795K), elegida por Kevin el
2026-10-20.

## 1. Qué muestra la app

La pestaña Estadísticas (`/stats`) tiene historias de la semana arriba y tres
pestañas:

| Pestaña | Contenido |
| --- | --- |
| Resumen | «Tu camino al ingreso» (medio anillo con el acierto del alumno y la marca «Ingreso N %», cuánto le falta para ingresar a su carrera y proyección al día del examen), «El búho te dice» (hallazgos con su acción), «Lo que más te acerca a <carrera>» y «Tus días de estudio» (calendario, racha y totales) |
| Guía | Solo la guía de estudio (el acierto del Simulador está en Resumen y Números): avance total como en Inicio, subtemas completados y dominados, y cada curso con sus temas como cuadros según las partes aprobadas («sin empezar», «en curso», «completo»; borde dorado si todos sus subtemas están dominados). Tocar un tema muestra sus partes y subtemas y «Seguir en la guía» (primer subtema que le falta) o «Repasar en la guía» |
| Números | Periodo (7, 30, 90 días o Todo), cuatro indicadores (acierto con su cambio frente al periodo anterior, preguntas, simulacros, ritmo), curva del acierto y detalle por curso |

Las historias (`/stats/story/:index`, pantalla completa) son: la semana
(preguntas contra la semana anterior, se puede compartir), el mejor curso, el
mejor examen, la racha y en qué enfocarse (con «Practicar»). Solo aparecen las
que tienen algo que contar.

En los textos de cara al alumno no se usa «corte»: se dice «Ingreso N %»,
«para ingresar a <carrera>» o «lo que más te acerca a <carrera>».

## 2. De dónde sale cada dato

No hay colecciones nuevas. Al abrir Estadísticas la app lee:

| Dato | Fuente | Costo |
| --- | --- | --- |
| Totales y los últimos 200 resultados | `{perfil}/simulatorSummary/current` (`totals`, `topics`, `recentResults`) | 1 lectura, compartida con el Simulador |
| Puntaje de ingreso a la carrera y reglas del examen | `{universities}/{id}/admissionExams` de la universidad del alumno (`simulator.cutoffs`, `maxScore`, puntos, duración) | Una lectura por examen, una vez por sesión |
| Ajustes | `{config}/stats` dentro de `{config}/app` | Ya leído al iniciar |
| XP de la semana, racha, avance de la guía por tema (partes aprobadas, mismo cálculo que Inicio), subtemas dominados, cursos | `xp/current`, plan, progreso local, resumen de logros, catálogo en caché | Ya en memoria |

Cambiar de pestaña o de periodo no lee nada. Tras entregar un examen se
invalidan los resultados como en el resto del Simulador.

### Cálculos (app, `lib/features/statistics/domain/stats_analysis.dart`)

- **Acierto**: correctas ÷ preguntas (igual que `SimulatorTotals.ratio`).
- **Puntaje de ingreso**: examen pasado más reciente de su universidad con
  `cutoffs[professionId]`. El acierto necesario, respondiendo todas, es
  `(cutoff/maxScore · correctPoints − incorrectPoints) / (correctPoints −
  incorrectPoints)`.
- **Proyección**: mínimos cuadrados ponderados por preguntas sobre los
  resultados (tope ±20 puntos por semana); necesita `projectionMinDays` de
  historia y la fecha del examen (`nextExam` de la universidad o el mes del
  plan).
- **Lo que más te acerca**: preguntas por curso del último examen pasado del
  alumno × (acierto necesario − acierto del curso). Sin examen pasado, se
  ordena por lo respondido y no se muestra «+N».
- **Hallazgos** (cada grupo con al menos `insightMinQuestions` preguntas): curso
  que subió o bajó (mitad antigua contra mitad reciente de los resultados),
  mejor franja horaria (mañana 5–12, tarde 12–19, noche), curso con muchas
  blancas (`blankWarnPercent`; el consejo cambia si el examen resta por
  incorrecta) y ritmo rápido (menos de `fastPacePercent` del tiempo por pregunta
  del examen, o del tamaño de práctica por defecto, y acierto por debajo de la
  meta).
- **Calendario y racha**: preguntas por día de los últimos 200 resultados; la
  racha máxima usa las mismas reglas que el plan (`minQuestionsPerSession`,
  `streakGraceDays`, `freeExamsCount`).
- **Ventanas de Números**: los últimos 200 resultados (antes, los últimos 60,
  lo que dejaba sin historia a quien rendía mucho); «Todo» usa los totales
  exactos del servidor.

## 3. Configuración `{config}/stats`

Editable en Configuración → Estadísticas. Si falta un campo o está fuera de
rango se usa el valor de fábrica. Viaja dentro de `{config}/app`
(`APP_CONFIG_SECTIONS`).

| Campo | Fábrica | Rango | Uso |
| --- | --- | --- | --- |
| `insightsEnabled` | `true` | — | Muestra «El búho te dice» |
| `storiesEnabled` | `true` | — | Muestra las historias de la semana |
| `insightMinQuestions` | 20 | 5–200 | Preguntas por grupo antes de un hallazgo |
| `insightMinGapPoints` | 10 | 1–50 | Diferencia de acierto para «mejor hora» o «subió» |
| `blankWarnPercent` | 25 | 5–90 | % en blanco de un curso que dispara el aviso |
| `fastPacePercent` | 50 | 10–90 | Por debajo de este % del tiempo por pregunta, «vas rápido» |
| `projectionMinDays` | 7 | 3–60 | Días de historia para proyectar |
| `focusCourses` | 3 | 1–5 | Cursos de «Lo que más te acerca» |
| `calendarWeeks` | 12 | 4–26 | Semanas del calendario |

Admin: `lib/src/domain/stats_settings.dart`, `AppConfigRepo.watchStatsSettings`
/ `saveStatsSettings`, tema «Estadísticas» del catálogo
(`settings_catalog.dart`). App: `lib/features/statistics/domain/stats_settings.dart`
y `statsSettingsProvider`.
