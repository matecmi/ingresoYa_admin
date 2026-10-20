---
name: revision-examen-propuestas
description: Revisión por pregunta renovada y validada en el teléfono (app #124/#125, admin #108/#109, 2026-10-19); quedan la propuesta 3 y el resto de la 4
metadata:
  node_type: memory
  type: project
  originSessionId: 040734b8-b867-4e16-8b29-ba048341054a
  modified: 2026-10-19T17:30:37.156Z
---

Lienzo: https://claude.ai/artifact/EAfyEe5ScqWQ7zPvfYExFk (capturas reales de hoy + 4 propuestas). La tarjeta actual es `_QuestionReviewCard` en `iya-app/.../exam_view/part_exam_result_screen.dart`, usada por el examen de parte y por `SimulatorReviewScreen`.

Propuestas: (1) tarjeta legible cerrada + todas las alternativas, rojo/gris/verde; (2) filtros Falladas/En blanco/Correctas/Todas + cuadrícula 1–20; (3) repaso una por una a pantalla completa con «Siguiente error»; (4) aprende del error: ir a la guía (el servidor ya manda courseId/topicId/subtopicId/partIds), parecidas, «Mis errores», reportar, un video abre todas las explicaciones (parámetro del admin).

**Implementado (2026-10-19):** Kevin eligió 1 + 2 + «Ver en la guía» de la 4. `ExamReviewSection` en `exam_view/part_exam_review.dart`; fusionado en `desarrollo` (app #124, admin #108); guía v24, arquitectura v29. Pulido tras probar en el teléfono (app #125, admin #109): etiqueta bajo la alternativa, una línea de enunciado que se desvanece, «En blanco», salto del mapa arriba; validado todo incluido «Ver en la guía»; captura real en la guía v25. Quedan sin hacer la 3 (una por una) y el resto de la 4 (Mis errores, parecidas, un video para todas).

**Why:** Kevin pidió 4 propuestas antes de implementar.
**How to apply:** cuando elija, implementar respetando [[pantallas-app-identicas]], [[parametros-en-admin]] y [[guias-vivas]].

**Candado del video (2026-10-19):** en el mismo lienzo, fila «Candado del video · cuatro propuestas» con captura real y A (búho explica + adelanto difuminado), B (recompensa +5 XP, requiere regla de XP en servidor/admin), C (un video abre todas las explicaciones, interruptor en {config}/ads), D (pista gratis = primer bloque de la explicación, resto con video). Esperando que Kevin elija.

**Elegida A + B (2026-10-19):** plantilla en el lienzo, fila «Elegida: A + B combinadas» (AB1 completa en la primera fallada, AB2 compacta en las siguientes, AB3 después del video con +5 XP). Reglas de XP propuestas: 5 XP por explicación, tope diario 25, una vez por pregunta fallada en exámenes entregados, parámetros en {config}/xp; pasado el tope el video abre igual sin XP. Falta que Kevin apruebe la plantilla para implementar (app + Function + admin).

**Cambio (2026-10-19):** Kevin descartó la pista/adelanto (A): solo la B, más compacta. Lienzo fila «Elegida: B compacta» (B1-compacta: degradado + búho guiñando + «Desbloquea la explicación · Ganas +5 XP · te quedan 25 XP hoy» + botones «Ver video · +5 XP» y «Premium»; AB3 después del video). Misma tarjeta en cada fallada.

**Implementado (2026-10-19, app #126, admin #110, Functions desplegadas en TEST):** candado B compacto con XP. Servidor: evento `explanation_video` (5 XP, tope propio 25/día en `today.explained`), callable `claimExplanationXp`; la corrección sale de la clave congelada (`answerKeys`), porque la revisión no se guarda en el intento. App: `ExplanationVideoCard`/`ExplanationOpenBox` en `exam_view/widgets/explanation_video_card.dart`, `RewardedUnlock.watch()` → solo `earned` da XP. Validado en el teléfono. Pendiente opcional: verificación SSV de AdMob desde el servidor.
