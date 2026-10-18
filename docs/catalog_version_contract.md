# Versión del catálogo (`{config}/catalog`)

Contrato compartido entre `ingresoya_admin` (quien lo escribe, desde Functions)
e `iya-app` (quien lo lee). Fase 2A de la reestructuración de costos
(2026-10-18).

## Problema

La app escuchaba la colección completa de cursos durante toda la sesión y
volvía a bajar el árbol de cada curso (1 + temas + subtemas lecturas, con las
lecciones embebidas) cada 30 minutos, aunque nada hubiera cambiado. El
selector de universidades del Simulador leía toda la colección en cada
apertura. Son lecturas y egreso que se repiten en cada sesión sin aportar nada.

## Documento

`{config}/catalog` en la colección de configuración del entorno
(`iya-config-test`, `iya-config-staging`, `iya-config`). Lectura: como el
resto del catálogo (reglas `isCatalog`). Escritura: solo el servidor.

| Campo | Tipo | Significado |
| --- | --- | --- |
| `coursesVersion` | number | Sube en 1 con cada cambio en un curso, tema o subtema (incluye sus partes) de cualquier curso. |
| `courseVersions` | map `{courseId: number}` | Sube en 1 el contador del curso tocado. Un curso sin entrada no ha cambiado desde que existe el documento. |
| `universitiesVersion` | number | Sube en 1 con cada cambio en una universidad o en sus subcolecciones (carreras, exámenes de admisión). |
| `updatedAt` | timestamp | Última subida. |

## Quién lo escribe

Los disparadores `audit*` de `functions/src/index.ts` (los mismos del
historial de cambios), tras anotar la escritura, llaman a
`bumpCatalogVersion` (`functions/src/catalog_version.ts`) con la familia que
corresponde:

| Disparador | Familia | Curso afectado |
| --- | --- | --- |
| `auditCourses` | courses | `{id}` |
| `auditTopics`, `auditSubtopics` | courses | `{c}` |
| `auditUniversities`, `auditUniversityChildren` | universities | — |

Un cambio que solo toca metadatos (`updatedAt`, `updatedBy`, …; ver
`onlyMetaChanged`) no sube la versión. El disparador `auditConfig` ignora
`{config}/catalog` para no anotar una entrada del historial por cada subida.

Si el documento no existe, el primer cambio lo crea (`set` con `merge`). En
TEST se creó a mano el 2026-10-18 con `coursesVersion: 1` y
`universitiesVersion: 1`.

## Cómo lo usa la app

- Al arrancar la Guía de estudio y al volver del segundo plano (con al menos
  5 minutos entre chequeos), lee `{config}/catalog` una vez
  (`FirestoreCatalogVersionRepository`). Tirar para refrescar fuerza el
  chequeo.
- **Resúmenes de cursos:** si `coursesVersion` es igual al guardado
  (`CatalogVersionStore`) y hay cursos en Hive, no lee la colección. Si no,
  la lee una vez (`get`, no listener) y guarda la versión.
- **Contenido de un curso:** cada curso en Hive guarda `contentVersion`. Se
  vuelve a bajar solo si `courseVersions[curso]` (0 si no hay entrada) es
  distinto del guardado. Ya no hay ventana de 30 minutos.
- **Universidades del Simulador:** la lista se conserva en memoria con
  `universitiesVersion`; se relee solo cuando cambia.
- **Sin red o sin documento** (`CatalogVersion.unknown`): lo guardado en Hive
  sirve tal cual; si no hay nada guardado, se baja como antes.

## Costo esperado

Segunda apertura de Inicio + un curso sin cambios: 1 lectura de catálogo en
vez de 1 + N cursos + 1 + T + S del árbol. Una edición en el admin cuesta a
cada alumno, en su siguiente arranque, la lectura de los resúmenes (N) y del
árbol del curso tocado, una sola vez.
