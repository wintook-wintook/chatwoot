---
titulo: Modelo de datos
tipo: diseno
tags: [campanas-vendedor, modelo-datos]
---

# Modelo de datos (nuevo)

> ⚠️ Nombre **`SalesCampaign`** (NO el `Campaign` nativo de Chatwoot, que es de envíos
> one_off/ongoing). Migraciones al final.

```
sales_campaigns                         sales_campaign_prospects
──────────────────────────────         ─────────────────────────────────────────
account_id            FK                sales_campaign_id     FK
name                  "Reactivación Q3" contact_id            FK
tracking_template_id  FK (entrenamiento)contact_tracking_id   FK (conversación IA)
objective             enum             assignee_id           FK users (vendedor)
inbox_id              FK (canal fijo)   status               enum (pendiente/conversando/
status                enum (draft/                              escalado/objetivo/sin_respuesta/
                       running/paused/   no_interesado)
                       finished)         interest             enum (alto/medio/bajo)
starts_at / ends_at   datetime          score                integer 0-100 (IA)
                                         priority             enum (alta/media/baja)
                                         result               enum (cotizacion/pedido/demo/
                                                                oportunidad/venta/ninguno)
                                         value_generated      decimal
                                         next_action          string
                                         kanban_process_id    FK (oportunidad, opcional)
                                         last_interaction_at  datetime
```

## Notas
- **`SalesCampaignProspect`** = la fila de la Vista 3 ([[Las-7-vistas]]). Enlaza su
  `contact_tracking` (la conversación IA real) y, si aplica, su oportunidad en el Kanban.
- **`score`/`interest`/`result`/`value_generated`/`next_action`** los alimenta la IA y los
  eventos de conversación (extiende el analyzer que ya ajusta seguimientos en `@contact_tracking`).
- **`inbox_id` en la campaña** = canal **fijo** (corrige el bug de inbox inferido del bulk,
  ver [[Bulk-assign-hallazgos]]).
- `objective` y demás enums → confirmar en [[Pendiente]].
- `contact_tracking` ya aporta señales reusables: `last_intent`, `last_sentiment_analysis`,
  `outcome` (no duplicar; el score las combina).
