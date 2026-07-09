# Plan técnico — Gestión de plantillas de WhatsApp (WABA) desde Chatwoot

> Rama: `feat/waba_templates` (desde `develop`).
> **Objetivo:** crear, enviar a aprobación (submit), editar y borrar plantillas de mensaje de WhatsApp desde la UI de Chatwoot, sin entrar a Meta Business Manager. Soporta variables `{{N}}`, cabeceras de imagen/vídeo/documento y botones.
>
> Este documento **NO implementa**: mapea el brief al código real del checkout y define arquitectura, contratos y orden de trabajo para revisión.

---

## 1. Mapeo brief → código real (verificado en el checkout)

| Pieza | Ruta real | Estado |
|---|---|---|
| Modelo canal | `app/models/channel/whatsapp.rb` | JSONB `message_templates`, `after_create :sync_templates`, delega `send_template`/`sync_templates` al provider |
| Provider Cloud | `app/services/whatsapp/providers/whatsapp_cloud_service.rb` | `send_template`, `sync_templates`, `fetch_whatsapp_templates`, `business_account_path` (v14.0), `phone_id_path` (v20.0), `api_headers` |
| Base provider | `app/services/whatsapp/providers/base_service.rb` | contrato a extender |
| Webhook entrada | `app/controllers/webhooks/whatsapp_controller.rb` → `Webhooks::WhatsappEventsJob` → `Whatsapp::IncomingMessageWhatsappCloudService` | `processed_params` extrae `entry[0].changes[0].value`, **nunca mira `changes[0].field`** |
| UI envío de plantilla | `app/javascript/dashboard/components/widgets/conversation/WhatsappTemplates/*` | picker de envío existente |
| UI settings inbox | `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue` | punto de anclaje de la gestión |
| App ID de Meta | `config/installation_config.yml:99` → **`FB_APP_ID`** | reutilizar (con override opcional `META_APP_ID`) |
| Jobs de sync | `app/jobs/channels/whatsapp/templates_sync_job.rb`, `templates_sync_scheduler_job.rb` | reescribir a upsert por fila |
| Feature flags | `config/features.yml` (`channel_whatsapp`) | sin flag nuevo; gating por canal Cloud |

**Nota de versiones Graph API:** el provider mezcla `v14.0` (business account) y `v20.0` (phone). Las llamadas nuevas usarán una constante de versión configurable (`GRAPH_VERSION`, default `v20.0`) para no arrastrar la inconsistencia.

---

## 2. Arquitectura general

```
┌──────────────────────────── FRONTEND (Vue) ────────────────────────────┐
│  settings/inbox → WhatsappTemplates/Manage.vue                          │
│   ├─ Lista (status · quality · motivo rechazo)                          │
│   ├─ Form creación (header none/text/image/video/doc, body {{N}},       │
│   │                 samples, botones)  ── validación en vivo (cliente)  │
│   └─ Acciones: submit · edit · delete · sync                            │
└───────────────┬─────────────────────────────────────────────────────────┘
                │  api/whatsapp/templates.js  (CRUD REST)
                ▼
┌──────────── CONTROLLER  Api::V1::Accounts::Whatsapp::TemplatesController ┐
│  Pundit policy + scoping por cuenta                                      │
└───────────────┬─────────────────────────────────────────────────────────┘
                ▼
┌──────────── ORQUESTADOR  Whatsapp::SubmitTemplateService ────────────────┐
│  validar → (DRY_RUN?) → resumable upload (si header imagen) →            │
│  provider.create/edit/delete → upsert fila local                        │
└───┬───────────────┬───────────────────┬────────────────────────────────┘
    ▼               ▼                   ▼
 Validator     ComponentBuilder    ResumableUploadService
 (PORO)        (función pura)      (2 pasos → handle)
    │               │                   │
    └───────────────┴──────► Provider  Whatsapp::Providers::WhatsappCloudService
                             create/edit/delete/send_template
                                       │
                                       ▼  Graph API
                             ┌─────────────────────┐
                             │   META (WABA)       │
                             └──────────┬──────────┘
                                        │ webhook message_template_*
                                        ▼
                     Webhooks::WhatsappEventsJob (rama nueva)
                                        ▼
                     Whatsapp::TemplateWebhookService → upsert status/quality
                                        ▼
                              ┌──────────────────────┐
                              │  tabla whatsapp_templates │
                              └──────────────────────┘
```

Persistencia en **tabla propia** `whatsapp_templates` (no el JSONB `message_templates`, que se conserva como fuente del picker de envío existente hasta migrar la UI).

---

## 3. Modelo de datos

### Migración `create_whatsapp_templates`

```
whatsapp_templates
├─ account_id              bigint  not null  (index, scoping)
├─ channel_whatsapp_id     bigint  not null  (index)
├─ name                    string  not null
├─ category                string          (MARKETING/UTILITY/AUTHENTICATION)
├─ language                string  not null
├─ header_type             string          (text|image|video|document|null)
├─ header_content          text            (texto de cabecera)
├─ header_media_url        string          (URL origen para upload)
├─ header_handle           string          (handle 'h:...' devuelto por Meta)
├─ body_text               text
├─ footer_text             string
├─ buttons                 jsonb   default: []
├─ sample_values           jsonb   default: {}   ({ body: [...], header: [...] })
├─ status                  string  default 'DRAFT'   (enum CRUDO de Meta)
├─ meta_template_id        string          (index)
├─ rejection_reason        string
├─ quality_score           string          (GREEN/YELLOW/RED/null)
├─ submission_error        text
├─ last_submitted_at       datetime
└─ timestamps

Índices:
  UNIQUE (channel_whatsapp_id, name, language)
  INDEX  (meta_template_id)
  INDEX  (account_id)
```

### Modelo `WhatsappTemplate`

- `belongs_to :account`, `belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp'`.
- **`status` guarda el enum CRUDO de Meta** (string, no enum de Rails TitleCase) para casar 1:1 con el webhook:
  ```
  DRAFT · PENDING · APPROVED · REJECTED · PAUSED · DISABLED · IN_APPEAL · PENDING_DELETION
  ```
- Helpers de clasificación:
  ```
  EDITABLE_STATUSES   = %w[APPROVED REJECTED PAUSED]
  TERMINAL_STATUSES   = %w[DISABLED PENDING_DELETION]
  RECOVERABLE_STATUSES= %w[DRAFT REJECTED]
  editable?  terminal?  local_only?  (meta_template_id.blank?)
  ```
- Scopes: `for_channel`, `by_meta_id`.

### Autorización

- `WhatsappTemplatePolicy` (Pundit) + `Scope` que filtra por `account`. Chatwoot no usa RLS → el scoping es en la policy/controller (patrón idéntico a `ExternalDbConnection`).

---

## 4. Validador `Whatsapp::TemplateValidator` (PORO puro — empezar aquí)

Corre **ANTES** de cualquier llamada a Meta. Cada regla lanza un error **específico por campo**, acumulados en una lista (`errors << "Botón #3 (URL) sin url"`), no un genérico.

```
NOMBRE      ^[a-z0-9_]{1,512}$
VARIABLES   {{N}} contiguas desde {{1}} en body, header y URL de botón
            ({{1}} {{3}} → inválido: "falta {{2}}")
LONGITUDES  body ≤1024 · footer ≤60 · header-texto ≤60 · texto botón ≤25
FOOTER      sin variables
HEADER txt  ≤1 variable y debe ser exactamente {{1}}
BOTONES     ≤10 total · ≤2 URL · ≤1 PHONE_NUMBER · ≤1 COPY_CODE
            QUICK_REPLY agrupados al inicio (no intercalados con CTA)
            URL con {{1}} → exige example · COPY_CODE → exige example
SAMPLES     1:1 exacto con nº de variables de body y de header
            no vacíos (Meta los usa para revisar)
```

Diagrama de la validación de variables contiguas:

```
extraer {{N}} de body → [1,2,3]  ✅ contiguo desde 1
                      → [1,3]    ❌ "Body: falta la variable {{2}}"
                      → [2]      ❌ "Body: la primera variable debe ser {{1}}"
samples.body.length == max(N)     ❌ si difiere → "Faltan valores de ejemplo (2 de 3)"
```

Salida: `Result(valid:, errors: [..])`. **Se reusa tal cual en el cliente** (se traduce a JS con las mismas reglas para feedback en vivo).

---

## 5. Builders

### 5a. `Whatsapp::TemplateComponentBuilder` (creación — función pura, tests snapshot)

Ensambla `components` en orden **HEADER → BODY → FOOTER → BUTTONS** para `POST /{business_account_id}/message_templates`:

```
HEADER texto   → { type: HEADER, format: TEXT, text, example: { header_text: [s1] } }
HEADER media   → { type: HEADER, format: IMAGE|VIDEO|DOCUMENT,
                   example: { header_handle: [handle] } }   ← handle del resumable
BODY           → { type: BODY, text, example: { body_text: [[v1, v2, ...]] } }  (2D)
FOOTER         → { type: FOOTER, text }
BUTTONS        → { type: BUTTONS, buttons: [ {type, text, url?, phone_number?,
                   example?} ... ] }  (mapeados por tipo)
```

### 5b. `Whatsapp::TemplateSendComponentBuilder` (envío — payload DISTINTO)

Para `POST /{phone_id}/messages` (extiende el `send_template` actual, hoy solo maneja `body`):

```
body      → parameters: [{type:text, text:valor}, ...]
header txt→ header component con parameter text ({{1}})
header med→ header component con { type: image, image: { link: URL } }
            ⚠️ EN ENVÍO va como `link` (o `id` de /media real), NUNCA header_handle
button URL→ button component index N con parameter text
COPY_CODE → button component con coupon_code
```

**Riesgo documentado:** confundir `header_handle` (solo sample de creación) con el `link` de envío → Meta rechaza. Test explícito para cada caso.

---

## 6. `Whatsapp::ResumableUploadService` (header de imagen)

Meta exige `example.header_handle`, no una URL, al **crear**. Flujo de 2 pasos:

```
1. POST /{GRAPH}/{FB_APP_ID}/uploads
      ?file_length=<bytes>&file_type=image/png&access_token=<user_token>
   → { id: "upload:<session>" }

2. POST /{GRAPH}/upload:<session>
      header: Authorization: OAuth <token>, file_offset: 0
      body:   <bytes crudos>
   → { h: "<handle>" }        ← esto va en example.header_handle
```

- Descarga bytes de `header_media_url`, valida **tipo (JPEG/PNG)** y **tamaño (≤5 MB)**.
- App ID: `ENV['META_APP_ID'].presence || GlobalConfigService FB_APP_ID`.
- **Alcance v1: solo imagen.** Vídeo/documento → o se pide `header_handle` ya hecho, o TODO explícito para el mismo flujo. Marcado como `# TODO(waba): resumable para video/document`.

---

## 7. Provider ampliado (`WhatsappCloudService`)

Métodos nuevos, todos devuelven un objeto de resultado accionable (no reintento ciego):

```
create_template(payload)
   POST /{business_account_id}/message_templates
   → { id, status } | error

edit_template(meta_id, components:, category:)
   POST /{meta_id}            (Meta reemplaza components enteros → vuelve a PENDING)

delete_template(name:, meta_template_id:)
   DELETE /{business_account_id}/message_templates?name=&hsm_id=<meta_id>
   (sin hsm_id borra TODAS las variantes de idioma; 404 = no-op)
```

**Rate limits → mensaje accionable, sin reintento:**
```
429 create  → "Límite de creación (100/hora). Intenta más tarde."
429 edit    → "Límite de edición (10/30 días; 1/24h en aprobadas)."
```

---

## 8. Orquestador `Whatsapp::SubmitTemplateService` + controller

### Flujo `create` (con DRY_RUN)

```
                 ┌─ validar (§4) ──── inválido ─→ 422 + errores por campo
                 ▼
        WHATSAPP_TEMPLATES_DRY_RUN?
         │ sí                          │ no
         ▼                             ▼
  fila PENDING                header imagen? ── sí ─→ ResumableUpload → handle
  meta_template_id=                    │ no                    │
   "dry-run-<uuid>"                    ▼                        ▼
  (sin red)              provider.create_template(payload con handle/url)
         │                             │
         │                   ┌─────────┴─────────┐
         │              Meta OK              Meta falla
         │                   │                   │
         │                   ▼                   ▼
         │        upsert fila local        fila DRAFT + submission_error
         │        (meta_id + status)       (reintentable)
         │                   │
         │              guardado local falla?
         │                   │ sí
         │                   ▼
         │        devolver meta_template_id + "Sync from Meta"
         │        (drift explícito)
         └───────────────────┴──→ 201 con la fila
```

### `update` (PATCH)
- Solo `status ∈ {APPROVED, REJECTED, PAUSED}` (editables). Reusa validador + builder. `provider.edit_template` → status vuelve a `PENDING`.

### `destroy`
- Valida `meta_template_id` como UUID. `provider.delete_template(hsm_id: meta_id)` → borra la fila local. Filas `local_only?` saltan la llamada a Meta.

### Controller `Api::V1::Accounts::Whatsapp::TemplatesController`
- `index / show / create / update / destroy / sync`. Pundit + scope por cuenta. Rutas bajo el namespace `whatsapp` existente (`config/routes.rb:174`).

---

## 9. Webhook de ciclo de vida

En `Webhooks::WhatsappEventsJob` (que ya tiene el `channel`), **antes** de despachar a `IncomingMessage*`, inspeccionar `changes[0].field`:

```
field = entry[0].changes[0].field   /   value = changes[0].value
│
├─ field empieza con "message_template_"  ─→ Whatsapp::TemplateWebhookService.new(channel, change).call
│      ├─ message_template_status_update
│      │     → update status por meta_template_id
│      │       REJECTED → guarda rejection_reason ; otros flips → lo limpia
│      ├─ message_template_quality_update
│      │     → quality_score GREEN/YELLOW/RED
│      └─ message_template_components_update
│            → log + sugiere re-sync (no auto-aplica)
│
├─ value tiene "message_echoes"  ─→ Whatsapp::EchoMessageService  (COEXISTENCIA, §16)
│            → crea mensaje OUTGOING en la conversación
│
└─ resto (messages, statuses)  ─→ IncomingMessageWhatsappCloudService (flujo actual, intacto)
```

Manejo de cardinalidad:
```
0 filas por meta_template_id → warning "webhook sin fila local (¿sync?)"
>1 filas                     → warning "colisión de meta_template_id"
```

> ⚠️ **Requisito manual imprescindible (documentar en el README del feature y en la UI):**
> los 3 campos `message_template_*` **no se suscriben por API**. Hay que activarlos a mano en
> **Meta App Dashboard → WhatsApp → Configuration → Webhooks**.
> El botón **Sync** se conserva como fallback si el webhook no está suscrito.

---

## 10. Sync reescrito a upsert por fila

Hoy `sync_templates` **reemplaza** el JSONB entero. Nuevo comportamiento:

```
fetch templates de Meta (paginado, ya existe fetch_whatsapp_templates)
  para cada template remoto:
     parsear components INVERSOS:
        HEADER  → header_type + content/handle
        BODY    → body_text + sample_values.body
        FOOTER  → footer_text
        BUTTONS → buttons[]
        + category / status / quality_score
     upsert por (channel_whatsapp_id, name, language)
  NO borrar locales sin contraparte remota (drafts/local-only se conservan)
```

Se mantiene también el volcado al JSONB `message_templates` mientras el picker de envío no migre a la tabla (compatibilidad).

---

## 11. Frontend (Vue)

Vista en **Settings → Inbox (WhatsApp)**:

```
Manage.vue
├─ TemplatesList.vue        (status chip · quality · motivo rechazo · acciones)
├─ TemplateForm.vue
│   ├─ selector header: none | text | image | video | document
│   ├─ ImageUpload (→ header_media_url)
│   ├─ BodyEditor  (detecta {{N}}, genera inputs de sample)
│   ├─ SamplesInputs (1:1 con variables)
│   └─ ButtonsEditor (QUICK_REPLY / URL / PHONE / COPY_CODE)
└─ acciones: submit · edit · delete · sync
```

- **Reusar las mismas reglas del validador §4** en cliente (feedback en vivo antes de enviar).
- API nueva: `app/javascript/dashboard/api/whatsapp/templates.js` + store module `whatsappTemplates`.
- i18n `es`/`en`.

---

## 12. Config nueva

| Clave | Uso | Origen |
|---|---|---|
| `META_APP_ID` | App ID para Resumable Upload | **fallback a `FB_APP_ID`** (ya existe en `installation_config.yml:99`) |
| `WHATSAPP_TEMPLATES_DRY_RUN` | crea filas PENDING sin llamar a Meta | ENV / installation config |
| `GRAPH_VERSION` | versión Graph para llamadas nuevas | ENV, default `v20.0` |

---

## 13. Orden de trabajo (fases)

```
FASE 1  Migración + modelo WhatsappTemplate + Pundit policy
FASE 2  Validator (PORO puro) + tests           ← lo más testeable, empieza aquí
FASE 3  ComponentBuilder (creación) + SendComponentBuilder + tests snapshot
FASE 4  Provider: create/edit/delete + ResumableUploadService
FASE 5  SubmitTemplateService + controller CRUD (con DRY_RUN)
FASE 6  Reescribir sync a upsert por fila
FASE 7  Rama webhook message_template_* + TemplateWebhookService
FASE 8  UI Vue (lista + form + validación cliente)
FASE 9  Coexistencia: echoes de mensajes del móvil → conversación (§16)
```

---

## 14. Criterios de aceptación

- [ ] **DRY_RUN on:** crear plantilla con body de 2 variables + header imagen + 2 botones **sin llamar a Meta**, verla `PENDING`.
- [ ] **Meta real (sandbox):** submit de plantilla de texto → aparece en Meta Manager; al aprobar, el webhook la pone `APPROVED` sin sync manual.
- [ ] Editar una `APPROVED` la devuelve a `PENDING`.
- [ ] Borrar elimina **solo** la variante de idioma correcta.
- [ ] Enviar una plantilla aprobada con imagen + variables **llega** correctamente al cliente (header como `link`, no handle).
- [ ] **Coexistencia:** responder a un cliente desde la **WhatsApp Business App** (móvil) hace que ese mensaje aparezca como **saliente** en el flujo de la conversación en Chatwoot, sin duplicar los que Chatwoot ya envió.

---

## 15. Riesgos y decisiones tomadas

| Tema | Decisión |
|---|---|
| App ID | Reutilizar `FB_APP_ID` con override `META_APP_ID` (confirmado con el usuario) |
| Persistencia | Tabla propia `whatsapp_templates`, **no** el JSONB (conservado por compat del picker de envío) |
| `status` | Enum **crudo** de Meta (string), para casar webhook 1:1 y distinguir recuperables/terminales |
| Resumable v1 | Solo imagen; vídeo/doc como TODO explícito |
| header en envío | `link`/`id` real, **nunca** `header_handle` (Meta lo rechaza) — test dedicado |
| Webhook lifecycle | Requiere suscripción **manual** en Meta App Dashboard; Sync como fallback |
| Rate limits | Mensaje accionable, sin reintento ciego (429 create/edit) |
| Versiones Graph | Constante `GRAPH_VERSION` configurable (evita arrastrar v14.0/v20.0 mezcladas) |
| Coexistencia | Manejar `message_echoes` como mensajes salientes; dedup por `source_id`; suscripción manual de campos SMB (§16) |

---

## 16. Coexistencia — reflejar mensajes enviados desde el móvil

**Problema:** con un número en **coexistencia** (WhatsApp Business App móvil + Cloud API sobre el mismo número), un agente puede responder desde el celular. Meta **sí emite** esos mensajes como *echoes*, pero Chatwoot hoy solo procesa `messages`/`statuses` (`incoming_message_base_service.rb:16-18`) y los descarta → no aparecen en la conversación.

**Solución:** convertir cada echo en un mensaje **saliente** dentro de la conversación correcta.

### Flujo

```
Agente responde desde la Business App (móvil)
        │
        ▼
Meta ── webhook (value.message_echoes[]) ──► Webhooks::WhatsappEventsJob
        │
        ▼
Whatsapp::EchoMessageService.new(inbox, params).perform
   1. echo = value.message_echoes.first
   2. contacto ← echo[:to]  (wa_id del CLIENTE, no el negocio)
        → ContactInboxWithContactBuilder (reusa la lógica existente)
   3. conversación ← set_conversation (reusa: última no resuelta / lock)
   4. DEDUP: find_message_by_source_id(echo[:id]) presente? → return
        (evita duplicar lo que Chatwoot ya envió: mismo source_id)
   5. crear mensaje:
        message_type: :outgoing
        sender:       nil          (enviado desde el móvil, sin agente Chatwoot)
        source_id:    echo[:id]
        status:       :delivered   (ya salió)
        content_attributes: { sent_from: 'whatsapp_mobile' }  ← distintivo
   6. attach_files si el echo trae media (reusa download_attachment_file)
```

### Puntos clave

- **Dirección:** el echo es un mensaje que **el negocio envió** → `outgoing`. El contacto se resuelve por `echo[:to]` (el cliente), **no** por `from` (que es el número del negocio).
- **Deduplicación (crítico):** los mensajes que Chatwoot mismo envía por API **también** regresan como echo con el mismo `id`. La guardia `find_message_by_source_id` (ya existe) evita el duplicado. Hay que asegurar que el `source_id` que Chatwoot guarda al enviar == el `id` del echo.
- **Reuso:** `set_contact`, `set_conversation`, `attach_files`, `download_attachment_file` del `IncomingMessageBaseService` se reutilizan; `EchoMessageService` puede heredar de esa base y solo sobreescribir la resolución de contacto (`to` en vez de `contacts[]`) y forzar `outgoing`.

### Alcance y extras (opcionales, marcar TODO)

| Campo webhook | Qué trae | Alcance v1 |
|---|---|---|
| `message_echoes` | mensajes salientes del móvil | **Sí** — núcleo de esta fase |
| `smb_app_state_sync` | contactos/chats de la Business App | TODO — sincroniza libreta de contactos |
| `history` | historial previo al onboarding de coexistencia | TODO — importación única, mensajes anteriores |

### Requisito manual (documentar en UI + README)

Igual que los webhooks de plantilla, los campos de coexistencia **se suscriben a mano** en
**Meta App Dashboard → WhatsApp → Configuration → Webhooks** (`message_echoes`, y opcional
`smb_app_state_sync` / `history`). Sin la suscripción, Meta no envía los echoes.

> ⚠️ **Verificar en implementación:** el nombre exacto del campo/estructura (`message_echoes` dentro del
> `value`, vs. un `field: smb_message_echoes`) debe confirmarse contra la doc vigente de coexistencia de
> Meta al construir la Fase 9 — la API de coexistencia es reciente y ha cambiado de forma.

### Limitaciones honestas

- Solo refleja lo enviado **después** de activar coexistencia (el historial previo es `history`, flujo aparte).
- La coexistencia requiere la **WhatsApp Business App** (no la de consumidor) y onboarding específico de Meta; disponibilidad por región/cuenta.
