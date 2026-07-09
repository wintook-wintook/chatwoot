# Gestor de Tickets — Plan v2.0
**Motor de Gestión de Casos Inteligente (MGCI) · Kontrolya / Wintook**

> **Versión:** 2.0 · **Fecha:** 2026-05-28
> **Rama base:** `feat/kbase_contact_tracking`
> **Estado:** Diseño finalizado — pendiente implementación

---

## Diagrama de Secuencia

<svg xmlns="http://www.w3.org/2000/svg" width="960" height="628" viewBox="0 0 960 628">
  <rect width="960" height="628" fill="#f8fafc" rx="8"/>
  <text x="480" y="20" text-anchor="middle" font-size="13" font-weight="700" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">Diagrama de Secuencia — Gestor de Tickets</text>
  <!-- PARTICIPANT BOXES -->
  <rect x="35" y="28" width="100" height="36" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
  <text x="85" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#1e3a8a" font-family="Segoe UI, system-ui, sans-serif">Cliente</text>
  <text x="85" y="61" text-anchor="middle" font-size="9" fill="#1e3a8a" font-family="Segoe UI, system-ui, sans-serif">(WhatsApp)</text>
  <rect x="168" y="28" width="114" height="36" rx="4" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5"/>
  <text x="225" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#0c4a6e" font-family="Segoe UI, system-ui, sans-serif">AnalyzerJob</text>
  <text x="225" y="61" text-anchor="middle" font-size="9" fill="#0c4a6e" font-family="Segoe UI, system-ui, sans-serif">ContactTracking</text>
  <rect x="315" y="28" width="120" height="36" rx="4" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
  <text x="375" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#14532d" font-family="Segoe UI, system-ui, sans-serif">Orchestrator</text>
  <text x="375" y="61" text-anchor="middle" font-size="9" fill="#14532d" font-family="Segoe UI, system-ui, sans-serif">Service</text>
  <rect x="455" y="28" width="120" height="36" rx="4" fill="#fef3c7" stroke="#d97706" stroke-width="1.5"/>
  <text x="515" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#78350f" font-family="Segoe UI, system-ui, sans-serif">RuleEngine</text>
  <text x="515" y="61" text-anchor="middle" font-size="9" fill="#78350f" font-family="Segoe UI, system-ui, sans-serif">Service</text>
  <rect x="598" y="28" width="124" height="36" rx="4" fill="#ede9fe" stroke="#7c3aed" stroke-width="1.5"/>
  <text x="660" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#4c1d95" font-family="Segoe UI, system-ui, sans-serif">KBase</text>
  <text x="660" y="61" text-anchor="middle" font-size="9" fill="#4c1d95" font-family="Segoe UI, system-ui, sans-serif">Service</text>
  <rect x="755" y="28" width="130" height="36" rx="4" fill="#fce7f3" stroke="#db2777" stroke-width="1.5"/>
  <text x="820" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#831843" font-family="Segoe UI, system-ui, sans-serif">TicketCreator</text>
  <text x="820" y="61" text-anchor="middle" font-size="9" fill="#831843" font-family="Segoe UI, system-ui, sans-serif">Service</text>
  <!-- LIFELINES -->
  <line x1="85"  y1="64" x2="85"  y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <line x1="225" y1="64" x2="225" y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <line x1="375" y1="64" x2="375" y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <line x1="515" y1="64" x2="515" y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <line x1="660" y1="64" x2="660" y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <line x1="820" y1="64" x2="820" y2="555" stroke="#cbd5e1" stroke-width="1" stroke-dasharray="4,3"/>
  <!-- AnalyzerJob activation bar -->
  <rect x="222" y="90" width="6" height="410" rx="1" fill="#bae6fd" stroke="#0284c7" stroke-width="0.8"/>
  <!-- MSG 1: Cliente → AnalyzerJob y=92 -->
  <line x1="85" y1="92" x2="222" y2="92" stroke="#1d4ed8" stroke-width="1.5"/>
  <polygon points="214,88 222,92 214,96" fill="#1d4ed8"/>
  <text x="153" y="88" text-anchor="middle" font-size="10" font-weight="500" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">mensaje entrante</text>
  <!-- MSG 2: AnalyzerJob → OrchestratorSvc y=120 -->
  <line x1="228" y1="120" x2="375" y2="120" stroke="#15803d" stroke-width="1.5"/>
  <polygon points="367,116 375,120 367,124" fill="#15803d"/>
  <text x="301" y="115" text-anchor="middle" font-size="10" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">find_or_create_ticket</text>
  <rect x="372" y="120" width="6" height="32" rx="1" fill="#bbf7d0" stroke="#16a34a" stroke-width="0.8"/>
  <!-- MSG 3 return: OrchestratorSvc → AnalyzerJob y=152 -->
  <line x1="372" y1="152" x2="228" y2="152" stroke="#15803d" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="236,148 228,152 236,156" fill="#15803d"/>
  <text x="301" y="147" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">CaseTicket + Event: ticket_created</text>
  <!-- MSG 4: AnalyzerJob → RuleEngineSvc y=180 -->
  <line x1="228" y1="180" x2="515" y2="180" stroke="#b45309" stroke-width="1.5"/>
  <polygon points="507,176 515,180 507,184" fill="#b45309"/>
  <text x="371" y="175" text-anchor="middle" font-size="10" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">evaluate!(ticket)</text>
  <rect x="512" y="180" width="6" height="30" rx="1" fill="#fde68a" stroke="#d97706" stroke-width="0.8"/>
  <!-- MSG 5 return: RuleEngineSvc → AnalyzerJob y=210 -->
  <line x1="512" y1="210" x2="228" y2="210" stroke="#b45309" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="236,206 228,210 236,214" fill="#b45309"/>
  <text x="371" y="205" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">acciones aplicadas (assign, priority...)</text>
  <!-- ALT BOX -->
  <rect x="18" y="228" width="932" height="326" rx="4" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="6,3"/>
  <rect x="18" y="228" width="28" height="18" rx="2" fill="#64748b"/>
  <text x="32" y="241" text-anchor="middle" font-size="10" font-weight="700" fill="white" font-family="Segoe UI, system-ui, sans-serif">alt</text>
  <!-- ALT 1 -->
  <text x="480" y="247" text-anchor="middle" font-size="10" font-weight="600" fill="#1d4ed8" font-family="Segoe UI, system-ui, sans-serif">[KnowledgeBase resuelve la consulta]</text>
  <!-- MSG 6a: AnalyzerJob → KBaseSvc y=264 -->
  <line x1="228" y1="264" x2="660" y2="264" stroke="#6d28d9" stroke-width="1.5"/>
  <polygon points="652,260 660,264 652,268" fill="#6d28d9"/>
  <text x="444" y="259" text-anchor="middle" font-size="10" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">search(@buscar_foro / @buscar_predefinidas)</text>
  <rect x="657" y="264" width="6" height="30" rx="1" fill="#ddd6fe" stroke="#7c3aed" stroke-width="0.8"/>
  <!-- MSG 7a return: KBaseSvc → AnalyzerJob y=294 -->
  <line x1="657" y1="294" x2="228" y2="294" stroke="#6d28d9" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="236,290 228,294 236,298" fill="#6d28d9"/>
  <text x="444" y="289" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">respuesta encontrada</text>
  <!-- MSG 8a: AnalyzerJob → Cliente return y=322 -->
  <line x1="222" y1="322" x2="85" y2="322" stroke="#1d4ed8" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="93,318 85,322 93,326" fill="#1d4ed8"/>
  <text x="153" y="317" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">respuesta al cliente</text>
  <text x="153" y="331" text-anchor="middle" font-size="9" fill="#64748b" font-family="Segoe UI, system-ui, sans-serif">CaseEvent: message_sent</text>
  <!-- Divider -->
  <line x1="18" y1="352" x2="950" y2="352" stroke="#64748b" stroke-width="1" stroke-dasharray="5,3"/>
  <!-- ALT 2 -->
  <text x="480" y="370" text-anchor="middle" font-size="10" font-weight="600" fill="#be185d" font-family="Segoe UI, system-ui, sans-serif">[KBase sin resultados + directiva @crear_ticket presente]</text>
  <!-- MSG 6b: AnalyzerJob → KBaseSvc y=388 -->
  <line x1="228" y1="388" x2="660" y2="388" stroke="#6d28d9" stroke-width="1.5"/>
  <polygon points="652,384 660,388 652,392" fill="#6d28d9"/>
  <text x="444" y="383" text-anchor="middle" font-size="10" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">search(@buscar_foro)</text>
  <rect x="657" y="388" width="6" height="27" rx="1" fill="#ddd6fe" stroke="#7c3aed" stroke-width="0.8"/>
  <!-- MSG 7b return: KBaseSvc → AnalyzerJob y=415 -->
  <line x1="657" y1="415" x2="228" y2="415" stroke="#6d28d9" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="236,411 228,415 236,419" fill="#6d28d9"/>
  <text x="444" y="410" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">sin resultados</text>
  <!-- MSG 8b: AnalyzerJob → TicketCreatorSvc y=444 -->
  <line x1="228" y1="444" x2="820" y2="444" stroke="#9d174d" stroke-width="1.5"/>
  <polygon points="812,440 820,444 812,448" fill="#9d174d"/>
  <text x="524" y="439" text-anchor="middle" font-size="10" fill="#1e293b" font-family="Segoe UI, system-ui, sans-serif">detect @crear_ticket → create_from_directive</text>
  <rect x="817" y="444" width="6" height="36" rx="1" fill="#fbcfe8" stroke="#db2777" stroke-width="0.8"/>
  <!-- MSG 9b: TicketCreatorSvc → Cliente y=480 -->
  <line x1="817" y1="480" x2="85" y2="480" stroke="#9d174d" stroke-width="1.5" stroke-dasharray="5,3"/>
  <polygon points="93,476 85,480 93,484" fill="#9d174d"/>
  <text x="452" y="475" text-anchor="middle" font-size="10" font-style="italic" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">"Tu caso fue registrado, un asesor te contactara"</text>
  <text x="452" y="490" text-anchor="middle" font-size="9" fill="#64748b" font-family="Segoe UI, system-ui, sans-serif">CaseEvent: ticket_created</text>
  <!-- SlaMonitorJob note -->
  <rect x="18" y="566" width="932" height="50" rx="6" fill="#f0fdf4" stroke="#86efac" stroke-width="1.5"/>
  <text x="480" y="585" text-anchor="middle" font-size="11" font-weight="700" fill="#14532d" font-family="Segoe UI, system-ui, sans-serif">CaseSlaMonitorJob — Sidekiq cron cada 15 min</text>
  <text x="480" y="601" text-anchor="middle" font-size="10" fill="#374151" font-family="Segoe UI, system-ui, sans-serif">Detecta SLA at_risk / overdue → RuleEngine → escalado automatico → auto-cierre 72h post resolved</text>
</svg>

---

## Propósito

Módulo nuevo que separa claramente tres conceptos que hoy están mezclados:

| Capa | Responsabilidad | Modelo |
|---|---|---|
| **Comunicación** | Canal con el cliente (WhatsApp, web, email) | `Conversation` (sin cambios) |
| **Ticket** | Problema o necesidad concreta del cliente | `CaseTicket` (nuevo) |
| **Seguimiento** | Acción automática sobre el ticket | `ContactTracking` (extendido) |
| **Eventos** | Historial auditable de todo lo que ocurre | `CaseEvent` (nuevo) |
| **Reglas** | Automatización de asignaciones y escalados | `CaseRule` (nuevo) |

**Regla de oro:** Un cliente puede tener 1 conversación activa · múltiples tickets · múltiples seguimientos por ticket.

**Convención:** tablas, columnas, enums y código en **inglés** (igual que Chatwoot). Las etiquetas de UI se muestran en español.

---

## Lo que NO se toca

| Componente | Estado |
|---|---|
| `ContactTracking` (modelo) | Sin cambios |
| `RouterService` | Sin cambios |
| `KnowledgeBaseResponseService` | Sin cambios |
| `BotSeller::Dispatcher` | Sin cambios |
| `Conversation` (modelo Chatwoot) | Sin cambios |
| `ContactTrackingResponseAnalyzerJob` — flujo principal | Sin cambios (solo se agrega un hook al inicio) |
| Todas las migraciones existentes | Sin cambios |

El único punto de contacto con código existente es un bloque nuevo al inicio de `process_message_for_tracking`, protegido con `rescue`.

---

## Tablas a crear (6 tablas, prefijo `ticket_`)

| # | Tabla | Modelo Rails | Descripción |
|---|---|---|---|
| 1 | `ticket_cases` | `CaseTicket` | Entidad principal — el ticket |
| 2 | `ticket_events` | `CaseEvent` | Log de auditoría inmutable |
| 3 | `ticket_rules` | `CaseRule` | Reglas de automatización |
| 4 | `ticket_types` | `CaseType` | Tipos configurables por cuenta |
| 5 | `ticket_priorities` | `CasePriority` | Prioridades + SLA configurables por cuenta |
| 6 | `ticket_settings` | `CaseSettings` | Config por cuenta (labels, defaults, etc.) |

---

## Enums: fijos vs configurables

### Enums fijos (Rails enum — lógica del sistema depende de ellos)

```ruby
# CaseTicket
enum :origin,        { inbox: 0, bot: 1, manual: 2 }
enum :status,        { open: 0, classified: 1, in_progress: 2, waiting_on_customer: 3,
                       waiting_on_internal: 4, escalated: 5, resolved: 6, closed: 7, cancelled: 8 }
enum :assignee_type, { bot: 0, agent: 1, team: 2, system: 3 }
enum :sla_status,    { on_time: 0, at_risk: 1, overdue: 2 }

# CaseEvent
enum :event_type, {
  ticket_created: 0, ticket_classified: 1, status_changed: 2, assigned: 3,
  reassigned: 4, escalated: 5, message_received: 6, message_sent: 7,
  tracking_triggered: 8, tracking_paused: 9, resolved: 10, reopened: 11,
  closed: 12, sla_at_risk: 13, sla_overdue: 14, error_detected: 15, internal_note: 16
}
enum :origin, { bot: 0, agent: 1, system: 2 }
```

### Configurables por cuenta (tablas separadas, NO enums)

| Concepto | Reemplaza | Tabla |
|---|---|---|
| Tipo de caso | `case_type` enum | `ticket_types` |
| Prioridad + SLA | `priority` enum | `ticket_priorities` |

---

## Schema de tablas

### `ticket_cases`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL | FK → accounts |
| `contact_id` | bigint NOT NULL | FK → contacts |
| `conversation_id` | bigint nullable | FK → conversations |
| `contact_tracking_id` | bigint nullable | FK → contact_trackings |
| `ticket_type_id` | bigint nullable | FK → ticket_types |
| `ticket_priority_id` | bigint NOT NULL | FK → ticket_priorities |
| `assignee_id` | bigint nullable | FK → users (cuando assignee_type = agent) |
| `team_id` | bigint nullable | FK → teams (cuando assignee_type = team) |
| `inbox_id` | bigint nullable | FK → inboxes (cuando origin = inbox) |
| `origin` | integer NOT NULL | enum fijo, default: 0 (inbox) |
| `status` | integer NOT NULL | enum fijo, default: 0 (open) |
| `assignee_type` | integer NOT NULL | enum fijo, default: 0 (bot) |
| `sla_status` | integer NOT NULL | enum fijo, default: 0 (on_time) |
| `title` | string NOT NULL | max 255 chars |
| `description` | text nullable | |
| `first_response_time_target` | integer nullable | minutos, copiado de ticket_priority al crear |
| `resolution_time_target` | integer nullable | minutos, copiado de ticket_priority al crear |
| `first_response_at` | datetime nullable | |
| `resolved_at` | datetime nullable | |
| `closed_at` | datetime nullable | |
| `metadata` | jsonb default: {} | datos adicionales libres |
| `custom_attributes` | jsonb default: {} | atributos personalizados por cuenta |
| timestamps | | |

**Índices:**
- `(account_id, status)`
- `(account_id, contact_id)`
- `(account_id, sla_status)`
- `(account_id, ticket_type_id)`
- GIN en `metadata`

**Relación `origin` ↔ `inbox_id`:**

| origin | inbox_id | Significado |
|---|---|---|
| `inbox` | `42` | Vino del inbox 42 (WhatsApp, web, email — ver `inbox.channel_type`) |
| `bot` | `42` | El bot lo detectó dentro del inbox 42 |
| `manual` | nil | Agente lo creó a mano |

---

### `ticket_types`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL | FK → accounts |
| `name` | string NOT NULL | "Soporte Técnico", "Comercial", etc. |
| `slug` | string NOT NULL | "support", "commercial" (para lógica de reglas) |
| `color` | string | "#2563eb" |
| `position` | integer | orden en UI |
| `active` | boolean default: true | |
| timestamps | | |

**Índice:** `(account_id, slug)` unique · `(account_id, position)`

**Valores default al crear cuenta:**

| slug | name |
|---|---|
| `support` | Soporte Técnico |
| `commercial` | Comercial |
| `implementation` | Implementación |
| `internal_tracking` | Seguimiento Interno |
| `system_incident` | Incidente de Sistema |

---

### `ticket_priorities`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL | FK → accounts |
| `name` | string NOT NULL | "Baja", "Media", "Alta", "Urgente" |
| `slug` | string NOT NULL | "low", "medium", "high", "urgent" |
| `color` | string | "#16a34a" |
| `position` | integer | orden en UI |
| `sla_response_minutes` | integer NOT NULL | tiempo al primer contacto |
| `sla_resolution_minutes` | integer NOT NULL | tiempo a resolución |
| `active` | boolean default: true | |
| timestamps | | |

**Índice:** `(account_id, slug)` unique · `(account_id, position)`

**Valores default al crear cuenta:**

| slug | name | sla_response_minutes | sla_resolution_minutes |
|---|---|---|---|
| `low` | Baja | 2880 (48h) | 7200 (5d) |
| `medium` | Media | 480 (8h) | 2880 (48h) |
| `high` | Alta | 120 (2h) | 480 (8h) |
| `urgent` | Urgente | 30 min | 120 (2h) |

El `CaseSlaMonitorJob` lee los minutos desde la asociación:
```ruby
priority = ticket.ticket_priority
response_limit = priority.sla_response_minutes
resolution_limit = priority.sla_resolution_minutes
```

---

### `ticket_events`

| Columna | Tipo | Notas |
|---|---|---|
| `ticket_case_id` | bigint NOT NULL | FK → ticket_cases |
| `account_id` | bigint NOT NULL | FK → accounts |
| `actor_id` | bigint nullable | FK → users (nil = bot/sistema) |
| `event_type` | integer NOT NULL | enum (17 tipos) |
| `origin` | integer NOT NULL | enum: bot/agent/system |
| `payload` | jsonb default: {} | datos del evento |
| `created_at` | datetime | solo inserción — no se edita |

**Índices:** `(ticket_case_id, event_type)` · `(account_id, created_at)` · GIN en `payload`

---

### `ticket_rules`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL | FK → accounts |
| `name` | string NOT NULL | nombre descriptivo |
| `description` | text nullable | |
| `active` | boolean default: true | |
| `continue_on_match` | boolean default: false | si true, evalúa reglas siguientes tras match |
| `position` | integer default: 0 | prioridad de evaluación (menor = primero) |
| `conditions` | jsonb default: [] | array de condiciones |
| `actions` | jsonb default: [] | array de acciones |
| timestamps | | |

**Índice:** `(account_id, active, position)`

**Estructura de condición:**
```json
{ "field": "ticket_type", "operator": "eq", "value": "support" }
```

**Operadores:** `eq`, `neq`, `contains`, `gte`, `lte`, `in`, `not_in`

**Fields evaluables:** `ticket_type` (slug), `origin`, `sla_status`, `status`, `message_content`, `time_without_response_min`

**Tipos de action:** `assign_agent`, `assign_team`, `change_priority`, `change_status`, `escalate`, `notify_agent`, `trigger_tracking`, `add_label`, `close_ticket`

**Reglas pre-cargadas por defecto:**
```
Rule 1: ticket_type=support    → assign_team "Soporte Técnico"
Rule 2: ticket_type=commercial → assign_team "Comercial"
Rule 3: message_content CONTAINS "urgente" → change_priority urgent + notify_agent admin
Rule 4: sla_status=overdue AND ticket_type=support → escalate + assign_team "Soporte Senior"
Rule 5: status=waiting_on_customer + message_received → change_status in_progress
Rule 6: status=resolved AND time_without_activity >= 72h → close_ticket
```

---

### `ticket_settings`

| Columna | Tipo | Notas |
|---|---|---|
| `account_id` | bigint NOT NULL unique | FK → accounts |
| `status_labels` | jsonb | labels de display por status |
| timestamps | | |

**Ejemplo `status_labels`:**
```json
{
  "open":                "Nuevo",
  "classified":          "Clasificado",
  "in_progress":         "En atención",
  "waiting_on_customer": "Esperando cliente",
  "waiting_on_internal": "Pendiente interno",
  "escalated":           "Escalado",
  "resolved":            "Resuelto",
  "closed":              "Cerrado",
  "cancelled":           "Cancelado"
}
```

Si una clave no existe, la UI usa el valor del enum como fallback.

---

## Máquina de estados (`status`)

```
open              → classified, cancelled
classified        → in_progress, cancelled
in_progress       → waiting_on_customer, waiting_on_internal, escalated, resolved, cancelled
waiting_on_customer → in_progress, cancelled
waiting_on_internal → in_progress, cancelled
escalated         → in_progress, cancelled
resolved          → closed, in_progress (reopen)
closed            → (ninguna — terminal)
cancelled         → (ninguna — terminal)
```

---

## Servicios a crear

| Servicio | Ubicación | Función |
|---|---|---|
| `Cases::OrchestratorService` | `app/services/cases/orchestrator_service.rb` | `find_or_create` ticket desde mensaje o acción manual |
| `Cases::RuleEngineService` | `app/services/cases/rule_engine_service.rb` | Evalúa reglas en cascada sobre un `CaseTicket` |
| `Cases::TicketCreatorService` | `app/services/cases/ticket_creator_service.rb` | Detecta `@crear_ticket` y crea el ticket cuando KBase no resolvió |
| `CaseSlaMonitorJob` | `app/jobs/case_sla_monitor_job.rb` | Cron cada 15min — detecta SLA at_risk/overdue, cierre automático 72h |

---

## Directiva `@crear_ticket`

Se agrega en el `complementary_prompt` del `ContactTracking`, igual que `@buscar_foro` y `@buscar_predefinidas`.

### Orden de ejecución en el job

```
[1] KnowledgeBaseResponseService  (@buscar_predefinidas / @buscar_foro)
      → si resuelve: responde y termina
      → si NO resuelve: continúa

[2] Cases::TicketCreatorService   (@crear_ticket)
      → si directiva presente: crea ticket, confirma al cliente y termina
      → si NO hay directiva: continúa

[3] Respuesta conversacional genérica (fallback GPT)
```

### Tabla de directivas del sistema

| Directiva | Servicio | Qué hace |
|---|---|---|
| `@buscar_predefinidas` | `KnowledgeBaseResponseService` | Busca en pgvector (respuestas predefinidas) |
| `@buscar_foro(nombre)` | `KnowledgeBaseResponseService` | Busca en Discourse via API semántica |
| `@crear_ticket` | `Cases::TicketCreatorService` | Crea `CaseTicket` si KBase no resolvió |
| Texto libre | IA (GPT) | Contexto, tono, instrucciones de comportamiento |

**Ejemplo de `complementary_prompt`:**
```
Eres un asistente de soporte técnico de Kontrolya.
Primero busca la solución en la base de conocimiento: @buscar_foro(soporte-tecnico).
Si no encuentras una respuesta específica al problema, no improvises.
Usa @crear_ticket para registrar el caso y avisa al cliente que un asesor lo atenderá.
```

---

## Hook en `ContactTrackingResponseAnalyzerJob`

```ruby
# [Gestor de Tickets] hook — falla silenciosamente para no romper el bot
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
rescue => e
  Rails.logger.error("[GestorTickets] hook error: #{e.message}")
end
# → todo el código existente continúa sin cambios
```

---

## Mapeo RouterService → CaseTicket

| Ruta del RouterService | event_type | Cambio de status |
|---|---|---|
| `:rejected` | `status_changed` | → `cancelled` |
| `:interested` | `escalated` | → `escalated` |
| `:reschedule` | `tracking_triggered` | → `waiting_on_customer` |
| `:kbase` · `:tracking` · `:botseller` | `message_sent` | sin cambio |

---

## Cómo se crea un ticket — dos formas

### Forma 1: Automática (el bot)
Cuando llega un mensaje dentro de un `ContactTracking` activo, `Cases::OrchestratorService` verifica si hay un `CaseTicket` activo para ese contacto. Si no existe, lo crea con `ticket_type`, `ticket_priority` e `inbox_id` inferidos. Las reglas se evalúan de inmediato.

### Forma 2: Manual (agente desde el panel)
El agente presiona **[+ Crear ticket]** en el panel derecho. Se abre un modal con: Tipo, Título, Prioridad y Descripción. Al confirmar, `Cases::OrchestratorService` crea el ticket y `Cases::RuleEngineService` evalúa las reglas.

---

## UI — Puntos de entrada

```
ContactPanel.vue (panel derecho de conversación)
  ├── [botón] Seguimientos       ← ya existe
  ├── [botón] Google Calendar    ← ya existe
  └── [sección] Ticket asociado  ← NUEVO
        Si NO hay ticket activo:
          └── [+ Crear ticket] → modal (tipo, título, prioridad, descripción)
        Si HAY ticket activo:
          ├── Badge: SOPORTE · EN ATENCIÓN · Alta · SLA: 1h 45min
          ├── [Ver timeline] → historial de events
          └── [Cambiar estado ▼] → waiting_on_customer / resolved / cancelled

Sidebar izquierdo
  └── [nuevo] Gestor de Tickets  (/tickets/list)
        ├── Todos los tickets
        ├── Urgentes / SLA overdue   (filtro rápido)
        ├── Sin asignar              (filtro rápido)
        └── Por tipo

Panel de contacto
  └── Tickets históricos del contacto con status y fecha
```

**Badge por `sla_status`:** `on_time` → verde · `at_risk` → amarillo · `overdue` → rojo

---

## API Endpoints

```
GET    /api/v1/accounts/:id/ticket_cases                      # lista con filtros
POST   /api/v1/accounts/:id/ticket_cases                      # crear manual
GET    /api/v1/accounts/:id/ticket_cases/:id                  # detalle
PATCH  /api/v1/accounts/:id/ticket_cases/:id/transition       # cambiar status
PATCH  /api/v1/accounts/:id/ticket_cases/:id/assign           # asignar agente/equipo
GET    /api/v1/accounts/:id/ticket_cases/:id/ticket_events    # timeline del ticket

GET    /api/v1/accounts/:id/ticket_rules                      # lista reglas
POST   /api/v1/accounts/:id/ticket_rules                      # crear regla
PATCH  /api/v1/accounts/:id/ticket_rules/:id                  # editar regla
DELETE /api/v1/accounts/:id/ticket_rules/:id                  # eliminar regla

GET    /api/v1/accounts/:id/ticket_types                      # tipos de la cuenta
POST   /api/v1/accounts/:id/ticket_types                      # crear tipo
PATCH  /api/v1/accounts/:id/ticket_types/:id                  # editar tipo

GET    /api/v1/accounts/:id/ticket_priorities                 # prioridades de la cuenta
PATCH  /api/v1/accounts/:id/ticket_priorities/:id             # editar prioridad/SLA

GET    /api/v1/accounts/:id/ticket_settings                   # config de la cuenta
PATCH  /api/v1/accounts/:id/ticket_settings                   # actualizar config
```

**Filtros para `GET /ticket_cases`:** `?status=`, `?ticket_type_id=`, `?ticket_priority_id=`, `?sla_status=`, `?assignee_id=`, `?contact_id=`, `?origin=`, `?page=`, `?per_page=`

---

## Archivos a crear

### Backend — Migraciones (6 archivos)

| Archivo | Tabla |
|---|---|
| `db/migrate/..._create_ticket_cases.rb` | `ticket_cases` |
| `db/migrate/..._create_ticket_events.rb` | `ticket_events` |
| `db/migrate/..._create_ticket_rules.rb` | `ticket_rules` |
| `db/migrate/..._create_ticket_types.rb` | `ticket_types` |
| `db/migrate/..._create_ticket_priorities.rb` | `ticket_priorities` |
| `db/migrate/..._create_ticket_settings.rb` | `ticket_settings` |

### Backend — Modelos (6 archivos)

| Archivo | Modelo | Tabla |
|---|---|---|
| `app/models/case_ticket.rb` | `CaseTicket` | `ticket_cases` |
| `app/models/case_event.rb` | `CaseEvent` | `ticket_events` |
| `app/models/case_rule.rb` | `CaseRule` | `ticket_rules` |
| `app/models/case_type.rb` | `CaseType` | `ticket_types` |
| `app/models/case_priority.rb` | `CasePriority` | `ticket_priorities` |
| `app/models/case_settings.rb` | `CaseSettings` | `ticket_settings` |

### Backend — Servicios y Jobs

| Archivo | Función |
|---|---|
| `app/services/cases/orchestrator_service.rb` | find_or_create ticket |
| `app/services/cases/rule_engine_service.rb` | Motor de reglas |
| `app/services/cases/ticket_creator_service.rb` | Detecta @crear_ticket |
| `app/jobs/case_sla_monitor_job.rb` | Monitor de SLA cron 15min |

### Backend — Controladores

| Archivo | Función |
|---|---|
| `app/controllers/api/v1/accounts/ticket_cases_controller.rb` | CRUD + transition + assign |
| `app/controllers/api/v1/accounts/ticket_events_controller.rb` | Index (timeline) |
| `app/controllers/api/v1/accounts/ticket_rules_controller.rb` | CRUD |
| `app/controllers/api/v1/accounts/ticket_types_controller.rb` | CRUD |
| `app/controllers/api/v1/accounts/ticket_priorities_controller.rb` | Index + update |
| `app/controllers/api/v1/accounts/ticket_settings_controller.rb` | Show + update |

### Backend — Modificados

| Archivo | Qué agregar |
|---|---|
| `app/jobs/contact_tracking_response_analyzer_job.rb` | Hook `Cases::OrchestratorService` con rescue |
| `config/routes.rb` | Rutas de todos los recursos ticket_* |
| `config/sidekiq.yml` | Cron `CaseSlaMonitorJob` cada 15min |

### Frontend — Fase 3 (panel derecho)

| Archivo | Función |
|---|---|
| `conversation/CaseTicketPanel.vue` | Sección ContactPanel — badge + botones |
| `conversation/CaseTicketModal.vue` | Modal de creación |
| `conversation/CaseTimeline.vue` | Timeline de events |

### Frontend — Fase 4 (vista dedicada)

| Archivo | Función |
|---|---|
| `gestorTickets/gestorTickets.routes.js` | Ruta `/tickets/list` |
| `gestorTickets/Index.vue` | Vista principal — lista con filtros y badges SLA |
| `gestorTickets/TicketDetail.vue` | Detalle + timeline |
| `gestorTickets/TicketRules.vue` | Gestión de reglas |
| `gestorTickets/TicketTypes.vue` | Gestión de tipos por cuenta |
| `gestorTickets/TicketPriorities.vue` | Gestión de prioridades y SLA por cuenta |
| `gestorTickets/api.js` | Llamadas al backend |
| `i18n/locale/es/gestorTickets.js` | Traducciones ES |
| `i18n/locale/en/gestorTickets.js` | Traducciones EN |

---

## Convención de identificación en código

- **Archivos nuevos:** encabezado `# ====... @tickets_cases`
- **Líneas en archivos existentes:** comentario inline `# @tickets_cases`

---

## Fases de implementación

| Fase | Contenido | Días est. |
|---|---|---|
| **0** | Migraciones + modelos + seeds de defaults | 2-3 |
| **1** | Servicios + jobs + integración bot | 2-3 |
| **2** | API REST (controladores + rutas) | 2 |
| **3** | Panel derecho conversación (ContactPanel) | 2-3 |
| **4** | Vista "Gestor de Tickets" en sidebar | 3-4 |
| **5** | Métricas y reportes | 2-3 |

**Dependencias:**
```
FASE 0 → FASE 1 → FASE 3
FASE 0 → FASE 2 → FASE 4
FASE 3 + FASE 4 → FASE 5
```

---

## FASE 0 — Detalle de aceptación

### Seeds automáticos al crear cuenta

Al crear una cuenta nueva, se deben seedear:
- 5 `CaseType` con los slugs por defecto
- 4 `CasePriority` con los SLA por defecto
- 1 `CaseSettings` vacío (labels = {})

### Criterio de aceptación

- Las 6 migraciones corren sin error con `rails db:migrate`
- Los modelos responden en `rails console`:
  - Crear un `CaseTicket` con `ticket_priority` de slug `urgent` asigna `first_response_time_target: 30` automáticamente
  - `transition!` lanza error en transiciones inválidas (ej: `closed → open`)
  - `CaseEvent` se crea asociado al ticket con `event_type` y `origin` correctos
  - `CaseRule` acepta `conditions` y `actions` como arrays JSON
  - `CasePriority` permite editar `sla_response_minutes` y el job lo toma de inmediato
- Tests de modelo cubren: transiciones inválidas, SLA defaults, validaciones de presencia

---

## Flujos de referencia rápida

### Flujo A — Problema técnico por WhatsApp (automático)
```
Mensaje → ContactTrackingResponseAnalyzerJob
→ Hook: ¿hay ticket activo? NO → crea CaseTicket (type: support, priority: high, origin: inbox)
→ RuleEngine: assign_team "Soporte", change_priority urgent si "no funciona"
→ RouterService: :tracking → KBase busca solución → responde al cliente
→ CaseEvent: message_received + message_sent registrados
→ SLA activo: 30min first_response_time_target (urgent)
```

### Flujo B — Cotización → seguimiento comercial
```
Agente envía cotización → CaseTicket (type: commercial) → status: waiting_on_customer
→ OrchestratorService crea ContactTracking (D+1, D+3, D+5)
→ Cliente responde "me interesa" → RouterService: :interested
→ CaseTicket: status → escalated → assign_team Comercial
→ CaseEvent: escalated + assigned + notificación al asesor
```

### Flujo C — SLA vencido → escalado automático
```
CaseSlaMonitorJob (cada 15min): detecta ticket urgent sin first_response_at > 30min
→ CaseEvent: sla_overdue registrado
→ RuleEngine: escalate + assign_team "Soporte Senior" + notify_agent supervisor
→ CaseTicket: status → escalated, sla_status → overdue, badge en rojo
```

### Flujo D — Agente crea ticket manual
```
Agente abre conversación → ContactPanel → [+ Crear ticket]
→ Modal: type=support, title="Error al guardar cotización", priority=high
→ OrchestratorService.create → RuleEngineService evalúa reglas
→ Panel: badge "SOPORTE · EN ATENCIÓN · Alta · SLA: 1h 55min"
→ Agente resuelve → [Cambiar estado → Resolved]
→ 72h después: cierre automático por CaseSlaMonitorJob
```

### Flujo E — KBase no resuelve → @crear_ticket
```
Mensaje → :kbase/:tracking → KnowledgeBaseResponseService → sin resultados
→ Cases::TicketCreatorService detecta @crear_ticket en complementary_prompt
→ Crea CaseTicket (type: support, origin: bot, inbox_id: conversación.inbox_id)
→ RuleEngine evalúa reglas → asignación automática
→ Responde al cliente: "Tu caso fue registrado, un asesor te contactará"
→ CaseEvent: ticket_created registrado
```

---

## Notas importantes

- Tablas, columnas y enums siempre en **inglés** — igual que Chatwoot.
- El `ContactTracking` NO es el ticket — es una **acción automatizada sobre el ticket**.
- `Conversation` es el contenedor de mensajes — `CaseTicket` es el contenedor del problema.
- `CaseRuleEngine` evalúa en cascada por `position`. Con `continue_on_match: false` (default), para en el primer match.
- Auto-cierre: 72h después de status `resolved` sin actividad → `closed`.
- `origin = inbox` + `inbox_id` reemplaza los valores `whatsapp/web/email` del enum v1. El tipo de canal se obtiene via `ticket.inbox.channel_type`.
- `ticket_type_id` y `ticket_priority_id` son configurables por cuenta — no hardcodear sus IDs en lógica de negocio; usar `.slug` para comparaciones en reglas.
- Todo el código del Gestor de Tickets va en `rescue` en el hook del job — un fallo nunca rompe el flujo de atención existente.
