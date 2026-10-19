# Anuncios de AdMob (`{config}/ads`)

Contrato compartido entre `ingresoya_admin` (tema «Anuncios» de Configuración,
sección `ads` de `{config}/app`) e `iya-app` (`google_mobile_ads`). Fase 5A de
la reestructuración de costos (2026-10-18). El porqué y las cifras:
«Costos Firebase y rentabilidad con AdMob».

## Reglas de producto

- Nunca hay anuncios dentro de una lección, un examen, el simulador ni las
  historias. El alumno que estudia no se interrumpe.
- Banner adaptable al pie de **Inicio**, **lista de noticias** y **Rankings**
  (cada pantalla se enciende por separado).
- Anuncio de pantalla completa (intersticial) **al salir del resultado** de un
  examen de parte, de dominio o del Simulador: el primer resultado del día
  (día del Perú) va libre si el admin lo pide, y entre dos anuncios pasan al
  menos `interstitialMinMinutes`.
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
| `bannerScreens` | map | `home`, `news`, `rankings` → bool | las tres en true | Dónde va el banner al pie. |
| `interstitialMinMinutes` | number | 1 a 240 | 10 | Minutos mínimos entre dos anuncios de pantalla completa. |
| `firstExamOfDayFree` | bool | | true | El primer resultado del día no muestra el anuncio. |
| `rewardedEnabled` | bool | | true | Video a cambio de la explicación de una pregunta fallada. |
| `schemaVersion`, `updatedAt`, `updatedBy` | | | | Metadatos del admin (no viajan en `{config}/app`). |

## Identificadores de AdMob (app)

`Env.adsAppId`, `adsBannerUnitId`, `adsInterstitialUnitId` y
`adsRewardedUnitId` por sabor (`lib/config/env.dart`); el ID de la app
también va en `android/app/build.gradle.kts` (`manifestPlaceholders["admobAppId"]`,
leído por `AndroidManifest.xml`). Hasta que Kevin registre la app en AdMob y
cree las tres unidades, los tres sabores usan los **ID de prueba oficiales de
Google** (`ca-app-pub-3940256099942544…`): muestran anuncios de prueba y no
generan ingresos ni infracciones. Antes de publicar: reemplazar los de
`production` (y el placeholder del sabor `production`) por los reales.

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
  `InterstitialCoordinator` (`preload()` al enviar el examen,
  `showAfterResult()` al salir del resultado) y `RewardedUnlock` (+
  `unlockedExplanationsProvider` para no pedir dos videos por la misma
  pregunta en la sesión).
- Frecuencia guardada en SharedPreferences (`ads.interstitial.*`).
- Pruebas: `test/ads_policy_test.dart`, `test/ads_widgets_test.dart`.

## Admin

- `lib/src/domain/ads_settings.dart` (mismos límites), `AppConfigRepo.watch/saveAdsSettings`,
  `SettingsDoc.ads`, tema «Anuncios» en `settings_catalog.dart` con «En la
  práctica».
- Ficha del alumno: «Premium hasta dd/mm/aaaa» o «Sin premium · ve anuncios»
  (`StudentProfile.premiumUntil`, lo escribe el servidor en la Fase 5B).
- Historial: «Configuración · Anuncios».

## Pendiente de Kevin

Cuenta de AdMob, registrar la app Android y crear las tres unidades (banner
adaptable, intersticial, video recompensado); pasar los ID. Formulario de
seguridad de datos de Play Console y política de privacidad (AdMob usa el ID
de publicidad). Probar en el teléfono con `{config}/ads.enabled = true` en
TEST.
