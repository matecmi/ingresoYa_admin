# Guías vivas de IngresoYa

Dos documentos que se mantienen al día con cada cambio funcional o de diseño, en los dos repos (`ingresoya_admin` e `iya-app`).

| Documento | Fuente | Publicado en |
|---|---|---|
| **Guía de IngresoYa**: cada pantalla de la app, todos sus mensajes y cuándo aparecen (Inicio, Guía de estudio, Simulador y los flujos que se agreguen). | `guia_app.html` | https://claude.ai/artifact/PN2pWRaUDno4DxxR7hHW1k |
| **Arquitectura de IngresoYa**: componentes, entornos, Cloud Functions (entradas, salidas, errores), flujos con diagramas, modelo de datos, casuística, seguridad y riesgos. | `arquitectura.html` | https://claude.ai/artifact/1GFrsbMycXxpZGhiT6ZQKe |

Comparten `estilo.css`. Las capturas van en `img/` (JPEG de 540 px de ancho, prefijo `est-` para la guía de estudio y `sim-` para el Simulador). Los diagramas son bloques `<pre class="mermaid">`; en sus etiquetas no usar `<br/>` (el visor lo quita), sino « · ».

## Cuándo actualizar (obligatorio, sin preguntar)

En todo desarrollo o PR que:
- agregue o cambie un flujo, una pantalla, un mensaje, una condición o un valor configurable → **Guía**;
- agregue o cambie una Function, un `reason` de error, una colección o campo, una regla de seguridad o un paso de un flujo → **Arquitectura**.

Al hacerlo:
1. Editar el HTML.
2. Agregar una línea en «Historial de cambios» con la fecha y el PR.
3. Si una observación o un riesgo quedó resuelto, tacharlo o quitarlo.
4. Si cambió una pantalla, reemplazar su captura en `img/`.
5. Publicar en la **misma** dirección: herramienta Artifact, `publish`, `url` = la del cuadro, `root` = esta carpeta y `files` con `estilo.css` y las imágenes nuevas.
6. Incluir los archivos en el commit del PR.
