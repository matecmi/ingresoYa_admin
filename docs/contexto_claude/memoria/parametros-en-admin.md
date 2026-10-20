---
name: parametros-en-admin
description: "Todo parámetro que pueda cambiar en el futuro se configura desde ingresoya_admin, no fijo en la app"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 45340872-5a5a-44b2-be34-077f4125e6ff
  modified: 2026-10-15T04:49:17.973Z
---

Cualquier valor de negocio que podría ajustarse después (tamaños de examen, umbrales, porcentajes, días, reglas de puntaje, visibilidad) va en el admin, normalmente en un documento `{config}/<módulo>` (como `{config}/study`) o en el registro que corresponda (p. ej. reglas por examen pasado en el catálogo de exámenes de origen). La app y Functions lo leen y solo usan un valor de fábrica si falta.

**Why:** Kevin lo pidió explícitamente (2026-10-14, diseño del Simulador) «para un mejor manejo»; ya se aplicó con las reglas de «Revisado» de la guía.

**How to apply:** al diseñar o programar un módulo, listar sus parámetros y proponer dónde viven en el admin; no fijar números en el código. Las preferencias propias del alumno (fecha de su examen, recordatorio) quedan en su perfil, no en el admin. Ver [[progreso-docs-sync]].
