# Retomar aquí: contexto de trabajo con Claude

Última actualización: **2026-10-19 (noche)**. Kevin cambia de máquina. Este documento, con los `PROGRESO.md` de los dos repos, basta para que una terminal nueva de Claude Code sepa en qué estamos, qué se hizo y qué sigue.

## 1. Primeros pasos en la máquina nueva

1. Clonar los dos repos en la misma carpeta padre y trabajar en la rama `desarrollo`:
   - `matecmi/ingresoYa_admin` → `ingresoya_admin`
   - `matecmi/IngresoYa` → `iya-app`
2. Abrir Claude Code en la carpeta padre y pedirle: «Lee `ingresoya_admin/docs/contexto_claude/README.md` y los `PROGRESO.md` de los dos repos».
3. **Restaurar la memoria de Claude.** Sus memorias viven fuera del repo, en `~/.claude`. Hay que copiarlas:
   - `memoria/*.md` → `~/.claude/projects/<carpeta-del-proyecto>/memory/`. El nombre de la carpeta lo crea Claude Code a partir de la ruta; en la máquina vieja era `C--kevin-Nueva-carpeta--3-`. Lo más simple es pedirle a Claude que lo haga.
   - `claude_global.md` → `~/.claude/CLAUDE.md`. Son las preferencias globales de Kevin.
4. Herramientas que hay que instalar e iniciar sesión, porque no viajan con el repo:
   - Flutter (Dart ^3.9.2) y Android SDK con `adb`.
   - Node 22 para las Functions y, opcional, Node 20 para el CLI `firebase`. Con nvm: `nvm install 22`.
   - `firebase-tools` y `firebase login` con la cuenta de Kevin.
   - Google Cloud SDK y `gcloud auth login`, proyecto `ingresoya-e5115`.
   - `gh auth login` para PR y merge.
   - Archivos locales que no están en git: `functions/.env.production` del admin. No hace falta para TEST.

## 2. Reglas de trabajo (vigentes)

- **Responder siempre en español.**
- Rama `codex/<nombre>` desde `desarrollo` → PR a `desarrollo` → Claude fusiona con `gh pr merge` (autorizado). **Nada a `main` ni a producción** (`ingresoya-prod`) hasta que Kevin publique en Play Console.
- Desplegar solo en TEST: `ingresoya-e5115`, colecciones `iya-*-test`.
- En cada PR: actualizar `PROGRESO.md` de **los dos** repos, `CLAUDE.md` si cambió algo, los contratos de `docs/` y las **guías vivas**, sin preguntar.
  - Guía de la app: https://claude.ai/artifact/PN2pWRaUDno4DxxR7hHW1k, versión 29.
  - Arquitectura: https://claude.ai/artifact/1GFrsbMycXxpZGhiT6ZQKe, versión 34.
  - Cómo publicarlas: `docs/guias/README.md`.
- Todo valor configurable va como parámetro del admin (`{config}/<módulo>` + `settings_catalog.dart` con descripción), nunca fijo en la app.
- Las pantallas de la app que aparezcan en diseños, admin o guías deben ser las reales, con capturas del teléfono.
- Antes de implementar algo de diseño, Kevin pide 4 o 5 propuestas en un lienzo y elige.
- **El teléfono de pruebas es el personal de Kevin.** Antes de cada toque por adb hay que comprobar que IngresoYa está al frente con `adb shell dumpsys window | grep mCurrentFocus`, que debe mostrar `com.ingresoya.app.dev`. También que no haya una llamada en curso. Si no, no se toca nada.
- GitHub Actions de `matecmi` está detenido por facturación: validar en local con `flutter analyze`, `flutter test`, `npm run build`, `npm run lint` y `npm test`.
- `flutter analyze` del admin reporta 374 avisos heredados, sin errores. Además regenera `macos/Flutter/GeneratedPluginRegistrant.swift`: descartar ese archivo antes de cada commit.

## 3. Dónde nos quedamos

Todo está fusionado en `desarrollo`. Los últimos PR son admin #114 y app #130. Todo está desplegado en TEST.

**Pregunta abierta de Kevin:** «¿ya no hay ninguna sección del admin que se dispare en lecturas?». Respuesta dada: quedan dos.

| Pantalla del admin | Qué lee hoy | Arreglo propuesto, **sin aprobar** |
|---|---|---|
| «Importar examen pasado», paso Clasificar | Las 1 432 preguntas del banco, en vivo, cada vez que se llega al paso | El servidor mantiene un documento compacto por curso con el texto corto de las preguntas clasificadas. Serían unos 18 documentos. |
| «Preguntas a revisar» | Hasta 500 estadísticas por apertura | Tope de 100 con «Ver más», o que el servidor guarde ya filtradas las que superan los umbrales |

El resto del admin tiene tope y es barato. Kevin dijo que si lo quiere lo pedirá. Esperar su respuesta antes de implementarlo.

## 4. Lo hecho en esta etapa (2026-10-17 a 2026-10-19)

Orden cronológico. El detalle de cada punto está en los `PROGRESO.md`.

1. **Noticias y nuevo Inicio de la app**: admin #88, app #105. **Storage** activado en TEST.
2. **Reestructuración de costos de Firebase**, por subfases: 0, 1A, 2A, 2B, 2C, 2D, 3A, 3B, 3C, 4A, 4B y 5A hechas. 5B premium y 1B producción quedan «En curso», a la espera de Play Console y facturación.
   - Plan y tablero: https://claude.ai/code/artifact/9593d89b-8959-4507-826c-300792dd21c0
   - Proyección de gastos actualizada, con comparación antes y después: https://claude.ai/code/artifact/046f856f-b32f-4c77-9c3b-0e74e18afe66
3. **Anuncios**: banner en siete pantallas e intersticial al terminar cada examen. Admin #107, app #123.
4. **Revisión por pregunta renovada**, con filtros, mapa y «Ver en la guía»: app #124 y #125, admin #108 y #109.
5. **Candado del video con XP**: 5 XP por explicación, tope de 25 al día, callable `claimExplanationXp`. App #126, admin #110.
6. **Menos lecturas por práctica**: memoria de preguntas vistas en un documento e índice de preguntas por curso. Crear una práctica de 20 bajó de 208 lecturas a 28. Admin #111.
7. **Resumen de resultados en un documento**, guardado por tiempo opcional y descripción en los 86 ajustes del admin. Admin #112, app #128.
8. **«Tu progreso e historial» renovado**, propuesta 3 + 2 del lienzo https://claude.ai/artifact/1EWCP88CmP5aEmuVk1ErtZ. Incluye totales exactos en el servidor y el ajuste del admin «Exámenes en el historial». Validado en el teléfono. Admin #113, app #129.
9. **Salud del contenido del admin en el servidor**: el Inicio del admin pasó de unas 1 570 lecturas a 1, y abrir un curso de unas 1 430 a 1. Admin #114, app #130.

Otros lienzos de diseño:
- Revisión y candado del video: https://claude.ai/artifact/EAfyEe5ScqWQ7zPvfYExFk
- Noticias e Inicio: https://claude.ai/artifact/D4E2FpduabooX7xD5zMZsw
- Rediseño del admin: https://claude.ai/artifact/AzcWwYLE34iCdw4YJryZSC

## 5. Pendientes

**De Kevin:**
1. Play Console:
   - suscripciones `premium_monthly` a S/ 9.90 y `premium_yearly` a S/ 59;
   - permiso a la cuenta de servicio;
   - notificaciones en tiempo real al tema `play-rtdn-test`;
   - tester de licencias;
   - AAB al canal interno. Ver `docs/test_promotion_runbook.md` §8.
2. AdMob: las tres unidades reales: banner, intersticial y recompensado.
3. Probar él mismo en el teléfono anuncios, premium y un examen con el candado del video.
4. Usar la app 3 días para la medición final de costos.
5. Recta final antes de Play Console:
   - facturación de `ingresoya-prod` y presupuesto;
   - Storage y Authentication;
   - **App Check**, ver `iya-app/docs/app_check.md`;
   - formulario de seguridad de datos y política de privacidad.

**De Claude:**
- Al tener Play Console:
  - poner `PLAY_VERIFIER=google`;
  - redesplegar `verifyPurchase` y `onPlayNotification`;
  - hacer una compra de prueba;
  - marcar 5B como hecha.
- Al tener facturación de producción, terminar 1B:
  - API, reglas, índices y Functions;
  - cargar el índice con `node tools/build_question_index.js --env production --project ingresoya-prod`.
- Cierre de costos: `node tools/cost_report.js --days 3`, actualizar `docs/cost_baseline.md` y el tablero.
- Opcionales ya conversados:
  - propuesta 3 de la revisión, una pregunta por pantalla;
  - resto de la propuesta 4: parecidas y un video para todas;
  - segunda oportunidad del reto diario con video;
  - probar `cpu: "gcf_gen1"` en Functions para bajar costo;
  - regenerar la vista previa del admin con `python tool/sync_app_preview.py`, que necesita Python.

## 6. Datos útiles del entorno

- TEST: proyecto `ingresoya-e5115`, número 377388184823, Firestore `nam5`. Functions en `us-central1`. Bucket `ingresoya-e5115.firebasestorage.app`.
- Producción, creada y sin desplegar: `ingresoya-prod`, Firestore en us-central1.
- Desplegar Functions:

```bash
FUNCTIONS_DISCOVERY_TIMEOUT=180 firebase deploy --only functions:<nombre> --project ingresoya-e5115 --force
```

  Buscar «Deploy complete» en la salida.
- Emuladores, en Bash: `npm run test:emulators` desde `functions/`. Antes hay que liberar el puerto 8080.
- APK para el teléfono:

```bash
rm -rf build/app/intermediates/flutter/developmentDebug
flutter build apk --debug --flavor development -t lib/main_development.dart
adb install -r build/app/outputs/flutter-apk/app-development-debug.apk
```

- Firestore por REST: usar el token de `gcloud auth print-access-token`. Desde Node se puede usar `@google-cloud/firestore` con un `OAuth2Client` y ese token, porque la biblioteca de administración pide credenciales de cuenta de servicio.

## 7. Contenido de esta carpeta

- `memoria/`: copia de las memorias de Claude al 2026-10-19. `MEMORY.md` es el índice; empezar por `donde-nos-quedamos.md`.
- `claude_global.md`: preferencias globales de Kevin, la copia de `~/.claude/CLAUDE.md`.

Al cerrar una etapa importante, volver a copiar aquí las memorias para que la próxima máquina las tenga.
