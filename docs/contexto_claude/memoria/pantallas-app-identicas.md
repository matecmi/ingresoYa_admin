---
name: pantallas-app-identicas
description: "toda pantalla de la app que aparezca en diseños, admin o guías debe ser idéntica a la app real"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 45340872-5a5a-44b2-be34-077f4125e6ff
  modified: 2026-10-16T23:35:07.257Z
---

Las pantallas de la app que se muestren en propuestas de diseño, en el admin (vista previa, miniaturas) o en guías deben ser idénticas o lo más iguales posible a la app real; nada de maquetas inventadas.

**Why:** Kevin lo pidió explícitamente al revisar los tableros 19/20 del lienzo del admin (2026-10-16); una pantalla distinta confunde sobre qué parte de la app se está tocando.

**How to apply:** usar capturas reales del celular (adb screencap) o calcar el widget real del código (`iya-app/lib/...`) en textos, colores, orden y componentes. En el admin, la vista previa en vivo debe reutilizar los mismos widgets de la app. Ver [[guias-vivas]].
