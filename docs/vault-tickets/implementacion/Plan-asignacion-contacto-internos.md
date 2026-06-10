---
titulo: Plan — Asignación manual · Ticket desde contacto · Tickets internos
tipo: plan
fase: pendiente
tags: [tickets, plan, asignacion, contacto, internos, notificaciones]
---

# Plan: Asignación manual · Ticket desde contacto · Tickets internos

> Plan de diseño (3 features nuevas). **Documento — no implementado todavía.**
> Decisiones abiertas ya resueltas con la mejor opción (ver "Decisiones cerradas").
> Relacionado: [[Modelo-de-datos]] · [[Servicios-Directiva-Integracion]] ·
> [[UI-y-API]] · [[Archivos-reales]] · [[Trampas]]

## Contexto / hallazgos del código (verificados)

- **Asignar a agente/equipo:** backend completo (`PATCH /case_tickets/:id/assign`,
  `controller:190-215`, registra `case_event :assigned`) y API client JS
  (`caseTickets.js:33`). **Falta cablear la UI** — no hay action en el store ni
  botón que llame a `assign`. Hoy lo único manual es el escalamiento.
- **Ticket de contacto sin conversación:** el modelo ya lo permite
  (`contact_id NOT NULL`, `conversation_id NULLABLE`). El `CaseTicketModal` ya
  acepta `conversationId` con default `null` y envía `conversation_id || undefined`.
  Solo falta **montarlo en la ficha de contacto** (`ContactInfoPanel.vue`).
- **Tickets internos:** hueco de diseño — el modelo es contacto-céntrico
  (`contact_id NOT NULL`). Un ticket agente→agente no tiene cliente.
- **`origin` es enum entero normal** (`whatsapp:0…manual:4`, `case_ticket.rb:113`)
  → agregar `internal: 5` al final es seguro (NO es el bitfield del feature flag).
- **Notificaciones nativas:** existe `Notification` + `NotificationBuilder`
  (`pattr: notification_type!, user!, account!, primary_actor!, secondary_actor`).
  ⚠️ `PRIMARY_ACTORS = ['Conversation'].freeze` y `NOTIFICATION_TYPES` es enum
  entero → para notificar tickets hay que **append** `case_ticket_assignment` y
  agregar `CaseTicket` a `PRIMARY_ACTORS`. El builder consulta
  `notification_settings.email_<type>?/push_<type>?` (bitfield FlagShihTzu) →
  el nuevo flag también va **al final**.

---

## ✅ Decisiones cerradas (la mejor opción)

| Tema | Decisión | Por qué |
|------|----------|---------|
| **Fase A — agente vs equipo** | Coexisten: un ticket puede tener **equipo (cola)** Y **agente (persona)** a la vez, como las conversaciones de Chatwoot. No mutuamente excluyentes. | Es el patrón nativo del producto; cola = responsable, agente = quien lo trabaja. |
| **Fase A — des-asignación** | Sí. Cada dropdown lleva "— Sin asignar —" / "— Sin equipo —" y limpia su campo de forma independiente. | UX esperada; un ticket debe poder volver a "Sin asignar". |
| **Fase A — `assignee_type`** | Derivado, no manual: `assignee` presente → `:agent`; sino `team` presente → `:team`; sino `:bot`. | Una sola fuente de verdad, sin estados inconsistentes. |
| **C5 — SLA en internos** | Sí. Reutiliza la matriz por prioridad para `resolution_time_target`. Se omite la semántica de `first_response` (no hay cliente que responda). | El trabajo interno tampoco debe caerse; reutilizar evita config nueva ahora. |
| **C5 — Reglas (RuleEngine)** | Sí corren en internos. Las condiciones de cliente (`message_content`) simplemente no hacen match. Sin casos especiales. | Menos ramas, mismo motor; `assign_agent`/`change_priority` son útiles igual. |
| **C5 — Notificación al asignado** | Sí, **nativa** (`Notification` type `case_ticket_assignment`). Aplica a Fase A (cualquier asignación manual) y Fase C (alta/asignación interna). | Integra campana + email + push del producto; es "lo mejor", no un parche. |

---

## Fase A — Asignación manual a agente / equipo (UI + pulido backend) ✅ HECHA (bell)

> **Estado:** núcleo + notificación in-app implementados y verificados en navegador
> (Puppeteer, cuenta 2): agente + equipo coexisten, des-asignación, `assignee_type`
> derivado, evento, y **notificación nativa en la campana** que enruta al ticket.
> Ver [[Historial-de-implementacion]] (entradas Fase A núcleo + parte 2).
> **Diferido (no bloqueante):** delivery email/push (flags off por defecto) +
> checkbox en `NotificationPreferences.vue`. La campana ya funciona.


```
TicketDetail.vue                 store/caseTickets.js          API
┌────────────────────┐  dispatch ┌──────────────────┐  PATCH  ┌──────────────┐
│ [Asignar]          │──────────▶│ assignTicket()   │────────▶│ /:id/assign  │
│  Equipo:  [····▼]  │  (nueva)  │  (NUEVA action)  │ (mejora)│ + notifica   │
│  Agente:  [····▼]  │           └──────────────────┘         └──────────────┘
│  (— Sin asignar —) │
└────────────────────┘   equipo + agente coexisten, c/u se limpia aparte
```

| Paso | Archivo | Cambio |
|------|---------|--------|
| A1 | `controller#assign` | Aceptar `assignee_id` **y/o** `team_id`; `null/none/0` limpia. Derivar `assignee_type`. Encolar notificación al nuevo `assignee`. |
| A2 | `store/modules/caseTickets.js` | Action `assignTicket({ ticketId, contactId, assigneeId, teamId })` → `caseTicketsAPI.assign` → `SET_ACTIVE_CASE_TICKET`. |
| A3 | `views/gestorTickets/TicketDetail.vue` | Tarjeta "Asignar": dropdown **Equipo** (`teams/getTeams`, ya en `:318`) + **Agente** (`agents/getAgents`), ambos con opción vacía. |
| A4 | `components/contacts/CaseTicket/CaseTicketPanel.vue` (opcional) | Mismo control en el panel derecho de la conversación. |
| A5 | `i18n/{es,en}/gestorTickets.json` | Claves `ASSIGN.*`. |

---

## Fase B — Crear ticket desde la ficha de contacto (sin conversación) ✅ HECHA

> **Estado:** implementada y verificada en navegador (Puppeteer, cuenta 2).
> Ver [[Historial-de-implementacion]] (entrada Fase B).

**Backend: 0 cambios.** Modal y modelo ya soportan `conversation_id = null`.

```
ANTES:  ContactPanel.vue (conv.)   → CaseTicketPanel → modal(contactId, conversationId)
AHORA: +ContactInfoPanel.vue (ficha)→ CaseTicketPanel → modal(contactId, conversationId=null ✅)
```

| Paso | Archivo | Cambio |
|------|---------|--------|
| B1 | `routes/dashboard/contacts/components/ContactInfoPanel.vue` | Montar `CaseTicketPanel`/`CaseTicketModal` con `:contactId`, **sin** `conversationId`. |
| B2 | Verificar | `getContactTickets(contactId)` carga bien fuera de la conversación. |

→ La más barata. Resuelve: contacto sin conversación → ticket igual (`conversation_id` queda `null`).

---

## Fase C — Tickets internos (agente → agente)

Decisión de modelo: `contact_id` nullable + `requester_id` + `origin: internal`.

```
EXTERNO (hoy):   contact(cliente) ─▶ CaseTicket ─assignee─▶ agente
INTERNO (nuevo): requester(agente A) ─▶ CaseTicket ─assignee─▶ agente B
                 contact_id = NULL · origin = internal
```

### C1 · Migración (SIEMPRE al final, sin reordenar)
```ruby
change_column_null :case_tickets, :contact_id, true            # antes NOT NULL
add_reference :case_tickets, :requester,
              foreign_key: { to_table: :users }, null: true     # solicitante interno
```

### C2 · Modelo `case_ticket.rb`
```ruby
enum origin: { whatsapp:0, web:1, email:2, bot:3, manual:4, internal:5 }  # append seguro
belongs_to :contact,   optional: true        # antes implícito required
belongs_to :requester, class_name: 'User', optional: true
validate :contact_or_requester_present       # externo→contact, interno→requester
scope :internal, -> { where(origin: :internal) }
```

### C3 · Orchestrator + Controller
```
OrchestratorService.create_internal(requester:, assignee:, title:, ...)
  └─ contact: nil, origin: :internal, assignee_type: :agent

controller#create:  if origin == 'internal'
                       requester = current_user; contact = nil
                     else
                       contact = account.contacts.find(...)   # rama actual
```
⚠️ Blindaje: `find_active_ticket` y el hook del bot
(`ContactTrackingResponseAnalyzerJob`) **solo corren en contexto de conversación**
→ siempre hay contacto, no se rompen. Los scopes de métricas que hacen
`left_joins(:contact)` ya toleran `NULL`.

### C4 · Notificación (compartida con Fase A)
```
NOTIFICATION_TYPES  += { case_ticket_assignment: 10 }   # append
PRIMARY_ACTORS      += ['CaseTicket']
notification_settings: nuevo flag email/push al FINAL del bitfield (FlagShihTzu)
NotificationBuilder.new(notification_type: :case_ticket_assignment,
                        user: assignee, account:, primary_actor: ticket).perform
```

### C5 · Frontend
| Archivo | Cambio |
|---------|--------|
| `views/gestorTickets/Index.vue` | Punto de entrada **[+ Ticket interno]** (no cuelga de un contacto) + filtro/badge `internal`. |
| `CaseTicketModal` (adaptar o variante) | Modal interno: **Asignar a (agente)**, título, tipo, prioridad, descripción. `requester = current_user`. |
| `views/gestorTickets/TicketDetail.vue` | Mostrar **"Solicitante: Agente A"** en vez del bloque de contacto cuando `origin === 'internal'`. |
| `i18n/{es,en}/gestorTickets.json` | Claves `INTERNAL.*`. |

---

## Orden sugerido

```
  Fase B  ──▶  Fase A  ──▶  Fase C
 (gratis)   (UI + notif)  (modelo + UI + notif)
```
B y A no tocan schema; C concentra el diseño nuevo. La notificación nativa
(C4) conviene construirla en A y reutilizarla en C.

## Pendiente al implementar (recordar)
- Tras editar enums/migraciones: correr migración y `touch tmp/restart.txt`.
- Verificar en navegador (account 2) según [[Pruebas-en-browser]].
- Añadir entrada a [[Historial-de-implementacion]] y gotchas nuevos a [[Trampas]].
