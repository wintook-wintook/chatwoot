# Plan — Notas internas (bitácora del ticket)

> Estado: ✅ **P1 implementado y verificado en navegador** (2026-07-21). Falta la
> **Fase 2** (nota al cambiar estado, §5). Changelog en [[Historial-de-implementacion]].
> ⚠️ Trampa encontrada al implementar: `add_note` debe ir en el `only:` del
> `before_action :set_ticket`; si no, `@ticket` es `nil` y el `rescue` del
> controlador disfraza el `NoMethodError` de 422.
> Relacionado: [[Comparativa-Agent-Panel-osTicket]] · [[Plan-Practicidad-osTicket]] · [[Pendiente]]

## 1. Por qué

En osTicket la bitácora de "qué estoy haciendo" vive **dentro del thread** del ticket
como **nota interna** (banner amarillo), separada de la respuesta al cliente (azul) y
de las system notes (naranja). Es la superficie donde el agente deja rastro sin
mandarle nada al cliente.

En MGCI el tipo **ya existe pero está vacío**:

| Pieza | Estado | Dónde |
|---|---|---|
| `event_type: internal_note = 16` | ✅ existe | `app/models/case_event.rb:45` |
| i18n `"Nota interna"` / `"Internal note"` | ✅ existe | `gestorTickets.json:754` (es/en) |
| La IA ya las lee para resumir | ✅ existe | `app/services/cases/ai/summarizer.rb:63` |
| Endpoint para **crear** una nota | ❌ no existe | — |
| Botón en la UI | ❌ no existe | — |
| Render diferenciado en el Historial | ❌ no existe | `JourneyView.vue:464` las pinta como un evento más |

O sea: el enum está reservado desde el diseño original, pero nadie puede producir
un `internal_note`. Este plan cierra ese hueco.

## 2. Alcance

**Dentro:**
1. Crear una nota interna desde la ficha del ticket.
2. Verla destacada en el **Historial** del Avance.
3. Nota opcional al **cambiar estado** (el popup de osTicket).

**Fuera (otro plan):** editar/borrar notas, adjuntos en la nota, menciones `@agente`,
Print/PDF por niveles, colaboradores/CC.

## 3. Flujo

```
   ┌──────────────── TicketDetail.vue ────────────────┐
   │  [Prioridad▾] [Vence▾] [+Vincular] [📄 Nota]     │
   │                          [Escalar] [Estado▾]     │
   └───────────────────────┬──────────────────────────┘
                           │ click
                           ▼
              ╔════════════════════════════╗
              ║  Modal "Nueva nota interna"║
              ║  ┌──────────────────────┐  ║
              ║  │ textarea (autofocus) │  ║
              ║  └──────────────────────┘  ║
              ║  ⓘ Solo visible para       ║
              ║    agentes                 ║
              ║        [Cancelar] [Guardar]║
              ╚═════════════╤══════════════╝
                            │ POST .../case_tickets/:id/note  { content }
                            ▼
        ┌───────────────────────────────────────────────┐
        │ CaseTicketsController#add_note                 │
        │   @ticket.add_internal_note!(                  │
        │     content:, actor: current_user)             │
        └───────────────────┬───────────────────────────┘
                            ▼
        ┌───────────────────────────────────────────────┐
        │ CaseTicket#add_internal_note!                  │
        │   case_events.create!(                         │
        │     event_type: :internal_note,                │
        │     origin: :agent, actor: actor,              │
        │     payload: { content: content })             │
        └───────────────────┬───────────────────────────┘
                            ▼
              dispatch('fetchEvents') → Avance se repinta
                            │
                            ▼
        ┌───────────────────────────────────────────────┐
        │ JourneyView · Historial                        │
        │  ● Nota interna                    🟡 amarillo │
        │    "Llamé al cliente, sin respuesta"           │
        │    Admin · [21/07/2026, 10:14]                 │
        └───────────────────────────────────────────────┘
```

## 4. Cambios por archivo

### 4.1 Backend

**`app/models/case_ticket.rb`** — método nuevo, siguiendo el patrón exacto de
`set_change_approval!` (línea ~300):

```
def add_internal_note!(content:, actor: nil)
  raise 'La nota no puede estar vacía' if content.blank?

  case_events.create!(
    account:    account,
    event_type: :internal_note,
    origin:     actor ? :agent : :system,
    actor:      actor,
    payload:    { content: content.to_s.strip }
  )
end
```

> `payload: { content: ... }` no es arbitrario: es la clave que **ya espera**
> `summarizer.rb:63` (`p['content'].present?`) y también `payloadSummary()` en
> `JourneyView.vue`. Respetarla hace que la IA y el timeline funcionen sin tocarlos.

**`app/controllers/api/v1/accounts/case_tickets_controller.rb`** — acción nueva junto
a `escalate` (línea ~329), mismo estilo de respuesta y de rescue:

```
# POST /api/v1/accounts/:account_id/case_tickets/:id/note
# @tickets_cases — bitácora: nota interna en el timeline (no visible al cliente)
def add_note
  @ticket.add_internal_note!(content: params[:content], actor: current_user)
  render json: { case_ticket: ticket_json(@ticket.reload) }
rescue StandardError => e
  render json: { error: e.message }, status: :unprocessable_entity
end
```

**`config/routes.rb`** — dentro del bloque `member do` de `case_tickets` (~línea 153,
donde ya están `lock`/`unlock`):

```
post :note # @tickets_cases — bitácora de notas internas
```

**Autorización:** hereda del `set_ticket` + policy existentes del controlador; no se
añade regla nueva. La nota **nunca** sale al cliente porque vive en `case_events`,
que el User Portal no expone.

### 4.2 Frontend

**`app/javascript/dashboard/api/caseTickets.js`** — junto a `escalate()` (línea 37):

```
addNote(ticketId, content) {
  return axios.post(`${this.url}/${ticketId}/note`, { content });
}
```

**`app/javascript/dashboard/store/modules/caseTickets.js`** — acción nueva con la
misma forma que `escalateTicket` (línea 343); al terminar despacha `fetchEvents`
para que el Avance se refresque:

```
async addNote({ commit, dispatch }, { ticketId, content }) { … }
```

**`app/javascript/dashboard/views/gestorTickets/TicketDetail.vue`**
- Botón en la fila de acciones, **entre `+Vincular ticket` y `Escalar`**:
  `<woot-button size="small" variant="smooth" color-scheme="secondary" icon="note">`
- `showNoteModal` + `noteContent` en `data()`.
- Modal con `<woot-modal>` (patrón ya usado por el modal de relaciones).
- El botón va **dentro** del div con `v-on-clickaway="closeActionMenus"` — no abre
  menú flotante, así que no hay que tocar `closeActionMenus()`.

**`app/javascript/dashboard/views/gestorTickets/JourneyView.vue`** — en el `<li>` del
Historial (línea 469), rama especial cuando `event.event_type === 'internal_note'`:

```
ANTES (se ve como cualquier evento)      DESPUÉS (destacada, tipo osTicket)
┌──────────────────────────────────┐     ┌──────────────────────────────────┐
│ ● Nota interna                   │     │ ┃ 📄 Nota interna                 │
│   Llamé al cliente, sin respu…   │  →  │ ┃ Llamé al cliente, sin respuesta │
│   Admin · [21/07, 10:14]         │     │ ┃ Admin · [21/07, 10:14]          │
└──────────────────────────────────┘     └──────────────────────────────────┘
                                          fondo amber-50 · borde-izq amber-400
                                          dark: amber-900/20 · amber-500
```

- El texto de la nota **no se trunca a 80 chars** como hace `payloadSummary()` hoy —
  la rama nueva imprime `event.payload.content` completo con `whitespace-pre-line`.
- Nodo del timeline en ámbar en vez del `statusDot()` normal.

### 4.3 i18n

`gestorTickets.json` (es/en) — bloque nuevo `CASE_TICKETS.NOTES`:
`ADD`, `TITLE`, `PLACEHOLDER`, `HINT` ("Solo visible para agentes"), `SAVE`,
`CANCEL`, `EMPTY_ERROR`, `SUCCESS`. Las claves `EVENT_TYPES.internal_note` ya existen.

## 5. Fase 2 — nota al cambiar estado

osTicket permite adjuntar una nota junto al cambio de estado. En MGCI el camino ya
está medio hecho: **`transition!` acepta `reason:`** y lo guarda en
`payload[:reason]`, que el Recorrido ya muestra como "Motivo".

Falta solo la UI: al elegir un estado en `Cambiar estado ▾`, abrir el mismo modal con
un textarea opcional y mandar `reason` en el `transitionTicket`. **Cero backend.**

```
[Cambiar estado ▾] → Resuelto ──▶ ╔═══════════════════════════╗
                                  ║ Cambiar a «Resuelto»      ║
                                  ║ Motivo (opcional)         ║
                                  ║ ┌───────────────────────┐ ║
                                  ║ └───────────────────────┘ ║
                                  ║      [Cancelar] [Cambiar] ║
                                  ╚═══════════════════════════╝
```

## 6. Orden de trabajo

```
 1. Modelo   add_internal_note!            ← testeable por consola de una
 2. Ruta + controlador  add_note
 3. API + store
 4. Botón + modal en TicketDetail
 5. Render destacado en JourneyView
 6. i18n es/en
 ── corte: aquí ya es usable ──
 7. Fase 2: nota opcional en Cambiar estado
```

Sin migraciones: `case_events` ya tiene `payload` (jsonb) y el enum ya reserva el 16.

## 7. Verificación

- **Consola:** `t.add_internal_note!(content: 'prueba', actor: u)` → aparece en
  `t.case_events.last` con `event_type: 'internal_note'`.
- **Browser** (Puppeteer, ver [[Pruebas-en-browser]]): crear nota desde la ficha →
  aparece amarilla en Avance › Historial, en claro y oscuro.
- **Regresión:** que la nota **no** rompa el Recorrido (vista 1), que ignora los
  eventos sin `to` en el payload.
- **IA:** `POST /summarize` sobre un ticket con notas → el resumen las incluye
  (ya funciona por `summarizer.rb:63`).

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| Nota confundida con respuesta al cliente | Color ámbar + leyenda "Solo visible para agentes" en el modal |
| `payload.content` largo rompe el layout | `whitespace-pre-line` + el card del Avance ya tiene scroll interno |
| Duplicar el timeline de Chatwoot (mensajes privados de la conversación) | La nota es del **ticket**, no de la conversación; vive en el Avance, no en el tab Conversación |
