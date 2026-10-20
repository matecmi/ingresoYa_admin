---
name: guias-vivas
description: mantener al día la Guía de la app y el documento de Arquitectura/servicios con cada cambio funcional o de diseño
metadata:
  node_type: memory
  type: feedback
  originSessionId: 45340872-5a5a-44b2-be34-077f4125e6ff
  modified: 2026-10-16T00:30:22.440Z
---

Kevin pidió (2026-10-15) dos documentos vivos: la **Guía de la app** (cada flujo: Simulador, Guía de estudio y los que se agreguen; pantallas, todos los mensajes y cuándo aparecen) y **Arquitectura y servicios** (gráfico: componentes, Functions, datos, secuencias, casuística).

**Why:** quiere una referencia definitiva de cómo funciona la app para él y el equipo; el lienzo de diseño no es el lugar para eso.

**How to apply:** en todo desarrollo/PR que cambie comportamiento o diseño (nuevo flujo, mensaje, regla, servicio, colección), actualizar ambos documentos en el mismo trabajo, sin preguntar, igual que [[progreso-docs-sync]]. Fuente y URLs: ver `docs/guias/README.md` del admin.
