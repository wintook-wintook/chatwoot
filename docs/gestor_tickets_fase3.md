# Gestor de Tickets — Fase 3: Panel Derecho de Conversación (Frontend)

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo  
**Depende de:** Fase 0 (modelos), Fase 1 (servicios), Fase 2 (API REST)

---

## Qué se implementó

Fase 3 es el primer frontend visible del Gestor de Tickets. Agrega una sección "Ticket asociado" en el panel derecho de cada conversación (`ContactPanel.vue`). El agente puede ver el ticket activo del contacto, crear uno nuevo, cambiar su estado y ver el historial de eventos.

---

## Archivos creados

| Archivo | Función |
|---------|---------|
| `app/javascript/dashboard/api/caseTickets.js` | Cliente HTTP account-scoped |
| `app/javascript/dashboard/store/modules/caseTickets.js` | Vuex store (estado, getters, actions, mutations) |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTicketPanel.vue` | Sección del panel derecho |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTicketModal.vue` | Modal de creación de ticket |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTimeline.vue` | Modal timeline de eventos |
| `app/javascript/dashboard/i18n/locale/es/gestorTickets.json` | Traducciones español |
| `app/javascript/dashboard/i18n/locale/en/gestorTickets.json` | Traducciones inglés |

## Archivos modificados

| Archivo | Qué se agregó |
|---------|---------------|
| `app/javascript/dashboard/store/mutation-types.js` | 3 constantes: `SET_CASE_TICKET_UI_FLAG`, `SET_ACTIVE_CASE_TICKET`, `SET_CASE_TICKET_EVENTS` |
| `app/javascript/dashboard/store/index.js` | Import y registro del módulo `caseTickets` |
| `app/javascript/dashboard/i18n/locale/es/index.js` | Import `gestorTickets.json` |
| `app/javascript/dashboard/i18n/locale/en/index.js` | Import `gestorTickets.json` |
| `ContactPanel.vue` | Import + registro + uso de `CaseTicketPanel` |

---

## Qué ve el agente

### Sin ticket activo

```
┌────────────────────────────────────┐
│  [🎫 + Crear ticket]               │  ← botón ancho, color secondary
└────────────────────────────────────┘
```

Al hacer click abre `CaseTicketModal` con el formulario de creación.

### Con ticket activo

```
┌────────────────────────────────────┐
│  [SOPORTE] [EN PROGRESO] [Alta]    │  ← badges con colores por tipo/prioridad
│  [SLA: 1h 45min]                   │  ← badge verde/amarillo/rojo según sla_status
│                                    │
│  Error al iniciar sesión           │  ← título del ticket
│                                    │
│  [Ver historial]  [Cambiar estado▼]│  ← botones de acción
└────────────────────────────────────┘
```

Al hacer click en "Cambiar estado", aparece un menú desplegable con las transiciones válidas desde el status actual (viene del campo `can_transition_to` de la API).

Al hacer click en "Ver historial", abre `CaseTimeline` con todos los eventos del ticket en orden cronológico.

---

## `CaseTicketPanel.vue`

### Props

| Prop | Tipo | Descripción |
|------|------|-------------|
| `contactId` | Number/String | ID del contacto |
| `conversationId` | Number/String | ID de la conversación |

### Comportamiento

- **mounted**: dispara `fetchActiveTicket({ contactId })` para cargar el ticket del store
- **watch `contactId`**: vuelve a cargar cuando cambia el contacto (navegación entre conversaciones)
- **SLA en tiempo real**: `slaText` calcula los minutos restantes en el cliente basándose en `created_at` del ticket y el target en minutos
- **Transiciones**: el menú "Cambiar estado" solo muestra las opciones válidas según `can_transition_to` (campo incluido por la API)
- **Colores badge**: `sla-on_time` → verde · `sla-at_risk` → amarillo · `sla-overdue` → rojo
- **Colores prioridad**: `priority-low` → gris · `priority-medium` → azul · `priority-high` → amarillo · `priority-urgent` → rojo

### Integración en ContactPanel

Se agrega después del botón de seguimientos, antes del bloque `<Draggable>`:

```vue
<!-- @tickets_cases: Sección Ticket asociado -->
<CaseTicketPanel
  v-if="contact.id"
  :contact-id="contact.id"
  :conversation-id="conversationId"
/>
```

---

## `CaseTicketModal.vue`

Modal de creación de ticket. Props: `show`, `contactId`, `conversationId`.

**Campos del formulario:**

| Campo | Tipo | Valores |
|-------|------|---------|
| Tipo de caso | `<select>` | support, commercial, implementation, internal_tracking, system_incident |
| Título | `<input>` | Texto libre, máx 255 chars, requerido |
| Prioridad | `<select>` | low, medium, high, urgent (default: medium) |
| Descripción | `<textarea>` | Opcional |

Al confirmar:
1. Llama a `store.dispatch('caseTickets/createTicket', payload)`
2. El store llama a `POST /api/v1/accounts/:id/case_tickets`
3. Actualiza el ticket activo en el store (el panel muestra la tarjeta inmediatamente)
4. Muestra toast de éxito o error
5. Emite `@created` y `@close`

---

## `CaseTimeline.vue`

Modal con el historial de eventos del ticket. Props: `show`, `ticketId`.

Al abrirse llama a `store.dispatch('caseTickets/fetchEvents', { ticketId })`.

**Por cada evento muestra:**
- **Punto de color** según `event_type` (azul=creado, verde=resuelto, rojo=vencido/escalado, amarillo=en riesgo)
- **Label** del tipo de evento (traducida vía `CASE_TICKETS.EVENT_TYPES.*`)
- **Detalle del payload** si aplica: `"Abierto → En progreso"`, o el contenido del mensaje
- **Meta**: nombre del actor y fecha/hora

---

## Vuex Store `caseTickets`

### Estado

```js
{
  activeTickets: { [contactId]: CaseTicket | null },
  events: { [ticketId]: CaseEvent[] },
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isTransitioning: false,
    isFetchingEvents: false,
  }
}
```

### Getters

| Getter | Uso |
|--------|-----|
| `getActiveTicket(contactId)` | Ticket activo del contacto |
| `getTicketEvents(ticketId)` | Eventos del ticket |
| `getUIFlags` | Flags de loading |

### Actions

| Action | Descripción |
|--------|-------------|
| `fetchActiveTicket({ contactId })` | GET /case_tickets?contact_id=X — filtra client-side el primer no cerrado/cancelado |
| `createTicket(payload)` | POST /case_tickets |
| `transitionTicket({ ticketId, contactId, status, reason })` | PATCH /case_tickets/:id/transition |
| `fetchEvents({ ticketId })` | GET /case_tickets/:id/case_events |

### "Ticket activo"

El store fetch pide los últimos 10 tickets del contacto y toma el primero que no esté `closed` ni `cancelled`. Esto evita mostrar tickets históricos cerrados como si fueran el activo.

---

## Claves i18n — namespace `CASE_TICKETS`

| Clave | ES | EN |
|-------|----|----|
| `SECTION_TITLE` | Ticket | Ticket |
| `CREATE_BUTTON` | + Crear ticket | + Create ticket |
| `VIEW_TIMELINE` | Ver historial | View history |
| `CHANGE_STATUS` | Cambiar estado | Change status |
| `SLA_OVERDUE` | SLA vencido | SLA overdue |
| `TYPES.*` | Soporte / Comercial / ... | Support / Commercial / ... |
| `STATUSES.*` | Abierto / En progreso / ... | Open / In progress / ... |
| `PRIORITIES.*` | Baja / Media / Alta / Urgente | Low / Medium / High / Urgent |
| `EVENT_TYPES.*` | 17 tipos de evento | 17 event types |

---

## Siguiente fase

**Fase 4 — Vista dedicada "Gestor de Tickets" en el sidebar izquierdo:**

```
Sidebar izquierdo
  └── [nuevo] Gestor de Tickets  ← /tickets/list
        ├── Todos los tickets
        ├── Urgentes / SLA overdue   (filtro rápido)
        ├── Sin asignar              (filtro rápido)
        └── Por tipo (Support / Commercial / ...)
```

Archivos:
- `gestorTickets/gestorTickets.routes.js` — ruta `/tickets/list`
- `gestorTickets/Index.vue` — vista principal con filtros y badges SLA
- `gestorTickets/TicketDetail.vue` — detalle + timeline
- `gestorTickets/TicketRules.vue` — gestión de reglas de automatización
