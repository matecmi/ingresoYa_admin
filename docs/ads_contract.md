# Anuncios de AdMob (`{config}/ads`)

Contrato compartido entre `ingresoya_admin` (tema «Anuncios» de Configuración,
sección `ads` de `{config}/app`) e `iya-app` (`google_mobile_ads`). Fase 5A de
la reestructuración de costos (2026-10-18). El porqué y las cifras:
«Costos Firebase y rentabilidad con AdMob».

## Reglas de producto

- Nunca hay anuncios dentro de una lección, un examen en curso ni las
  historias. El alumno que estudia no se interrumpe.
- Banner adaptable al pie de las cinco pestañas (**Inicio**, **Cursos**,
  **portada del Simulador**, **Stats**, **Perfil**), de la **lista de
  noticias** y de **Rankings**; cada pantalla se enciende por separado. Un
  mismo banner cargado se comparte entre pestañas: al cambiar de pestaña
  aparece al instante (la primera carga tarda unos segundos).
- Anuncio de pantalla completa (intersticial) **al terminar un examen** (de
  parte, de dominio o del Simulador): en cuanto el servidor acepta la entrega
  y **antes del resultado**, para que el alumno lo vea haga lo que haga
  después. De fábrica sale en cada examen; el admin puede liberar el primer
  resultado del día (día del Perú, `firstExamOfDayFree`) y exigir
  `interstitialMinMinutes` entre dos. Se precarga al abrir el examen; si no
  está listo se espera hasta 5 s y se sigue sin él; si caducó (exámenes de
  más de 50 min) se pide otro.
- Video recompensado para **ver la explicación de una pregunta fallada** en la
  revisión de un examen; las acertadas se ven directo. Si no hay video
  disponible (sin relleno, sin red, tiempo agotado) la explicación se abre
  igual: el anuncio nunca bloquea el estudio.
- Los alumnos **premium** (Fase 5B, `premium.until` en el perfil) no ven
  ningún anuncio.
- Apagar `enabled` quita todos los anuncios en la siguiente sesión de cada
  alumno, sin publicar una versión nueva.

## Documento `{config}/ads`

Solo lo escribe el admin (Configuración → Anuncios); la app lo lee dentro de
`{config}/app` (`APP_CONFIG_SECTIONS`, docs/app_config_contract.md), una
lectura por sesión.

| Campo | Tipo | Límites | Fábrica | Efecto |
| --- | --- | --- | --- | --- |
| `enabled` | bool | | false | Interruptor general. |
| `bannerScreens` | map | `home`, `courses`, `simulator`, `stats`, `profile`, `news`, `rankings` → bool | las siete en true | Dónde va el banner al pie. |
| `interstitialMinMinutes` | number | 0 a 240 | 0 | Minutos mínimos entre dos anuncios de pantalla completa; 0 = al terminar cada examen. |
| `firstExamOfDayFree` | bool | | false | El primer resultado del día no muestra el anuncio. |
| `rewardedEnabled` | bool | | true | Video a cambio de la explicación de una pregunta fallada. |
| `schemaVersion`, `updatedAt`, `updatedBy` | | | | Metadatos del admin (no viajan en `{config}/app`). |

## Identificadores de AdMob (app)

`Env.adsAppId`, `adsBannerUnitId`, `adsInterstitialUnitId` y
`adsRewardedUnitId` por sabor (`lib/config/env.dart`); el ID de la app
también va en `android/app/build.gradle.kts` (`manifestPlaceholders["admobAppId"]`,
leído por `AndroidManifest.xml`). Desde el 2026-10-19 el ID de la app es el
real de AdMob (`ca-app-pub-6838711524343941~9067462885`) en los tres sabores;
las tres unidades siguen siendo los **ID de prueba oficiales de Google**
(`ca-app-pub-3940256099942544/…`): muestran anuncios de prueba y no generan
ingresos ni infracciones (combinación recomendada por Google para desarrollo).
Antes de publicar: reemplazar las unidades de `production` por las reales
(banner adaptable anclado, intersticial y recompensado) en `env.dart`.

## Cómo lo hace la app

- `lib/core/ads/ads_settings.dart`: `AdsSettings` (lectura tolerante del
  documento), `decideInterstitial` (regla de frecuencia, pura) e
  `InterstitialState` (lo que el teléfono recuerda: último anuncio, día y
  resultados del día).
- `lib/features/ads/`: `AdsRuntime` (puente con el SDK; `NoAdsRuntime` en
  pruebas, web y escritorio; `MobileAdsRuntime` (presentation, con `google_mobile_ads`), que
  inicializa el SDK en el primer uso, no en el arranque), providers
  (`adsSettingsProvider` desde `ConfigDocs`, `premiumActiveProvider`,
  `adsActiveProvider` = ajustes vigentes o null), `AdBannerSlot(screen)`,
  `InterstitialCoordinator` (`preload()` al abrir el examen,
  `showAfterExam()` al aceptarse la entrega, antes del resultado; espera
  `freshLoadWait` = 5 s si no había precarga y descarta anuncios de más de
  `maxAge` = 50 min) y `RewardedUnlock` (+
  `unlockedExplanationsProvider` para no pedir dos videos por la misma
  pregunta en la sesión).
- Frecuencia guardada en SharedPreferences (`ads.interstitial.*`).
- `MobileAdsRuntime` comparte un banner cargado por unidad y ancho entre
  pantallas (el `AdWidget` se vuelve a montar en la pestaña nueva); si otra
  pantalla viva ya lo tiene (una ruta encima de otra), la segunda carga uno
  propio.
- Pruebas: `test/ads_policy_test.dart`, `test/ads_widgets_test.dart`.

## Admin

- `lib/src/domain/ads_settings.dart` (mismos límites), `AppConfigRepo.watch/saveAdsSettings`,
  `SettingsDoc.ads`, tema «Anuncios» en `settings_catalog.dart` con «En la
  práctica».
- Ficha del alumno: «Premium hasta dd/mm/aaaa» o «Sin premium · ve anuncios»
  (`StudentProfile.premiumUntil`, lo escribe el servidor en la Fase 5B).
- Historial: «Configuración · Anuncios».

## Pendiente de Kevin

Cuenta de AdMob y app Android registradas (ID de app entregado el 2026-10-19).
Falta crear las tres unidades reales (banner adaptable anclado, intersticial,
video recompensado) y pasar sus ID para `Env.production`. Formulario de
seguridad de datos de Play Console y política de privacidad (AdMob usa el ID
de publicidad). Probar en el teléfono con `{config}/ads.enabled = true` en
TEST.
