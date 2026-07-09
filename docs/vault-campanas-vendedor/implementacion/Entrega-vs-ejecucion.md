---
titulo: Entrega vs Ejecución — visibilidad de entrega en el dashboard
tipo: implementacion
tags: [campanas-vendedor, dashboard, entrega, whatsapp, delivery]
---

# Entrega vs Ejecución

## El problema

El dashboard de una campaña hoy solo refleja el **estado de ejecución** del
`ContactTracking` (`pending` / `active` / `completed` / `failed`). Eso mide si el
Agente **corrió su ciclo**, NO si el mensaje **llegó** por WhatsApp.

Son dos ejes distintos que hoy se mezclan visualmente:

```
  EJE A — EJECUCIÓN (ContactTracking.status)   ← lo que ya hay
  pending → active → completed / failed
     "¿el Agente hizo su trabajo?"

  EJE B — ENTREGA (Message.status del canal)   ← lo que falta
  progress → sent → delivered → read  |  failed(+external_error)
     "¿el mensaje llegó al cliente?"
```

Por eso una campaña puede verse **"completada"** aunque Meta haya **rechazado**
los mensajes (ej. error `131049`). No es un bug del ciclo de vida: es que el eje
de entrega **no se muestra**.

## Alcance (solo visibilidad — NO se toca la lógica de negocio)

- ❌ **NO** se toca `mark_attempt_successful!` ni cuándo un tracking pasa a
  `completed`. Eso es una decisión de negocio aparte.
- ✅ Solo se **agrega** un eje de lectura (entrega) al lado del existente.
- ✅ Sin migración: se reusa `Message.status` (enum ya existente) y
  `content_attributes[:external_error]`.

## Diseño

`Message` ya tiene todo lo necesario:

```
enum status:       { progress: -1, sent: 0, delivered: 1, read: 2, failed: 3 }
content_attributes: { external_error: "..." }   # ej. "131049"
enum message_type: { incoming: 0, outgoing: 1, activity: 2, template: 3 }
```

### 3 estados de entrega (no binario)

Meta es **asíncrono** y hay canales que **nunca** confirman entrega. Un badge
binario (entregado/error) haría ver como "falla" lo que solo está pendiente de
confirmación. Por eso 3 buckets:

| Bucket        | Message.status       | UI            |
|---------------|----------------------|---------------|
| `delivered`   | `delivered`, `read`  | ✅ Entregado  |
| `sent`        | `sent`, `progress`   | ⏳ Sin confirmar |
| `failed`      | `failed`             | ⚠️ Error (+ `external_error` en tooltip) |

### Unidad = ÚLTIMO mensaje saliente por conversación (no mensajes crudos)

Un tracking hace **varios intentos** → varios mensajes. Contar mensajes crudos
haría el KPI de entrega **incomparable** con el de trackings (que es por
prospecto). Por eso la unidad es **el último mensaje saliente** (`outgoing` o
`template`) de la conversación del tracking → 1 por prospecto.

Trackings sin conversación o sin mensaje saliente aún, no cuentan (aún no se
"envió"). Por eso `total_entrega ≤ total_prospectos`, y está bien.

### Query en batch (sin N+1)

Mismo patrón que `stats_by_campaign`:

```
last_ids = Message.where(conversation_id: convs, message_type: [:outgoing, :template])
                  .group(:conversation_id).maximum(:id)      # 1 query
last_msgs = Message.where(id: last_ids.values)               # 1 query
```

## Cambios

**Backend (sin migración):**

1. `TrackingCampaignsController#delivery_by_campaign(ids)` → nueva query agregada;
   `campaign_json` expone `delivery: { delivered, sent, failed }` como eje aparte
   de `stats`.
2. `ContactTrackings::ListController` → `index` arma un hash
   `conversation_id → { status, error }` en batch; `row` agrega
   `last_message_status` y `last_message_error`.

**Frontend (`CampaignDetail.vue`):**

3. Sección **"Entrega (WhatsApp)"** separada de los KPIs de ejecución, con
   Entregados / Sin confirmar / Error.
4. Columna **"Entrega"** en la tabla de prospectos: badge ✅/⏳/⚠️ con tooltip del
   `external_error`, aparte de la columna "Estado" existente.
5. Claves i18n ES/EN (`TRACKING_CAMPAIGN_DETAIL.DELIVERY.*` y `COL.DELIVERY`).

## Qué queda afuera (a propósito)

- Cambiar el ciclo de vida del tracking según la entrega (`mark_attempt_successful!`).
- Reintentos automáticos ante `failed` de Meta.
- Alertas/notificaciones por rechazo de plantilla.

Todo eso es negocio y se decide aparte. Ver [[Pendiente]].
