# Configuración fundida para la app (`{config}/app`)

Contrato compartido entre `ingresoya_admin` (lo escriben las Functions) e
`iya-app` (lo lee una vez por sesión). Fase 2B de la reestructuración de
costos (2026-10-18).

## Problema

La app leía siete documentos de `{config}` por sesión (`xp`, `rankings`,
`news`, `simulator`, `sync`, `study`, `exam`) más `catalog` en cada arranque,
cada uno con su propia lectura (y, hasta la Fase 2C, con listeners que se
volvían a facturar al reconectar).

## Documento

`{config}/app` en la colección de configuración del entorno. Lectura: como el
resto del catálogo (reglas `isCatalog`). Escritura: solo el servidor.

| Campo | Contenido |
| --- | --- |
| `xp`, `rankings`, `news`, `simulator`, `sync`, `study`, `exam`, `ads`, `premium`, `stats`, `catalog` | Copia del documento homónimo de `{config}`, sin `updatedAt`, `updatedBy` ni `schemaVersion`. Una sección ausente va como mapa vacío (la app aplica sus valores de fábrica). |
| `version` | Sube en 1 en cada reescritura. |
| `updatedAt` | Última reescritura. |

## Quién lo escribe

`functions/src/app_config.ts` (`publishAppConfig`): lee las ocho secciones
con un `getAll` y reescribe `{config}/app` con `set` + `merge`. Lo llama el
disparador `auditConfig` (`index.ts`) tras cada cambio real de un documento
de configuración (los cambios solo de metadatos no cuentan) y tras cada
subida de `{config}/catalog`. `auditConfig` ignora `{config}/app` para no
anotarlo en el historial ni entrar en bucle.

Costo por edición del admin: 8 lecturas y 1 escritura, además de las que ya
hacía el historial. Si el documento no existe (primer despliegue), la app cae
a los documentos individuales como antes.

## Cómo lo usa la app

- `ConfigDocs` (`lib/core/config/config_docs.dart`) e implementación
  `FirestoreConfigDocs` (`lib/infrastructure/firebase/`): lee `{config}/app`
  una vez, lo recuerda 5 minutos y entrega cada sección; con `force` relee.
- Lo reciben por constructor los lectores de configuración: noticias, XP,
  rankings, catálogo del Simulador, fuentes de `exam`, `study` y `sync`, y
  `FirestoreCatalogVersionRepository` (la versión del catálogo viaja dentro
  del mismo documento, con `force` en cada chequeo para respetar su propio
  intervalo).
- Una sola instancia por app (`configDocsProvider`,
  `lib/app/providers/config_docs_provider.dart`). En pruebas se pasa
  `FixedConfigDocs` o se omite (lectura directa, como antes).

## Costo esperado

Por sesión: 1 lectura de configuración (más 1 por cada chequeo forzado de la
versión del catálogo al volver del segundo plano o refrescar) en vez de 7 a 8.
