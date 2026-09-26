# Migración segura de preguntas legacy

`LegacyQuestionMigrationRepo` convierte registros del banco anterior al contrato v2 sin publicar ninguno. Es un proceso exclusivo para administradores: las reglas sólo permiten leer o escribir sus reportes en `iya-question-migration-runs-{entorno}` con el claim `admin`.

## Ejecución

Primero se ejecuta un lote en modo de vista previa:

```dart
final repo = LegacyQuestionMigrationRepo(FirebaseFirestore.instance);
final preview = await repo.runBatch(dryRun: true, batchSize: 20);
```

El resultado contiene `runId`, la lista de documentos revisados y el cursor. Cada decisión también queda en `iya-question-migration-runs-{entorno}/{runId}/items/{questionId}`. Para continuar exactamente el mismo recorrido, se usa el `runId` con el mismo modo:

```dart
await repo.runBatch(dryRun: true, runId: preview.runId, batchSize: 20);
```

Después de revisar el reporte, una ejecución real empieza con otro proceso (`dryRun: false`). Un proceso no puede cambiar de modo. Cada lote está limitado a 50 preguntas (20 por defecto), se ordena por ID y guarda el cursor; nunca carga todo el banco en memoria.

## Qué transforma

- Conserva `statementText` y crea `content` v2, usando un bloque `legacy` cuando el texto debe revisar su formato.
- Lee la subcolección legacy `alternatives`, conserva sus IDs, normaliza los labels a A, B, C… y crea las alternativas públicas dentro del documento raíz.
- Cuando hay exactamente una alternativa correcta, crea `questionAnswerKeys/{questionId}_1` con la explicación de la colección privada. La clave y la explicación nunca se escriben en la pregunta pública.
- Asigna `questionId`, `version: 1`, `schemaVersion: 2` y `status: draft`.
- Copia una procedencia sólo cuando `universityId` y `examId` señalan exactamente a un examen del catálogo. Un label, nombre, año o modalidad legacy no se interpreta para inventar una procedencia.

## Casos manuales y respaldo

Alternativas correctas múltiples, IDs de alternativas inválidos y `partIds` duplicados se clasifican como `manual`: el documento legacy no cambia. La ausencia de explicación, clasificación incompleta o menos de dos alternativas sí puede migrar a borrador, pero impide su publicación mediante las validaciones editoriales existentes.

La escritura real usa un marcador `migration`, conserva los campos legacy en el documento raíz, no borra la subcolección `alternatives` ni la explicación privada y registra sus rutas, IDs de alternativas y campos originales relevantes en el reporte. Esto constituye un respaldo lógico y permite inspección o reversión editorial sin pérdida automática.

## Idempotencia

La marca `migration.name = legacy-question-to-v2-draft-v1` hace que una nueva ejecución salte una pregunta ya convertida. Si ya existe una clave privada v2, la migración nunca la sobrescribe. Reintentar un lote o reanudar un `runId` por tanto no crea otra versión, no duplica la clave ni publica la pregunta.

No se despliegan reglas ni se ejecuta esta migración contra datos reales como parte de este cambio.
