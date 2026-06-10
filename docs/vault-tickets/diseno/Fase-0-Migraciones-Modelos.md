---
titulo: Fase 0 — Migraciones y modelos (detalle)
tipo: diseño
fase: "0"
tags: [tickets, fase-0, migraciones, modelos]
---

## FASE 0 — Migraciones y Modelos (detalle)

### Migraciones a crear (3 archivos)

#### 1. `create_case_tickets`

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
| `first_response_time_target` | integer, nullable | minutos, asignado por priority al crear |
| `resolution_time_target` | integer, nullable | minutos, asignado por priority al crear |
| `first_response_at` | datetime, nullable | |
| `resolved_at` | datetime, nullable | |
| `closed_at` | datetime, nullable | |
| `metadata` | jsonb, default: {} | |
| `custom_attributes` | jsonb, default: {} | |
| `created_at / updated_at` | datetime | |

Índices: `(account_id, status)` · `(account_id, contact_id)` · `(account_id, sla_status)` · `(account_id, case_type)` · GIN en `metadata`

#### 2. `create_case_events`

| Columna | Tipo | Notas |
|---------|------|-------|
| `case_ticket_id` | bigint, NOT NULL | FK → case_tickets |
| `account_id` | bigint, NOT NULL | FK → accounts |
| `actor_id` | bigint, nullable | FK → users |
| `event_type` | integer, NOT NULL | enum (17 tipos) |
| `origin` | integer, NOT NULL | enum: bot/agent/system |
| `payload` | jsonb, default: {} | |
| `created_at` | datetime | solo inserción |

Índices: `(case_ticket_id, event_type)` · `(account_id, created_at)` · GIN en `payload`

#### 3. `create_case_rules`

| Columna | Tipo | Notas |
|---------|------|-------|
| `account_id` | bigint, NOT NULL | FK → accounts |
| `name` | string, NOT NULL | |
| `description` | text, nullable | |
| `active` | boolean, default: true | |
| `continue_on_match` | boolean, default: false | |
| `position` | integer, default: 0 | |
| `conditions` | jsonb, default: [] | |
| `actions` | jsonb, default: [] | |
| `created_at / updated_at` | datetime | |

Índice: `(account_id, active, position)`

---

### Modelos a crear (3 archivos)

#### `CaseTicket` (`app/models/case_ticket.rb`)

- Enums: `case_type`, `origin`, `priority`, `status`, `assignee_type`, `sla_status`
- Validaciones: `title`, `case_type`, `origin`, `priority`, `status` presentes
- Constante `VALID_TRANSITIONS` — hash que mapea cada status a sus destinos permitidos
- Constante `SLA_BY_PRIORITY` — hash con minutos de `first_response_time_target` y `resolution_time_target` por priority
- `can_transition_to?(new_status)` — valida antes de cambiar
- `transition!(new_status, actor:, reason:)` — cambia status y registra `CaseEvent`
- `calculate_sla_status` — retorna `on_time`, `at_risk` o `overdue` según tiempo transcurrido
- `after_create` → asigna SLA según priority + registra event `ticket_created`
- Asociaciones: `belongs_to account, contact, conversation (opt), contact_tracking (opt), assignee/User (opt), team (opt)` · `has_many case_events`

#### `CaseEvent` (`app/models/case_event.rb`)

- Enums: `event_type` (19 valores; +`in_diagnosis`,`validating` en 2A), `origin` (bot/agent/system)
- Validaciones: `event_type` y `origin` presentes
- Asociaciones: `belongs_to case_ticket, account, actor/User (opt)`
- Solo inserción — los eventos nunca se editan ni eliminan

#### `CaseRule` (`app/models/case_rule.rb`)

- Validaciones: `name` presente · `conditions` y `actions` son arrays
- Scope `enabled` → `where(active: true).order(:position)`
- Asociaciones: `belongs_to account`

---

### Criterio de aceptación de la Fase 0

- Las 3 migraciones corren sin error con `rails db:migrate`
- Los modelos responden en `rails console`:
  - Crear un `CaseTicket` con `priority: :urgent` asigna `first_response_time_target: 30` automáticamente
  - `transition!` lanza error en transiciones inválidas (ej: `closed → open`)
  - `CaseEvent` se crea asociado al ticket con `event_type` y `origin` correctos
  - `CaseRule` acepta `conditions` y `actions` como arrays JSON
- Tests de modelo cubren: transiciones inválidas, SLA defaults por priority, validaciones de presencia

---



## 🔗 Relacionado
- [[Modelo-de-datos]] · [[case_type-tabla-configurable]]
