# Contrato: Noticias y fecha del examen

Diseño aprobado: lienzo «Noticias IngresoYa» (https://claude.ai/artifact/D4E2FpduabooX7xD5zMZsw), secciones «Noticias · cómo funciona», «Aviso con imagen» e «Inicio · versión final».

Copia en `../iya-app/docs/news_contract.md` (mantener iguales).

## 1. Colección `iya-news-{env}` (`iya-news-test`, `iya-news-staging`, `iya-news`)

Un documento por noticia. Lo escribe el admin; el servidor solo escribe `pushSentAt`.

| Campo | Tipo | Notas |
|---|---|---|
| `title` | string | 4–90 caracteres |
| `body` | string | Texto. Opcional si `image.mode == 'only'` |
| `category` | `notice` \| `admission` \| `appUpdate` \| `tip` | Aviso, Examen de admisión, Novedad de la app, Consejo |
| `priority` | `normal` \| `pinned` \| `urgent` | Ver §3 |
| `status` | `draft` \| `published` \| `archived` | La app solo lee `published` |
| `audience` | `all` \| `universities` | Informativo; manda `universityIds` |
| `universityIds` | string[] | Ids de documento de `iya-universities-{env}`. Vacío = todos |
| `universityLabels` | string[] | Siglas para la etiqueta «Solo UNPRG» |
| `publishAt` | timestamp | Antes de esta hora la app no la muestra (programada) |
| `expiresAt` | timestamp \| null | Obligatoria si `priority != normal`. Al vencer sale del Inicio y de historias; sigue en la lista («Anteriores») |
| `eventAt`, `eventLabel` | timestamp \| null, string | Cuenta regresiva («Faltan 3 días · Cierre de inscripciones») |
| `keyDates` | `[{label, at}]` | «Fechas clave» del detalle (máx. 6) |
| `image` | `{storagePath, url, width, height, alt, mode: 'only' \| 'withText'}` \| null | Imagen en Storage `news-public/{uuid}.{ext}` (≤ 2 MB, PNG/JPG/WebP). `url` es la URL de descarga: la app no usa Firebase Storage. `alt` obligatorio |
| `story` | `{enabled, color}` | También como historia. `color`: `violet` `blue` `red` `green` `amber` (si no hay imagen) |
| `action` | `{label, type: 'url' \| 'route', target}` \| null | Botón. `route` = ruta de go_router de la app (`/simulators`, `/admission_exams`, `/study_guide`, `/rankings`, `/practice?mode=mistakes`, `/profile`) |
| `push` | bool | Enviar notificación al publicarse (una vez) |
| `pushSentAt` | timestamp \| null | Solo el servidor |
| `createdAt/By`, `updatedAt/By` | | Del admin |

## 2. Reglas

- Firestore: el alumno (sesión iniciada) lee solo documentos con `status == 'published'` (las consultas deben filtrar `where('status', '==', 'published')`). Staff: `news:v` lee todo; `news:e` crea y edita borradores; publicar o tocar una publicada pide `news:p`; borrar `news:a`. `pushSentAt` no lo cambia ningún cliente.
- Storage `news-public/{file}`: leer con sesión; subir solo admin, ≤ 2 MB, `image/(png|jpeg|webp)`; no se reemplaza ni borra.
- Sección de permisos `news` («Noticias»): Editor `ve`, Revisor `vep`, Solo lectura `v`. Los perfiles ya guardados en Firestore no cambian solos: sumar «Noticias» desde «Perfiles y permisos».
- Historial: disparador `auditNews` (sección `news`).

## 3. Dónde la muestra la app

«Para su universidad» = `universityIds` vacío o contiene la universidad del perfil (`universityIdDoc`, si no `universityId`). Solo noticias visibles: `published`, `publishAt <= ahora`.

| Noticia | Ventana al abrir | Fijada en Inicio | Historias | Lista «Noticias» | Push |
|---|---|---|---|---|---|
| Urgente, para su universidad | Sí, una sola vez | Sí, hasta `expiresAt` | Si `story.enabled` | Arriba, en «Fijado» | Si `push` |
| Fijada, para su universidad | No | Sí, hasta `expiresAt` | Si `story.enabled` | Arriba, en «Fijado» | Si `push` |
| Normal, para su universidad | No | No | Si `story.enabled` | Por fecha | Si `push` |
| De otra universidad | Nunca | Nunca | Nunca | Solo en «Otras universidades», con «Solo {siglas}» | Nunca |

- Un solo fijado en el Inicio: la urgente más reciente; si no hay, la fijada más reciente.
- Ventana: la urgente vigente más reciente que el alumno no haya visto.
- Historias: `story.enabled`, vigentes y publicadas hace ≤ `storyDays`; las `maxStories` más nuevas.
- Leído: en el teléfono del alumno (SharedPreferences por usuario): ventanas vistas, historias vistas, noticias abiertas. Contador de no leídas en el atajo «Noticias».

## 4. Configuración `{config}/news`

| Campo | Fábrica | Límites |
|---|---|---|
| `urgentPerWeek` | 1 | 0–7 (por audiencia, lo aplica el admin al publicar) |
| `storyDays` | 7 | 1–30 |
| `maxStories` | 5 | 1–10 |

## 5. Fecha del próximo examen

Campo `nextExam: {name, at}` en el documento de la universidad (`iya-universities-{env}/{id}`). Se edita en el admin: Universidades → ficha → «Próximo examen de admisión». La app muestra «Tu examen · N días» en el Inicio; sin fecha, invita a ver la ficha de su universidad.

## 6. Notificaciones

Temas de FCM: `news-all-{env}` (todos) y `news-uni-{universityId}-{env}`. La app se suscribe a los dos al iniciar sesión (y cambia de tema si cambia de universidad). La Function `sendNewsPush` (disparador sobre `iya-news-{env}/{id}`) envía cuando la noticia está `published`, `push == true`, `pushSentAt == null` y `publishAt <= ahora`; las programadas las envía el job `sendScheduledNewsPush` (cada 15 min). Marca `pushSentAt`. Al tocar la notificación la app abre el detalle `/news/{id}`.
