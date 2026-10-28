# Plan — Canal TikTok (mensajes directos)

**Rama:** `feat/inbox_tiktok` (desde `develop`, `8bdb62a1`)
**Origen:** `/opt/chatwoot_tiktok`, Chatwoot **4.16.2**, donde el canal ya funciona.
**Destino:** este fork, Chatwoot **3.13.6**.
**Estado:** solo plan. Nada implementado.

El trabajo es una **paridad**: portar el canal tal cual está en 4.16.2, adaptándolo a lo
que 3.13.6 no tiene. No hay que diseñar nada nuevo — hay que traducir.

---

## 1. Qué es exactamente

Mensajes directos de TikTok contra la **TikTok Business API**
(`business-api.tiktok.com/open_api/v1.3`). Nada de comentarios en vídeos: solo la bandeja
de DMs de una cuenta de empresa.

Se parece a lo que ya hicimos con Instagram, pero hay **tres diferencias de fondo** que
cambian el diseño y conviene tener claras antes de empezar:

```
                     Instagram (ya hecho)          TikTok (esto)
  ─────────────────────────────────────────────────────────────────────────
  Identidad          instagram_id (IGSID)          business_id (open_id)
  source_id del      id del usuario                id de la CONVERSACIÓN
    contact_inbox    ↑ un contacto = una persona   ↑ un contacto = un hilo
  Token              60 días, se renueva solo      ~1 día + refresh token
  Webhook            se suscribe POR CUENTA        se registra UNA VEZ por app
  Verificación       handshake GET hub.challenge   firma HMAC-SHA256 por petición
  Ventana            24 h (7 días con HUMAN_AGENT) 48 h fijas
```

La segunda fila es la más importante y la más fácil de pasar por alto: **el `source_id`
del `contact_inbox` es el id de la conversación de TikTok, no el del usuario.** Es una
decisión de upstream, no un error: la API de mensajería de TikTok gira alrededor de
`conversation_id` y no expone un identificador estable de persona con el que agrupar.
Consecuencia práctica: si el mismo usuario abriera dos hilos, saldrían como dos contactos.

---

## 2. Cómo funciona

### 2.1 Las piezas

```
   ┌──────────────────────────── ALTA (OAuth) ────────────────────────────┐
   │                                                                       │
   │  Tiktok.vue ──► authorizations_controller ──► AuthClient.authorize_url│
   │  (botón)          (firma el state en JWT)      www.tiktok.com/v2/auth │
   │                                                          │            │
   │                        TikTok redirige                   ▼            │
   │  callbacks_controller ◄──────────────────────  /tiktok/callback       │
   │        │                                                              │
   │        ├─ AuthClient.obtain_short_term_access_token(code)             │
   │        ├─ Client.business_account_details  (nombre, avatar)           │
   │        └─ crea Channel::Tiktok + Inbox                                │
   └───────────────────────────────────────────────────────────────────────┘

   ┌────────────────────────── ENTRADA (webhook) ─────────────────────────┐
   │                                                                       │
   │  TikTok ──POST /webhooks/tiktok──► TiktokController                   │
   │                                      │ verify_signature! (HMAC+5 s)   │
   │                                      ▼                                │
   │                              TiktokEventsJob   (lock por conversación)│
   │                                      │                                │
   │            ┌─────────────────────────┼──────────────────────────┐     │
   │            ▼                         ▼                          ▼     │
   │      im_receive_msg            im_send_msg             im_mark_read_msg│
   │      (entrante)                (eco / saliente)        (leído)         │
   │            │                         │                          │     │
   │            └────────► MessageService ◄┘              ReadStatusService │
   │                            │                                          │
   │                            ├─ MessagingHelpers: contacto, conversación │
   │                            ├─ Client.file_download_url  (imágenes)     │
   │                            └─ crea Message                             │
   └───────────────────────────────────────────────────────────────────────┘

   ┌────────────────────────── SALIDA (respuesta) ────────────────────────┐
   │                                                                       │
   │  Agente ──► SendReplyJob ──► SendOnTiktokService                       │
   │                                 │ validate_message_support!            │
   │                                 ▼                                      │
   │                             Tiktok::Client                             │
   │                                 ├─ send_text_message                   │
   │                                 └─ send_media_message (upload + send)  │
   │                                        │                               │
   │                                 TokenService ──► token válido          │
   └───────────────────────────────────────────────────────────────────────┘
```

### 2.2 El ciclo de los tokens

Es lo más distinto respecto a Instagram y el punto donde más fácil es equivocarse:

```
  alta ──► access_token (~1 día)  +  refresh_token (vida propia, más larga)
              │
              ▼
   cada llamada pide channel.validated_access_token
              │
              ▼
        ┌─ ¿faltan más de 5 min para que caduque? ──► sí ──► se usa tal cual
        │
        └─ no ──► ¿el refresh_token sigue vivo?
                        │
                        ├─ sí ──► lock Redis (30 s) ──► renew_short_term_access_token
                        │           │                     guarda AMBOS tokens
                        │           └─ ¿no consigo el lock? ──► devuelve el actual
                        │              (otro proceso lo está renovando)
                        │
                        └─ no ──► prompt_reauthorization!  (banner + correo)
```

Se renueva **de forma perezosa**, al usarlo, no con un job programado. Con tokens de un
día eso significa que **un inbox sin tráfico durante más de un día se queda sin token
válido hasta que llegue el primer mensaje**, que sí lo renueva. Es aceptable porque el
webhook entrante también pasa por aquí.

> ⚠️ En Instagram añadimos un job diario justo porque el refresco perezoso dejaba morir
> los inboxes dormidos. Aquí no hace falta lo mismo (el webhook entra igual), pero
> **conviene decidirlo a conciencia**, no por omisión. Ver §6.

### 2.3 Qué mensajes se soportan

| Tipo TikTok  | Entrada                              | Salida                    |
|--------------|--------------------------------------|---------------------------|
| `text`       | ✅ contenido del mensaje             | ✅                        |
| `image`      | ✅ se descarga y adjunta             | ✅ 1 sola, JPG/PNG, <3 MB |
| `share_post` | ✅ adjunto `embed` con la URL        | ❌                        |
| `sticker`    | ⚠️ se marca `is_unsupported`         | ❌                        |

Dos restricciones de la API que se validan **antes** de enviar, porque TikTok rechaza el
mensaje entero: **no se pueden mezclar texto y adjunto** en el mismo mensaje, y **solo un
adjunto por mensaje**. Además, el envío de imágenes se consulta **por conversación**
(capacidad `IMAGE_SEND`) y se cachea en `conversation.additional_attributes.tiktok_capabilities`.

---

## 3. Inventario: qué se trae

### 3.1 Backend — copia casi literal (13 archivos)

```
  app/models/channel/tiktok.rb                        modelo + validaciones + encrypts
  db/migrate/*_add_tiktok_channel.rb                  tabla channel_tiktok
  app/services/tiktok/auth_client.rb                  OAuth + registro del webhook
  app/services/tiktok/token_service.rb                refresco con lock
  app/services/tiktok/client.rb                       API: enviar, subir, descargar
  app/services/tiktok/message_service.rb              webhook → Message
  app/services/tiktok/messaging_helpers.rb            contacto / conversación / adjuntos
  app/services/tiktok/read_status_service.rb          acuses de lectura
  app/services/tiktok/send_on_tiktok_service.rb       envío
  app/controllers/webhooks/tiktok_controller.rb       firma HMAC
  app/jobs/webhooks/tiktok_events_job.rb              router de eventos
  app/controllers/tiktok/callbacks_controller.rb      callback OAuth
  app/controllers/api/v1/accounts/tiktok/
                     authorizations_controller.rb     inicio del OAuth
  app/helpers/tiktok/integration_helper.rb            state firmado en JWT
```

### 3.2 Backend — líneas sueltas en archivos compartidos

```
  app/models/inbox.rb                    + tiktok?
  app/models/account.rb                  + has_many :tiktok_channels
  app/models/concerns/reauthorizable.rb  + tiktok_disconnect
  app/jobs/send_reply_job.rb             + entrada en el mapa
  app/views/api/v1/models/_inbox.json.jbuilder  + reauthorization_required
  app/mailers/.../channel_notifications_mailer.rb + tiktok_disconnect + plantilla
  lib/redis/redis_keys.rb                + 2 claves de lock
  config/routes.rb                       + 4 rutas
  config/features.yml                    + channel_tiktok  (AL FINAL, ver §6)
  config/installation_config.yml         + 3 claves
  app/controllers/super_admin/app_configs_controller.rb + grupo 'tiktok'
  enterprise/app/helpers/super_admin/features.yml       + tarjeta
  app/views/super_admin/application/_icons.html.erb     + icono
```

### 3.3 Frontend

Aquí **ya tenemos molde**: es exactamente la misma forma que el canal de Instagram que
acabamos de construir en 3.13. Se copia la estructura, no el código de 4.16.

```
  tiktokClient.js                        nuevo (calcado de instagramClient.js)
  channels/Tiktok.vue                    nuevo (calcado de Instagram.vue)
  channels/tiktok/Reauthorize.vue        nuevo (calcado de instagram/Reauthorize.vue)
  ChannelList.vue · channel-factory.js   + tarjeta y ruta
  inboxMixin.js · helper/inbox.js        + isATiktokChannel, INBOX_TYPES.TIKTOK, icono
  Settings.vue                           + banner de reautorización
  ReplyBox.vue                           + límite de longitud, texto/adjunto excluyentes,
                                           capacidad IMAGE_SEND por conversación
  ReplyBottomPanel.vue                   + ocultar lo no soportado
  dashboard-icons.json                   + icono brand-tiktok
  i18n es/en                             + INBOX_MGMT.ADD.TIKTOK.*
```

### 3.4 Specs

En 4.16 hay 6 archivos de specs (`client`, `message_service`, `read_status_service`,
`send_on_tiktok_service`, `token_service`, `tiktok_events_job`). Se portan: son la red de
seguridad que hace verificable todo lo anterior sin tener una cuenta de TikTok delante.

---

## 4. La brecha 3.13 ↔ 4.16

Esto es el trabajo real. Todo lo de §3 es copiar; **esto es traducir**.

| Lo que usa 4.16 | ¿En 3.13? | Cómo se resuelve |
|---|---|---|
| `Messages::StatusUpdateService` | ❌ | Portarlo (≈30 líneas, sin dependencias). Lo usa el envío para marcar `delivered`/`failed`. **Lo necesitábamos ya para Messenger**, ver `fix/messenger-paridad-v45`. |
| `Message#outgoing_content` | ❌ | Sustituir por `message.content`. Es lo mismo salvo firma del agente. |
| `Api::V1::Accounts::OauthAuthorizationController` | ❌ | No portar la clase: TikTok solo usa de ella el guard de administrador. Se replica con un `before_action :check_authorization` de 3 líneas, igual que hicimos en el controlador de Instagram. |
| `Attachment` `file_type: :embed` | ❌ | Añadir el valor al enum (**al final**, el número importa). Solo lo usa `share_post`. Alternativa: mapear a `:file` y perder la vista previa. |
| `Chatwoot.encryption_configured?` + `encrypts` | ❌ | Decisión, ver §6. Lo más simple: **guardar los tokens en claro**, como ya hacen `Channel::Instagram` y `Channel::FacebookPage` en este fork. |
| `CustomExceptions::Inbox::LimitExceeded` | ❌ | Quitar ese `rescue` del callback. En 3.13 no hay límite de inboxes. |
| `Conversations::MessageWindowService` | ❌ | No portar el servicio. La ventana de 48 h se implementa con `messaging_window_enabled?` en el canal + una rama en `Conversation#can_reply?`, que es como funciona hoy aquí. |
| Onboarding (`return_to`, `app_onboarding_inbox_setup_url`) | ❌ | No existe ese flujo en 3.13. Se elimina el `return_to` del state y la rama del callback. |
| `InboxReconnectionRequired.vue`, `components-next`, `useInbox.js` | ❌ | No usar. El front se calca del de Instagram nuestro. |
| `Conversations::UpdateMessageStatusJob` | ✅ | Igual, salvo que la nuestra actualiza el mensaje directo en vez de pasar por `StatusUpdateService`. Compatible. |
| `MutexApplicationJob#with_lock(key, timeout)` | ✅ | Misma firma. |
| `Redis::LockManager` | ✅ | Igual. |
| Gemas `down`, `faraday-multipart`, `jwt`, `oauth2`, `httparty` | ✅ | Todas presentes. **No hay que tocar el Gemfile.** |

---

## 5. Fases

Cada fase deja el árbol en verde y es verificable por sí sola.

```
  F1  Modelo y migración          channel_tiktok, Channel::Tiktok, feature flag,
                                  account.rb, inbox.rb. Sin UI, sin red.
                                  ✔ rails runner: crear un canal a mano

  F2  Configuración               installation_config, grupo en Super Admin,
                                  tarjeta + icono, rutas.
                                  ✔ /super_admin/app_config?config=tiktok

  F3  OAuth                       AuthClient, IntegrationHelper, los dos
                                  controladores, alta del inbox.
                                  ✔ specs con dobles; authorize_url a ojo

  F4  Tokens                      TokenService + lock + reautorización.
                                  ✔ spec portado

  F5  Entrada                     webhook + firma HMAC + events job +
                                  MessageService + MessagingHelpers + Client
                                  (descarga). Aquí entra el enum :embed.
                                  ✔ specs portados con payloads reales

  F6  Salida                      SendOnTiktokService + Client (envío y subida)
                                  + Messages::StatusUpdateService + SendReplyJob.
                                  ✔ specs portados

  F7  Lectura y ventana           ReadStatusService + ventana de 48 h.
                                  ✔ spec portado

  F8  Front                       cliente, Tiktok.vue, Reauthorize, ChannelList,
                                  mixin, ReplyBox (reglas de adjuntos), i18n.
                                  ✔ navegador

  F9  Registro del webhook        ⚠️ ver §6 — `update_webhook_callback` existe
      y puesta en marcha          pero NADIE lo llama. Rake + guía.
```

---

## 6. Decisiones abiertas y riesgos

### 6.1 ⚠️ El webhook no se registra solo

`AuthClient.update_webhook_callback` está escrito y **nadie lo llama** — ni un job, ni el
callback, ni una tarea. En 4.16 es una operación manual de consola.

Es el mismo tipo de agujero que nos bloqueó Instagram, con una diferencia que lo hace
menos grave: aquí el registro es **por aplicación, una sola vez**, no por cuenta. Aun así,
si no se hace, **no llega ni un mensaje** y no hay ningún error visible.

Propuesta: una tarea rake `tiktok:doctor` / `tiktok:webhook` al estilo de la de Instagram,
que consulte `webhook_callback` (listar) y permita fijarlo con `update_webhook_callback`.
Es barato y evita repetir la historia.

### 6.2 Cifrado de los tokens

4.16 cifra `access_token` y `refresh_token` con `encrypts`, condicionado a
`Chatwoot.encryption_configured?`, que en 3.13 no existe. Opciones:

- **(a) Sin cifrar** — coherente con `Channel::Instagram` y `Channel::FacebookPage` de este
  fork, que ya guardan sus tokens en claro. Cero trabajo, cero riesgo nuevo.
- **(b) Portar el helper y cifrar** — hay que configurar las claves de Active Record
  Encryption en el entorno; si faltan, la app no arranca. Afecta a más que TikTok.

Recomiendo **(a)** ahora y (b) como trabajo aparte para todos los canales a la vez.

### 6.3 Restricción geográfica de TikTok

El propio código de 4.16 lo documenta: `im_receive_msg` solo llega para usuarios **fuera
del Espacio Económico Europeo, Suiza y Reino Unido**. Un cliente europeo escribiendo a la
cuenta **no genera webhook entrante**. No es un fallo del código y no tiene arreglo por
nuestra parte: es política de TikTok. Conviene saberlo antes de prometer el canal.

### 6.4 Un contacto por conversación

Ya explicado en §1. Si mañana quisiéramos agrupar por persona, el dato existe
(`social_tiktok_user_id` en `additional_attributes`), pero cambiar el `source_id` implica
migrar los `contact_inbox` existentes. **Decidirlo ahora sale gratis; después, no.**

### 6.5 El feature flag va al final

`channel_tiktok` se añade **al final** de `config/features.yml`: la posición define el bit
en FlagShihTzu y moverlo revuelve los flags de todas las cuentas. Misma trampa que ya
pisamos con Instagram.

### 6.6 ¿Refresco programado?

Ver §2.2. El refresco perezoso basta porque el webhook entrante también renueva. Pero si
se quiere que el inbox esté siempre listo para enviar sin esperar a un entrante, hace
falta un job diario como el de Instagram. **Decisión de producto, no técnica.**

---

## 7. Lo que hace falta fuera del código

Sin esto, nada de lo anterior sirve:

1. **App en el portal de TikTok for Developers** con el producto de mensajería.
2. **Scopes aprobados** — son nueve, y varios (`message.list.*`, `user.insights`) exigen
   revisión de TikTok. El callback rechaza la autorización si el usuario no concede
   *todos*, así que una aprobación parcial deja el canal inutilizable.
3. **`TIKTOK_APP_ID` y `TIKTOK_APP_SECRET`** en Super Admin.
4. **Redirect URI** `https://<FRONTEND_URL>/tiktok/callback` dada de alta en el portal.
5. **Webhook** `https://<FRONTEND_URL>/webhooks/tiktok` registrado — ver §6.1.
6. Una **cuenta TikTok Business** de prueba, fuera del EEE (§6.3).

> ⚠️ El punto 2 es el que puede parar el proyecto y no depende de nosotros. Merece
> comprobarse **antes** de escribir código: si los permisos de mensajería no están
> concedidos, se puede portar todo y no poder probar nada.

---

## 8. Referencias

- Origen: `/opt/chatwoot_tiktok` (4.16.2)
- Molde del front y del OAuth: rama `instagram` de este repo · `docs/instagram_plan.md`
- API: `https://business-api.tiktok.com/portal/docs?id=1832184159540418` (OAuth),
  `?id=1832184403754242` (envío), `?id=1832190670631937` (webhooks)
