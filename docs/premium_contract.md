# Plan premium (`{config}/premium`, `premium` del perfil)

Fase 5B de la reestructuración de costos (2026-10-19). Suscripción mensual o
anual vendida por Google Play que quita los anuncios (Fase 5A,
`docs/ads_contract.md`) y abre los exámenes pasados sin límite diario. El
servidor es el único que decide quién es premium: la app manda el token de la
compra, las Functions lo comprueban con la API de Play y escriben el perfil.
Copia idéntica en `iya-app/docs/premium_contract.md`.

## Productos

| ID en Play Console | Plan | Precio sugerido |
| --- | --- | --- |
| `premium_monthly` | Mensual | S/ 9.90 |
| `premium_yearly` | Anual | S/ 59 |

Son identificadores (como las unidades de AdMob): van fijos en la app
(`PremiumProducts`), el admin (`PremiumSettings.monthlyProductId`) y las
Functions (`PREMIUM_PRODUCT_IDS`). Los precios los fija Play Console y la app
los muestra tal como los devuelve la tienda.

## `{config}/premium` (lo decide el admin)

| Campo | Tipo | Fábrica | Límites | Efecto |
| --- | --- | --- | --- | --- |
| `enabled` | bool | `false` | | Apagado: la app no muestra la pantalla Premium ni la tarjeta del Perfil, no hay límites de cuenta gratuita y `verifyPurchase` sigue funcionando (por si alguien ya pagó). |
| `freePastExamsPerDay` | int | 3 | 0–20 | Exámenes pasados que una cuenta gratuita puede **empezar** por día del Perú. 0 = sin límite. Los premium nunca lo tienen. |
| `schemaVersion`, `updatedAt`, `updatedBy` | | | | Metadatos del admin (no viajan en `{config}/app`). |

La app lo lee como sección `premium` de `{config}/app`
(`docs/app_config_contract.md`); Configuración → «Plan Premium» en el admin.

## `premium` y `usage` en el perfil (`{perfil}/{uid}`)

```json
"premium": { "productId": "premium_monthly", "until": <Timestamp>, "source": "play" | "admin", "updatedAt": <Timestamp> },
"usage":   { "pastExamDay": "2026-10-19", "pastExamStarts": 2 }
```

- **Solo las Functions los escriben.** Las reglas dejan al alumno crear y
  editar su perfil salvo las claves `premium` y `usage`
  (`affectedKeys().hasAny([...])`). El alumno los lee con su perfil (una
  lectura por sesión); el admin con `students:v`.
- Premium vigente = `premium.until > ahora`. `source` dice si vino de Play o
  de un regalo del admin (`productId: "admin_grant"`).
- `{perfil}/{uid}/premiumEvents/{auto}`: bitácora (`type`: `admin_grant`,
  `admin_revoke`, `purchase`, `rtdn_<n>`; `by`, `reason`, `untilMs`, `atMs`).
  Server-only; la leen el alumno y `students:v`.
- `iya-purchase-tokens-{env}/{sha256(token)}` → `{uid, productId}`: a quién
  pertenece cada compra, para rechazar el mismo token desde otra cuenta y para
  encontrar al alumno cuando Play avisa una renovación. Nadie lo lee desde el
  cliente.

## Callables y disparadores (`functions/src/premium.ts`)

| Función | Quién | Entrada | Salida / efecto |
| --- | --- | --- | --- |
| `verifyPurchase` | alumno (App Check según entorno) | `{productId, purchaseToken}` | Consulta `purchases.subscriptionsv2.get` con la cuenta de servicio de Functions, indexa el token, escribe `premium` y devuelve `{productId, untilMs, source}`. Errores: `purchases_unavailable` (sin verificador), `purchase_not_found`, `purchase_invalid`, `purchase_owned_elsewhere`, `invalid-argument` si el producto no coincide. |
| `setStudentPremium` | admin con `students:e` (sin App Check) | `{uid, action: "grant", days: 1–3650, reason}` o `{uid, action: "revoke", reason}` | Regalar suma días al premium vigente (o desde hoy); quitar pone `until = ahora`. Devuelve el estado. `permission-denied` sin el permiso, `student_not_found`. |
| `onPlayNotification` | Pub/Sub, tema `PLAY_RTDN_TOPIC` (`play-rtdn-{env}`) | Notificación en tiempo real de Play (`subscriptionNotification`) | Busca el uid por el token, vuelve a consultar la suscripción y reescribe `premium` (renovación, cancelación, pausa, retención, vencimiento). Nunca lanza; `retry: false`. |

Vigencia según Play (`entitlementUntil`): `ACTIVE`, `IN_GRACE_PERIOD` y
`CANCELED` conservan el acceso hasta `expiryTime`; `ON_HOLD`, `PAUSED`,
`EXPIRED` y los demás lo cortan de inmediato (`until = min(expiry, ahora)`).

La app reconoce la compra ante Play (`completePurchase`) **solo después** de
que el servidor la aceptó; si no se reconoce en tres días Google la reembolsa,
así que una verificación que falla se reintenta con «Restaurar compras».

### Variables de entorno (`functions/.env*`)

| Variable | Fábrica | Uso |
| --- | --- | --- |
| `PLAY_VERIFIER` | `off` | `google` activa la verificación real. Con `off` (TEST hoy) `verifyPurchase` responde `purchases_unavailable` y el premium solo llega por regalo del admin. |
| `PLAY_PACKAGE_NAME` | `com.ingresoya.app` | Paquete registrado en Play Console (`com.ingresoya.app.staging` en staging si se publica). |
| `PLAY_RTDN_TOPIC` | `play-rtdn-{env}` | Tema de Pub/Sub que Play Console → Monetización → Notificaciones en tiempo real debe apuntar (`projects/<id>/topics/<tema>`). |

Permisos para `google`: en Play Console → Usuarios y permisos, invitar la
cuenta de servicio de las Functions (`<project-number>-compute@developer.gserviceaccount.com`
o la que use el despliegue) con «Ver datos financieros» y «Administrar
pedidos y suscripciones». No hace falta una clave JSON.

## Tope diario de exámenes pasados (`pastExamGate`)

En `createExamAttempt` con `purpose: "past_exam"`, si `premium.enabled` y
`freePastExamsPerDay > 0` y el alumno no es premium: se lee `usage` del perfil
(ya cargado para la universidad, sin lectura extra) y, si `pastExamDay` es hoy
y `pastExamStarts >= límite`, responde `resource-exhausted` con
`reason: "past_exam_daily_limit"` y `limit`. Si pasa, el mismo `runTransaction`
que crea el intento guarda `usage` con el contador +1. Un reintento con el
mismo `requestId` devuelve el intento existente y no cuenta.

## Cómo lo hace la app (`lib/features/premium/`)

- `lib/core/premium/premium.dart`: `PremiumSettings`, `PremiumStatus`
  (`until`, `productId`, `source`, `isActiveAt`), `PremiumProducts`.
- `premiumStatusProvider`: una lectura del perfil al entrar; `apply()` con lo
  que devuelva `verifyPurchase`. `premiumActiveProvider` (= vigente ahora) es
  el que apaga los anuncios en `adsActiveProvider`.
- `BillingGateway` (`StoreBillingGateway` con `in_app_purchase`;
  `NoBillingGateway` en pruebas): ofertas con precio de Play, comprar,
  restaurar y el flujo de eventos. `PremiumPurchaseController` manda el token
  al servidor, aplica el estado, reconoce la compra y avisa (`PremiumNotice`).
- Pantalla `/profile/premium` (`PremiumScreen`): beneficios, los dos planes,
  «Restaurar compras», estado vigente y «Administrar en Google Play». Tarjeta
  `PremiumProfileCard` en el Perfil (oculta con Premium apagado salvo que el
  alumno ya lo tenga). «O hazte Premium» bajo el candado de la explicación.
  Al chocar con el tope diario: aviso «Exámenes pasados de hoy» con «Ver
  Premium» (`ExamPastExamDailyLimitFailure`).

## Admin

- Configuración → «Plan Premium» (`domain/premium_settings.dart`,
  `AppConfigRepo.watch/savePremiumSettings`, `SettingsDoc.premium`).
- Ficha del alumno: píldora «Premium hasta dd/mm/aaaa · regalo | Google
  Play», botones «Regalar premium» (7/30/90/365 días + motivo) y «Quitar
  premium» (motivo), vía `StudentRepo.setPremium` → `setStudentPremium`.
- Historial: «Configuración · Plan premium» (disparador `auditConfig`).

## Pendiente de Kevin (Play Console)

Crear las dos suscripciones con esos ID y precios, dar acceso a la cuenta de
servicio, configurar las notificaciones en tiempo real al tema
`play-rtdn-<env>` del proyecto, agregar su cuenta como tester de licencias y
hacer una compra de prueba. Después: `PLAY_VERIFIER=google` en el `.env` del
entorno y redesplegar `verifyPurchase` y `onPlayNotification`. Hasta entonces el
premium se prueba con «Regalar premium» desde la ficha del alumno.
