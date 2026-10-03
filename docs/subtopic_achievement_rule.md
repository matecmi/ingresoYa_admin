# Regla de «Subtema completado» (v1)

Esta fase implementa la **concesión server-owned** del logro. Todavía no
agrega pantallas ni una API pública para listar logros en la app.

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

La concesión es idempotente: repetir `submitExamAttempt` o la confirmación de
secciones no reescribe el logro. Si el admin añade una parte más tarde, la
versión y el documento anterior permanecen intactos. El alumno podrá ganar
la nueva versión al verificar la parte nueva; la presentación futura deberá
mostrar una sola insignia vigente y conservar el historial de versiones.

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
