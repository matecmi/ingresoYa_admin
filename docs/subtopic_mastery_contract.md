# Contrato editorial: Dominio del subtema (fase de preparación)

Esta especificación es compartida por `ingresoya_admin` e `iya-app`. Amplía el contrato v2 de exámenes sin modificar los flujos existentes `part_completion`, `practice` ni `simulation`.

## Plantilla y asociación

- La plantilla de examen conserva `schemaVersion: 2` y usa `purpose: subtopic_mastery`.
- En esta primera versión, `mode` debe ser `dynamic`. No se ofrece `fixed` para dominio; el parser compartido lo rechaza.
- El admin guarda la plantilla en la colección `iya-exam-templates-test` (o la variante del entorno) con ID técnico estable, `status: published` y `active: true`. Cada edición incrementa la versión inmutable.
- En el editor de subtemas, «Examen integrador» permite seleccionar **solo** plantillas publicadas, activas, dinámicas y de propósito `subtopic_mastery`. El ID elegido se guarda como `masteryTemplateId` en el documento existente del subtema, bajo `courses/{courseId}/topics/{topicId}/subtopics/{subtopicId}` de la colección configurada para el entorno. Los subtemas anteriores carecen de este campo; se interpretan como no asociados.
- Publicar la asociación: guardar la plantilla y luego seleccionar esa plantilla en el subtema y guardar el subtema. Retirar la asociación: seleccionar «Sin examen integrador» y guardar. Desactivar la plantilla la quita del selector e impide nuevas asociaciones; no borra la asociación ya persistida, por lo que conviene retirarla también del subtema si se desea quitar la oferta editorial. Las versiones e intentos anteriores no se borran.

## Solicitud futura a `createExamAttempt`

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

El cliente reutilizará el mismo `requestId` al reintentar la creación. No enviará `count`, `filters`, `selectionPolicy`, porcentaje ni nota mínima. Functions deberá comprobar sesión, pertenencia y prerrequisitos; resolver la asociación publicada y la configuración vigente; verificar que el `templateId` solicitado coincida con `masteryTemplateId`; y seleccionar/calificar preguntas según la plantilla. Los identificadores de contexto son los IDs técnicos del catálogo, no nombres visibles.

El intento v2 puede guardar opcionalmente `courseId`, `topicId` y `subtopicId` junto a los campos actuales. Los intentos previos sin ellos siguen siendo válidos. El contrato de preguntas, respuestas y resultados no cambia.

## Límite de esta entrega

La versión actual de Functions todavía valida únicamente `part_completion` para crear intentos. Esta fase **no** añade `subtopic_mastery` a Functions, no expone una pantalla/botón al alumno y no concede «Dominio del subtema». Configurar y publicar la plantilla o asociarla en el admin solo deja preparado el catálogo. No se deben invocar intentos de dominio en producción hasta implementar y probar la validación, idempotencia, calificación y concesión del logro en el backend.
