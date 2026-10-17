# Perfiles y permisos del admin

Rediseño del admin, fase 2 (lienzo v3.1, tableros 13 y 14). Quién puede entrar al admin y qué puede hacer en cada sección. La seguridad real está en las **reglas de Firestore** y en las **Functions**: ocultar un menú no basta.

## Secciones y acciones

| Sección (`p.<clave>`) | Cubre |
|---|---|
| `questions` | Banco de preguntas, claves, explicaciones privadas, carga rápida. |
| `courses` | Cursos, temas, subtemas, partes y plantillas de examen. |
| `universities` | Universidades, modalidades, carreras y exámenes pasados. |
| `students` | Ficha del alumno, XP, nombres de usuario, rankings y reto del día de cada alumno. |
| `settings` | Configuración de la app (`{config}/*`). |
| `staff` | Perfiles y permisos (esta pantalla). |
| `history` | Historial de cambios y restaurar. |
| `production` | Pasar cambios de TEST a producción (recta final). |

Acciones, una letra cada una: `v` ver · `e` crear y editar · `p` publicar · `a` archivar o borrar.
Sin `p`, «Publicar» se convierte en **«Enviar a revisión»**: la pregunta queda en borrador con `review.status = "pending"` y la publica alguien con `p`.

## Perfiles de fábrica

| `roleId` | Nombre | Permisos |
|---|---|---|
| `owner` | Dueño | Todo. No se puede borrar ni quedar sin ninguno. Solo un Dueño asigna o quita el perfil Dueño. |
| `editor` | Editor de contenido | `questions:ve`, `courses:ve`, `universities:ve`, `settings:v`, `history:v` |
| `reviewer` | Revisor | `questions:vep`, `courses:vep`, `universities:vep`, `settings:v`, `history:v` |
| `support` | Soporte a alumnos | `students:ve`, `questions:v`, `courses:v`, `history:v` |
| `readonly` | Solo lectura | `v` en todo salvo `staff` y `production` |

Los perfiles de fábrica se pueden ajustar (salvo Dueño) y se pueden crear perfiles nuevos.

## Datos

- `iya-admin-roles-{env}/{roleId}`: `{name, description, perms: {<sección>: "vep"}, builtIn, updatedAt, updatedBy}`.
- `iya-admin-staff-{env}/{uid}`: `{uid, email, name, roleId, extra: {<sección>: "p"}, scope: {courseIds: [], universityIds: []}, status: "active" | "revoked", invitedBy, createdAt, updatedAt, lastSeenAt}`.
- `iya-admin-invites-{env}/{correo en minúsculas}`: `{email, roleId, extra, scope, invitedBy, createdAt, expiresAt}` (14 días).

Lectura: cualquier miembro activo lee los perfiles y su propia ficha; con `staff:v` lee todas. Escritura: **solo Functions**.

## Claims del token

`{admin: true, role: "<roleId>", p: {<sección>: "<letras>"}, cs?: [courseIds], us?: [universityIds]}`.
`p` es el perfil más las excepciones (`extra`). `cs`/`us` solo existen si hay alcance (máx. 20 ids). Un token con `admin: true` y sin `role` (cuentas anteriores a esta fase) se trata como **Dueño** hasta que `syncAdminAccess` crea su ficha.

## Callables

- `syncAdminAccess()` — la llama el admin al iniciar sesión. Crea la ficha desde una invitación pendiente (por correo), o como Dueño si el token ya era admin; recalcula los claims y responde `{active, roleId, changed}`. Si `changed`, el admin refresca el token.
- `manageAdminStaff({action, ...})` — requiere `staff:e` (verificado contra la ficha, no solo el token). Acciones: `invite {email, roleId, extra?, scope?}`, `update {uid, roleId?, extra?, scope?}`, `revoke {uid}` (quita claims y cierra sesiones), `cancelInvite {email}`, `saveRole {roleId?, name, description, perms}` (recalcula a sus miembros), `deleteRole {roleId}` (sin miembros y no de fábrica).

Errores (`details.reason`): `not_staff`, `staff_forbidden`, `owner_only`, `last_owner`, `self_revoke`, `role_not_found`, `role_in_use`, `builtin_role`, `invalid_permissions`, `invalid_scope`.

## Reglas (resumen)

`can(sección, letra)` = admin y (`role == "owner"` o la letra está en `p[sección]`). Las preguntas exigen `p` para dejar o tocar el estado `published` y crear `versions`, y `a` para `retired` o borrar. Cursos y preguntas respetan `cs` si existe.
