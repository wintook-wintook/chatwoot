# Gestor de Tickets — Fase 2: API REST

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo  
**Depende de:** Fase 0 (modelos), Fase 1 (servicios)

---

## Qué se implementó

Fase 2 expone el Gestor de Tickets como una API REST consumible por el frontend. Se crearon tres controladores y se registraron todas las rutas. También se agregaron las asociaciones `has_many` al modelo `Account`.

---

## Archivos creados

| Archivo | Controlador |
|---------|-------------|
| `app/controllers/api/v1/accounts/case_tickets_controller.rb` | `Api::V1::Accounts::CaseTicketsController` |
| `app/controllers/api/v1/accounts/case_events_controller.rb` | `Api::V1::Accounts::CaseEventsController` |
| `app/controllers/api/v1/accounts/case_rules_controller.rb` | `Api::V1::Accounts::CaseRulesController` |

## Archivos modificados

| Archivo | Qué se agregó |
|---------|---------------|
| `config/routes.rb` | Rutas para `case_tickets`, `case_events` y `case_rules` |
| `app/models/account.rb` | `has_many :case_tickets` y `has_many :case_rules` |

---

## Endpoints

### CaseTickets

#### `GET /api/v1/accounts/:account_id/case_tickets`

Lista todos los tickets de la cuenta con filtros opcionales y paginación.

**Query params:**

| Param | Tipo | Descripción |
|-------|------|-------------|
| `status` | string | `open`, `classified`, `in_progress`, `waiting_on_customer`, `waiting_on_internal`, `escalated`, `resolved`, `closed`, `cancelled` |
| `case_type` | string | `support`, `commercial`, `implementation`, `internal_tracking`, `system_incident` |
| `priority` | string | `low`, `medium`, `high`, `urgent` |
| `sla_status` | string | `on_time`, `at_risk`, `overdue` |
| `assignee_id` | integer | ID del agente asignado |
| `contact_id` | integer | ID del contacto |
| `page` | integer | Página (default: 1) |
| `per_page` | integer | Registros por página (default: 25, máx: 100) |

**Respuesta:**
```json
{
  "case_tickets": [ { ...ticket_json } ],
  "meta": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "total_count": 3
  }
}
```

---

#### `POST /api/v1/accounts/:account_id/case_tickets`

Crea un ticket manualmente (desde el agente).

**Body:**
```json
{
  "case_ticket": {
    "contact_id": 42,
    "conversation_id": 100,
    "case_type": "support",
    "title": "Error al iniciar sesión",
    "priority": "high",
    "description": "El cliente no puede ingresar desde ayer"
  }
}
```

Internamente llama a `Cases::OrchestratorService#create_for_manual`, que:
1. Crea el ticket con `origin: :manual` y `assignee_type: :agent`
2. Ejecuta `Cases::RuleEngineService#evaluate!` automáticamente

**Respuesta:** `201 Created` con `{ "case_ticket": { ...ticket_json } }`

---

#### `GET /api/v1/accounts/:account_id/case_tickets/:id`

Retorna el detalle de un ticket.

**Respuesta:** `200 OK` con `{ "case_ticket": { ...ticket_json } }`

---

#### `PATCH /api/v1/accounts/:account_id/case_tickets/:id/transition`

Cambia el status del ticket. Valida la transición contra `VALID_TRANSITIONS`.

**Body:**
```json
{
  "status": "in_progress",
  "reason": "El agente tomó el caso"
}
```

- Usa `ticket.transition!(status, actor: current_user, reason: reason)`
- Retorna `422` si la transición no es válida (ej: `closed → open`)
- Registra un `CaseEvent` con `origin: :agent` y el `actor` del usuario actual

**Respuesta:** `200 OK` con el ticket actualizado.

---

#### `PATCH /api/v1/accounts/:account_id/case_tickets/:id/assign`

Asigna el ticket a un agente o equipo.

**Body para asignar agente:**
```json
{ "assignee_id": 15 }
```

**Body para asignar equipo:**
```json
{ "team_id": 3 }
```

- Registra evento `assigned` con los datos del agente/equipo
- Actualiza `assignee_type` a `:agent` o `:team` según corresponda
- Retorna `404` si el agente/equipo no existe en la cuenta

---

### CaseEvents (Timeline)

#### `GET /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/case_events`

Retorna todos los eventos del ticket ordenados cronológicamente (ASC).

**Respuesta:**
```json
{
  "case_events": [
    {
      "id": 1,
      "event_type": "ticket_created",
      "origin": "system",
      "payload": { "case_type": "support", "priority": "high", "origin": "whatsapp" },
      "created_at": "2026-06-04T14:00:00.000Z",
      "actor": null
    },
    {
      "id": 2,
      "event_type": "status_changed",
      "origin": "agent",
      "payload": { "from": "open", "to": "classified", "reason": "clasificado manualmente" },
      "created_at": "2026-06-04T14:05:00.000Z",
      "actor": { "id": 5, "name": "Andrés Liverio", "avatar_url": "..." }
    }
  ]
}
```

---

### CaseRules

#### `GET /api/v1/accounts/:account_id/case_rules`

Lista todas las reglas de la cuenta ordenadas por `position`.

**Respuesta:**
```json
{
  "case_rules": [
    {
      "id": 1,
      "name": "Soporte → Equipo Soporte",
      "active": true,
      "continue_on_match": false,
      "position": 0,
      "conditions": [{ "field": "case_type", "operator": "eq", "value": "support" }],
      "actions": [{ "type": "assign_team", "value": "Soporte Técnico" }]
    }
  ]
}
```

---

#### `POST /api/v1/accounts/:account_id/case_rules`

Crea una nueva regla.

**Body:**
```json
{
  "case_rule": {
    "name": "Urgente → notificar supervisor",
    "active": true,
    "continue_on_match": false,
    "position": 5,
    "conditions": [
      { "field": "priority", "operator": "eq", "value": "urgent" }
    ],
    "actions": [
      { "type": "notify_agent", "value": "supervisor@empresa.com" },
      { "type": "change_status", "value": "escalated" }
    ]
  }
}
```

**Respuesta:** `201 Created`

---

#### `PATCH /api/v1/accounts/:account_id/case_rules/:id`

Actualiza una regla existente. Acepta los mismos campos que `create`.

---

#### `DELETE /api/v1/accounts/:account_id/case_rules/:id`

Elimina una regla. **Respuesta:** `204 No Content`

---

## Estructura de `ticket_json`

Todos los endpoints que retornan un ticket usan esta estructura:

```json
{
  "id": 9,
  "title": "Error al iniciar sesión",
  "description": "No puede ingresar desde ayer",
  "case_type": "support",
  "origin": "manual",
  "priority": "high",
  "status": "open",
  "assignee_type": "agent",
  "sla_status": "on_time",
  "first_response_time_target": 120,
  "resolution_time_target": 480,
  "first_response_at": null,
  "resolved_at": null,
  "closed_at": null,
  "metadata": {},
  "custom_attributes": {},
  "created_at": "2026-06-04T15:00:00.000Z",
  "updated_at": "2026-06-04T15:00:00.000Z",
  "contact_id": 42,
  "conversation_id": 100,
  "contact_tracking_id": null,
  "assignee_id": null,
  "team_id": null,
  "can_transition_to": ["classified", "cancelled"]
}
```

El campo `can_transition_to` permite al frontend habilitar/deshabilitar opciones en el menú de cambio de status sin necesidad de conocer la lógica de transiciones.

---

## Rutas registradas

```
PATCH  /api/v1/accounts/:account_id/case_tickets/:id/transition  → case_tickets#transition
PATCH  /api/v1/accounts/:account_id/case_tickets/:id/assign      → case_tickets#assign
GET    /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/case_events → case_events#index
GET    /api/v1/accounts/:account_id/case_tickets                 → case_tickets#index
POST   /api/v1/accounts/:account_id/case_tickets                 → case_tickets#create
GET    /api/v1/accounts/:account_id/case_tickets/:id             → case_tickets#show
GET    /api/v1/accounts/:account_id/case_rules                   → case_rules#index
POST   /api/v1/accounts/:account_id/case_rules                   → case_rules#create
PATCH  /api/v1/accounts/:account_id/case_rules/:id               → case_rules#update
DELETE /api/v1/accounts/:account_id/case_rules/:id               → case_rules#destroy
```

---

## Tests de aceptación verificados

| Test | Resultado |
|------|-----------|
| `POST /case_tickets` crea ticket con SLA y priority correctos | ✅ |
| `GET /case_tickets?status=open` filtra correctamente | ✅ |
| `GET /case_tickets/:id/case_events` retorna timeline del ticket | ✅ |
| `PATCH /transition` cambia status y registra evento | ✅ |
| `POST /case_rules` crea regla | ✅ |
| `PATCH /case_rules/:id` actualiza active | ✅ |
| `DELETE /case_rules/:id` elimina regla | ✅ |
| Rutas Rails registradas correctamente (11 endpoints) | ✅ |

---

## Decisiones técnicas

### `can_transition_to` en `ticket_json`

El JSON de cada ticket incluye el array de transiciones válidas desde el status actual. Esto permite al frontend renderizar los botones de cambio de status de forma declarativa sin conocer la tabla `VALID_TRANSITIONS`. Al cambiar el status, el frontend recibe el ticket actualizado con el nuevo `can_transition_to`.

### Filtros por valor de enum (no por entero)

Los filtros `?status=open`, `?priority=high` usan el nombre del enum, no el entero. El controlador hace la conversión con `CaseTicket.statuses[params[:status]]`. Esto hace la API más legible y desacopla el frontend de los valores internos del enum.

### Asociaciones en Account

Se agregaron `has_many :case_tickets` y `has_many :case_rules` al modelo `Account` para que `Current.account.case_tickets` y `Current.account.case_rules` funcionen en los controladores. El scope implícito de `account_id` garantiza que cada cuenta solo vea sus propios tickets.

### `rule_params` con arrays de hashes

El `permit` de `rule_params` permite arrays de hashes para `conditions` y `actions`:
```ruby
conditions: [:field, :operator, :value],
actions:    [:type, :value]
```
Esto es compatible con el formato JSON que enviará el frontend y pasa automáticamente por las validaciones del modelo `CaseRule`.

---

## Siguiente fase

**Fase 3 — Panel derecho de la conversación (frontend):**

Primer componente visible para el agente. Aparece en el panel derecho de cada conversación (`ContactPanel.vue`):

| Componente | Archivo | Función |
|-----------|---------|---------|
| `CaseTicketPanel.vue` | `conversation/CaseTicketPanel.vue` | Badge SLA + botones de acción |
| `CaseTicketModal.vue` | `conversation/CaseTicketModal.vue` | Modal de creación de ticket |
| `CaseTimeline.vue` | `conversation/CaseTimeline.vue` | Timeline de eventos del ticket |
| API client | `gestorTickets/api.js` | Llamadas a los endpoints de Fase 2 |
