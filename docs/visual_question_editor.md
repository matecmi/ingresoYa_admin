# Etapa 2 · Editor visual de preguntas

## Uso

1. Preguntas → crear o editar → Enunciado → Constructor.
2. «Agregar bloque» inserta texto, fórmula o imagen exactamente en esa posición.
3. En texto, cada fragmento permite negrita y cursiva; «Fórmula en línea» inserta
   una fórmula entre fragmentos. Agregar otro fragmento permite continuar la frase.
   Los saltos de línea se conservan. También se reconoce `\(x^2\)` en texto.
4. Fórmulas: escribir LaTeX o insertar una plantilla en la posición del cursor.
   Un error se muestra en la previsualización sin modificar el original.
5. Imágenes: seleccionar PNG/JPG/WebP, arrastrar un archivo o pegar una imagen
   con Ctrl+V/⌘V en web. En plataformas nativas se ofrecen selector y arrastre.
   Límite 5 MB. También se admite una URL HTTP(S).
6. Descripción accesible y pie son editables; tamaños 40 %, 70 % y 100 % mantienen
   la proporción. Reemplazar conserva descripción, pie, ID y tamaño de presentación.
7. Los botones de cada bloque permiten subir, bajar, duplicar y eliminar.
   Deshacer conserva hasta 50 cambios recientes, incluidos contenido y tamaños.
8. En pantallas amplias se muestra la vista de móvil al lado. En pantallas pequeñas,
   el botón de teléfono alterna entre edición y vista previa (máximo 390 px).
9. «Aplicar contenido» devuelve el resultado al formulario; **guardar la pregunta**
   lo persiste. Alternativas usan el mismo editor. La pestaña Explicación tiene
   su propio botón «Guardar explicación» y conserva la edición al cambiar de pestaña.

## Persistencia y compatibilidad

- `content` usa los bloques del contrato compartido de etapa 1 sin alterar su esquema.
- `contentSchemaVersion: 2` indica el formato del contenido dentro del documento
  administrativo existente. No se presenta ese documento como una QuestionDocument v2
  completa: la migración de catálogos, versiones y publicación pertenece a etapas posteriores.
- `contentPresentation: {blockId: fraction}` es metadato editorial adicional para
  tamaño relativo. `width` y `height` siguen siendo dimensiones intrínsecas en píxeles.
- Se mantienen `statementText` y `descriptionText` como proyección para clientes antiguos.
  La tipografía enriquecida y tamaños se conservan en v2; la app antigua no los representa.
  Los delimitadores reservados del formato antiguo siguen siendo una limitación de esa
  proyección, no del contenido v2.
- El contenido antiguo se mantiene en bloques `legacy` sin conversión destructiva.
- Explicaciones: colección `${questionsCollection}-editor-private`, fuera del árbol
  público. No se incluyen dentro del enunciado ni en su proyección antigua.
- Seleccionar una alternativa correcta guarda esa alternativa y desmarca las otras
  en un único batch. La futura publicación/versionado debe controlar también concurrencia.

## Imágenes e infraestructura

La carga usa Firebase Storage en `question-editor/<uuid>.<ext>` y conserva una URL
de descarga en el bloque (permitida por el contrato). Los nombres son inmutables para
que reemplazar y deshacer no rompan otras preguntas. La URL es de acceso por token;
no debe tratarse como un secreto o como protección de la respuesta.

Se incluyen `storage.rules` (carga exclusiva de administradores con claim `admin`)
y reglas Firestore para la colección editorial privada. **No se despliegan reglas
automáticamente.** Es necesario habilitar Storage y revisar/desplegar estas reglas
en el entorno Firebase elegido antes de verificar cargas reales.
Si el proyecto ya tiene reglas de Storage para otras carpetas, integrar esta regla
con las existentes antes de desplegar; este archivo solo describe el editor.

Errores de conexión/permisos muestran mensajes y conservan la edición. El usuario
puede reintentar. Cargas canceladas, imágenes eliminadas o descartadas pueden dejar
archivos sin referencias: la limpieza por referencias/antigüedad se implementará
con el ciclo de publicación de la siguiente etapa. No se eliminan archivos de Storage
desde el editor para proteger el historial y las preguntas ya guardadas.

No hay autoguardado tras cerrar el navegador. «Aplicar» no sustituye a «Guardar».
Los bloques con LaTeX inválido pueden guardarse como trabajo editorial para corregirlos;
la validación de publicación deberá impedir publicar contenido inválido.

## Validación

`flutter test test/content_editor_test.dart test/question_contract_v2_test.dart`
verifica serialización, guardado/reapertura mediante Firestore simulado, contenido
antiguo, alternativas y explicación separada, edición, deshacer, errores LaTeX,
arrastre/reintento de imagen con uploader simulado y vista de móvil.

La prueba de aceptación contra Firebase real queda separada: crear una pregunta con
texto → imagen subida → fórmula → texto, guardar, cerrar y reabrir; repetir en
alternativa y explicación. Requiere sesión con claim admin y reglas desplegadas.
