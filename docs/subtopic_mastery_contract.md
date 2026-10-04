# Contrato v2: Dominio del subtema

Esta especificación es compartida por `ingresoya_admin` e `iya-app`. Amplía el contrato v2 de exámenes sin modificar los flujos existentes `part_completion`, `practice` ni `simulation`.

## Plantilla y asociación

- La plantilla de examen conserva `schemaVersion: 2` y usa `purpose: subtopic_mastery`.
- En esta primera versión, `mode` debe ser `dynamic`. No se ofrece `fixed` para dominio; el parser compartido lo rechaza.
- El admin guarda la plantilla en la colección `iya-exam-templates-test` (o la variante del entorno) con ID técnico estable, `status: published` y `active: true`. Cada edición incrementa la versión inmutable.
- En el editor de subtemas, «Examen integrador» permite seleccionar **solo** plantillas publicadas, activas, dinámicas y de propósito `subtopic_mastery`. El ID elegido se guarda como `masteryTemplateId` en el documento existente del subtema, bajo `courses/{courseId}/topics/{topicId}/subtopics/{subtopicId}` de la colección configurada para el entorno. Los subtemas anteriores carecen de este campo; se interpretan como no asociados.
- Publicar la asociación: guardar la plantilla y luego seleccionar esa plantilla en el subtema y guardar el subtema. Retirar la asociación: seleccionar «Sin examen integrador» y guardar. Desactivar la plantilla la quita del selector e impide nuevas asociaciones; no borra la asociación ya persistida, por lo que conviene retirarla también del subtema si se desea quitar la oferta editorial. Las versiones e intentos anteriores no se borran.

## Solicitud a `createExamAttempt`

```json
{
  "requestId": "uuid-estable-para-reintentos",
  "purpose": "subtopic_mastery",
  "courseId": "course-1",
  "topicId": "topic-1",
  "subtopicId": "subtopic-1",
  "templateId": "mastery-v1"
}
```

El cliente reutiliza el mismo `requestId` al reintentar la creación. No envía `count`, `filters`, `selectionPolicy`, `partId`, porcentaje ni nota mínima; los campos adicionales se rechazan. Los identificadores de contexto son IDs técnicos del catálogo, no nombres visibles. El handler exige Firebase Auth (y App Check según el entorno); Functions comprueba que el curso, tema y subtema estén activos, que `masteryTemplateId` coincida con la plantilla solicitada, que esta esté publicada, activa y sea dinámica, y que exista una insignia **servidora** `subtopic_completed` para la misma clave académica. Si falta ese logro, el progreso histórico, el resumen local o un porcentaje enviado por el cliente no autorizan el examen.

Cada bloque dinámico se vincula al curso, tema y subtema solicitado. Puede restringir origen, universidad, dificultad u opcionalmente una parte de ese subtema, de acuerdo con la configuración editorial publicada; el cliente no controla esos filtros. Un bloque sin `partId` selecciona del subtema completo. La cantidad, duración, selección y exigencia de aprobación proceden exclusivamente de la plantilla. Se requieren índices compuestos adicionales de Firestore para las búsquedas de subtema sin `partIds` y la consulta puntual de la insignia verificada; están versionados en `firestore.indexes.json` y deberán publicarse junto con Functions en una fase de despliegue posterior.

La creación almacena en la colección de intentos configurada para el entorno el contexto académico, `templateId`, `templateVersion`, política/umbral congelados, versiones y orden de preguntas, alternativas públicas y hora de vencimiento. La clave `examRequestKeys/{requestId}` apunta al mismo `attemptId`: repetir la solicitud devuelve exactamente el intento ya congelado, aun si la plantilla fue editada o desactivada después. Reutilizar el `requestId` con otro propósito, contexto o plantilla se rechaza. Un fallo antes de confirmar la transacción no deja un intento parcial.

`getExamAttempt` y `saveExamAnswers` siguen disponibles y solo aceptan al propietario. La proyección anterior a la entrega contiene preguntas y respuestas del alumno, nunca `correctAlternativeId`, explicaciones ni documentos `answerKeys`. El intento v2 puede guardar opcionalmente `courseId`, `topicId` y `subtopicId`; los intentos anteriores sin ellos siguen siendo válidos. `submitExamAttempt` lee las claves privadas de las versiones congeladas, califica en servidor y responde con la revisión existente y, al aprobar dominio, `masteryUpdate: {courseId, topicId, subtopicId, mastered: true}`.

## Insignia y resumen de Perfil

Una entrega aprobada crea una sola insignia `type: subtopic_mastery` por clave `(courseId, topicId, subtopicId)`, con ID estable independiente de la versión de la plantilla. Guarda `templateId`, `templateVersion`, `examAttemptId` y fecha. La insignia y el resultado `submitted` se confirman en la **misma transacción**. Repetir `submitExamAttempt` no duplica insignias ni altera la primera concesión. Reprobar deja «Subtema completado» intacto y permite crear otro intento con un `requestId` nuevo. Desactivar o editar la plantilla después de iniciar no invalida la calificación del intento congelado.

`getAchievementSummary` conserva `schemaVersion: 1`, `totalCompletedSubtopics`, `completedSubtopicKeys` y `recent`, y agrega de forma aditiva `totalMasteredSubtopics`, `masteredSubtopicKeys` y `recentMastery` (máximo cinco entradas con contexto, plantilla, versión, intento y fecha). Perfil lee una sola proyección; no recorre todos los intentos. Una proyección antigua se reconstruye una vez desde las insignias servidoras. Los clientes actuales pueden ignorar los tres campos nuevos.

Ejemplo de la extensión del resumen (se omiten aquí los campos anteriores, que siguen presentes):

```json
{
  "totalMasteredSubtopics": 1,
  "masteredSubtopicKeys": ["[\"course-1\",\"topic-1\",\"subtopic-1\"]"],
  "recentMastery": [{
    "courseId": "course-1", "topicId": "topic-1", "subtopicId": "subtopic-1",
    "templateId": "mastery-v1", "templateVersion": 2,
    "examAttemptId": "attempt-123", "awardedAtMs": 1791111111111
  }]
}
```

Errores `HttpsError.details.reason` relevantes para el cliente: `mastery_prerequisite_missing` (sin logro verificado), `mastery_template_not_associated` (asociación retirada o distinta), `subtopic_not_available`, `template_not_published`, `template_incompatible`, `template_subtopic_mismatch`, `template_changed_retry` (reintentar creación), `request_id_conflict` (usar un ID nuevo para otra solicitud) y los errores existentes de intento/respuestas. La autenticación ausente conserva `authentication_required`.

## Alcance de esta entrega

El backend y el contrato están implementados y probados localmente, pero **no se desplegaron**. La pantalla del alumno y la presentación del nuevo logro en la app quedan para otro cambio. Hasta publicar Functions e índices y actualizar la app, la asociación editorial por sí sola no habilita el examen al alumno.
