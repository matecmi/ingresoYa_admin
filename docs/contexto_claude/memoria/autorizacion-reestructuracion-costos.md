---
name: autorizacion-reestructuracion-costos
description: "Kevin autorizó (2026-10-18) hacer todo lo posible sin depender de él en la reestructuración de costos: fusionar PRs, desplegar en TEST, usar gcloud/firebase CLI y APIs; él solo prueba en el teléfono y crea cuentas que exigen su identidad"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 040734b8-b867-4e16-8b29-ba048341054a
  modified: 2026-10-18T20:47:55.250Z
---

El 2026-10-18 Kevin dijo: «te doy todos los permisos necesarios para que en todo lo que puedas no dependas de cosas que tenga que hacer yo». Aplica a la reestructuración de costos por subfases (plan: https://claude.ai/code/artifact/9593d89b-8959-4507-826c-300792dd21c0).

**Why:** es el único desarrollador y quiere que cada subfase quede cerrada de punta a punta; al terminar cada una espera un estatus de lo hecho.

**How to apply:** en cada subfase, primero intentar por CLI o API todo lo que antes era «Te toca»: fusionar PRs con `gh pr merge`, desplegar reglas, índices, Functions y Storage en TEST, exclusiones de logs y alertas de presupuesto con `gcloud`, crear buckets o el proyecto de producción con `gcloud`/`firebase` si la cuenta lo permite, cambiar parámetros de `{config}` en TEST con un script de Functions. Dejar a Kevin solo lo que exige su identidad o un dispositivo: probar en el teléfono, cuentas de AdMob y Play Console, tarjeta o cuenta de facturación. Sigue vigente [[sin-produccion-aun]]: nada a `main` ni a producción hasta Play Console; crear el proyecto de producción está permitido, publicar en él no. Al cerrar cada subfase: estatus en el chat, Estado en el tablero del doc y PROGRESO.md en ambos repos ([[progreso-docs-sync]]).

**Ajuste 2026-10-19:** Kevin pidió «por el momento hagamos en test»: nada de producción (1B, facturación, despliegues a `ingresoya-prod`) hasta que él lo pida en la recta final; las fases restantes se cierran en TEST y, al terminar cada una, además del estatus, él quiere que lo hecho y lo pendiente queden guardados en la memoria y en PROGRESO.md de ambos repos.
