# Regla de «Subtema completado» (v1)

Esta fase implementa la **concesión server-owned** del logro y una proyección
de lectura para Perfil. Todavía no agrega pantallas en la app.

## Requisito publicado

Functions lee curso, tema y subtema desde el catálogo del ambiente activo:
`{courses}/{courseId}/topics/{topicId}/subtopics/{subtopicId}`. Exige que los
tres documentos estén activos y toma únicamente los IDs de `listPart` cuya
parte está activa. No acepta desde el móvil una lista de partes, cantidad,
porcentaje o versión. Un catálogo vacío, inactivo, mal formado o con IDs
duplicados no puede conceder un logro.

La lista se ordena por ID y se versiona como
`parts-v1-${sha256(JSON.stringify([courseId, topicId, subtopicId, sortedActivePartIds]))}`.
Reordenar o renombrar partes no cambia el requisito; añadir, retirar o
desactivar una parte sí lo cambia. No se depende de un contador manual del
admin. `v1` identifica el algoritmo: cambiar su significado requiere `v2`.

## Evidencia y concesión

Cada parte requerida debe tener `partProgress.{partId}.schemaVersion: 2`,
contexto académico coincidente, evidencia `completedAt` de las cinco secciones,
`completed: true` y un `examAttemptId` aprobado por el servidor. Los campos
históricos de vistas, clics, notas y porcentajes locales no cuentan.

Sólo cuando una parte pasa a `verified`, la misma transacción de Functions
consulta el catálogo y evalúa el conjunto. Si todas las partes están
verificadas, crea un documento en
`{users}/{uid}/learningProgress/current/achievements/{requirementVersion}`.
El documento congela `requiredPartIds`, `requirementVersion`, IDs académicos,
`examAttemptId` de la última parte y `awardedAt` de servidor. Ese árbol es
ilegible e inmodificable directamente para el alumno; la futura UI recibirá
una proyección segura desde el backend.

La misma transacción actualiza
`{users}/{uid}/learningProgress/current/achievementSummary/current` con
`schemaVersion: 1`, `totalCompletedSubtopics`, `completedSubtopicKeys` y
`recent` (máximo cinco). La clave de subtema combina curso, tema y subtema;
una versión nueva de requisitos actualiza el elemento reciente pero no cuenta
otra insignia del mismo subtema. El resumen no contiene notas, intentos,
respuestas ni claves. También está protegido contra lecturas y escrituras
directas del alumno.

La callable autenticada `getAchievementSummary({})` devuelve ese resumen.
Sólo usa el `uid` del token, no acepta IDs proporcionados por la app. En el
caso habitual lee un solo documento; nunca recorre los intentos. Si existían
logros de la versión anterior sin resumen, la primera lectura reconstruye la
proyección desde los documentos de logros y la guarda; las siguientes vuelven
a leer sólo el resumen. También se hace esa reconstrucción si la primera
concesión nueva ocurre antes de que Perfil consulte la callable.

La concesión es idempotente: repetir `submitExamAttempt` o la confirmación de
secciones no reescribe el logro. Si el admin añade una parte más tarde, la
versión y el documento anterior permanecen intactos. El alumno podrá ganar
la nueva versión al verificar la parte nueva; Perfil mostrará una sola insignia
por subtema y el historial de versiones seguirá en los documentos de logros.

## Límites de esta fase

- No se conceden automáticamente logros retroactivos a subtemas verificados
  antes del despliegue. Un proceso de reconciliación deberá hacerlo de forma
  explícita y sin tratar progreso legacy como evidencia real.
- Un cambio del catálogo que reduzca las partes requeridas no crea por sí solo
  una nueva concesión; se necesita un evento de reconciliación. Nunca revoca
  un documento de logro ya emitido.
- Las lecturas adicionales del catálogo ocurren sólo cuando una parte queda
  verificada por primera vez; los guardados ordinarios y reintentos no pagan
  ese costo.
- `completedSubtopicKeys` es una lista compacta de claves de subtema dentro de
  un solo documento Firestore. Si el catálogo crece hasta acercarse al límite
  de 1 MiB por documento, habrá que paginar esa proyección antes de alcanzar
  el límite; no se deben consultar intentos desde Perfil.
