# Plan — Integración de Instagram como canal nativo

**Rama:** `instagram` (derivada de `develop`)
**Base:** Chatwoot fork 3.13.6
**Fecha:** 2026-07-27
**Estado:** Documento de plan (sin implementar)

---

## 1. Contexto — qué hay hoy

En 3.13.6 **Instagram no es un canal**. Es un "pasajero" de `Channel::FacebookPage`:
al conectar una Página de Facebook, `CallbacksController#set_instagram_id` consulta
`instagram_business_account` y guarda el `instagram_id` en la misma fila de
`channel_facebook_pages`. Los DMs de Instagram caen en **el mismo inbox** que Messenger.

```
                        ESTADO ACTUAL (3.13.6)
                        ======================

  Meta ──POST /webhooks/instagram──► Webhooks::InstagramController
                                          │ params['object'] == 'instagram'
                                          ▼
                                 Webhooks::InstagramEventsJob
                                   (mutex por sender_id+ig_account_id)
                                          │
                                          ▼
                              Instagram::MessageText / ReadStatusService
                                          │
                                          ▼
                         Instagram::WebhooksBaseService#inbox_channel
                                          │
                    Channel::FacebookPage.where(instagram_id: <ig_id>)
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │  INBOX ÚNICO          │
                              │  Channel::FacebookPage│
                              │  ├─ page_id           │  ← Messenger
                              │  └─ instagram_id      │  ← Instagram DM
                              └───────────────────────┘
                                          │
       conversation.additional_attributes['type'] == 'instagram_direct_message'
                                          │
                                          ▼
                    SendReplyJob → Instagram::SendOnInstagramService
                                          │
                       POST graph.facebook.com/v11.0/me/messages
                            (auth: channel.page_access_token)
```

### Inventario del código actual

| Archivo | Rol |
|---|---|
| `app/controllers/webhooks/instagram_controller.rb` | Verify + recepción de eventos (`IG_VERIFY_TOKEN`) |
| `app/controllers/concerns/meta_token_verify_concern.rb` | `hub.challenge` compartido con WhatsApp |
| `app/jobs/webhooks/instagram_events_job.rb` | Fan-out de `entry[:messaging]` / `entry[:standby]` |
| `app/services/instagram/webhooks_base_service.rb` | Resuelve inbox por `instagram_id`, crea contacto |
| `app/services/instagram/message_text.rb` | Evento `message` |
| `app/services/instagram/read_status_service.rb` | Evento `read` |
| `app/services/instagram/send_on_instagram_service.rb` | Envío saliente (Graph v11.0) |
| `app/builders/messages/instagram/message_builder.rb` | Hereda de `Messages::Messenger::MessageBuilder` |
| `app/models/inbox.rb:105` | `instagram?` = `facebook? && channel.instagram_id.present?` |
| `app/models/channel/facebook_page.rb` | `fetch_instagram_story_link`, `delete_instagram_story` |
| `app/models/conversation.rb:148,170` | Ventana de 24 h (`can_reply_on_instagram?`) |
| `app/models/attachment.rb:84` | `data_url = external_url` para adjuntos IG entrantes |
| `app/javascript/.../channels/Facebook.vue` | Login FB SDK con scopes `instagram_basic, instagram_manage_messages` |
| `.../bubble/InstagramStory*.vue` | Render de story mention / story reply |
| `config/installation_config.yml` | `IG_VERIFY_TOKEN`, `FB_APP_ID`, `FB_APP_SECRET` |

### Problemas de este diseño

1. **Dependencia de Facebook Login.** El flujo actual exige Página de Facebook vinculada.
   Meta está retirando "Instagram Messaging via Facebook Login" en favor de
   **Instagram API with Instagram Login** (`instagram_business_*`). ⚠️ *Verificar fechas
   exactas de sunset en la doc de Meta antes de arrancar — ver §9.*
2. **Graph API v11.0** hardcodeada en `send_on_instagram_service.rb` y en el `base_uri`
   del job. Versión muy anterior a la mínima soportada hoy.
3. **Inbox compartido.** No se pueden asignar agentes, horarios, automatizaciones ni
   reportes distintos para Messenger vs Instagram.
4. **Token de Página**, no de Instagram: si se rompe la vinculación FB↔IG, muere el canal.
5. **Sin refresh de token.** No hay job de renovación (los tokens de Instagram Login
   caducan a 60 días y requieren refresh explícito).
6. **Cobertura de eventos mínima:** solo `message` y `read`. Faltan reacciones,
   `message_unsend` (borrado), postbacks de icebreakers, respuestas a Reels.

---

## 2. Objetivo

Convertir Instagram en un **canal de primera clase** (`Channel::Instagram`), con
autenticación propia (Instagram Login), inbox propio, refresco de token automático y
una **ruta de migración** para los inboxes que hoy funcionan vía `Channel::FacebookPage`.
El canal viejo debe seguir funcionando durante la transición (modo dual).

```
                        ESTADO OBJETIVO
                        ===============

  Meta ──POST /webhooks/instagram──► Webhooks::InstagramController
                                          │
                                          ▼
                              Webhooks::InstagramEventsJob
                                          │
                                          ▼
                        ┌─────────── ROUTER por entry[:id] ───────────┐
                        │                                             │
          Channel::Instagram.find_by(instagram_id:)     Channel::FacebookPage
                        │  (nuevo, prioritario)          .find_by(instagram_id:)
                        ▼                                             ▼
             ┌──────────────────────┐                    ┌──────────────────────┐
             │ INBOX Instagram      │                    │ INBOX Facebook       │
             │ Channel::Instagram   │                    │ (legacy IG dentro)   │
             │ ├─ instagram_id      │                    │ ├─ page_id           │
             │ ├─ access_token      │                    │ └─ instagram_id      │
             │ └─ expires_at        │                    └──────────────────────┘
             └──────────────────────┘                                │
                        │                                             │
                        ▼                                             ▼
      POST graph.instagram.com/v22.0/{ig_id}/messages   graph.facebook.com/.../messages
             (auth: channel.access_token)                  (auth: page_access_token)
```

---

## 3. Modelo de datos

Nueva tabla `channel_instagram` (espejo de la de upstream, para facilitar futuros merges):

```
channel_instagram
├── id            bigint  PK
├── account_id    bigint  NOT NULL  (index)
├── access_token  string  NOT NULL  (index)   ← long-lived, 60 días
├── instagram_id  string  NOT NULL  UNIQUE    ← IGSID de la cuenta de negocio
├── expires_at    datetime                    ← vencimiento del token
├── provider_config jsonb DEFAULT '{}'        ← metadatos (username, name, avatar)
├── created_at / updated_at
└── index [account_id, instagram_id] UNIQUE
```

`Channel::Instagram` incluye `Channelable` + `Reauthorizable` y expone:

```ruby
def name                    = 'Instagram'
def messaging_window_enabled?  = true          # ventana de 24 h real
def create_contact_inbox(ig_scoped_id, name)   # igual firma que FacebookPage
def token_expired?          = expires_at < Time.current
def refresh_long_lived_token
```

---

## 4. Flujo de autenticación (Instagram Login)

```
  Agente (dashboard)                Chatwoot                       Meta / Instagram
        │                              │                                  │
        │ 1. click "Instagram"         │                                  │
        ├─────────────────────────────►│                                  │
        │                              │ 2. redirect a                    │
        │◄─────────────────────────────┤ instagram.com/oauth/authorize    │
        │                              │    scope=instagram_business_basic│
        │                              │         ,..._manage_messages     │
        │ 3. login + consentimiento    │                                  │
        ├──────────────────────────────┼─────────────────────────────────►│
        │                              │ 4. GET /instagram/callback?code= │
        │                              │◄─────────────────────────────────┤
        │                              │                                  │
        │                              │ 5. POST api.instagram.com/oauth/access_token
        │                              ├─────────────────────────────────►│
        │                              │◄──── short-lived token (1 h) ────┤
        │                              │                                  │
        │                              │ 6. GET graph.instagram.com/access_token
        │                              │        grant_type=ig_exchange_token
        │                              ├─────────────────────────────────►│
        │                              │◄──── long-lived token (60 d) ────┤
        │                              │                                  │
        │                              │ 7. GET /me?fields=user_id,username,
        │                              │        name,profile_picture_url  │
        │                              ├─────────────────────────────────►│
        │                              │                                  │
        │                              │ 8. crea Channel::Instagram + Inbox
        │                              │    + AvatarFromUrlJob            │
        │ 9. redirect a "añadir agentes"                                  │
        │◄─────────────────────────────┤                                  │
```

Renovación (job diario):

```
  Cron diario ──► Channels::Instagram::RefreshOauthTokenJob
                        │
                        ├─ Channel::Instagram.where('expires_at < ?', 10.days.from_now)
                        │
                        ├─ GET graph.instagram.com/refresh_access_token
                        │       grant_type=ig_refresh_token
                        │
                        ├─ éxito  → update(access_token:, expires_at: +60d)
                        └─ fallo  → channel.authorization_error!  (banner de reautorizar)
```

> Nota: el refresh solo funciona si el token tiene ≥24 h de vida y <60 días.
> Por eso el umbral de 10 días de margen y un reintento diario.

---

## 5. Ruteo de webhooks (modo dual)

El endpoint `/webhooks/instagram` es único; hay que decidir a qué canal pertenece cada
`entry`. Además, con Instagram Login el payload puede llegar con `entry[:messaging]`
igual que hoy, pero el `entry[:id]` es el **IGSID** de la cuenta.

```
                       entry[:id]  (ig account id)
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
   Channel::Instagram exists?        Channel::FacebookPage
              │                      .where(instagram_id:)
        SÍ ───┤                              │
              │                        SÍ ───┤
              ▼                              ▼
   inbox nativo Instagram          inbox legacy (Messenger+IG)
              │                              │
              └──────────────┬───────────────┘
                             ▼
                  NO ──► log warn + descartar
                         (no romper con 200 OK a Meta)
```

Implementación: extraer la resolución a `Instagram::ChannelResolver` (o método privado
en `WebhooksBaseService`) que devuelva el inbox y que **priorice** `Channel::Instagram`.
Así, cuando se migre un inbox, el tráfico salta solo al canal nuevo.

Eventos a soportar (ampliando `SUPPORTED_EVENTS`):

| Evento | Payload | Acción |
|---|---|---|
| `message` | `messaging[].message` | crea mensaje (ya existe) |
| `read` | `messaging[].read` | marca leído (ya existe) |
| `message_reactions` | `reaction` | *fase 2* — guardar en `content_attributes` |
| `messaging_postbacks` | `postback` | *fase 2* — icebreakers / botones |
| `message_unsend` | `message.is_deleted` | *fase 2* — borrar/tachar mensaje |
| `standby` | `entry[:standby]` | ya contemplado (handover protocol) |

### 5.1 Idempotencia — cómo se evitan los duplicados

Durante la convivencia una misma cuenta de Instagram puede quedar entregando por las dos
rutas a la vez. **No se puede delegar en Meta**: el job procesa también los eventos de
standby (`messages(entry)` lee `entry[:messaging].presence || entry[:standby]`), así que
una app degradada a standby igual produce mensaje. La defensa va en el código:

```
  Copia A (ruta legacy)        Copia B (canal nativo)
        │                            │
        └──────────┬─────────────────┘
                   ▼
   ① ROUTER prioriza Channel::Instagram
      → ambas copias caen en el MISMO inbox/conversación
                   ▼
   ② MUTEX de InstagramEventsJob
      key = sender_id + ig_account_id → idéntico en ambas
      → procesamiento serializado, sin carrera SELECT/INSERT
                   ▼
   ③ already_sent_from_chatwoot?  (mismo mid, misma conversación)
      → la segunda copia se descarta
```

Las capas ① y ② ya existen. La ③ **también existe** —
`message_builder.rb:160` consulta `conversation.messages.where(source_id: mid)` — pero
está condicionada a los echoes salientes:

```ruby
# message_builder.rb:109  (actual)
return if @outgoing_echo && already_sent_from_chatwoot?
# propuesto
return if already_sent_from_chatwoot?
```

El índice `index_messages_on_source_id` ya está en `schema.rb:1185`, así que el coste es
despreciable. **Beneficio colateral:** hoy no hay nada que impida duplicados por los
reintentos de webhook de Meta ni por el `retry_on LockAcquisitionError, attempts: 8` del
job; este cambio los cubre también.

> Un índice `UNIQUE` a nivel de BD sería el cinturón definitivo, pero `source_id` tiene
> semánticas distintas en email y WhatsApp — se descarta como endurecimiento global.

---

## 6. Fases de trabajo

### F0 — Preparación (sin código)
- [ ] App de Meta con producto **Instagram** (Instagram Login para business) configurada.
- [ ] Permisos: `instagram_business_basic`, `instagram_business_manage_messages`
      (verificar nombres vigentes en la doc de Meta).
- [ ] URI de redirección: `https://<host>/instagram/callback`.
- [ ] Webhook `instagram` suscrito a `messages`, `messaging_seen`, `message_reactions`,
      `messaging_postbacks` con el `IG_VERIFY_TOKEN` existente.
- [ ] Decidir si se reutiliza `FB_APP_ID/SECRET` o se crean `IG_APP_ID/IG_APP_SECRET`
      (recomendado: **claves propias**, para poder desacoplar de Facebook).

### F1 — Modelo y esquema
- `db/migrate/*_create_channel_instagram.rb` + `db/schema.rb`
- `app/models/channel/instagram.rb`
- `app/models/account.rb` → `has_many :instagram_channels, class_name: 'Channel::Instagram'`
- `app/models/inbox.rb` → `instagram?` pasa a ser
  `channel_type == 'Channel::Instagram' || (facebook? && channel.instagram_id.present?)`
  y se añade `instagram_direct?` para distinguir el canal nativo.
- `config/features.yml` → feature `channel_instagram` — **añadir AL FINAL del archivo**,
  ver §8.bis-1
- `config/installation_config.yml` + `.env.example` → `IG_APP_ID`, `IG_APP_SECRET`

**Tres decisiones de F1 que no son cosméticas:**

**a) La columna se llama `instagram_id`, no `ig_id`.** `message.rb:252` (`save_story_info`)
hace `inbox.channel.instagram_id`, y esa ruta **está viva**: la invoca el builder de
Instagram en `save_story_id` (`message_builder.rb:123`). Con otro nombre de columna, las
story replies del canal nativo revientan con `NoMethodError`.

**b) Las conversaciones nativas siguen marcándose con
`additional_attributes['type'] = 'instagram_direct_message'`.** `conversation.rb:148` no
mira `inbox.instagram?` — se bifurca por ese atributo. Si el canal nativo deja de
ponerlo, `can_reply?` cae en la rama genérica y **se pierde la lógica de 7 días con
`HUMAN_AGENT`** de `can_reply_on_instagram?` (`conversation.rb:170`). Manteniéndolo, el
diff en la ventana de respuesta es cero.

**c) No hace falta reimplementar `fetch_instagram_story_link`.** `validate_instagram_story`
(`message.rb:185`) e `instagram_story_mention?` (`message_filter_helpers.rb:28`) son
**código muerto en este fork** — nadie los llama (el único otro hit es el archivo de
respaldo `message090226.rb090226`). En upstream sí se invocan desde el controlador de
mensajes. Como ese método es justo el que depende de Koala y del token de Página,
`Channel::Instagram` se ahorra la parte más fea. Las stories se siguen renderizando
porque `InstagramStory.vue` trabaja sobre `content_attributes`, no sobre esos helpers.

**Compatibilidad de `inbox.instagram?`** — con la redefinición propuesta, los llamadores
existentes se comportan igual:

| Llamador | Con canal nativo |
|---|---|
| `attachment.rb:84` (`data_url = external_url` en entrantes) | Correcto, IG sirve URLs de CDN |
| `message_filter_helpers.rb:29,33` | Correcto (código muerto, pero coherente) |
| `conversation.rb:148` | No usa `instagram?` — ver (b) |

**Criterio de aceptación:** `Channel::Instagram.create!` + `Inbox.create!` por consola
funciona, `inbox.instagram?` da `true`, y un inbox legacy Messenger+IG sigue dando `true`
con sus specs en verde. No hay UI ni tráfico todavía.

### F2 — OAuth y alta de inbox
- `app/controllers/instagram/callbacks_controller.rb` (patrón de `google/callbacks`)
- `app/services/instagram/oauth_service.rb` (authorize URL, exchange, long-lived, `/me`)
- `config/routes.rb` → `get 'instagram/callback'` + `post :register_instagram_page`
- Reautorización: reutilizar `Reauthorizable` y el banner existente.

### F3 — Recepción
- Router dual en `WebhooksBaseService` (§5)
- **Idempotencia por `mid`** (ver §5.1): quitar el `@outgoing_echo &&` de
  `message_builder.rb:109`. Sin esto la convivencia de canales genera mensajes duplicados.
- `Webhooks::InstagramEventsJob`: quitar `base_uri` v11.0, resolver canal antes del mutex
- `Messages::Instagram::MessageBuilder`: dejar de depender de Koala cuando el canal es
  nativo (los errores de auth llegan como HTTP 190 de `graph.instagram.com`)
- Perfil del contacto: `GET graph.instagram.com/v22.0/{igsid}?fields=name,username,profile_pic`

### F4 — Envío
- `Instagram::SendOnInstagramService`: elegir host y credencial según `channel_class`
  ```
  Channel::Instagram   → graph.instagram.com/v22.0/{ig_id}/messages  + access_token
  Channel::FacebookPage → graph.facebook.com/{API_VER}/me/messages   + page_access_token
  ```
- `SendReplyJob`: añadir `'Channel::Instagram' => ::Instagram::SendOnInstagramService`
  al hash de servicios (el `case` de FacebookPage se queda para el legacy)
- Versión de API a constante configurable (`FACEBOOK_API_VERSION` ya existe; añadir
  `INSTAGRAM_API_VERSION`) — **no** volver a hardcodear.

### F5 — Renovación de token
- `app/jobs/channels/instagram/refresh_oauth_token_job.rb`
- Entrada en `config/schedule.yml` (diario)
- `authorization_error!` cuando falle → banner de reautorizar en el dashboard

### F6 — Frontend
Nueva tarjeta "Instagram" en la pantalla *Añadir inbox*. Hoy esa lista está **hardcodeada**
en `ChannelList.vue:28-44` (8 entradas; `{ key: 'facebook', name: 'Messenger' }` es la de
Meta). Hacen falta tres cosas, ninguna opcional:

1. `+ { key: 'instagram', name: 'Instagram' }` en `channelList`
2. Rama `if (key === 'instagram')` en `ChannelItem.vue#isActive` → `channel_instagram`
   (+ que la app de IG esté configurada, igual que `hasFbConfigured` para Messenger)
3. **`public/assets/images/dashboard/channels/instagram.png`** — el thumbnail se resuelve
   por convención (`` `/assets/images/dashboard/channels/${key}.png` ``) y ese archivo
   **no existe**; sin él la tarjeta sale con la imagen rota

Y además, lo que la revisión destapó (§8.bis-2 y §8.bis-3) y que es el grueso de F6:

4. `INBOX_TYPES.INSTAGRAM` + `isAnInstagramInbox` / `isAMetaInbox` en `inboxMixin.js`, y
   sustituirlos en los ~19 puntos que hoy usan `isAFacebookInbox` con intención de "Meta"
5. Badge de conversación: entrada `'Channel::Instagram'` en `Thumbnail.vue` (el PNG
   `instagram-dm.png` ya existe)
6. Pantalla de reautorización propia (`Settings.vue:234` hoy la condiciona a Facebook)

- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Instagram.vue`
  → botón que abre la URL de autorización (sin FB SDK)
- i18n `en` / `es` / `pt_BR`
- Settings del inbox: mostrar `@username` y fecha de expiración del token
- Los componentes `InstagramStory*.vue` se reutilizan tal cual

### F7 — Migración de inboxes existentes

Migración **voluntaria** (banner en el inbox), no masiva. Con la idempotencia de §5.1
activa, el orden correcto es **conectar antes de desconectar** — así no hay ventana en la
que los DMs no lleguen a ningún lado:

```
  1. El agente conecta la cuenta por Instagram Login
        └─► se crea Channel::Instagram  (el router ya lo prioriza)
                    │
  2. SOLAPAMIENTO ──┤  llegan duplicados por ambas rutas
                    │  → ambos resuelven al inbox nuevo → dedupe por mid los absorbe
                    ▼
  3. Quitar permiso/suscripción de Instagram a la app vieja
  4. instagram_id → nil en el Channel::FacebookPage
        └─► el inbox legacy se queda solo con Messenger, intacto
```

> Al revés (desconectar primero) se abre un hueco de pérdida de mensajes. No hacerlo así.

- `lib/tasks/instagram_migration.rake` — mueve conversaciones + `contact_inboxes` del inbox
  viejo al nuevo; **dry-run obligatorio** + reporte
- ⚠️ Los `source_id` de Instagram (IGSID) **se conservan** entre ambas APIs, así que las
  conversaciones históricas siguen entregando. Confirmar con una cuenta de prueba antes
  de tocar producción.

### F8 — Integración con los módulos del fork
Esto es lo que upstream no cubre y aquí sí importa:

| Módulo | Qué tocar |
|---|---|
| `command_agents/commands/sigue.rb:673` | Ya lista `Channel::Instagram` en `META_CHANNEL_TYPES` — validar que el canal nuevo cumple la ventana de 24 h |
| Contact Tracking / Campañas | Los seguimientos que asumen `Channel::FacebookPage` para IG deben aceptar el canal nativo |
| Agentes IA (adjuntos, `{{doc:}}`) | Verificar `SendOnInstagramService` con adjuntos: IG solo acepta URL pública, tipos `image/audio/video/file` |
| Tickets / KB | Sin cambios (canal-agnóstico), solo probar creación de ticket desde conversación IG |
| Plantillas de seguimiento | Instagram **no** tiene plantillas tipo WABA: fuera de ventana solo `HUMAN_AGENT` (7 días, requiere aprobación de Meta) |

### F9 — Pruebas y rollout
- Specs nuevos: `spec/models/channel/instagram_spec.rb`,
  `spec/services/instagram/oauth_service_spec.rb`, router dual en
  `spec/jobs/webhooks/instagram_events_job_spec.rb`, envío nativo en
  `send_on_instagram_service_spec.rb` (parametrizar por canal)
- Fixtures de webhook con `entry[:id]` de cuenta nativa
- Rollout: feature flag por cuenta → 1 cuenta piloto → migrar el resto

---

## 6.bis Configuración en Super Admin

### Cómo está hoy

`/super_admin/app_config?config=facebook` se arma en tres puntos:

```
  enterprise/app/helpers/super_admin/features.yml
      messenger:
        name: 'Messenger'
        description: 'Stay connected ... Facebook & Instagram.'
        config_key: 'facebook'        ◄── genera el enlace ⚙ de la tarjeta
                    │
                    ▼
  app/views/super_admin/settings/show.html.erb:107
      href="/super_admin/app_config?config=<%= attrs[:config_key] %>"
                    │
                    ▼
  app/controllers/super_admin/app_configs_controller.rb:37
      when 'facebook'
        %w[FB_APP_ID FB_VERIFY_TOKEN FB_APP_SECRET
           IG_VERIFY_TOKEN                     ◄── único campo de Instagram, mezclado
           FACEBOOK_API_VERSION
           ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT]
                    │
                    ▼
  config/installation_config.yml → display_title / description / type de cada campo
```

### Cómo queda

**No se toca el grupo `facebook`.** Se añade una tarjeta y un grupo `instagram` aparte,
siguiendo el mismo patrón que ya usa `whatsapp_embedded` en este fork
(`app_configs_controller.rb:44`) — precedente probado, no invento nuevo.

```
   ANTES                                  DESPUÉS
   ─────                                  ───────
  ┌────────────────────┐                 ┌────────────────────┐  ┌────────────────────┐
  │ Messenger      ⚙   │                 │ Messenger      ⚙   │  │ Instagram      ⚙   │
  │ Facebook &         │       ──►       │ Facebook           │  │ Cuentas Business   │
  │ Instagram          │                 │ (Messenger)        │  │ directas           │
  └────────────────────┘                 └────────────────────┘  └────────────────────┘
   config=facebook                        config=facebook         config=instagram
   ├ FB_APP_ID                            ├ FB_APP_ID   (igual)   ├ IG_APP_ID      ★
   ├ FB_VERIFY_TOKEN                      ├ FB_VERIFY_TOKEN       ├ IG_APP_SECRET  ★
   ├ FB_APP_SECRET                        ├ FB_APP_SECRET         ├ IG_VERIFY_TOKEN ↔
   ├ IG_VERIFY_TOKEN  ←mezclado           ├ IG_VERIFY_TOKEN ↔     ├ INSTAGRAM_API_VERSION ★
   ├ FACEBOOK_API_VERSION                 ├ FACEBOOK_API_VERSION  └ ENABLE_MESSENGER_
   └ ENABLE_MESSENGER_HUMAN_AGENT         └ ENABLE_MESSENGER_...      CHANNEL_HUMAN_AGENT ↔

   ★ = clave nueva      ↔ = misma fila de InstallationConfig, visible en ambas pantallas
```

**Claves nuevas** en `config/installation_config.yml`:

| Clave | display_title | Notas |
|---|---|---|
| `IG_APP_ID` | Instagram App ID | Del producto Instagram. **Distinto del Facebook App ID**, incluso dentro de la misma app de Meta |
| `IG_APP_SECRET` | Instagram App Secret | Usado para el intercambio de código y el `appsecret_proof` del canal nativo |
| `INSTAGRAM_API_VERSION` | Instagram API Version | Default `v22.0`. Evita repetir el hardcode de v11.0 |

**Claves compartidas a propósito** (aparecen en los dos grupos):

- `IG_VERIFY_TOKEN` — es **una sola fila** de `InstallationConfig`, así que no puede
  desincronizarse; se muestra en ambos sitios para que quien configure cualquiera de las
  dos rutas lo encuentre. Único cuidado: con dos pestañas abiertas, el último submit gana.
- `ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT` — el mismo flag gobierna el tag `HUMAN_AGENT` en
  Messenger y en Instagram (`send_on_instagram_service.rb#merge_human_agent_tag`). Se
  reutiliza en vez de crear un `ENABLE_INSTAGRAM_...` para no duplicar semántica.

**Lo que NO se añade:** `IG_REDIRECT_URI`. Se deriva de `FRONTEND_URL` igual que hacen
Google y Microsoft — un knob menos que se puede configurar mal.

### ⚠️ El icono no existe

`features.yml` referencia iconos del sprite de super admin
(`app/views/super_admin/application/_icons.html.erb`). Ese sprite tiene
`icon-messenger-line`, `icon-whatsapp-line`, `icon-telegram-line`… pero **no tiene
`icon-instagram-line`**. Hay que añadir el `<symbol id="icon-instagram-line">`; si no, la
tarjeta se renderiza con un hueco vacío.

### Por qué Messenger no se rompe

| Garantía | Motivo |
|---|---|
| La lista `when 'facebook'` no cambia | Los 6 campos actuales siguen exactamente donde están |
| `FB_APP_ID` / `FB_APP_SECRET` intactos | El envío legacy sigue firmando con `FB_APP_SECRET`; el nativo usa `IG_APP_SECRET`, elegido por clase de canal |
| `IG_VERIFY_TOKEN` no cambia de valor | Las apps ya dadas de alta en Meta siguen superando el handshake `hub.challenge` |
| `set_instagram_id` sigue igual | Un inbox de Messenger recién creado sigue capturando Instagram como hoy |
| Router con prioridad | Si no existe `Channel::Instagram` para ese IGSID, cae al `Channel::FacebookPage` — comportamiento idéntico al actual |
| `vueapp.html.erb`: `fbAppId` intacto | La URL de autorización de Instagram se construye en backend, así que el OAuth no necesita `igAppId` en el front. Único añadido: un booleano `instagramEnabled` para atenuar la tarjeta cuando IG no está configurado — no altera `fbAppId` ni el `FB.init` de Messenger |

---

## 7. Archivos — crear vs modificar

```
NUEVOS
  db/migrate/xxxx_create_channel_instagram.rb
  app/models/channel/instagram.rb
  app/controllers/instagram/callbacks_controller.rb
  app/services/instagram/oauth_service.rb
  app/services/instagram/channel_resolver.rb
  app/jobs/channels/instagram/refresh_oauth_token_job.rb
  app/javascript/.../settings/inbox/channels/Instagram.vue
  lib/tasks/instagram_migration.rake
  spec/… (4 archivos)

MODIFICADOS
  db/schema.rb
  app/models/account.rb                      (+has_many)
  app/models/inbox.rb                        (instagram? / instagram_direct?)
  app/models/conversation.rb                 (can_reply_on_instagram? por canal)
  app/models/message.rb                      (validate_instagram_story → solo legacy)
  app/services/instagram/webhooks_base_service.rb   (router dual)
  app/services/instagram/send_on_instagram_service.rb (host + credencial por canal)
  app/jobs/webhooks/instagram_events_job.rb  (quitar base_uri v11.0)
  app/builders/messages/instagram/message_builder.rb (dedupe por mid + errores no-Koala)
  app/jobs/send_reply_job.rb                 (+Channel::Instagram)
  config/routes.rb                           (callback + register)
  config/schedule.yml                        (refresh diario)
  .env.example
  config/locales/{en,es,pt_BR}.yml
  app/javascript/.../settings/inbox/ChannelList.vue      (+entrada instagram)
  app/javascript/.../widgets/ChannelItem.vue             (+isActive instagram)
  app/views/layouts/vueapp.html.erb                      (+instagramEnabled)
  public/assets/images/dashboard/channels/instagram.png  (NUEVO — no existe)

MODIFICADOS — front, acoplamiento con Facebook (§8.bis-2 y -3)
  app/javascript/shared/mixins/inboxMixin.js         (INBOX_TYPES.INSTAGRAM,
                                                      isAnInstagramInbox / isAMetaInbox,
                                                      INBOX_FEATURE_MAP, inboxBadge)
  app/javascript/dashboard/helper/inbox.js           (icono, nombre, warning)
  app/javascript/.../widgets/Thumbnail.vue           (badge Channel::Instagram)
  app/javascript/.../conversation/{Message,MessagesView,ReplyBox}.vue
  app/javascript/.../conversation/bubble/Actions.vue
  app/javascript/.../settings/inbox/Settings.vue     (+ reautorización)

MODIFICADOS — Super Admin (§6.bis)
  config/features.yml                                (channel_instagram AL FINAL — §8.bis-1)
  config/installation_config.yml                     (IG_APP_ID, IG_APP_SECRET,
                                                      INSTAGRAM_API_VERSION)
  app/controllers/super_admin/app_configs_controller.rb  (when 'instagram')
  enterprise/app/helpers/super_admin/features.yml    (tarjeta instagram + config_key)
  app/views/super_admin/application/_icons.html.erb  (symbol icon-instagram-line)
```

---

## 8. Riesgos

| # | Riesgo | Mitigación |
|---|---|---|
| 1 | Cambiar `inbox.instagram?` rompe adjuntos, stories y ventana de 24 h | Mantener el método retrocompatible + specs antes de tocar |
| 2 | ~~Doble entrega si un IGSID queda en ambas tablas~~ **RESUELTO** | Ver §5.1: router con prioridad + mutex existente + dedupe por `mid` (una línea en `message_builder.rb:109`). Pasa a ser tarea de F3, no riesgo abierto |
| 3 | Token de 60 días caduca sin aviso | Job de refresh con margen de 10 días + `authorization_error!` visible |
| 4 | Revisión de la App de Meta (App Review) se demora | Empezar F0 en paralelo a F1–F3; probar con cuentas de rol de la app |
| 5 | `HUMAN_AGENT` tag no aprobado → no se puede responder fuera de 24 h | Documentarlo; los seguimientos IA deben respetar la ventana |
| 6 | Divergencia con upstream si algún día se hace rebase a 4.x | Nombrar tablas/clases **igual que upstream** (`channel_instagram`, `Channel::Instagram`) |
| 7 | Adjuntos: IG exige URL pública accesible | Verificar `attachment.download_url` en la instancia (ActiveStorage host público) |

---

## 8.bis Inconvenientes detectados en la revisión del código

Hallazgos de una pasada específica buscando qué puede estorbar. Ordenados por gravedad.

### 1. 🔴 CRÍTICO — el orden de `config/features.yml` no es libre

El flag de cuenta **no** vive en `enterprise/app/helpers/super_admin/features.yml` (ese
archivo solo dibuja la tarjeta del panel). Vive en `config/features.yml`, y
`Featurable` asigna el bit **por posición en el array**:

```ruby
# app/models/concerns/featurable.rb
FEATURES = FEATURE_LIST.each_with_object({}) do |feature, result|
  result[result.keys.size + 1] = "feature_#{feature['name']}".to_sym
end
```

FlagShihTzu guarda eso en `accounts.feature_flags` (`bigint`, `schema.rb:56`). Es decir:

> **`channel_instagram` debe añadirse AL FINAL de `config/features.yml`.**
> Insertarlo en medio desplaza un bit todas las features posteriores y **revuelve los
> flags de todas las cuentas existentes** — WhatsApp, tickets, ERP, todo.

Nota de capacidad: hay 57 features hoy y un `bigint` da 63 bits utilizables. Quedan ~6
huecos. No es un problema para este trabajo, pero conviene tenerlo en el radar.

### 2. 🟠 ALTO — el front asume `isAFacebookInbox` para todo lo de Instagram

Este es el que más subestimaba F6. Hoy Instagram *es* un inbox de Facebook, así que
**~19 puntos del front** condicionan el comportamiento de Instagram a
`isAFacebookInbox` (`inboxMixin.js:60`, que compara con `Channel::FacebookPage`). Con el
canal nativo ese booleano pasa a `false` y se pierden **en silencio**:

| Qué se pierde | Dónde |
|---|---|
| Render de story mentions / replies | `Message.vue:494` (`isAFacebookInbox && isInstagram`) |
| Comportamiento del compositor | `ReplyBox.vue:235,252` |
| Acciones de la burbuja de mensaje | `Actions.vue:128,149,170` |
| Citar mensaje (`REPLY_TO`) | `inboxMixin.js:23` — `INBOX_FEATURE_MAP` |
| Banner de reautorización | `Settings.vue:234` |
| Secciones de ajustes del inbox | `Settings.vue:206,225`, `WeeklyAvailability.vue:63` |
| Icono de aviso del inbox | `inbox.js:90` (`allowedInboxTypes`) |
| Icono y nombre legible del inbox | `inbox.js:24,58` |

**Propuesta:** añadir `INBOX_TYPES.INSTAGRAM` y dos computed en `inboxMixin` —
`isAnInstagramInbox` y `isAMetaInbox = isAFacebookInbox || isAnInstagramInbox` — y
sustituir en los puntos cuyo *intent* es "canal de Meta" (la mayoría), dejando
`isAFacebookInbox` solo donde de verdad se quiera decir Messenger. Es trabajo mecánico
pero hay que hacerlo entero: cada punto omitido es una regresión silenciosa para el
usuario que migre.

### 3. 🟡 MEDIO — el badge de la conversación saldría vacío

`inboxMixin#inboxBadge` cae a `this.channelType` cuando el inbox no es FB/Twitter/
Twilio/WhatsApp → devolvería `'Channel::Instagram'`. Y `Thumbnail.vue:73` mapea por
clave exacta:

```js
badgeSrc() {
  return {
    instagram_direct_message: 'instagram-dm',
    facebook: 'messenger',
    ...
  }[this.badge];   // 'Channel::Instagram' → undefined → sin badge
}
```

Arreglo trivial: entrada `'Channel::Instagram': 'instagram-dm'`, o que `inboxBadge`
devuelva `instagram_direct_message` para el canal nativo. **El asset ya existe**
(`public/integrations/channels/badges/instagram-dm.png`), se reutiliza tal cual.

### 4. 🟡 MEDIO — el webhook no verifica la firma de Meta

`Webhooks::InstagramController#events` acepta cualquier POST con `object == 'instagram'`;
no valida `X-Hub-Signature-256`. Hoy el daño está acotado porque el evento debe casar con
un `instagram_id` conocido, pero permite inyectar mensajes falsos en conversaciones
existentes a quien conozca el IGSID (que es semipúblico).

No es un bloqueante y **es deuda preexistente, no la introduce este trabajo** — pero F1b
mete `IG_APP_SECRET` en la instalación, que es justo lo que hace falta para verificar.
Buen momento para cerrarlo.

### 5. ⚪ BAJO — archivos basura que ensucian la búsqueda

`config/routes.rb310725`, `config/routes_new.rb`, `app/models/message090226.rb090226`,
`app/models/conversation_old.txt`. Aparecen en los greps y confunden al rastrear qué
código está vivo (de hecho el hallazgo F1-c salió de descartar uno de ellos). No bloquean
nada; conviene limpiarlos en algún momento, fuera de esta rama.

---

## 9. Decisiones abiertas (para confirmar antes de F1)

1. **¿App de Meta nueva o la existente?** Recomendación: **dos apps** — Messenger está en
   producción y un App Review de Instagram no debería poder tocar la app que ya funciona.
   *No bloquea el desarrollo:* la pantalla de Super Admin (§6.bis) es idéntica en los dos
   escenarios. Con una sola app, `IG_APP_ID`/`IG_APP_SECRET` son los del producto Instagram
   (que ya de por sí difieren del Facebook App ID); con dos apps, los de la app nueva. En
   ambos casos `IG_VERIFY_TOKEN` puede ser el mismo valor, dado de alta en cada app.
2. **¿Migrar inboxes existentes o dejarlos convivir?** Recomendación: opción A (voluntaria,
   con banner) — cero riesgo de cortar conversaciones vivas.
3. **¿Fase 2 de eventos (reacciones, unsend, postbacks) entra en este alcance o después?**
   Recomendación: después; el MVP es paridad funcional con lo que ya hay + canal propio.
4. **Versiones/permisos de la API de Meta:** los nombres y versiones citados aquí
   (`instagram_business_basic`, `graph.instagram.com/v22.0`, ventana de 60 días) hay que
   **contrastarlos con la doc vigente de Meta** al arrancar la implementación; Meta cambia
   estos nombres con frecuencia y este documento se escribió sin consultarla en vivo.

---

## 10. Pendiente

- [ ] F0 — App de Meta, permisos, webhook y redirect URI
- [x] F1 — Modelo `Channel::Instagram` + migración + feature flag
- [x] F1b — Super Admin: grupo `instagram`, claves nuevas, tarjeta y `icon-instagram-line` (§6.bis)
- [x] F2 — OAuth Instagram Login + alta de inbox (falta el botón que lo dispara: F6)
- [x] F3 — Router dual de webhooks + **dedupe por `mid`** (§5.1) + builder
- [x] F4 — Envío por `graph.instagram.com` + `SendReplyJob`
      (la ruta legacy se queda en Graph v11.0 a propósito; subirla es decisión aparte)
- [x] F5 — Job de refresh de token + schedule
- [ ] F6 — Frontend: canal propio, i18n, settings
- [ ] F7 — Rake task de migración (dry-run)
- [ ] F8 — Integración con agentes IA / seguimientos / campañas
- [ ] F9 — Specs + rollout con cuenta piloto
