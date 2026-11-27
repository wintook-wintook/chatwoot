# WhatsApp (WABA): pestaña «Diagnóstico» y botón «Reconectar con Meta»

> Rama: `diag/waba` (desde `origin/develop` 29535466) · Plan v1.3 · 26/11/2026 (v1.1: D1–D7 confirmadas, F0 completa · v1.2: F1 completa · v1.3: H14 arreglado, F2 completa · v1.4: F3 completa, objetivo y D8 · v1.5: D8 confirmada, F4 completa, reconectar siempre)
> Estado: **D1–D8 confirmadas** · **F0–F4 completas** · falta F5 (navegador con datos reales) · **acción pendiente del usuario: App Secret** (H7).

---

## 1. Qué se pide

> **Objetivo (usuario, 26/11/2026):** bajar los reportes a soporte por errores de canales de
> WhatsApp. Que el cliente **verifique primero cuál es el problema** —con textos claros y botones
> que lo arreglan— antes de levantar un reporte.

1. **¿Se puede reconectar un WhatsApp (WABA) desde el sistema?** → hacerlo fácil: botón
   **«Reconectar con Meta»** en la bandeja.
2. **Una herramienta dentro de la configuración de la bandeja** que corra un **diagnóstico**
   de por qué **no recibe** o **no envía** mensajes, y diga cómo arreglarlo.

---

## 2. Cómo está hoy

```
  Configuración → Bandejas → (WhatsApp Cloud)
  ┌ Ajustes │ Colaboradores │ Horario │ Configuración │ Preguntas │ Llamadas │ Bot ┐
  │                                    └─ «Actualizar API key»: pegar un token nuevo │
  └──────────────────────────────────────────────────────────────────────────────────┘
       ✗ no hay «Reconectar con Meta» (Facebook, Instagram, Microsoft y TikTok sí tienen
         su «Reautorizar»; WhatsApp no)          Settings.vue:448
       ✗ no hay diagnóstico: el usuario solo nota que «ya no llegan» o «no salen»
```

Lo que **ya existe** y se va a reusar:

```
  Alta con Meta (Embedded Signup)            CloudEmbededSignupWhatsapp.vue → FB.login(config_id)
    POST /whatsapp/authorization {code, business_id, waba_id, phone_number_id, inbox_id}
      └ Whatsapp::EmbeddedSignupService
          1 code → token (servidor)       FacebookApiClient#exchange_code_for_token
          2 permisos sobre la WABA        #validate_token_access (debug_token)
          3 datos del número              #fetch_phone_info
          4 con inbox_id: ACTUALIZA la bandeja (api_key, phone_number_id)  ← reconexión
          5 suscribe el webhook           #subscribe_webhook (subscribed_apps)
  Marca «requiere reconexión»                Reauthorizable (2 errores → prompt_reauthorization!
                                             + correo whatsapp_disconnect; reauthorized! la quita)
  Límite diario del número                   TrackingDispatch::MessagingTier (messaging_limit_tier)
  Errores de envío                           messages.status = failed + external_error
```

Hallazgos (entran al plan):

| # | Hallazgo |
|---|---|
| H1 | La reconexión con `inbox_id` **no revisa que sea el mismo número**: si en la ventana de Meta eligen otro número u otra WABA, la bandeja cambia de número sin avisar (`embedded_signup_service.rb:53`). |
| H2 | Al reconectar **no se quita la marca** «requiere reconexión» (no llama `reauthorized!`). |
| H3 | La marca solo se activa con un 401 **al descargar archivos recibidos** (`incoming_message_whatsapp_cloud_service.rb:39`). Un **envío** con token vencido (401 / código 190) solo deja el mensaje en «fallido» con el JSON crudo de Meta (`whatsapp_cloud_service.rb:242`) y **no cuenta**. |
| H4 | Con la marca puesta, en pantalla **no sale ningún aviso** para WhatsApp (sí para Facebook y Microsoft). |
| H5 | El aviso por correo (`whatsapp_disconnect`) existe, pero en develop los correos del sistema no salen (ver diag/revision_correos). |
| H6 | `external_error` guarda el error crudo (a veces JSON entero): el usuario no entiende por qué falló un envío. |

---

## 3. Cómo quedaría

### 3.1 Pestaña «Diagnóstico» (solo bandejas WhatsApp Cloud)

```
  ┌ Ajustes │ … │ Configuración │ Llamadas │ Diagnóstico │ Bot ┐
  │                                                              │
  │  Último diagnóstico: hoy 10:42            [Ejecutar diagnóstico]
  │                                                              │
  │  RECIBIR MENSAJES                                            │
  │  ✓ Token de Meta válido · permanente · permisos completos    │
  │  ✗ La WABA no está suscrita a nuestra app:                   │
  │    Meta no nos manda los mensajes que te escriben.  [Suscribir ahora]
  │  ⚠ Último mensaje recibido: hace 3 días                      │
  │                                                              │
  │  ENVIAR MENSAJES                                             │
  │  ✓ Número +52 55 1234 5678 · conectado · calidad Alta        │
  │  ✓ Límite: 1 000 conversaciones por día                      │
  │  ⚠ Nombre visible «Kontrolya» pendiente de aprobación        │
  │  ✗ La cuenta no tiene método de pago: no salen plantillas.   │
  │    Agrégalo en Meta Business → Pagos.          [Abrir Meta]  │
  │  ⚠ 12 envíos fallidos en 7 días:                             │
  │      9 · Pasaron más de 24 h desde el último mensaje del     │
  │          cliente: usa una plantilla.                         │
  │      3 · La plantilla «promo_nov» fue rechazada.             │
  │                                                              │
  │  SISTEMA                                                     │
  │  ✓ Bandeja sin marca de reconexión                           │
  │  ✓ Envíos procesándose (cola sin atoros)                     │
  │                                                              │
  │              [Reconectar con Meta]   [Cambiar token]         │
  └──────────────────────────────────────────────────────────────┘
```

Revisiones (cada una: estado ✓ / ⚠ / ✗, texto sencillo y, si aplica, acción):

| # | Revisión | De dónde sale | ✗ / ⚠ cuando | Acción |
|---|---|---|---|---|
| R1 | Token válido, vence, permisos (`whatsapp_business_messaging`, `whatsapp_business_management`) | Meta `debug_token` (ya existe) | inválido / vence pronto / falta permiso | Reconectar con Meta · Cambiar token |
| R2 | WABA suscrita a nuestra app | Meta `GET /{waba_id}/subscribed_apps` | nuestra app no aparece | **Suscribir ahora** (`subscribe_webhook`, ya existe) |
| R3 | Último mensaje recibido | base (`messages` incoming de la bandeja) | > 2 días con la bandeja activa (⚠) | — (orienta a R1/R2) |
| R4 | Número: estado, verificación, calidad, nombre aprobado, plataforma | Meta `GET /{phone_number_id}?fields=status,code_verification_status,quality_rating,name_status,platform_type,display_phone_number,verified_name` | no CONNECTED, calidad roja, nombre rechazado | Abrir Meta |
| R5 | Límite diario | `messaging_limit_tier` (ya existe) | — (informativo) | — |
| R6 | Cuenta WABA: revisión, método de pago | Meta `GET /{waba_id}?fields=account_review_status,…` + error 131042 en envíos | rechazada / sin pago | Abrir Meta |
| R7 | Envíos fallidos (7 días), agrupados y **traducidos** | base: `messages.status = failed`, `external_error` | hay fallidos (⚠) / todos fallan (✗) | según el código |
| R8 | Marca «requiere reconexión» | `reauthorization_required?` | marcada | Reconectar con Meta |
| R9 | Cola de envíos | Sidekiq: jobs de envío en cola/reintentos/muertos de la bandeja | atoro | — (avisar a soporte) |

Traducción de errores de Meta (R7, también para el detalle del mensaje fallido, H6):

| Código | Texto para el usuario |
|---|---|
| 131047 / 470 | Pasaron más de 24 h desde el último mensaje del cliente: usa una plantilla. |
| 131026 | El número del cliente no tiene WhatsApp o no puede recibir el mensaje. |
| 131042 | Problema de pago en la cuenta de WhatsApp Business. |
| 131049 / 131050 | Meta frenó el envío para cuidar la experiencia del cliente (demasiados mensajes de marketing). |
| 131051 | Tipo de mensaje no permitido. |
| 132000–132016 | Problema con la plantilla (parámetros, pausada, rechazada o borrada). |
| 130429 / 131056 | Demasiados envíos seguidos; se reintentará más lento. |
| 190 / 401 | El permiso de Meta venció: reconecta la bandeja. |
| 131031 / 368 | La cuenta o el número está bloqueado por Meta. |
| otro | «Meta respondió: <título del error>» |

### 3.2 «Reconectar con Meta»

```
  Bandeja WhatsApp (pestaña Diagnóstico o Configuración)
     [Reconectar con Meta]
          │  misma ventana oficial de Facebook (FB.login con config_id)
          ▼
     1. entra con la cuenta que administra el negocio en Meta
     2. elige negocio, WABA y el MISMO número
     3. acepta permisos
          │  WA_EMBEDDED_SIGNUP → { code, business_id, waba_id, phone_number_id }
          ▼
     POST /whatsapp/authorization { …, inbox_id }
          ├─ H1: ¿mismo número que la bandeja? ── no → 422 «Elegiste otro número
          │                                             (+52…). Para ese crea una bandeja nueva.»
          ├─ token nuevo → guarda api_key + phone_number_id (conversaciones, contactos,
          │   plantillas, agentes y Agente IA no se tocan)
          ├─ re-suscribe el webhook
          └─ H2: reauthorized! → quita la marca y el aviso
          ▼
     «Listo: la bandeja quedó reconectada» → corre el diagnóstico solo
```
Requisito: quien reconecta necesita ser administrador del negocio en Meta (si no, la ventana
de Facebook no le deja elegir la WABA). Se dice antes de abrirla.

### 3.3 Aviso «Reconexión requerida» (H3, H4)

```
  Envío o descarga con 401 / código 190 ── authorization_error! (2 seguidos) ──► marca
                                                                                  │
  Bandeja WhatsApp con marca:                                                     ▼
  ┌ ⚠ WhatsApp perdió el permiso de Meta: no se reciben ni envían mensajes. ┐
  │                                              [Reconectar con Meta]       │
  └──────────────────────────────────────────────────────────────────────────┘
  (el mismo componente InboxReconnectionRequired que usan Facebook/Microsoft)
```

---

## 4. Decisiones (recomendación primero) — ✅ confirmadas las 7 recomendaciones (26/11/2026)

| # | Pregunta | Recomendación | Alternativa |
|---|---|---|---|
| D1 | ¿Quién ve la pestaña Diagnóstico? | **Administradores** (como el resto de la configuración de la bandeja; muestra datos de la cuenta de Meta) | También agentes de la bandeja, solo lectura |
| D2 | ¿Se corre solo al abrir la pestaña? | **No: botón «Ejecutar diagnóstico»** (hace ~5 consultas a Meta) y se muestra el último resultado con su hora | Correr solo al abrir |
| D3 | ¿«Enviar mensaje de prueba» en v1? | **No en v1** (una plantilla a un número cobra conversación y puede afectar la calidad); queda para después | Sí, con aviso de costo y número escrito a mano |
| D4 | Botones que arreglan (Suscribir ahora) | **Sí, con confirmación**, solo los seguros (re-suscribir webhook); lo demás con «Abrir Meta» | Solo mostrar el problema |
| D5 | Reconectar eligiendo otro número | **Rechazar** con mensaje claro (H1) | Permitir con confirmación «cambiar el número de esta bandeja» |
| D6 | Envío con 401 / 190 cuenta para la marca (H3) | **Sí** (2 seguidos → marca + aviso + correo) | Dejarlo como hoy (solo descargas) |
| D7 | ¿Traducir también el error en cada mensaje fallido de la conversación (H6)? | **Sí**, con la misma tabla (el detalle técnico queda en un «ver más») | Solo en el diagnóstico |
| D8 ✅ | Botón **«Copiar diagnóstico para soporte»** (texto con bandeja, hora y cada revisión ✓/⚠/✗) para pegarlo en el reporte cuando aun así haga falta soporte | **Sí** (soporte entiende el caso sin preguntar; va con el objetivo) | No |

---

## 5. Fases

### F0 — Medición (solo lectura, con OK)
- Listar en develop (`chatwoot_dev`) las bandejas WhatsApp Cloud: `source` (embedded_signup o
  manual), `waba_id`, marca de reconexión, último entrante, fallidos 7 días y sus códigos.
- Con el token de cada una, **solo GET** a Meta: `debug_token`, `subscribed_apps`, datos del
  número y de la WABA. Anotar qué campos llegan de verdad (algunos dependen de permisos).
- Medir: ¿un envío con token vencido devuelve 401 o 400 con código 190? (de los fallidos
  guardados, sin enviar nada nuevo).

#### ✅ F0 hecha (26/11/2026) — medición de solo lectura

Scripts en el scratchpad (no quedan en el repo); **solo GET a Meta**, ningún envío ni cambio.
Ningún token se imprimió.

**Bandejas WhatsApp en develop (`chatwoot_dev`):** una sola.

```
  #1563 «Whatsapp» · cuenta 2 · whatsapp_cloud · alta MANUAL (no embedded_signup)
  waba ✓ · phone_number_id ✓ · token ✓ · marca de reconexión: no
  último entrante 22/10 02:09 · último saliente 31/10 01:21 · fallidos: 0 (históricos: 0)
```

**Lo que respondió Meta con el token de la bandeja:**

```
  R1  debug_token (con la app del alta)   ✗ 400 · 190 «Invalid OAuth access token signature»
      /me con el token de la bandeja      ✓ 200  → el TOKEN de la bandeja sirve
  R2  subscribed_apps                     ✓ 4 apps: WintookV1 (la nuestra), Wintook WA API,
                                            Wintook Cloud API5, Wintook Cloud API
  R4  número                              ✓ CONNECTED · calidad GREEN · CLOUD_API · STANDARD
                                          ⚠ name_status DECLINED (nombre visible rechazado)
                                          · code_verification_status EXPIRED (normal en Cloud)
                                          · messaging_limit_tier NO vino en la respuesta
  R6  WABA                                ✓ account_review_status APPROVED · negocio verified
      plantillas                          ✓ 58 APPROVED
  App del alta (App ID | App Secret)      ✗ «Error validating client secret» (client_credentials)
  Log de develop (22/10 20:53 → hoy)      ✗ 0 avisos POST /webhooks/whatsapp
```

**Hallazgos nuevos:**

| # | Hallazgo | Efecto |
|---|---|---|
| H7 | El **App Secret** guardado (`WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET`) **no corresponde** al App ID. | En develop **fallarían** el alta con Meta y «Reconectar con Meta» (cambiar el código por token usa el secret), y `debug_token` no sirve para R1. **Lo corrige el usuario** en Super Admin con el secret correcto de la app WintookV1. |
| H8 | **No llega ningún aviso de WhatsApp a develop desde, al menos, el 22/10.** La WABA sí está suscrita a nuestra app, así que el webhook de la app en Meta apunta a **otro servidor** (probablemente producción). | Develop no recibe mensajes de WhatsApp. Para confirmarlo hace falta el secret correcto (`GET /{app_id}/subscriptions`). |
| H9 | El nombre visible del número está **rechazado**. | Los clientes ven el número en lugar del nombre; no bloquea envíos. |
| H10 | `messaging_limit_tier` no vino al pedir el número con este token. | R5 debe decir «no disponible» en vez de fallar. |
| H11 | `external_error` vive dentro de `content_attributes` (no es columna), y esa columna json guarda **texto JSON** (doble codificado: `json_typeof` = string). | R7 lo lee con el modelo (`select(:id, :content_attributes).map(&:external_error)`); `->>` en SQL siempre da vacío (corregido en F1). |
| H12 | No hay envíos fallidos guardados en develop. | La tabla de traducción (§3.1) se prueba con datos simulados. |

**Cambios al diseño por la F0:**
- **R1** usa primero `GET /me` con el token de la bandeja (no depende de la app). `debug_token`
  (vencimiento y permisos) solo si la app está bien configurada; si no, ⚠ «No se pudo revisar el
  vencimiento: la app de Meta del sistema está mal configurada».
- **R0 nueva — App de Meta del sistema** (solo administradores del sistema): valida App ID |
  App Secret con `client_credentials`. Si falla: ✗ «Reconectar con Meta no funcionará hasta
  corregir el App Secret en Super Admin».
- **R2 se amplía:** además de «nuestra app está suscrita», con app válida revisa **a dónde manda
  los avisos** (`GET /{app_id}/subscriptions` → callback URL) y lo compara con este servidor
  (H8: ✗ «Meta manda los mensajes a otro servidor: <dominio>»).
- **R3** marca ⚠ con > 2 días sin entrantes **y** ✗ si tampoco hay avisos en el log (sin
  avisos = Meta no está llamando a este servidor).
- El botón **Reconectar con Meta** se deshabilita con aviso si R0 falla.

### F1 — Servidor: diagnóstico
- `Whatsapp::HealthCheckService` (nuevo): corre R1–R9 y devuelve `[{ key, group, status,
  title, detail, action }]`; tolera que Meta no responda (esa revisión sale «no se pudo
  consultar», no truena todo).
- `Whatsapp::ErrorTranslator` (nuevo): tabla de §3.1.
- `GET /api/v1/accounts/:id/inboxes/:inbox_id/whatsapp_health` (admin) y
  `POST …/whatsapp_health/subscribe` (D4). Último resultado en caché (D2).
- RSpec con Meta simulado: cada revisión en ✓/⚠/✗, Meta caído, permisos.

#### ✅ F1 hecha (26/11/2026)

**Qué se hizo**
- `app/services/whatsapp/health_check_service.rb` (nuevo): R0–R9; cada revisión
  `{ key, group, status (ok|warn|fail|unknown), title, detail, lines, action }`. Solo GET a Meta
  (timeout 8 s); si una revisión truena sale «No se pudo revisar» y las demás siguen.
- `app/services/whatsapp/error_translator.rb` (nuevo): tabla de §3.1; entiende «código: título»
  y la respuesta JSON del envío (usa `error_data.details` si viene).
- `Api::V1::Accounts::Whatsapp::HealthChecksController` + rutas (solo admin, `authorize :update?`;
  solo `whatsapp_cloud`):
  `GET  /whatsapp/health_checks/:inbox_id` (último resultado, caché 7 días),
  `POST …/:inbox_id/run`, `POST …/:inbox_id/subscribe`.
- `FacebookApiClient#subscribe_app`: suscribe SIN cambiar la URL del webhook.
- Textos `whatsapp_health.*` es/en (títulos por estado, detalles, calidad, límites, «hace X»).

**Cómo funciona — puntos finos**

```
  R1 token   GET /me con el token de la bandeja (no depende de la app);
             con app válida → debug_token: permanente / vence el … / faltan permisos
  R2 webhook subscribed_apps: ¿nuestra app (App ID)? → no: ✗ [Suscribir ahora]
             sí → URL: override_callback_uri de la WABA, o la de la app (GET /{app}/subscriptions,
             necesita app válida) → host == FRONTEND_URL ? ✓ : ✗ «a otro servidor (host)»
             (sin poder ver la URL → ⚠)
  R9 colas   solo las de WhatsApp: SendReplyJob (high) y WhatsappEventsJob (low);
             ✗ si ningún Sidekiq las atiende, ⚠ si van > 5 min atrasadas
  Suscribir  alta a mano → POST subscribed_apps SIN URL (la WABA puede estar compartida con
             producción: mandar la URL de develop le quitaría los mensajes).
             alta con Meta → con la URL de este servidor (como el alta).
```

**Diagnóstico real de la bandeja #1563 (develop, solo lectura, 2,5 s):**

```
  SISTEMA  ✗ App de Meta del sistema mal configurada (App ID o App Secret)
           ✓ Sin marca de reconexión · ✓ Envíos procesándose
  RECIBIR  ✓ Permiso de Meta vigente (no se pudo ver el vencimiento: app mal configurada)
           ⚠ Nuestra app está suscrita, no se pudo ver a qué servidor manda los mensajes
           ⚠ Último mensaje recibido: hace 35 días
  ENVIAR   ✓ Número conectado · calidad alta
           ⚠ Meta rechazó el nombre visible «Ventas De Wintook»            [Abrir Meta]
           ? No se pudo consultar el límite de envío
           ✓ Cuenta aprobada · ✓ Sin envíos fallidos en 7 días
```

**Hallazgos de la F1**

| # | Hallazgo |
|---|---|
| H11 (corregido) | `content_attributes` guarda **texto JSON** dentro de la columna json (doble codificado): `->>` en SQL siempre da vacío. R7 lee `external_error` con el modelo. |
| H13 | La cola **`low_priority`** no la atiende ningún Sidekiq de develop: **207 trabajos** (`ContactTrackings::CleanupJob`) detenidos ~258 días. No es de WhatsApp; R9 ya no la mira. Pendiente de decidir aparte. |
| H14 | **Bandejas de 360dialog truenan al recibir cualquier mensaje**: el servicio base llama `outgoing_message_type?`, que solo existe en Cloud/UnoAPI (`incoming_message_base_service.rb:114`, desde el commit 8038e766 de 22/01/2024). En develop no hay bandejas 360dialog. Es la causa de las **22 pruebas que ya fallaban** en `spec/services/whatsapp` (fallan igual sin esta rama). Arreglo de una línea, pendiente del OK. |

**Pila de pruebas**
- `spec/services/whatsapp/error_translator_spec.rb` (4), `health_check_service_spec.rb` (10: sana,
  app mal, token vencido, sin suscribir, otro servidor, nombre rechazado y calidad baja,
  fallidos traducidos y «nunca recibió», cola sin atender, marca, Meta sin responder),
  `controllers/…/whatsapp/health_checks_controller_spec.rb` (6: vacío/correr/guardar, solo admin,
  solo Cloud, suscribir a mano sin URL, alta con Meta con URL, Meta rechaza). **20 ejemplos,
  0 fallas.** En `spec/services/whatsapp` + `controllers/whatsapp` + modelo: 310 ejemplos, las
  mismas 22 fallas que ya había (H14), ninguna nueva. Rubocop: nuevos limpios;
  `facebook_api_client.rb` conserva sus 2 previas.

**Cómo pedírselo al Asistente**
«¿Por qué no recibe la bandeja X?» → `POST /api/v1/accounts/:id/whatsapp/health_checks/:inbox_id/run`
y leer los `checks` en ✗ / ⚠.

### F2 — Pantalla: pestaña «Diagnóstico»
- `settingsPage/WhatsappHealthPage.vue` en `Settings.vue` (solo `isAWhatsAppCloudChannel`, D1).
- Grupos Recibir / Enviar / Sistema, iconos ✓ ⚠ ✗, acciones, hora del último diagnóstico.
- Componentes nativos (SettingsSection, woot-button), sin scroll innecesario.
- Vitest.

#### ✅ H14 arreglado (26/11/2026) — 360dialog y metadata

- `incoming_message_base_service.rb`: `outgoing_message_type?` por defecto `false` (Cloud/UnoAPI
  lo redefinen). Las bandejas de 360dialog ya no truenan al recibir.
- `incoming_message_whatsapp_cloud_service.rb`: `business_phone` lee
  `metadata.display_phone_number` con `dig`; si un aviso de Meta no trae `metadata`, ya no truena.
- Pruebas de WhatsApp (`spec/services/whatsapp` + controladores + modelo + job de webhooks):
  **325 ejemplos, de 22 fallas a 2**. Las 2 que quedan son de números de Brasil sin el 9
  (`incoming_message_service_spec.rb:313` y `:337`), ajenas a este diagnóstico.

#### ✅ F2 hecha (26/11/2026)

**Qué se hizo**
- `api/whatsappHealth.js`: `last`, `run`, `subscribe`.
- `settingsPage/WhatsappHealthPage.vue`: SettingsSection; botón «Ejecutar diagnóstico», hora del
  último y resumen («1 problema(s) y 3 aviso(s)»); grupos Recibir / Enviar / Sistema; cada
  revisión con icono (✓ verde, ⚠ ámbar, ✗ rojo, ⓘ gris), texto, detalle y líneas; acciones:
  **Suscribir ahora** con confirmación en línea (D4), **Cambiar token** (lleva a Configuración;
  F3 suma «Reconectar con Meta»), **Abrir Meta** (WhatsApp Manager en otra pestaña).
- `Settings.vue`: pestaña «Diagnóstico» para bandejas WhatsApp Cloud (la página ya es solo de
  administradores, D1); `goToTab`.
- i18n `whatsappHealth.json` es/en.

**Medido en navegador** (headless, Admin #1, cuenta 2, bandeja #1563; solo «Ejecutar
diagnóstico», que únicamente consulta; sesión borrada): pestaña junto a «Llamadas»; resultado
«1 problema(s) y 3 aviso(s)» igual al de la F1; «Abrir Meta» en el nombre rechazado.

**Pila de pruebas**
- Vitest `settingsPage/specs/WhatsappHealthPage.spec.js` (5): sin diagnóstico, correr + grupos
  + resumen + líneas, suscribir con confirmación, Meta rechaza, «Cambiar token» → Configuración.
- eslint: nuevos limpios; Settings.vue en su 1 previa. webpack «Compiled successfully».

### F3 — «Reconectar con Meta» + marca + aviso
- Componente `whatsapp/Reauthorize.vue` que reusa el FB.login de
  `CloudEmbededSignupWhatsapp.vue` y manda `inbox_id`.
- `EmbeddedSignupService`: H1 (mismo número) y H2 (`reauthorized!`).
- `Settings.vue`: `InboxReconnectionRequired` también para WhatsApp (H4).
- D6: `process_response` con 401 / 190 → `authorization_error!`.
- RSpec + Vitest.

#### ✅ F3 hecha (26/11/2026)

**Ajuste del usuario:** la pestaña «Diagnóstico» va **justo después de «Configuración»**
(orden: Ajustes, Agentes, Horario, Configuración, Diagnóstico, Preguntas, Llamadas, Bot).

**Servidor**
- `EmbeddedSignupService` con `inbox_id` → `reconnect_channel`:
  - **H1**: si en la ventana de Meta eligen otro número → 422 «En la ventana de Meta elegiste otro
    número (+52…). Para reconectar esta bandeja elige su mismo número…»; la bandeja no se toca.
  - Guarda token, `phone_number_id` y `business_account_id`; **H2**: `reauthorized!` (quita la marca).
  - **Bandeja dada de alta a mano**: conserva su origen y solo `subscribe_app` (sin mandar la URL
    de este servidor: la WABA puede estar compartida con producción).
  - **No registra el número al reconectar** (registrarlo pone un PIN nuevo de verificación en dos
    pasos; `code_verification_status: EXPIRED` es normal en Cloud). Riesgo encontrado al hacer F3.
  - Con el token nuevo la bandeja re-sincroniza sus plantillas (comportamiento de siempre).
- `_inbox.json.jbuilder`: WhatsApp manda `reauthorization_required` (**H4**: antes no llegaba a la
  pantalla).
- `WhatsappCloudService#process_response` (**D6 / H3**): un envío con 401 o error 190 suma
  `authorization_error!` (2 seguidos → marca + correo de aviso).

**Pantalla**
- `channels/whatsapp/embeddedSignupMixin.js`: la ventana oficial de Meta (SDK, FB.login con
  config_id, mensajes WA_EMBEDDED_SIGNUP). El alta (`CloudEmbededSignupWhatsapp.vue`) no se tocó.
- `channels/whatsapp/Reauthorize.vue`:
  - `variant="banner"`: aviso rojo arriba de la bandeja — «WhatsApp perdió el permiso de Meta:
    esta bandeja no recibe ni envía mensajes. Reconéctala…» [Reconectar con Meta].
  - `variant="button"`: en el Diagnóstico, junto a «Cambiar token», con la ayuda «entra con la
    cuenta que administra el negocio y elige el mismo número».
  - Deshabilitado con explicación si la app de Meta del sistema está mal (R0) o falta App ID /
    config_id. Al terminar recarga las bandejas y el Diagnóstico se corre solo.

```
  token vencido ─► envío falla 401/190 (×2) ─► marca ─► aviso rojo en la bandeja
                                                      └► Diagnóstico: ✗ permiso / ✗ marca
  [Reconectar con Meta] ─► ventana de Meta ─► POST /whatsapp/authorization {…, inbox_id}
        ├─ otro número → «elegiste otro número…» (no cambia nada)
        └─ mismo número → token nuevo, sin marca, re-suscribe → «Listo» → diagnóstico de nuevo
```

**Pila de pruebas**
- RSpec: `embedded_signup_service_reconnect_spec.rb` (5: misma bandeja y token nuevo, alta a mano
  sin URL ni registro, alta con Meta con URL, otro número, quita la marca),
  `providers/whatsapp_cloud_service_token_error_spec.rb` (3: 190 suma error, dos marcan, 131047 no
  cuenta), `inboxes/whatsapp_reauthorization_spec.rb` (1). WhatsApp completo: **333 ejemplos,
  2 fallas** (las de Brasil de siempre).
- Vitest: `channels/whatsapp/specs/Reauthorize.spec.js` (5: abre Meta y manda inbox_id, otro
  número, app mal configurada, sin config_id, cancelar). Bandejas: **22 pruebas, 0 fallas**.
- Rubocop / eslint sin faltas nuevas; webpack «Compiled successfully».
- Navegador: el aviso rojo no se pudo ver sin marcar la bandeja (escribiría en Redis y mandaría
  el correo de aviso) → F5.

**Requisito para probar en develop:** App Secret correcto de la app del alta en Super Admin y
`develop.wintook.com` permitido en esa app de Meta (dominios del SDK de JavaScript / OAuth); el
usuario indica que hoy esos datos son de otro dominio.

### F4 — Errores traducidos en la conversación (D7)
- El mensaje fallido muestra el texto de la tabla; el error crudo en «ver más».

#### ✅ F4 hecha (26/11/2026) + D8 + reconectar siempre

**F4 / D7 — error traducido en la conversación**
- `dashboard/helper/metaErrorTranslator.js` (nuevo): mismos códigos que el traductor del
  servidor; entiende «código: título» y el JSON del envío. Código conocido → texto claro +
  «(Meta 131047)» para soporte; desconocido → el texto original (correo y otros canales igual).
- `Message.vue` (`externalError`): el tooltip del ícono rojo del mensaje fallido usa el
  traductor. Ej.: «Pasaron más de 24 h desde el último mensaje del cliente: usa una plantilla.
  (Meta 131047)» en vez de `{"error":{"message":"(#131047) Re-engagement message",…}}`.
- Se hizo en pantalla (no en el servidor): no cambia cómo se guarda ni cómo viaja el mensaje.

**D8 — «Copiar diagnóstico para soporte»** (junto a «Ejecutar diagnóstico»)
```
  Diagnóstico de WhatsApp · Whatsapp +5213… · bandeja #1563
  Último diagnóstico: 26/11/2026 22:51

  RECIBIR MENSAJES
  ✓ El permiso de Meta de esta bandeja está vigente
     No se pudo revisar cuándo vence: …
  ⚠ Último mensaje recibido: hace 35 días
  …
```

**Pedido del usuario — reconectar siempre se puede**
- Sección fija «Reconexión con Meta» al final del Diagnóstico con [Reconectar con Meta] y
  [Cambiar token], y el texto según el estado:
  - conectada → «La bandeja está conectada: **no es necesario reconectar**. Hazlo solo si soporte
    te lo pide o si cambió la cuenta de Meta que administra el número.»
  - permiso rechazado o marca → «Meta rechazó el permiso de esta bandeja: reconectarla lo resuelve.»
  - sin diagnóstico → «Úsalo si el permiso venció… Ejecuta el diagnóstico para saber si hace falta.»
- El «Reconectar» de cada revisión abre esa misma sección (una sola ventana de Meta).
- **Riesgo corregido:** con la bandeja marcada había dos instancias escuchando la ventana de Meta
  (aviso rojo + Diagnóstico) y las dos habrían mandado la reconexión; ahora solo procesa la que
  abrió la ventana (`signupStarted` en el mixin).

**Pila de pruebas**
- Vitest: `helper/specs/metaErrorTranslator.spec.js` (3), `WhatsappHealthPage.spec.js` +3
  (estados de reconexión, «Reconectar» de la revisión, copiar para soporte),
  `Reauthorize.spec.js` +1 (dos instancias, procesa una). Bandejas + traductor + conversación:
  **85 nuevas/actuales en verde**; las 4 de `MoveActions` (silenciar conversación) ya fallaban
  sin esta rama.
- eslint sin faltas nuevas (`Message.vue` conserva su 1 previa). webpack «Compiled successfully».
- Navegador (headless, #1563, solo «Ejecutar diagnóstico»; sesión borrada): pestaña después de
  Configuración, botón de copiar visible, sección de reconexión en «no es necesario».

### F5 — Pruebas en navegador (develop, cuenta con WABA de prueba)
1. Diagnóstico de una bandeja sana: todo ✓.
2. Quitar la suscripción en Meta → R2 ✗ → «Suscribir ahora» → ✓ y vuelven a llegar mensajes.
3. Reconectar con Meta eligiendo el mismo número → listo; con otro número → rechazo (H1).
4. Token revocado → envío falla 2 veces → aviso «Reconexión requerida» → reconectar → se quita.
5. Mensaje fuera de 24 h → fallido con «usa una plantilla».

---

## 6. Fuera de alcance
- Revisión automática diaria de todas las bandejas (job) — después, si sirve el manual.
- Mensaje de prueba (D3).
- 360dialog, Twilio y UnoAPI (este diagnóstico es para WhatsApp Cloud).
- Arreglar los correos del sistema (H5, diag/revision_correos).
