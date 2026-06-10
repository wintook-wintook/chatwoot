# Gestor de Tickets — Fase 4: Vista Dedicada en el Sidebar

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo  
**Depende de:** Fases 0–3

---

## Qué se implementó

Fase 4 agrega el Gestor de Tickets como sección propia en la navegación principal de Chatwoot: un icono en el sidebar izquierdo y tres vistas dedicadas (lista, detalle, reglas). También se extendió el store Vuex con estado para listado y reglas.

---

## Archivos creados

| Archivo | Función |
|---------|---------|
| `routes/dashboard/gestorTickets/routes.js` | 3 rutas Vue Router |
| `components/layout/config/sidebarItems/gestorTickets.js` | Config del menú secundario |
| `views/gestorTickets/Index.vue` | Lista de tickets con filtros rápidos |
| `views/gestorTickets/TicketDetail.vue` | Detalle + timeline + cambio de estado |
| `views/gestorTickets/TicketRules.vue` | CRUD de reglas de automatización |
| `api/caseRules.js` | Cliente HTTP para case_rules |

## Archivos modificados

| Archivo | Qué se agregó |
|---------|---------------|
| `routes/dashboard/dashboard.routes.js` | Import + spread de `gestorTicketsRoutes` |
| `config/sidebarItems/primaryMenu.js` | Icono `task-list-square-ltr` en el sidebar izquierdo |
| `config/default-sidebar.jsx` | `gestorTickets(accountId)` en `secondaryMenu` |
| `store/modules/caseTickets.js` | Estado `ticketsList`, `ticketsMeta`, `rules`; actions `fetchTickets`, `fetchRules`, `createRule`, `updateRule`, `deleteRule` |
| `store/mutation-types.js` | 4 constantes nuevas: `SET_CASE_TICKETS_LIST`, `SET_CASE_TICKETS_META`, `SET_CASE_RULES`, `SET_CASE_RULES_UI_FLAG` |
| `i18n/locale/es/gestorTickets.json` | Claves `SIDEBAR`, `LIST`, `RULES` |
| `i18n/locale/en/gestorTickets.json` | Claves `SIDEBAR`, `LIST`, `RULES` |

---

## Rutas

```
/accounts/:accountId/tickets           → gestorTickets_index   (agente + admin)
/accounts/:accountId/tickets/rules     → gestorTickets_rules   (solo admin)
/accounts/:accountId/tickets/:id       → gestorTickets_detail  (agente + admin)
```

El orden en `routes.js` es importante: `/tickets/rules` va **antes** de `/tickets/:id` para evitar que "rules" sea interpretado como un ID numérico.

---

## `Index.vue` — Lista de tickets

### Filtros rápidos (botones pill)

| Filtro | Param enviado a la API |
|--------|----------------------|
| Todos | (sin filtro) |
| SLA vencido | `sla_status=overdue` |
| Sin asignar | `assignee_id=null` |

### Filtros por tipo (pills secundarios)

Todos los tipos / Soporte / Comercial / Implementación

### Columnas en cada fila

- Punto SLA (verde/amarillo/rojo según `sla_status`)
- Badges: tipo de caso + prioridad (con color)
- Título + status actual
- Tiempo SLA restante (calculado client-side)
- Fecha de creación
- Chevron → navega a `TicketDetail`

### Paginación

Se muestra si `meta.total_pages > 1`. Cada cambio de página redispara `fetchTickets`.

---

## `TicketDetail.vue` — Detalle del ticket

Accesible desde la lista haciendo click en una fila o navegando a `/tickets/:id`.

### Secciones

1. **Header** — badges (tipo, estado, prioridad, SLA), título, descripción, botón "Cambiar estado ▾"
2. **Información** — grid 2 columnas con tipo, prioridad, estado, SLA, fecha creación, fecha resolución
3. **Historial** — timeline idéntico al `CaseTimeline` de Fase 3 pero inline (sin modal): puntos coloreados por tipo de evento, descripción del payload, actor y timestamp

### Cambio de estado

El dropdown "Cambiar estado ▾" muestra las transiciones válidas del ticket (`can_transition_to`). Al seleccionar:
1. Llama `transitionTicket({ ticketId, status })`
2. Refresca la lista con `fetchTickets()`
3. El store actualiza el ticket en `activeTickets` si está en cache del panel

---

## `TicketRules.vue` — Gestión de reglas

Vista disponible solo para administradores. Permite crear, activar/desactivar, editar y eliminar reglas de automatización.

### Visualización de cada regla

```
[#0]  Soporte → Equipo Soporte           [toggle] [✏️] [🗑]
SI: case_type eq support  → ENTONCES: assign_team: Soporte Técnico
```

- El número indica la `position` (orden de evaluación)
- Las tarjetas inactivas se muestran con opacidad reducida
- El toggle activa/desactiva sin abrir el modal

### Modal crear/editar

Campos del formulario:
- Nombre (obligatorio)
- Descripción
- Activa (checkbox)
- Continuar si coincide (checkbox)
- Posición (número)
- Condiciones (textarea JSON) — validación client-side antes de enviar
- Acciones (textarea JSON) — validación client-side antes de enviar

El JSON se valida con `JSON.parse` y se verifica que sea un `Array`. Si hay error de sintaxis, se muestra debajo del textarea sin bloquear el formulario.

---

## Navegación en el sidebar

### Primary menu (iconos)

```
Icono: task-list-square-ltr
Label (i18n): CASE_TICKETS.SIDEBAR.PRIMARY_LABEL → "Tickets"
Route: gestorTickets_index
```

### Secondary menu (cuando el primary está activo)

```
[📋] Todos los tickets   → gestorTickets_index
[⚙️] Reglas              → gestorTickets_rules
```

---

## Store extendido (Fase 4)

### Nuevo estado

```js
ticketsList: [],          // tickets para Index.vue
ticketsMeta: {},          // { current_page, total_pages, total_count, ... }
rules: [],                // reglas de automatización
rulesUiFlags: { isFetching, isSaving, isDeleting }
```

### Nuevos getters

| Getter | Uso |
|--------|-----|
| `getTicketsList` | Array de tickets para la lista |
| `getTicketsMeta` | Metadata de paginación |
| `getTicketById(id)` | Busca en `ticketsList` por ID |
| `getRules` | Array de reglas |
| `getRulesUIFlags` | Flags de carga para reglas |

### Nuevas actions

| Action | Descripción |
|--------|-------------|
| `fetchTickets(filters)` | GET /case_tickets con filtros opcionales |
| `fetchRules()` | GET /case_rules |
| `createRule(payload)` | POST /case_rules |
| `updateRule({ id, ...payload })` | PATCH /case_rules/:id |
| `deleteRule(id)` | DELETE /case_rules/:id |

---

## Claves i18n nuevas en `CASE_TICKETS`

```json
"SIDEBAR": {
  "PRIMARY_LABEL": "Tickets",
  "TITLE": "Gestor de Tickets",
  "ALL_TICKETS": "Todos los tickets",
  "RULES": "Reglas de automatización"
},
"LIST": {
  "LOADING": "Cargando tickets...",
  "EMPTY": "No hay tickets que coincidan con los filtros"
},
"RULES": {
  "CREATE_BUTTON": "+ Nueva regla",
  "CREATE_TITLE": "Crear regla",
  "EDIT_TITLE": "Editar regla",
  "EMPTY": "Sin reglas configuradas. Las reglas automatizan asignaciones y escalados."
}
```

---

## Resumen de la navegación completa implementada

```
Sidebar izquierdo (primaryMenu)
  └── [task-list-square-ltr] Tickets

Panel secundario (cuando Tickets está activo)
  ├── Todos los tickets  → /accounts/:id/tickets
  └── Reglas             → /accounts/:id/tickets/rules

Desde la lista:
  └── Click en fila      → /accounts/:id/tickets/:id  (detalle + timeline)
```
