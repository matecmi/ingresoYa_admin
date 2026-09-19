# Etapa 2 · Catálogo de exámenes de origen

En Universidades → detalle → **Exámenes de origen** se pueden registrar y editar
exámenes. Primero se registran las modalidades de la universidad. Cada examen tiene
tipo (admisión, práctica oficial u otro), nombre completo, modalidad, año (1900–2100),
período (I, II, III o sin período), referencia opcional al documento original y estado.
«Usar nombre sugerido» construye el nombre con modalidad, año y período, pero se puede
escribir otro nombre completo. La etiqueta concatena la sigla y ese nombre, sin repetir
automáticamente año ni período: `UNPRG - EXAMEN DE ADMISIÓN ORDINARIO 2015 I`.

Los registros se guardan en `iya-universities-test/{universityId}/admissionExams/{id}`.
Los exámenes inactivos dejan de ofrecerse a nuevas selecciones. No se eliminan desde
esta pantalla para proteger las referencias históricas.

En Preguntas, curso → tema y universidad → examen son desplegables dependientes.
Cambiar el padre limpia la selección hija. No se escriben IDs manualmente. Las lecturas
son streams compartidos por Riverpod mientras hay consumidores; los temas y exámenes
se consultan solo dentro del padre elegido, sin recorrer todos los catálogos.

La pregunta conserva los IDs y campos de filtro `universityId`, `examId`, `modalityId`,
`year`, `period`, `courseId`, `topicId`; también guarda `sourceExam` compatible con el
contrato v2, `sourceType`, etiqueta y una instantánea editorial `admissionExam`.
Al corregir el examen, las preguntas vinculadas reciben los datos de origen actuales,
sin modificar su contenido ni su clasificación. Crear o editar una pregunta vuelve a
leer el examen en una transacción para no guardar los datos de un formulario obsoleto.

Las preguntas antiguas sin origen estructurado conservan su examId/label al editar
solo contenido. Si se comienza a elegir universidad, es obligatorio elegir también
el examen. Los IDs antiguos que no estén en el catálogo se muestran como registros
guardados no disponibles; no se borran silenciosamente.

Validación local: `flutter test test/admission_catalog_test.dart` verifica catálogos
por universidad, metadatos guardados, etiquetas, cambios de padre y validación de
modalidad/período. Las reglas existentes del catálogo cubren esta subcolección.

## Convocatorias únicas y revisiones

Una convocatoria se identifica por universidad + tipo + modalidad + año + período.
Renombrar o desactivar un examen no permite duplicar esa convocatoria.
`admissionExamKeys/{key}` reserva transaccionalmente cada combinación dentro de la
universidad; la clave codifica los cuatro campos restantes en base64url. Se comprueban
también los registros del mismo año creados antes de las reservas. Al cambiar una
convocatoria se libera su reserva anterior en la misma transacción.

`revision` impide que dos formularios sobrescriban sus modificaciones silenciosamente.
La modalidad debe existir bajo la universidad elegida. Los nombres y siglas se leen
de sus documentos al guardar. No se crean exámenes con modalidades/universidades
inactivas. Estas garantías corresponden al flujo del admin; escrituras manuales en
consola o clientes antiguos que omitan el repositorio deben evitarse.

## Sincronización y recuperación

1. Guardar el examen incrementa su revisión y marca `syncPending: true`.
2. Se consultan preguntas por `examId` en páginas de 100 ordenadas por ID.
3. Cada página vuelve a leer el examen y las preguntas dentro de una transacción.
   Solo se actualizan los campos de origen y fecha de modificación de las preguntas
   que aún pertenecen a esa universidad y examen y no tienen la revisión actual.
4. Se limpia `syncPending` si la revisión no cambió durante el recorrido.

No se atribuye universidad a registros antiguos que solo tengan un `examId`.
Si se interrumpe la red o se cierra el navegador, el examen queda guardado y la lista
muestra la actualización pendiente. Se puede reintentar desde el formulario o con
el icono de sincronización de la lista. Recorrer nuevamente las páginas es idempotente.
Es un proceso del admin: tras una interrupción, alguien debe reintentar los pendientes.

La consulta utiliza el índice automático de `examId`. Hay una consulta por página y
una lectura transaccional por pregunta, además de las del examen. Solo se escriben
preguntas desactualizadas. Los intentos y versiones publicadas se implementarán en
etapas posteriores con sus propias instantáneas históricas.

## Validación y entrega

`test/exam_catalog_completion_test.dart` cubre duplicados, registros antiguos e
inactivos, cambios de reserva, ediciones obsoletas, más de 200 preguntas, recuperación
tras fallo y formularios con datos antiguos. El contrato se prueba en ambos proyectos.
Las pruebas usan Firestore simulado; no crean datos de prueba en Firebase real.
La validación con permisos reales y despliegue se hará en el entorno de pruebas antes
de producción. Esta etapa no implementa publicación, generación ni calificación.
