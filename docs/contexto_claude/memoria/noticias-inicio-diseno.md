---
name: noticias-inicio-diseno
description: "Lienzo y decisiones de diseño de Noticias (aviso por universidad + historias), Inicio nuevo y Universidades (2026-10-16)"
metadata:
  node_type: memory
  type: project
  originSessionId: 03e8cd9f-e16b-40e6-be08-29054e5acaea
  modified: 2026-10-17T04:20:53.147Z
---

Lienzo de diseño: https://claude.ai/artifact/D4E2FpduabooX7xD5zMZsw (Noticias, Inicio, Universidades, ideas extra).

Decisiones de Kevin (2026-10-16):
- Noticias = Propuesta 3 + 4. Aviso importante con audiencia elegida en el admin: General o Por universidad (una o varias). Alumnos de esa universidad: ventana al abrir + fijado en el Inicio. Los demás lo ven solo en la lista de Noticias, con la etiqueta «Solo UNPRG».
- Historias en el Inicio. Cada una con «Ver noticia completa» (detalle) y «Todas las noticias» (lista).
- Inicio: rechazó la 1.ª ronda (H1–H5). Lo que pide: ver lo pendiente, el % de la guía, los días que faltan para su examen y acceso fácil a los demás apartados. 2.ª ronda N1–N4; elegida la versión final «F-Inicio» (2026-10-17): base B (dos contadores + 1 pendiente destacado + aviso fijado + historias + 4 atajos), la frase de ritmo y la marca de ritmo ideal de C, «Ver los 3» → pantalla «Tus pendientes», y el búho OwlMascot (feliz) junto al saludo. Fecha del examen por universidad, en el admin.
- Noticias, funcionamiento final en el lienzo (2026-10-17, sección «Noticias · cómo funciona»): colección `news/{id}` (priority normal|pinned|urgent, audience all|universities + universityIds, publishAt/expiresAt/eventAt, story opcional, action, push), lecturas en `{perfil}/newsReads`, parámetros en `{config}/news` (1 urgente/semana, historia 7 días, máx. 5 historias). Solo un fijado en el Inicio a la vez. Imagen opcional (comunicados): `image {url, alt, mode only|withText}` en Storage, vertical 4:5; la ventana la muestra grande y se amplía a pantalla completa (zoom, Compartir, Guardar).
- Universidades (directorio, ficha de universidad, ficha de carrera): pedida por Kevin, diseño en el lienzo, sin implementar.

**Why:** son la base para implementar sin volver a preguntar.
**How to apply:** al implementar, la configuración va en el admin ([[parametros-en-admin]]), las pantallas tienen que ser iguales a la app ([[pantallas-app-identicas]]) y hay que actualizar las guías ([[guias-vivas]]).

Implementado (2026-10-17, rama `codex/noticias-inicio`): PR admin matecmi/ingresoYa_admin#88 (fusionado el 2026-10-18) y PR app matecmi/IngresoYa#105 (ver PROGRESO.md). Desplegado en TEST: reglas de Firestore, índice y Functions. Firebase Storage activado en TEST el 2026-10-18 (bucket us-central1) con storage.rules desplegadas. Diferencia con el lienzo: el contador del examen abre Exámenes pasados (aún no hay ficha de universidad) y el atajo «Universidades» se cambió por «Noticias»; no hay marca de «ritmo ideal».
