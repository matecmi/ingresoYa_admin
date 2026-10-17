# Historial de cambios del admin

Rediseño del admin, fase 6 (lienzo v3.1, tablero 12). Quién cambió qué en el admin, con el valor anterior y el nuevo, y cómo deshacerlo.

## Cómo se anota

Un disparador de Firestore por colección del admin (`functions/src/audit.ts`, región **us-central1** porque la base está en `nam5`) compara antes y después de cada escritura y agrega una entrada en `iya-admin-audit-{env}`:

| Disparador | Ruta |
|---|---|
| `auditQuestions` | `{questions}/{id}` |
| `auditCourses`, `auditTopics`, `auditSubtopics` | `{courses}/{id}`, `…/topics/{id}`, `…/subtopics/{id}` (las partes viven en `listPart`) |
| `auditTemplates` | `{templates}/{id}` |
| `auditUniversities`, `auditUniversityChildren` | `{universities}/{id}`, `{universities}/{u}/{sub}/{id}` |
| `auditProfessions` | `{professions}/{id}` |
| `auditConfig` | `{config}/{id}` |
| `auditStaff`, `auditStaffRoles` | fichas y perfiles del personal |

No se anotan los cambios que solo tocan campos automáticos (`updatedAt`, `createdAt`, `updatedBy`, `searchTokens`, `partSearchTokens`, `randomKey`, `lastSeenAt`, `publishedAt`).

## Entrada

`{at, actor: {uid, email, type: "user" | "system"}, path, docId, kindKey, section, kind: "create" | "update" | "delete" | "restore", title, changes: [{field, before, after}], statusBefore, statusAfter, before, after, tooLarge, restoredEntryId?}`

- `actor`: el usuario del admin (por el `authId` del evento y su ficha) o «Sistema» (Functions, scripts).
- `changes`: campos con su texto corto; mapas anidados como `league.promotePercent`; partes de `listPart` por id (`listPart «Aceleración».active`). Máximo 40.
- `before`/`after`: copia completa (hasta ≈180 KB; si es más grande, `tooLarge: true` y no se puede restaurar).

Lectura: `history:v` (reglas). Escritura: solo los disparadores.

## Restaurar — callable `restoreAuditEntry({entryId, force?})`

Requiere `history:v` y `e` en la sección del cambio (y `questions:p` si la pregunta estaba publicada). La restauración escribe el documento con `auditRestoredBy: {uid, email, entryId, at}`; el disparador la anota como `restore` a nombre de esa persona, así que también se puede deshacer.

| Caso | Qué hace |
|---|---|
| Cambio común | Vuelve a `before`. Si el documento cambió después (`changed_since`), solo con `force: true` (se pierden los cambios posteriores). |
| Eliminado | Lo vuelve a crear con `before` («Recuperar»). |
| Pregunta archivada (publicada → retirada) | La vuelve a publicar («Recuperar»). |
| Pregunta en borrador | Vuelve al borrador anterior. |
| Pregunta publicada editada | No: se edita y se publica una versión nueva (`question_restore_unsupported`). |
| Creación | No: se elimina desde su sección (`creation_restore_unsupported`). |

Errores (`details.reason`): `entry_not_found`, `staff_forbidden`, `changed_since`, `creation_restore_unsupported`, `question_restore_unsupported`, `too_large`.
