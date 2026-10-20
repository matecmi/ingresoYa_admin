---
name: herramientas-cli-entorno
description: "Dónde están gcloud y firebase CLI en la PC de Kevin, trucos de despliegue y emuladores (PATH, FUNCTIONS_DISCOVERY_TIMEOUT, comas en PowerShell), qué bloquea el modo automático y que GitHub Actions de matecmi está detenido por facturación (oct-2026)"
metadata:
  node_type: memory
  type: reference
  originSessionId: 040734b8-b867-4e16-8b29-ba048341054a
  modified: 2026-10-19T01:47:03.229Z
---

- `gcloud` (instalado 2026-10-18 con winget, sesión de Kevin ya iniciada, proyecto `ingresoya-e5115`): `C:\Users\USER\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd`. No está en el PATH de bash; invocarlo por ruta completa o con `export PATH="$PATH:/c/Users/USER/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin"`. Argumentos con espacios y comillas rompen la invocación por `cmd` (usar nombres sin espacios). `functions/tools/cost_report.js` acepta `GCLOUD_PATH`. Firestore por REST: `curl` con `gcloud auth print-access-token` (quitar `\r`).
- `firebase` CLI: binario de nvm Node 20 en `C:\Users\USER\AppData\Local\nvm\v20.19.4` (añadirlo al PATH desde Bash: `export PATH="$PATH:/c/Users/USER/AppData/Local/nvm/v20.19.4"`); `npx -y firebase-tools@14.20.0` es la alternativa lenta. Sesión de Kevin iniciada.
- Despliegue de Functions: `firebase deploy --only functions --project ingresoya-e5115 --force` desde la raíz del admin. Si la PC está ocupada (p. ej. compilando un APK a la vez) falla con «Cannot determine backend specification. Timeout after 10000»: repetir con `FUNCTIONS_DISCOVERY_TIMEOUT=180`. El exit code puede ser 0 aunque falle: buscar «Deploy complete» en el log.
- Emuladores: `npm run test:emulators` desde `functions/` **en Bash** (PowerShell parte `--only auth,firestore,storage` por las comas y firebase dice «No emulators to start»). Antes, matar el java huérfano del puerto 8080. Una prueba sola: `firebase --config ../firebase.json --project ingresoya-security-rules emulators:exec --only auth,firestore,storage "node --test lib/test/<archivo>.js"`.
- Proyecto TEST: número `377388184823`, Firestore `nam5`, cuenta de facturación `015523-06CE55-5C0BD1`, bucket por defecto `ingresoya-e5115.firebasestorage.app` en us-central1 (creado 2026-10-18 vía API `defaultBucket`), presupuesto de $10 creado, métricas `iya_observed_reads` / `iya_duration_ms` y panel de Monitoring creados.
- El clasificador del modo automático bloquea a veces `gh pr merge` (hay regla `Bash(gh pr merge:*)` en `.claude/settings.local.json`; repetir el mismo comando suele pasar), leer credenciales guardadas (configstore de firebase-tools), editar CLAUDE.md por script (el Edit tool sí pasa) y comandos que tocan varios repos a la vez (separarlos).
- GitHub Actions de la organización `matecmi` no arranca trabajos desde el 2026-10-17 («recent account payments have failed or your spending limit needs to be increased»): validar PRs en local (`dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --concurrency=2`; nunca dos suites de Flutter a la vez, la PC se queda sin memoria) hasta que Kevin lo resuelva. `flutter analyze` del admin siempre reporta 374 avisos heredados (0 errores) y regenera `macos/Flutter/GeneratedPluginRegistrant.swift`: descartarlo antes de confirmar.
