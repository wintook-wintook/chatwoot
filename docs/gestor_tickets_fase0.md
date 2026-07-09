# Gestor de Tickets — Fase 0: Migraciones y Modelos

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo

---

## Qué se implementó

Fase 0 establece la base de datos y los modelos Rails para las tres entidades nuevas del Gestor de Tickets: `CaseTicket`, `CaseEvent` y `CaseRule`. Ningún archivo existente fue modificado.

---

## Archivos creados

### Migraciones

| Archivo | Tabla |
|---------|-------|
| `db/migrate/20260604000001_create_case_tickets.rb` | `case_tickets` |
| `db/migrate/20260604000002_create_case_events.rb` | `case_events` |
| `db/migrate/20260604000003_create_case_rules.rb` | `case_rules` |

### Modelos

| Archivo | Clase |
|---------|-------|
| `app/models/case_ticket.rb` | `CaseTicket` |
| `app/models/case_event.rb` | `CaseEvent` |
| `app/models/case_rule.rb` | `CaseRule` |

---

## Tabla `case_tickets`

Representa un problema o necesidad concreta del cliente, separado del canal de comunicación (`Conversation`).

### Columnas

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | bigint | PK | |
| `account_id` | bigint | NOT NULL | FK → accounts |
| `contact_id` | bigint | NOT NULL | FK → contacts |
| `conversation_id` | bigint | nullable | FK → conversations |
| `contact_tracking_id` | bigint | nullable | FK → contact_trackings |
| `assignee_id` | bigint | nullable | FK → users |
| `team_id` | bigint | nullable | FK → teams |
| `case_type` | integer | NOT NULL, default: 0 | enum |
| `origin` | integer | NOT NULL, default: 0 | enum |
| `priority` | integer | NOT NULL, default: 1 | enum (1 = medium) |
| `status` | integer | NOT NULL, default: 0 | enum (0 = open) |
| `assignee_type` | integer | NOT NULL, default: 0 | enum (0 = bot) |
| `sla_status` | integer | NOT NULL, default: 0 | enum (0 = on_time) |
| `title` | string | NOT NULL, max 255 | |
| `description` | text | nullable | |
| `first_response_time_target` | integer | nullable | minutos, se asigna por priority al crear |
| `resolution_time_target` | integer | nullable | minutos, se asigna por priority al crear |
| `first_response_at` | datetime | nullable | cuándo se registró la primera respuesta |
| `resolved_at` | datetime | nullable | cuándo se marcó como resuelto |
| `closed_at` | datetime | nullable | cuándo se cerró definitivamente |
| `metadata` | jsonb | NOT NULL, default: {} | datos adicionales libres |
| `custom_attributes` | jsonb | NOT NULL, default: {} | atributos personalizados por cuenta |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

### Índices

| Índice | Columnas | Tipo |
|--------|----------|------|
| `index_case_tickets_on_account_id_and_status` | `(account_id, status)` | btree |
| `index_case_tickets_on_account_id_and_contact_id` | `(account_id, contact_id)` | btree |
| `index_case_tickets_on_account_id_and_sla_status` | `(account_id, sla_status)` | btree |
| `index_case_tickets_on_account_id_and_case_type` | `(account_id, case_type)` | btree |
| `index_case_tickets_on_metadata` | `metadata` | GIN |

---

## Tabla `case_events`

Registro inmutable del historial de cada ticket. Solo inserción — los eventos nunca se editan ni eliminan.

### Columnas

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | bigint | PK | |
| `case_ticket_id` | bigint | NOT NULL | FK → case_tickets |
| `account_id` | bigint | NOT NULL | FK → accounts |
| `actor_id` | bigint | nullable | FK → users (nil = bot/sistema) |
| `event_type` | integer | NOT NULL | enum (17 tipos) |
| `origin` | integer | NOT NULL | enum: bot/agent/system |
| `payload` | jsonb | NOT NULL, default: {} | datos del evento |
| `created_at` | datetime | NOT NULL | solo inserción, sin updated_at |

### Índices

| Índice | Columnas | Tipo |
|--------|----------|------|
| `index_case_events_on_case_ticket_id_and_event_type` | `(case_ticket_id, event_type)` | btree |
| `index_case_events_on_account_id_and_created_at` | `(account_id, created_at)` | btree |
| `index_case_events_on_payload` | `payload` | GIN |

---

## Tabla `case_rules`

Reglas de automatización evaluadas en cascada por el `RuleEngineService` (Fase 1).

### Columnas

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | bigint | PK | |
| `account_id` | bigint | NOT NULL | FK → accounts |
| `name` | string | NOT NULL | nombre descriptivo |
| `description` | text | nullable | |
| `active` | boolean | NOT NULL, default: true | |
| `continue_on_match` | boolean | NOT NULL, default: false | si true, evalúa siguientes reglas tras match |
| `position` | integer | NOT NULL, default: 0 | prioridad de evaluación (menor = primero) |
| `conditions` | jsonb | NOT NULL, default: [] | array de condiciones |
| `actions` | jsonb | NOT NULL, default: [] | array de acciones |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

### Índice

| Índice | Columnas | Tipo |
|--------|----------|------|
| `index_case_rules_on_account_id_and_active_and_position` | `(account_id, active, position)` | btree |

---

## Modelo `CaseTicket`

### Enums

```ruby
enum case_type:    { support: 0, commercial: 1, implementation: 2, internal_tracking: 3, system_incident: 4 }
enum origin:       { whatsapp: 0, web: 1, email: 2, bot: 3, manual: 4 }
enum priority:     { low: 0, medium: 1, high: 2, urgent: 3 }
enum status:       { open: 0, classified: 1, in_progress: 2, waiting_on_customer: 3,
                     waiting_on_internal: 4, escalated: 5, resolved: 6, closed: 7, cancelled: 8 }
enum assignee_type: { bot: 0, agent: 1, team: 2, system: 3 }, _prefix: :assignee
enum sla_status:   { on_time: 0, at_risk: 1, overdue: 2 }
```

> **Nota:** `assignee_type` usa `_prefix: :assignee` para evitar conflicto con el método `bot?` generado por el enum `origin`. Los métodos resultantes son `assignee_bot?`, `assignee_agent?`, etc.

### Asociaciones

```ruby
belongs_to :account
belongs_to :contact
belongs_to :conversation,     optional: true
belongs_to :contact_tracking, optional: true
belongs_to :assignee,         class_name: 'User', optional: true
belongs_to :team,             optional: true
has_many   :case_events,      dependent: :destroy
```

### Constantes

#### `VALID_TRANSITIONS`

Define las transiciones de status permitidas:

```ruby
{
  'open'                => ['classified', 'cancelled'],
  'classified'          => ['in_progress', 'cancelled'],
  'in_progress'         => ['waiting_on_customer', 'waiting_on_internal', 'escalated', 'resolved', 'cancelled'],
  'waiting_on_customer' => ['in_progress', 'cancelled'],
  'waiting_on_internal' => ['in_progress', 'cancelled'],
  'escalated'           => ['in_progress', 'cancelled'],
  'resolved'            => ['closed', 'in_progress'],
  'closed'              => [],
  'cancelled'           => []
}
```

#### `SLA_BY_PRIORITY`

Tiempos SLA en minutos por nivel de prioridad:

| Prioridad | first_response_time_target | resolution_time_target |
|-----------|---------------------------|----------------------|
| `low`     | 2880 min (48h)            | 7200 min (5d)        |
| `medium`  | 480 min (8h)              | 2880 min (48h)       |
| `high`    | 120 min (2h)              | 480 min (8h)         |
| `urgent`  | 30 min                    | 120 min (2h)         |

### Callbacks

| Callback | Método | Qué hace |
|----------|--------|----------|
| `before_create` | `assign_sla_targets` | Asigna `first_response_time_target` y `resolution_time_target` según la `priority`. Solo sobreescribe si son `nil` (permite override manual). |
| `after_create` | `create_ticket_created_event` | Crea el primer `CaseEvent` con `event_type: :ticket_created` y `origin: :system`. El payload incluye `case_type`, `priority` y `origin` del ticket. |

### Métodos públicos

#### `can_transition_to?(new_status)`

Retorna `true` si la transición desde el status actual al `new_status` es válida según `VALID_TRANSITIONS`.

```ruby
ticket.status          # => "open"
ticket.can_transition_to?(:classified)  # => true
ticket.can_transition_to?(:closed)      # => false
```

#### `transition!(new_status, actor: nil, reason: nil)`

Cambia el status del ticket y registra el `CaseEvent` correspondiente.

- Lanza `RuntimeError` si la transición no es válida.
- Asigna `resolved_at` o `closed_at` automáticamente según el nuevo status.
- Crea un `CaseEvent` con el `event_type` apropiado (ver tabla abajo).
- `origin` del evento: `:agent` si se pasa `actor`, `:system` si es nil.

**Mapeo de transición → event_type:**

| Nuevo status | event_type registrado |
|-------------|----------------------|
| `escalated` | `:escalated` |
| `resolved` | `:resolved` |
| `closed` | `:closed` |
| `in_progress` (desde `resolved`) | `:reopened` |
| cualquier otro | `:status_changed` |

#### `calculate_sla_status`

Calcula el estado SLA actual del ticket basado en el tiempo transcurrido.

- Retorna `:on_time` si el ticket está `resolved`, `closed` o `cancelled`.
- Compara tiempo transcurrido contra `first_response_time_target` (si aún no hay `first_response_at`) o `resolution_time_target`.
- Thresholds: `>= 100%` del target → `:overdue`, `>= 80%` → `:at_risk`, `< 80%` → `:on_time`.

---

## Modelo `CaseEvent`

### Enums

```ruby
enum event_type: {
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

enum origin: { bot: 0, agent: 1, system: 2 }
```

### Asociaciones

```ruby
belongs_to :case_ticket
belongs_to :account
belongs_to :actor, class_name: 'User', optional: true
```

### Comportamiento inmutable

La tabla `case_events` no tiene columna `updated_at`. Los eventos son de solo escritura — una vez creados, no se modifican ni eliminan desde la aplicación.

---

## Modelo `CaseRule`

### Asociaciones y scopes

```ruby
belongs_to :account
scope :enabled, -> { where(active: true).order(:position) }
```

### Validaciones

- `name` — presencia obligatoria.
- `conditions` — debe ser un `Array` (validación custom).
- `actions` — debe ser un `Array` (validación custom).

### Estructura esperada de conditions y actions

**Condition:**
```json
{ "field": "case_type", "operator": "eq", "value": "support" }
```

**Operadores soportados (evaluados en Fase 1):** `eq`, `neq`, `contains`, `gte`, `lte`, `in`, `not_in`

**Fields evaluables:** `case_type`, `origin`, `priority`, `status`, `sla_status`, `message_content`, `time_without_response_min`

**Action:**
```json
{ "type": "assign_team", "value": "Soporte Técnico" }
```

**Tipos de action (implementados en Fase 1):** `assign_agent`, `assign_team`, `change_priority`, `change_status`, `escalate`, `notify_agent`, `trigger_tracking`, `add_label`, `close_ticket`

---

## Criterios de aceptación verificados

| Criterio | Resultado |
|----------|-----------|
| Las 3 migraciones corren sin error | ✅ |
| `CaseTicket` con `priority: :urgent` asigna `first_response_time_target: 30` automáticamente | ✅ |
| `CaseTicket` con `priority: :urgent` asigna `resolution_time_target: 120` automáticamente | ✅ |
| `after_create` crea 1 `CaseEvent` con `event_type: :ticket_created` | ✅ |
| `transition!(:open)` desde `closed` lanza `RuntimeError` | ✅ |
| `CaseRule` acepta `conditions` y `actions` como arrays JSON | ✅ |

---

## Decisiones técnicas tomadas

### Prefix en `assignee_type`

**Problema:** Dos enums (`origin` y `assignee_type`) ambos definen el valor `bot`, generando el mismo método de instancia `bot?`. Rails 7 lanza `ArgumentError` al cargar el modelo.

**Solución:** Se agrega `_prefix: :assignee` al enum `assignee_type`. Los métodos generados pasan a ser `assignee_bot?`, `assignee_agent?`, `assignee_team?`, `assignee_system?`. Los scopes de clase siguen el mismo patrón: `CaseTicket.assignee_bot`.

### `case_events` sin `updated_at`

La migración no incluye columna `updated_at`. Rails maneja correctamente la ausencia — no intenta actualizarla en ningún callback. El comportamiento inmutable es garantizado por ausencia de columna, no por lógica de aplicación.

### SLA con `||=` en `assign_sla_targets`

El `before_create` usa `||=` para asignar los targets SLA solo si son `nil`. Esto permite que código externo (como `Cases::OrchestratorService` en Fase 1) pase valores personalizados al crear un ticket sin que el callback los sobreescriba.

---

## Siguiente fase

**Fase 1 — Servicios + Jobs + Integración con el bot:**

| Componente | Archivo | Función |
|-----------|---------|---------|
| `Cases::OrchestratorService` | `app/services/cases/orchestrator_service.rb` | `find_or_create` ticket desde mensaje o acción manual |
| `Cases::RuleEngineService` | `app/services/cases/rule_engine_service.rb` | Evalúa reglas en cascada sobre un `CaseTicket` |
| `Cases::TicketCreatorService` | `app/services/cases/ticket_creator_service.rb` | Detecta `@crear_ticket` y crea ticket cuando KBase no resolvió |
| `CaseSlaMonitorJob` | `app/jobs/case_sla_monitor_job.rb` | Cron cada 15min — detecta SLA at_risk/overdue, cierre automático 72h |
| Hook en `ContactTrackingResponseAnalyzerJob` | archivo existente | Agrega bloque con `rescue` al inicio de `process_message_for_tracking` |
