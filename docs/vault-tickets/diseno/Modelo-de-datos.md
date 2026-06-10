---
titulo: Modelo de datos (CaseTicket / CaseEvent / CaseRule)
tipo: diseño
tags: [tickets, modelo, enums, db]
---

## Entidades a crear

### CaseTicket (`case_tickets`)

**Enums (nombre columna → valores en inglés):**

> ⚠️ **`case_type` YA NO es enum** — fue rediseñado a tabla `case_types` configurable por cuenta (ver sección "CAMBIO ARQUITECTÓNICO" al final). El bloque de abajo refleja el **diseño original**; en el código real `case_type` es `belongs_to :case_type` + columna `case_type_id`.

```ruby
# case_type → MIGRADO a tabla case_types (FK case_type_id). Ya NO es este enum.
origin:       { whatsapp: 0, web: 1, email: 2, bot: 3, manual: 4 }
priority:     { low: 0, medium: 1, high: 2, urgent: 3 }
status:       { open: 0, classified: 1, in_progress: 2, waiting_on_customer: 3,
                waiting_on_internal: 4, escalated: 5, resolved: 6, closed: 7, cancelled: 8 }
assignee_type: { bot: 0, agent: 1, team: 2, system: 3 }
sla_status:   { on_time: 0, at_risk: 1, overdue: 2 }
```

**Columnas:**

| Columna | Tipo | Notas |
|---------|------|-------|
| `account_id` | bigint, NOT NULL | FK → accounts |
| `contact_id` | bigint, NOT NULL | FK → contacts |
| `conversation_id` | bigint, nullable | FK → conversations |
| `contact_tracking_id` | bigint, nullable | FK → contact_trackings |
| `assignee_id` | bigint, nullable | FK → users |
| `team_id` | bigint, nullable | FK → teams |
| `case_type` | integer, NOT NULL | enum, default: 0 |
| `origin` | integer, NOT NULL | enum, default: 0 |
| `priority` | integer, NOT NULL | enum, default: 1 (medium) |
| `status` | integer, NOT NULL | enum, default: 0 (open) |
| `assignee_type` | integer, NOT NULL | enum, default: 0 (bot) |
| `sla_status` | integer, NOT NULL | enum, default: 0 (on_time) |
| `title` | string, NOT NULL | max 255 chars |
| `description` | text, nullable | |
| `first_response_time_target` | integer, nullable | minutos — se asigna por priority al crear |
| `resolution_time_target` | integer, nullable | minutos — se asigna por priority al crear |
| `first_response_at` | datetime, nullable | |
| `resolved_at` | datetime, nullable | |
| `closed_at` | datetime, nullable | |
| `metadata` | jsonb, default: {} | datos adicionales libres |
| `custom_attributes` | jsonb, default: {} | atributos personalizados por cuenta |
| `created_at / updated_at` | datetime | |

**SLA por priority (minutos):**

| priority | first_response_time_target | resolution_time_target |
|----------|---------------------------|----------------------|
| low      | 2880 (48h)                | 7200 (5d)            |
| medium   | 480 (8h)                  | 2880 (48h)           |
| high     | 120 (2h)                  | 480 (8h)             |
| urgent   | 30 min                    | 120 (2h)             |

**Índices:**
- `(account_id, status)` — consultas por estado dentro de la cuenta
- `(account_id, contact_id)` — tickets por contacto
- `(account_id, sla_status)` — vista de SLA vencidos/en riesgo
- `(account_id, case_type)` — filtros por tipo
- `metadata` — índice GIN

**Transiciones válidas de status:**

```
open              → classified, cancelled
classified        → in_progress, cancelled
in_progress       → waiting_on_customer, waiting_on_internal, escalated, resolved, cancelled
waiting_on_customer → in_progress, cancelled
waiting_on_internal → in_progress, cancelled
escalated         → in_progress, cancelled
resolved          → closed, in_progress (reopen)
closed            → (ninguna)
cancelled         → (ninguna)
```

---

### CaseEvent (`case_events`)

**Enums:**

```ruby
event_type: {
  ticket_created:     0,
  ticket_classified:  1,
  status_changed:     2,
  assigned:           3,
  reassigned:         4,
  escalated:          5,
  message_received:   6,
  message_sent:       7,
  tracking_triggered: 8,
  tracking_paused:    9,
  resolved:           10,
  reopened:           11,
  closed:             12,
  sla_at_risk:        13,
  sla_overdue:        14,
  error_detected:     15,
  internal_note:      16
}

origin: { bot: 0, agent: 1, system: 2 }
```

**Columnas:**

| Columna | Tipo | Notas |
|---------|------|-------|
| `case_ticket_id` | bigint, NOT NULL | FK → case_tickets |
| `account_id` | bigint, NOT NULL | FK → accounts |
| `actor_id` | bigint, nullable | FK → users (nil = bot/sistema) |
| `event_type` | integer, NOT NULL | enum |
| `origin` | integer, NOT NULL | enum |
| `payload` | jsonb, default: {} | datos del evento |
| `created_at` | datetime | solo inserción — no se edita |

**Índices:**
- `(case_ticket_id, event_type)` — timeline del ticket
- `(account_id, created_at)` — eventos recientes por cuenta
- `payload` — índice GIN

---

### CaseRule (`case_rules`)

**Columnas:**

| Columna | Tipo | Notas |
|---------|------|-------|
| `account_id` | bigint, NOT NULL | FK → accounts |
| `name` | string, NOT NULL | nombre descriptivo |
| `description` | text, nullable | |
| `active` | boolean, default: true | |
| `continue_on_match` | boolean, default: false | si true, evalúa siguientes reglas tras match |
| `position` | integer, default: 0 | prioridad de evaluación (menor = primero) |
| `conditions` | jsonb, default: [] | array de condiciones |
| `actions` | jsonb, default: [] | array de acciones |
| `created_at / updated_at` | datetime | |

**Índice:** `(account_id, active, position)` — evaluación en cascada ordenada

**Estructura de condition:**
```json
{ "field": "case_type", "operator": "eq", "value": "support" }
```

**Operadores:** `eq`, `neq`, `contains`, `gte`, `lte`, `in`, `not_in`

**Fields evaluables:** `case_type`, `origin`, `priority`, `status`, `sla_status`, `message_content`, `time_without_response_min`

**Tipos de action:** `assign_agent`, `assign_team`, `change_priority`, `change_status`, `escalate`, `notify_agent`, `trigger_tracking`, `add_label`, `close_ticket`

**Reglas pre-cargadas por defecto:**
```
Rule 1: case_type=support → assign_team "Soporte Técnico"
Rule 2: case_type=commercial → assign_team "Comercial"
Rule 3: case_type=implementation → assign_agent José Luis
Rule 4: message_content CONTAINS "urgente" → change_priority urgent + notify_agent admin
Rule 5: sla_status=overdue AND case_type=support → escalate + assign_team "Soporte Senior"
Rule 6: status=waiting_on_customer + message_received → change_status in_progress
Rule 7: status=resolved AND time_without_activity >= 72h → close_ticket
```

---



## 🔗 Relacionado
- Estado actual de case_type: [[case_type-tabla-configurable]]
- [[Servicios-Directiva-Integracion]] · [[Fase-0-Migraciones-Modelos]]
