# Contrato: sección Universidades (ficha para el alumno)

Diseño: lienzo «Noticias IngresoYa» (https://claude.ai/artifact/D4E2FpduabooX7xD5zMZsw), pantallas «Universidades · Directorio», «Ficha UNPRG» y «Ficha de carrera».

Todo vive en el documento de la universidad `iya-universities-{env}/{id}` (catálogo: el alumno con sesión lo lee, el admin con `universities:e` lo escribe; el historial lo anota con `auditUniversities`). **Los datos se cargan desde el admin y deben salir de fuentes oficiales**: la app nunca los inventa ni los calcula.

## Campos

| Campo | Tipo | Notas |
|---|---|---|
| `name`, `acronym`, `professions[]`, `modes[]`, `nextExam` | existentes | `professions[]` = carreras de la universidad (`id`, `name`, `acronym`, `active`). `nextExam` = `{name, at}` (contrato de noticias) |
| `faculties` | `[{id, name, acronym, active}]` | «Facultad de Ingeniería Civil, de Sistemas y de Arquitectura» · `FICSA` (sigla en mayúsculas, única en la universidad) |
| `careerDetails` | `{ [careerId]: {...} }` | Ver abajo. La clave es el `id` de `professions[]` |
| `profile` | mapa | Ver abajo |
| `identity` | mapa | Identidad para el alumno (abajo). Ausente: la app queda como siempre |

`careerDetails.{careerId}`:

| Campo | Tipo | Notas |
|---|---|---|
| `facultyId` | string | `''` = sin facultad (al quitar una facultad, sus carreras quedan así) |
| `vacancies` | int \| null | 0–5000, del proceso `scorePeriod` |
| `minScore`, `maxScore` | number \| null | 0–5000; mínimo ≤ máximo |
| `scorePeriod` | string | Obligatorio si hay vacantes o puntajes: «2026-I» |
| `durationYears` | int \| null | 1–10 |
| `degree` | string | «Ingeniero Civil» |
| `officialUrl` | string | `https://…` |
| `description` | string | Breve |

`profile`:

| Campo | Tipo | Notas |
|---|---|---|
| `visible` | bool | `false`: la app solo muestra el nombre en el directorio |
| `summary` | string | ≤ 600 |
| `type` | `''` \| `public` \| `private` | |
| `foundedYear` | int \| null | |
| `links` | `[{kind, url, label}]` | `kind`: `website`, `admission`, `facebook`, `instagram`, `tiktok`, `youtube`, `map`, `other`; `url` https |
| `admissionInfo` | string | Modalidades y requisitos en pocas líneas |
| `admissionDates` | `[{label, at}]` | Calendario de admisión, ordenado por fecha |
| `source` | string | Obligatorio si `visible`: «Prospecto de admisión 2026-I» |
| `sourceCheckedAt` | timestamp \| null | Última revisión de los datos |

`identity` (lienzo «Personalización por universidad», https://claude.ai/artifact/Cy1v2BPPwUaY1UqAqAJcBQ, 2026-10-29):

| Campo | Tipo | Notas |
|---|---|---|
| `primaryColor` | `#RRGGBB` | Bufanda del búho, confeti de las celebraciones (nunca en el dominio, que es dorado) y el puntito del chip de la cabecera. Sin él no hay bufanda |
| `secondaryColor` | `#RRGGBB` | Rayas de la bufanda y borla del birrete; sin él, blanco |
| `freshmanName` | string ≤ 24 | «cachimbo»: Inicio → «Tu examen · 33 días · para ser cachimbo» (con fecha confirmada). Vacío con colores: «ingresante» |
| `rankUpPhrase` | string ≤ 90 | Frase del búho al subir de rango; `{uni}` = sigla, `{nombre}` = nombre del alumno (sin nombre se va también la coma) |
| `showWouldHaveEntered` | bool (`true`) | Resultado de un examen pasado: «¡Con este puntaje habrías ingresado a {carrera}!» y «¿Y en otras carreras?» (las 4 más cercanas a su puntaje, con los `cutoffs` del examen que la app ya tiene) |

Sin escudos ni logos oficiales (marcas registradas): solo colores y texto. La app no suma lecturas: todo viene en el documento de la universidad que ya lee una vez por sesión.

## Admin

Universidades → ficha → «Ficha para el alumno» (`/universities/:id/ficha`): pestañas Resumen y enlaces (con fuente y «Marcar revisada hoy»), Facultades (agregar, editar, quitar), Carreras (facultad, vacantes, puntajes con su proceso, duración, título, enlace) y Admisión (próximo examen, cómo es la admisión, calendario) e Identidad (colores con la vista previa del búho real, cómo llamar al ingresante, frase al subir de rango, «¿habrías ingresado?»; `UniversityRepo.setIdentity`). Muestra lo que falta. Las carreras de la universidad se siguen eligiendo en la pestaña «Profesiones».

## App (fases U2–U5)

Directorio (`/universities`), ficha de universidad y ficha de carrera; «Tu examen» del Inicio abre la ficha de la universidad del alumno. Muestra «Fuente: {source} · revisado el {fecha}» al final de cada ficha.
