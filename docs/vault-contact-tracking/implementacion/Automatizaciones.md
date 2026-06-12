---
titulo: Automatizaciones (Automation Rules) — Contact Tracking
tipo: implementacion
tags: [contact-tracking, automatizaciones, automation-rules]
---

# Automatizaciones que crean / controlan seguimientos

El módulo se engancha al motor de **Automation Rules** de Chatwoot con **3 acciones**.
Así se crean (y pausan/cancelan) seguimientos **sin intervención manual**, disparados
por eventos de conversación.

> **Terminología:** en producto y UI, una `tracking_template` se llama **"Agente IA"**.
> Ver [[Vision-y-convenciones]]. La acción de crear seguimiento = "asignar un Agente IA".

## Acciones disponibles

Registradas en `app/models/automation_rule.rb` (lista blanca `ACTIONS`) y en el frontend
`routes/dashboard/settings/automation/constants.js`:

| `action_name` | Label UI | inputType | Implementación |
|---|---|---|---|
| `assign_tracking_template` | "Asignar plantilla de seguimiento" | `search_select` (dropdown de Agentes IA filtrado por inbox) | `app/services/action_service.rb:101` |
| `pause_active_tracking` | "Pausar seguimiento activo" | — | `app/services/automation_rules/action_service.rb:67` |
| `cancel_active_tracking` | "Cancelar seguimiento activo" | — | `app/services/automation_rules/action_service.rb:81` |

> Ojo: hay **dos** action services. `assign_tracking_template` vive en el principal
> `app/services/action_service.rb`; pause/cancel viven en
> `app/services/automation_rules/action_service.rb`. Marcador común:
> `proyecto@automatizacion_tracking`.

## `assign_tracking_template` — crear seguimiento desde una regla

`action_service.rb:101`. Param: `template_id` (la plantilla / Agente IA elegido en el
dropdown). Lógica:

1. Resuelve `template = @account.tracking_templates.find_by(id: template_id)`; aborta si
   no existe o el id es `nil`/blank.
2. **Guarda anti-duplicado:** si el contacto ya tiene un tracking en
   `pending/scheduled/active/paused`, **no crea** otro (respeta "1 activo por contacto",
   ver [[Ciclo-de-vida]]).
3. `inbox_id` = el de la plantilla, con fallback al inbox de la conversación.
4. Copia de la plantilla: `objective`, `ai_context` (fallback al objetivo),
   `complementary_prompt`, `whatsapp_templates`, `keyword_actions`,
   `calendar_integration_ids`, `tracking_template_id`.
5. `max_attempts` = nº de plantillas WA presentes, `clamp(1, 10)` (3 si no hay).
6. `scheduled_for` = `now + intervalo de la plantilla` (`retry_interval_value/unit`,
   default 1 día) para que el primer intento caiga con la misma cadencia que los demás.

## Pre-check en `message.rb` (evita doble respuesta)

`app/models/message.rb` (`will_trigger_tracking_automation?`, ~line 477): antes de
encolar el `ContactTrackingResponseAnalyzerJob`, comprueba si **alguna** regla activa
con evento `conversation_created` / `conversation_opened` / `message_created` y acción
`assign_tracking_template` va a crear un tracking para esta conversación
(usa `AutomationRules::ConditionsFilterService`).

- Si va a crear uno → encola el analyzer con **5 s de delay** (`wait: 5.seconds`) para
  que el tracking ya exista cuando corra.
- Si el contacto ya tiene uno activo → sin delay (el analyzer lo ve igual).
- Comentario en el código: NO se re-encola el job tras crear el tracking; el delay de
  5 s del job inicial es suficiente. Re-encolar causaba **respuestas dobles** porque las
  respuestas de BotSeller no llevan el flag `sentiment_auto_reply`.

## Flujo típico

```
Evento (conversation_created / opened / message_created)
        │
        ▼
AutomationRule activa  ──►  assign_tracking_template(template_id)
        │                          │ (si no hay tracking activo)
        │                          ▼
        │                   ContactTracking.create!  (status pending, scheduled_for = now+intervalo)
        ▼
message.rb encola ResponseAnalyzerJob (+5s) ──► RouterService / sentimiento
```

Acciones gemelas para el lado contrario: `pause_active_tracking` y
`cancel_active_tracking` recorren los trackings activos del contacto (filtrando por la
condición `inbox_id` de la regla si existe) y llaman `pause!` / `cancel!`.
