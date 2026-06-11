# Gestor de Tickets — Fase 1: Servicios, Jobs e Integración con el Bot

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo  
**Depende de:** Fase 0 (modelos y migraciones)

---

## Qué se implementó

Fase 1 conecta los modelos de la Fase 0 con el flujo real del bot. Se crearon cuatro archivos nuevos y se modificaron dos existentes. El principio rector fue **zero impacto** en el flujo actual: si cualquier componente del Gestor de Tickets falla, el bot sigue funcionando exactamente igual que antes.

---

## Archivos creados

| Archivo | Clase | Función |
|---------|-------|---------|
| `app/services/cases/orchestrator_service.rb` | `Cases::OrchestratorService` | Punto de entrada para crear/encontrar tickets |
| `app/services/cases/rule_engine_service.rb` | `Cases::RuleEngineService` | Motor de reglas en cascada |
| `app/services/cases/ticket_creator_service.rb` | `Cases::TicketCreatorService` | Detecta `@crear_ticket` y actúa |
| `app/jobs/case_sla_monitor_job.rb` | `CaseSlaMonitorJob` | Monitor de SLA + cierre automático |

## Archivos modificados

| Archivo | Qué se agregó |
|---------|---------------|
| `app/jobs/contact_tracking_response_analyzer_job.rb` | Hook en `process_message_for_tracking` + integración de `TicketCreatorService` en `try_kbase_then_conversational` |
| `config/schedule.yml` | Cron de `CaseSlaMonitorJob` cada 15 minutos |

---

## `Cases::OrchestratorService`

**Archivo:** `app/services/cases/orchestrator_service.rb`

Punto de entrada único para crear o encontrar un `CaseTicket`. Toda la lógica de "¿hay un ticket activo para este contacto?" pasa por aquí.

### Inicialización

```ruby
Cases::OrchestratorService.new(account:, contact:, conversation: nil)
```

### Métodos públicos

#### `find_active_ticket`

Busca el ticket más reciente del contacto en la cuenta que no esté `closed` ni `cancelled`. Retorna `nil` si no existe.

```ruby
orch = Cases::OrchestratorService.new(account: account, contact: contact, conversation: conv)
ticket = orch.find_active_ticket  # => CaseTicket o nil
```

#### `find_or_create_from_message(message, tracking: nil)`

Busca un ticket activo. Si no existe, crea uno nuevo con los datos inferidos del mensaje:

| Atributo | Valor |
|----------|-------|
| `case_type` | `:support` (por defecto) |
| `origin` | Inferido del canal del inbox: `whatsapp`, `web`, `email` o `bot` |
| `priority` | `:medium` |
| `assignee_type` | `:bot` |
| `title` | `message.content.truncate(100)` |

No duplica: si ya existe un ticket activo, lo retorna sin crear uno nuevo.

#### `create_for_manual(case_type:, title:, priority:, description: nil)`

Crea un ticket iniciado por un agente desde el panel (Fase 3 — UI). Origin siempre `:manual`, `assignee_type: :agent`. Llama automáticamente a `Cases::RuleEngineService.new(ticket).evaluate!` después de crear.

---

## `Cases::RuleEngineService`

**Archivo:** `app/services/cases/rule_engine_service.rb`

Evalúa las `CaseRule` activas de la cuenta en orden de `position` (menor = primero). Implementa AND implícito entre condiciones y respeta `continue_on_match`.

### Inicialización

```ruby
Cases::RuleEngineService.new(ticket, trigger_message: nil)
```

- `trigger_message`: mensaje que disparó la evaluación (necesario para condiciones sobre `message_content`)

### Método principal

#### `evaluate!`

```ruby
Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
```

Flujo:
1. Carga `CaseRule.where(account: ticket.account).enabled` — reglas activas ordenadas por `position`
2. Para cada regla: evalúa todas las `conditions` (AND)
3. Si todas coinciden: ejecuta las `actions` en orden
4. Si `continue_on_match: false` (default): para en el primer match
5. Cualquier error en una acción individual queda registrado en log y no interrumpe el flujo

### Operadores de condición

| Operador | Descripción |
|----------|-------------|
| `eq` | `field == value` |
| `neq` | `field != value` |
| `contains` | `field.downcase.include?(value.downcase)` |
| `gte` | `field.to_f >= value.to_f` |
| `lte` | `field.to_f <= value.to_f` |
| `in` | `value.include?(field)` |
| `not_in` | `!value.include?(field)` |

### Fields evaluables

| Field | Qué devuelve |
|-------|-------------|
| `case_type` | String: `"support"`, `"commercial"`, etc. |
| `origin` | String: `"whatsapp"`, `"bot"`, etc. |
| `priority` | String: `"low"`, `"medium"`, `"high"`, `"urgent"` |
| `status` | String: `"open"`, `"in_progress"`, etc. |
| `sla_status` | String: `"on_time"`, `"at_risk"`, `"overdue"` |
| `message_content` | String: contenido del `trigger_message` (vacío si nil) |
| `time_without_response_min` | Integer: minutos desde `created_at` |

### Acciones disponibles

| Tipo | Qué hace |
|------|----------|
| `assign_agent` | Busca usuario por nombre o ID y lo asigna |
| `assign_team` | Busca equipo por nombre o ID y lo asigna |
| `change_priority` | Cambia `priority` si el valor es válido |
| `change_status` | Llama `ticket.transition!(value)` si es válido |
| `escalate` | Llama `ticket.transition!(:escalated)` si es válido |
| `close_ticket` | Llama `ticket.transition!(:closed)` si es válido |
| `notify_agent` | Log — implementación en Fase 3 |
| `add_label` | Log — implementación en Fases posteriores |
| `trigger_tracking` | Log — implementación en Fases posteriores |

### Ejemplo de regla completa

```json
{
  "name": "Soporte urgente → Soporte Senior",
  "active": true,
  "continue_on_match": false,
  "position": 10,
  "conditions": [
    { "field": "case_type", "operator": "eq", "value": "support" },
    { "field": "sla_status", "operator": "eq", "value": "overdue" }
  ],
  "actions": [
    { "type": "escalate" },
    { "type": "assign_team", "value": "Soporte Senior" },
    { "type": "notify_agent", "value": "supervisor@empresa.com" }
  ]
}
```

---

## `Cases::TicketCreatorService`

**Archivo:** `app/services/cases/ticket_creator_service.rb`

Detecta la directiva `@crear_ticket` en el `complementary_prompt` del `ContactTracking` activo y crea el ticket cuando `KnowledgeBaseResponseService` no pudo resolver la consulta.

### Inicialización

```ruby
Cases::TicketCreatorService.new(message, tracking: tracking)
```

### Método principal

#### `create_if_needed`

Retorna `true` si creó el ticket y respondió al cliente, `false` si no actuó.

**Condición para actuar:** `tracking.complementary_prompt` debe contener `@crear_ticket`.

**Flujo cuando actúa:**
1. Llama a `OrchestratorService#find_or_create_from_message` — no duplica si ya hay un ticket activo
2. Llama a `RuleEngineService#evaluate!` — aplica reglas automáticas inmediatamente
3. Envía confirmación al cliente usando `Messages::MessageBuilder`
4. Registra evento `message_sent` en el `CaseTicket`

### Ejemplo de `complementary_prompt`

```
Eres un asistente de soporte técnico de Kontrolya.
Busca en la base de conocimiento: @buscar_foro(soporte-tecnico).
Si no encuentras respuesta, usa @crear_ticket para registrar el caso
y avisa que un asesor lo atenderá.
```

### Mensaje de confirmación al cliente

```
Tu consulta fue registrada (caso #42). Un asesor te contactará a la brevedad.
```

El ID del ticket queda visible en el mensaje para referencia futura.

---

## `CaseSlaMonitorJob`

**Archivo:** `app/jobs/case_sla_monitor_job.rb`  
**Queue:** `scheduled_jobs`  
**Frecuencia:** Cada 15 minutos (`*/15 * * * *`)

### Qué hace en cada ejecución

#### 1. Actualizar `sla_status`

Consulta todos los tickets con `sla_status: on_time` o `at_risk` que no estén cerrados/cancelados/resueltos. Por cada uno llama a `ticket.calculate_sla_status` y, si el estado cambió:

- Actualiza `sla_status` con `update_columns` (sin callbacks)
- Crea un `CaseEvent` con `event_type: :sla_at_risk` o `:sla_overdue`
- Si el nuevo estado es `:overdue` → ejecuta `RuleEngineService#evaluate!` para disparar reglas de escalado

#### 2. Cierre automático (`auto_close_stale_resolved`)

Busca tickets con `status: resolved` y `resolved_at < 72.hours.ago`. Por cada uno llama `ticket.transition!(:closed)` si la transición es válida.

Esto implementa la regla de negocio: **un ticket resuelto sin actividad por 72h se cierra automáticamente**.

### Cron en `config/schedule.yml`

```yaml
case_sla_monitor_job:
  cron: "*/15 * * * *"
  class: "CaseSlaMonitorJob"
  queue: scheduled_jobs
  description: "Monitor SLA status of CaseTickets and auto-close stale resolved tickets"
```

---

## Integración con `ContactTrackingResponseAnalyzerJob`

### Hook en `process_message_for_tracking`

Se agregó un bloque al inicio del método, envuelto en `rescue StandardError` para garantizar que un fallo en el Gestor de Tickets nunca interrumpa el bot:

```ruby
# [Gestor de Tickets] hook — falla silenciosamente @tickets_cases
begin
  ticket = Cases::OrchestratorService.new(
    account:      message.account,
    contact:      message.conversation.contact,
    conversation: message.conversation
  ).find_active_ticket

  if ticket
    ticket.update_columns(first_response_at: Time.current) if ticket.first_response_at.nil?
    ticket.case_events.create!(
      account:    message.account,
      event_type: :message_received,
      origin:     :bot,
      payload:    { message_id: message.id }
    )
    Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
  end
rescue StandardError => e
  Rails.logger.error "[GestorTickets] hook error: #{e.message}"
end
```

**Qué hace si existe un ticket activo:**
- Registra `first_response_at` si aún no está marcado
- Crea evento `message_received`
- Evalúa reglas (ej. si el cliente vuelve a escribir mientras está `waiting_on_customer`, puede activar `change_status: in_progress`)

**Qué hace si no hay ticket activo:** nada — el ticket no se crea automáticamente con cada mensaje, solo con `find_or_create_from_message` o `@crear_ticket`.

### Integración en `try_kbase_then_conversational`

Se insertó `Cases::TicketCreatorService` entre el fallback de KBase y la respuesta conversacional:

```
[1] KnowledgeBaseResponseService  → si resuelve: fin
[2] Cases::TicketCreatorService   → si @crear_ticket: crea ticket + confirma al cliente: fin
[3] generate_and_send_conversational_reply (fallback)
```

Código agregado:

```ruby
# @tickets_cases: si la directiva @crear_ticket está en el prompt
if Cases::TicketCreatorService.new(message, tracking: tracking).create_if_needed
  Rails.logger.info '[TrackingBot] 🎫 Ticket creado via @crear_ticket'
  return true
end
```

---

## Tests de aceptación verificados

| Test | Resultado |
|------|-----------|
| `OrchestratorService` crea ticket con SLA y evento `ticket_created` | ✅ |
| `find_active_ticket` retorna el ticket existente (no duplica) | ✅ |
| `RuleEngineService` evalúa condición y cambia priority | ✅ |
| `CaseSlaMonitorJob` corre sin errores en cuenta activa | ✅ |
| `CaseSlaMonitorJob` auto-cierra ticket resuelto hace 73h | ✅ |
| Las clases cargan sin errores de dependencia | ✅ |

---

## Decisiones técnicas

### Hook con rescue total

El bloque del hook usa `rescue StandardError => e` en lugar de rescatar excepciones específicas. Esto es intencional: cualquier error en el Gestor de Tickets (incluyendo errores de DB, clases no cargadas, etc.) queda contenido. El log registra el error con el tag `[GestorTickets]` para facilitar búsquedas en producción.

### `update_columns` para SLA

`CaseSlaMonitorJob` usa `update_columns` para actualizar `sla_status` en lugar de `update!`. Esto evita disparar callbacks de ActiveRecord (en particular `after_create` del ticket) y reduce la carga en la ejecución del cron. El evento se crea manualmente a continuación.

### `reload` al inicio de cada acción en RuleEngine

`execute_single_action` llama `@ticket.reload` antes de ejecutar. Esto garantiza que si una acción anterior modificó el ticket (ej. `change_status`), la siguiente acción trabaja con el estado actualizado desde DB. Es crítico para que `escalate` no falle si `change_priority` ya actualizó el registro.

### `TicketCreatorService` no crea si ya hay ticket activo

`create_if_needed` llama a `find_or_create_from_message` que internamente llama a `find_active_ticket` primero. Si el cliente escribe varias veces sin que KBase responda, solo se crea un único ticket — los mensajes posteriores quedan registrados como eventos `message_received`.

---

## Siguiente fase

**Fase 2 — API REST (controladores + rutas):**

| Endpoint | Función |
|----------|---------|
| `GET /api/v1/accounts/:id/case_tickets` | Lista con filtros (`status`, `case_type`, `priority`, `sla_status`, `contact_id`) |
| `POST /api/v1/accounts/:id/case_tickets` | Crear ticket manual |
| `GET /api/v1/accounts/:id/case_tickets/:id` | Detalle del ticket |
| `PATCH /api/v1/accounts/:id/case_tickets/:id/transition` | Cambiar status |
| `PATCH /api/v1/accounts/:id/case_tickets/:id/assign` | Asignar agente/equipo |
| `GET /api/v1/accounts/:id/case_tickets/:id/case_events` | Timeline del ticket |
| `GET/POST/PATCH/DELETE /api/v1/accounts/:id/case_rules` | CRUD de reglas |
