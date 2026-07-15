---
titulo: Modal de preview con tabs por bucket
tipo: implementacion
tags: [campanas-vendedor, bulk-assign, preview, ui, plan]
---

# Modal de preview con tabs por bucket (segmentación de la audiencia)

> **Estado:** PLAN (no implementado). Mejora del paso "revisar contactos" del
> [[Bulk-assign-hallazgos|bulk assign]]. Solo documento; no tocar código aún.

## 1. Problema

Hoy el paso de revisión (`ReviewContactsModal`) es una **lista plana**: muestra los
contactos del filtro y permite excluirlos a mano. El usuario **no sabe** cuántos
contactos realmente recibirán el Agente hasta después de confirmar — y ahora que el
bulk corre en background ([[Bulk-assign-hallazgos]] #1), menos todavía. No se ve:

- a quién se le **va a enviar** de verdad,
- a quién se **omite** por tener ya un seguimiento activo,
- a quién **no se puede** contactar (sin teléfono/correo para el canal).

## 2. Idea

Convertir la revisión en **tabs que segmentan la audiencia según qué le pasará a
cada contacto** al lanzar la campaña. La clasificación reusa la misma lógica de
`BulkAssignService#process_contact`, pero en **dry-run** (no crea nada).

### Los 4 buckets

| Tab | Incluye | Regla (canal = inbox de la plantilla) |
|-----|---------|----------------------------------------|
| ✅ **Listos para enviar** | Recibirán el Agente | Canal válido **y** (si `skip_active`) sin seguimiento activo en ese inbox |
| 🔁 **Ya en seguimiento** | Se omiten / duplicarían | Tienen `ContactTracking` activo (`pending/scheduled/active/paused`) en el inbox de la campaña |
| 🚫 **No contactables** | No se les puede enviar | Sin identificador válido para el canal (WhatsApp/SMS sin teléfono, Email sin correo, Web/API sin conversación previa) |
| ✖️ **Excluidos manualmente** | Quitados a mano | Están en `excluded_contact_ids` (tab propio para poder **Deshacer**) |

**Precedencia** (un contacto cae en un solo bucket, en este orden):
`excluido` → `en seguimiento` → `no contactable` → `listo`.

> Solo el bucket **Listos** entra al lote real. "Confirmar" muestra ese conteo.

## 3. Mockup

```
┌─ Asignación masiva de Agentes IA ───────────────────────────────┐
│ Audiencia: 240 · Canal: WhatsApp Ventas · Agente: Cobranza Jun  │
│                                                                 │
│  ┌────────────┬───────────────┬─────────────────┬────────────┐ │
│  │✅ Listos 182│🔁 En segui. 41│🚫 No contact. 17│✖️ Excl. 0 │ │ ← tabs c/ badge
│  └────────────┴───────────────┴─────────────────┴────────────┘ │
│   Nombre            Teléfono / Correo     Motivo      Acción     │
│   Juan Pérez        +52 55 1234 5678        —        [Excluir]  │
│   María López       +52 33 2222 1111        —        [Excluir]  │
│   …                                              (paginado 15)  │
│                                                                 │
│   ▸ Se crearán 182 seguimientos al confirmar.                   │
│                          [Cancelar]   [Confirmar · 182]         │
└─────────────────────────────────────────────────────────────────┘

Tab "No contactables" → columna Motivo con el porqué:
   Pedro Gómez        (sin teléfono)        WhatsApp requiere número
   Ana Ruiz           (sin teléfono)        WhatsApp requiere número
```

## 4. Backend

### 4.1 Endpoint nuevo (dry-run, no crea nada)

```
POST /api/v1/accounts/:account_id/contact_tracking_bulk_assigns/preview
  params: payload[], template_id, skip_active, excluded_contact_ids[]
  resp 200:
  {
    "channel": { "inbox_id": 9, "inbox_name": "WhatsApp Ventas",
                 "channel_type": "Channel::Whatsapp" },
    "counts":  { "ready": 182, "in_tracking": 41, "unreachable": 17,
                 "excluded": 0, "total": 240 },
    "contacts": [
      { "id": 5, "name": "Juan Pérez", "phone_number": "+52…",
        "email": null, "bucket": "ready", "reason": null },
      { "id": 9, "name": "Pedro Gómez", "phone_number": null,
        "email": null, "bucket": "unreachable",
        "reason": "WHATSAPP_NO_PHONE" }
    ]
  }
  resp 422: { "error": "La plantilla no tiene un inbox configurado." }
```

> Como `MAX_BULK_ASSIGN = 100`, el endpoint devuelve **toda** la lista clasificada
> (≤100) en una sola respuesta y el front pagina/agrupa en cliente. No hace falta
> paginación por bucket en el server. → ver edge case §6 para >100.

### 4.2 Servicio: `ContactTrackings::BulkAssignPreviewService` (nuevo)

Clase aparte para **no** inflar `BulkAssignService` (que ya arrastra deuda de
métricas rubocop). Comparte reglas con el create vía un módulo extraído:

```
ContactTrackings::Eligibility   (módulo nuevo, mixin)
  · ACTIVE_STATUSES
  · contactable_for_channel?(contact, channel) → bool + reason
  · active_tracking_contact_ids(inbox_id, contact_ids) → Set   (1 query batch)
  · contact_inbox_contact_ids(inbox_id, contact_ids)   → Set   (1 query batch)
```

`BulkAssignService` y `BulkAssignPreviewService` lo incluyen → la clasificación del
preview y la del create **no divergen**.

**Algoritmo del preview** (todo en memoria tras 2-3 queries batch):

```
inbox   = template.inbox            # requerido (mismo gate que #call)
ids     = resolve_contacts.pluck(:id)   # reusa Contacts::FilterService
active  = active_tracking_contact_ids(inbox.id, ids)      # Set
linked  = contact_inbox_contact_ids(inbox.id, ids)        # Set (para web/api)

por contacto:
  excluido?            → :excluded
  elsif active.include?(id)               → :in_tracking
  elsif !contactable?(contact, channel)   → :unreachable (+ reason)
  else                                    → :ready
```

### 4.3 Regla `contactable_for_channel?` por tipo de canal

| Canal | Contactable si… | reason si no |
|-------|-----------------|--------------|
| `Channel::Whatsapp`, `Channel::Sms`, `Channel::TwilioSms` | `phone_number` presente | `WHATSAPP_NO_PHONE` / `SMS_NO_PHONE` |
| `Channel::Email` | `email` presente | `EMAIL_NO_EMAIL` |
| `Channel::Telegram` | `phone_number` o identifier | `NO_IDENTIFIER` |
| `Channel::Api`, `Channel::WebWidget` | ya existe `contact_inbox` en ese inbox | `NO_PRIOR_CONVERSATION` |
| Otros | conservador: requiere `contact_inbox` existente | `NO_PRIOR_CONVERSATION` |

> Espejo de lo que hoy haría `ContactInboxBuilder` al crear: si no podría construir
> el `contact_inbox`, el contacto es **no contactable** (antes terminaba como error
> silencioso del lote).

## 5. Frontend

### 5.1 `PreviewContactsModal.vue` (evoluciona `ReviewContactsModal.vue`)

- **Al abrir / al cambiar `template_id` o `skip_active`:** llama `preview()`.
- Header: audiencia total · canal · agente.
- **Tabs** con badge de conteo (`ready/in_tracking/unreachable/excluded`).
- Cada tab: tabla paginada en cliente (page size 15). Columnas: Nombre ·
  Teléfono/Correo · Motivo (solo no-contactables / en-seguimiento) · Acción.
- **Excluir/Deshacer:** mueve el contacto al tab "Excluidos" actualizando
  `localExcluded`; se recalcula **en cliente** (sin re-pegarle al backend) restando
  el set excluido de los demás buckets.
- Footer: `Se crearán {ready - readyExcluidos} seguimientos` + `Confirmar`.

### 5.2 `BulkAssignModal.vue`

- El conteo "X (clic para revisar)" pasa a mostrar el de **Listos** (del preview),
  no el total crudo del filtro.
- Refresca el preview cuando cambian plantilla/fecha/skip_active.
- `onConfirm` no cambia (sigue mandando `excluded_contact_ids`).

### 5.3 API client

`contactTrackingBulkAssigns.js` → método `preview({ payload, templateId, skipActive, excludedContactIds })`.

## 6. Edge cases / decisiones — RESUELTAS

- **Audiencia > `PREVIEW_LIMIT` (200):** ✅ el servicio devuelve `counts_only: true`
  (solo `total`, sin listas) y el modal muestra el banner "reduce el filtro". Se
  descartó la opción de COUNT en SQL exacto: sobre el límite el usuario no puede
  confirmar igual, así que el desglose preciso no aporta.
- **Sin `template_id` aún:** ✅ el link "revisar" se deshabilita hasta elegir plantilla
  (el preview necesita canal) — hecho en P3.
- **`skip_active = false`:** ✅ el tab "Ya en seguimiento" se **oculta** (siempre 0,
  porque esos contactos se crean igual); quedan en "Listos", fiel al create.
- **Coste:** 2-3 queries batch + clasificación en memoria de ≤200 → trivial.

## 7. Archivos a tocar

```
NUEVO  app/services/contact_trackings/bulk_assign_preview_service.rb
NUEVO  app/services/contact_trackings/eligibility.rb            (módulo compartido)
NUEVO  app/javascript/.../BulkTrackingAssign/PreviewContactsModal.vue
MOD    app/services/contact_trackings/bulk_assign_service.rb    (include Eligibility, reusar reglas)
MOD    app/controllers/api/v1/accounts/contact_tracking_bulk_assigns_controller.rb  (+ preview)
MOD    config/routes.rb                                         (+ collection :preview)
MOD    app/javascript/dashboard/api/contactTrackingBulkAssigns.js  (+ preview)
MOD    app/javascript/.../BulkTrackingAssign/BulkAssignModal.vue   (conteo = listos)
MOD    i18n es/en bulkTrackingAssign.json                       (tabs, motivos, footer)
```

## 8. Fases sugeridas

```
P1 ✅ Módulo Eligibility + BulkAssignPreviewService + endpoint /preview (con specs)
P2 ✅ PreviewContactsModal con tabs (ready/in_tracking/unreachable/excluded)
P3 ✅ Integrar en BulkAssignModal (conteo = listos, refresco por plantilla/skip_active)
P4 ✅ Edge case >PREVIEW_LIMIT (counts_only) + pulido visual + decisiones §6
```

### P4 — implementado
- **counts_only:** si la audiencia supera `PREVIEW_LIMIT (200)`, el servicio devuelve
  `counts_only: true` con `contacts: []` y solo `total` (evita conteos truncados
  engañosos). El modal muestra un banner "Audiencia demasiado grande, reduce el filtro";
  `BulkAssignModal` deja el desglose desconocido → el conteo cae a "a procesar" y salta
  el aviso de límite. Spec nuevo con `stub_const` del límite.
- **Decisión §6.2 (skip_active=false):** el tab "Ya en seguimiento" se **oculta** (siempre
  sería 0, porque esos contactos se crean igual); quedan en "Listos", fiel al create.
- **Pulido visual:** badges de los tabs con color por bucket (verde/ámbar/rojo/gris).
- Reasons i18n ya estaban (P2): NO_PHONE / NO_EMAIL / UNSUPPORTED_CHANNEL / IN_TRACKING.

### P2 — implementado
- `PreviewContactsModal.vue`: tabs con badge, tabla paginada en cliente, columna
  Motivo, excluir/deshacer (reclasifica en cliente), footer "Se crearán N".
- Contrato del preview ajustado: bucket **natural** + flag `excluded` por contacto
  (para reclasificar en cliente sin re-fetch). i18n es/en (tabs, motivos, footer).

### P3 — implementado
- `BulkAssignModal` usa `PreviewContactsModal` (reemplaza `ReviewContactsModal`, borrado).
- El conteo del modal muestra los **Listos** (`displayCount` = ready del preview) cuando
  hay plantilla; sin plantilla, el tamaño bruto de la audiencia.
- `fetchCount` llama a `/preview` si hay plantilla; refresco al cambiar plantilla o
  skipActive; `canConfirm` exige readyCount > 0. El límite sigue sobre los "a procesar"
  (consistente con `BulkAssignService#call`).

### P1 — implementado

- `app/services/contact_trackings/eligibility.rb` — mixin compartido (reglas +
  queries batch). `BulkAssignService` ahora lo `include` (drop de su `ACTIVE_STATUSES`
  local) → preview y create no divergen.
- `app/services/contact_trackings/bulk_assign_preview_service.rb` — dry-run, devuelve
  `{ channel, counts, contacts[], truncated }`. Tope `PREVIEW_LIMIT = 200`.
- Endpoint `POST …/contact_tracking_bulk_assigns/preview` (route + acción `preview`).
- `contactTrackingBulkAssigns.js#preview()` (API client, listo para P2).
- Specs: `eligibility_spec` (7), `bulk_assign_preview_service_spec` (8),
  request `contact_tracking_bulk_assigns_controller_spec` (3) → **17 ejemplos, 0 fallos**.
  Factory nueva `contact_trackings`.
- Reasons emitidos: `NO_PHONE`, `NO_EMAIL`, `UNSUPPORTED_CHANNEL` (→ i18n en P2/P4).

> Relacionado: [[Bulk-assign-hallazgos]] (lógica de `process_contact` que se refleja),
> [[Las-7-vistas]] (este modal alimenta el "Paso 2 — seleccionar prospectos").
