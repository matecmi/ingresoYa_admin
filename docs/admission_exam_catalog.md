# Catálogo de exámenes y clasificación de preguntas

En Universidades → detalle → **Exámenes de admisión** se pueden registrar y editar
exámenes. Primero se registran las modalidades de la universidad. Cada examen tiene
nombre completo, modalidad, año (1900–2100), período (I, II, III o sin período) y estado.
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
Cambiar el catálogo no modifica en masa las preguntas antiguas. Para actualizar su
origen se selecciona nuevamente el examen y se guarda la pregunta.

Las preguntas antiguas sin origen estructurado conservan su examId/label al editar
solo contenido. Si se comienza a elegir universidad, es obligatorio elegir también
el examen. Los IDs antiguos que no estén en el catálogo se muestran como registros
guardados no disponibles; no se borran silenciosamente.

Validación local: `flutter test test/admission_catalog_test.dart` verifica catálogos
por universidad, metadatos guardados, etiquetas, cambios de padre y validación de
modalidad/período. Las reglas existentes del catálogo cubren esta subcolección.
