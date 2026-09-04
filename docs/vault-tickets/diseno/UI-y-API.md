---
titulo: UI en el dashboard + API endpoints
tipo: diseño
tags: [tickets, ui, api, endpoints]
---

## Integración en el dashboard de Chatwoot (UI)

### Panel derecho de la conversación — ContactPanel.vue

```
ContactPanel.vue
  ├── [botón] Seguimientos       ← ya existe
  ├── [botón] Google Calendar    ← ya existe
  ├── [sección] Ticket asociado  ← NUEVO @tickets_cases
  │     Si NO hay ticket activo:
  │       └── [+ Crear ticket] → modal (case_type, title, priority, description)
  │     Si HAY ticket activo:
  │       ├── Badge: SUPPORT · IN_PROGRESS · High · SLA: 1h 45min
  │       ├── [Ver timeline] → historial de events
  │       └── [Cambiar estado ▼] → waiting_on_customer / resolved / cancelled
  ├── Acciones (agente, equipo, prioridad)
  └── ...
```

**Badge visual por sla_status:**
- `on_time` → verde · `at_risk` → amarillo · `overdue` → rojo

### Vista "Gestor de Tickets" en el sidebar izquierdo

```
Sidebar izquierdo
  └── [nuevo] Gestor de Tickets  ← /tickets/list  @tickets_cases
        ├── Todos los tickets
        ├── Urgentes / SLA overdue   (filtro rápido)
        ├── Sin asignar              (filtro rápido)
        └── Por tipo (Support / Commercial / Implementation / ...)
```

### Panel de contacto

Muestra todos los tickets históricos del contacto con status y fecha.

### Los 3 puntos de entrada

| Punto de entrada | Qué muestra | Para quién |
|-----------------|-------------|-----------|
| **Panel derecho de conversación** | Ticket vinculado — crear / ver / cambiar status | Agente atendiendo |
| **Vista "Gestor de Tickets"** (sidebar) | Todos los tickets de la cuenta con filtros | Supervisores, equipo |
| **Panel de contacto** | Tickets históricos del contacto | Agente revisando historial |

---

## API Endpoints

```
GET    /api/v1/accounts/:id/case_tickets                     # lista con filtros
POST   /api/v1/accounts/:id/case_tickets                     # crear manual
GET    /api/v1/accounts/:id/case_tickets/:id                 # detalle
PATCH  /api/v1/accounts/:id/case_tickets/:id/transition      # cambiar status
PATCH  /api/v1/accounts/:id/case_tickets/:id/assign          # asignar agente/equipo
GET    /api/v1/accounts/:id/case_tickets/:id/case_events     # timeline del ticket

GET    /api/v1/accounts/:id/case_rules                       # lista reglas
POST   /api/v1/accounts/:id/case_rules                       # crear regla
PATCH  /api/v1/accounts/:id/case_rules/:id                   # editar regla
DELETE /api/v1/accounts/:id/case_rules/:id                   # eliminar regla
```

**Filtros para `GET /case_tickets`:** `?q=` (folio/título/descripción/**nombre de contacto** vía `left_joins(:contact)` + ILIKE), `?status=`, `?case_type_id=`, `?priority=`, `?sla_status=`, `?assignee_id=` (acepta `null`/`none`/`unassigned`/`0` → `IS NULL`), `?contact_id=`, `?date_from=` / `?date_to=` (rango sobre `created_at`, formato `YYYY-MM-DD`), `?sort_by=` (whitelist `created_at|priority|sla_status|status`), `?sort_order=` (`asc|desc`, default desc), `?page=`, `?per_page=` (default 25, máx 100).

> **Vistas guardadas** (`feat/tickets_filtros`): ese mismo juego de filtros se puede
> guardar con nombre y compartir con la cuenta, reusando `custom_filters` con
> `filter_type: case_ticket`. Ver [[Vistas-guardadas]].

> Implementado en métodos privados del controller: `apply_search`, `apply_assignee`, `apply_date_range`, `apply_sort` (constante `SORTABLE_COLUMNS`). El orden interpola columna/dirección desde whitelists → seguro con `Arel.sql`. El JOIN a `contacts` es 1:1 (`belongs_to`) → no duplica filas, sin `distinct`.

---



## 🔗 Relacionado
- [[Rutas-Metricas-Builder]] · [[Archivos-reales]]
