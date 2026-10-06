# Plan — Reglas del ticket cerrado

> Estado: ✅ **Pasos 1–7 completos (todo el plan) y verificados** (2026-07-22).
> Paso 6: `post_closure` se mide contra el PRIMER evento `closed` del timeline
> (no contra `closed_at`, que se borra al reabrir), así sobrevive a los ciclos.
> ⚠️ Trampa: el icono `arrow-counterclockwise` NO existe en el set de Fluent;
> el nombre real es `arrow-rotate-counter-clockwise`.
> ⚠️ Trampa: tras `reopenTicket` hay que llamar a `refetch()` en la vista, como
> hace `runTransition`; si no, el PATCH devuelve 200 pero la ficha sigue
> pintando "Cerrado".
> Relacionado: [[Plan-Practicidad-osTicket]] · [[Plan-Notas-Internas]] · [[Pendiente]] · [[Historial-de-implementacion]]

## 1. Por qué

Hoy "cerrado" no es un estado con reglas: es **una puerta sin cerradura y sin
salida a la vez**.

**Sin salida.** En `case_ticket.rb:93` la tabla de transiciones dice:

```ruby
'closed'    => [],
'cancelled' => []
```

Un ticket cerrado no vuelve nunca. Ni el admin puede reabrirlo. Esto es **más
estricto que osTicket**, donde reabrir es una operación normal y hasta
automática cuando el cliente responde.

**Sin cerradura.** Salvo `escalate!` (`case_ticket.rb:241`, que sí levanta
`'Ticket cerrado: no se puede escalar'`), **no hay una sola validación de
cerrado en el backend**. Lo comprobado leyendo los controladores:

| Acción sobre un ticket CERRADO | UI | API |
|---|---|---|
| Escalar | oculta (`canEscalate`) | ❌ bloqueada en el modelo |
| Tomar / asignar | oculta (`canClaim`) | ✅ **la acepta** (`case_tickets_controller.rb:253`) |
| Cambiar prioridad | visible | ✅ la acepta (`:170 update`) |
| Cambiar vencimiento | visible | ✅ la acepta |
| Crear/editar/borrar tareas | visible | ✅ la acepta |
| Crear/editar/borrar notas | visible | ✅ la acepta |
| Vincular tickets | visible | ✅ la acepta |
| Responder al cliente | visible | ✅ la acepta |

Ocultar un botón no es una regla. Cualquiera con el token de la cuenta cambia
la prioridad de un ticket cerrado hace seis meses y nadie se entera.

> El objetivo de este plan **no** es blindar: es que el estado "cerrado"
> signifique algo y que reabrir sea posible pero deje rastro.

## 2. Alcance

**Dentro (P1):**
1. Reapertura controlada: quién, hasta cuándo, con motivo obligatorio.
2. Congelar lo editable, **validado en el backend**.
3. Notas internas: explícitamente **permitidas** siempre.
4. El cliente responde por su canal → reabre solo.

**Fuera (otro plan):** auto-cierre por inactividad, requisitos duros para poder
cerrar (cero tareas pendientes), reapertura desde el User Portal, reapertura de
`cancelled` (se trata igual que cerrado pero sin ventana: ver §7).

## 3. Piezas que ya existen (no hay que inventarlas)

| Pieza | Estado | Dónde |
|---|---|---|
| `event_type: reopened = 11` | ✅ existe | `case_event.rb` |
| `event_type_for_transition` ya devuelve `:reopened` | ✅ existe, pero solo desde `resolved`/`validating` | `case_ticket.rb` |
| `closed_at` en la tabla | ✅ existe | `case_tickets` |
| `transition!(..., reason:)` guarda el motivo | ✅ existe | `case_ticket.rb:205` |
| El Recorrido pinta `reason` como "Motivo" | ✅ existe | `JourneyView.vue` |
| `sla_pause_attrs` (pausa/reanuda el reloj) | ✅ existe | `case_ticket.rb` |
| `current_user.administrator?` | ✅ existe | `user_attribute_helpers.rb:34` |
| `case_settings` (config por cuenta) | ✅ existe, hoy solo `itil_enabled` | `case_settings` |

O sea: **el evento `reopened` lleva reservado desde el diseño original y nadie
puede producirlo desde `closed`.** Igual que pasó con `internal_note`.

## 4. Regla 1 — Reapertura controlada

```
            ┌──────────────────────────────────────────┐
            │            Ticket CERRADO                │
            │  closed_at: 12/07/2026                   │
            └───────────────────┬──────────────────────┘
                                │ [Reabrir]
                                ▼
              ┌─────────────────────────────────┐
              │ ¿Quién?    admin  ó  el asignado │──── no ──▶ 403
              │ ¿Cuándo?   dentro de N días      │──── no ──▶ 422 "ventana vencida"
              │ ¿Motivo?   obligatorio           │──── no ──▶ 422 "motivo requerido"
              └─────────────────┬───────────────┘
                                │ sí a las tres
                                ▼
        ╔═══════════════════════════════════════════════╗
        ║ status      → in_progress                     ║
        ║ closed_at   → nil                             ║
        ║ reopen_count += 1                             ║
        ║ evento `reopened` { from:'closed', reason: }   ║
        ║ SLA: reloj NUEVO desde ahora  (ver decisión)   ║
        ╚═══════════════════════════════════════════════╝
```

**Cambio mínimo en la tabla de transiciones:**

```ruby
'closed' => %w[in_progress],   # solo reabrir; nada de saltar a resolved
```

Y `event_type_for_transition` debe devolver `:reopened` también cuando
`old_status == 'closed'` (hoy solo contempla `resolved`/`validating`).

### Decisiones que NO tomo yo

| Decisión | Opciones | Mi recomendación |
|---|---|---|
| ¿Quién reabre? | (a) cualquier agente · (b) admin o el asignado · (c) solo admin | **(b)** — (a) vacía la regla, (c) atasca al equipo un viernes por la noche |
| Ventana | (a) sin límite · (b) N días desde `closed_at` | **(b) con N=30**, configurable por cuenta |
| SLA al reabrir | (a) reloj nuevo · (b) reanuda el viejo | **(a)** — reanudar el viejo nace vencido y ensucia el cumplimiento |
| Pasada la ventana | (a) nadie reabre · (b) solo admin | **(b)** — deja una salida sin volver al agujero actual |

## 5. Regla 2 — Congelar, en el backend

Guarda única en el modelo, usada por todos los controladores:

```ruby
# case_ticket.rb
FROZEN_WHEN_CLOSED = %i[priority due_at case_type_id assignee_id team_id].freeze

def frozen_for_edit?
  closed? || cancelled?
end
```

- `case_tickets_controller#update` → 422 si toca un campo congelado.
- `#assign` → 422 (hoy la acepta aunque la UI esconda "Tomar").
- `case_tasks_controller#create/#update/#destroy` → 422, **salvo** marcar como
  completada una tarea que quedó abierta (cerrar el ticket no debe obligar a
  mentir sobre lo que sí se hizo).
- `case_notes_controller` → **sin restricción** (ver §6).
- Relaciones entre tickets → **sin restricción**: vincular es informativo y
  normalmente se hace después, al descubrir el patrón.

En la UI: los botones ya ocultos siguen ocultos, y los que hoy quedan visibles
(Prioridad, Vence) pasan a `disabled` con tooltip "Ticket cerrado", en vez de
desaparecer — que el agente vea *por qué* no puede.

## 6. Regla 3 — Las notas siempre se pueden

Deliberadamente **sin restricción**. La nota interna es bitácora y auditoría:
"el cliente volvió a llamar tres semanas después" es exactamente la información
que hay que poder dejar en un ticket cerrado. osTicket también lo permite.

Único añadido: marcarlas visualmente como **post-cierre** en la tabla y en el
Historial (comparar `created_at` de la nota contra `closed_at` del ticket) para
que se distinga lo que se supo durante la atención de lo que llegó después.

```
Notas internas
├─ 12/07 10:14  Admin      Se reemplazó la fuente. Cliente confirma.
├─ 12/07 10:20  Admin      Cierre documentado.
│  ─────────────── ✕ cerrado el 12/07 10:21 ───────────────
└─ 02/08 09:03  Ana    🔓  Volvió a fallar. Abro ticket nuevo #01102.
```

## 7. Regla 4 — El cliente responde y el ticket reabre

Es la regla más útil de osTicket ("Reopen ticket on client reply") y la que hoy
provoca tickets fantasma: el cliente contesta por WhatsApp y ese mensaje no
llega a ningún lado del módulo.

**El enganche no existe todavía**: ningún listener de
`async_dispatcher.rb:10` conoce los tickets. Hay que crear
`CaseTicketListener` y registrarlo ahí, igual que se hizo con
`CommandAgentListener`.

```
  cliente escribe en la conversación
              │
              ▼
   MESSAGE_CREATED (dispatcher async)
              │
              ▼
      CaseTicketListener  ── ¿hay case_ticket con esta conversation_id?  no ─▶ nada
              │ sí
              ▼
        ¿está cerrado?  ── no ─▶ nada
              │ sí
              ▼
        ¿dentro de la ventana de N días?
        ├─ sí ─▶ reabrir (actor: nil → origin :system)
        │        evento `reopened` { reason: 'Respuesta del cliente' }
        └─ no ─▶ crear ticket NUEVO enlazado al viejo (relación `follows_up`)
                 así no se resucita un caso de hace un año
```

⚠️ **Trampa esperada**: el mensaje del propio agente también dispara
`MESSAGE_CREATED`. Filtrar por `message_type: :incoming` o el ticket reabrirá
solo al escribir la respuesta de cierre.

## 8. Cambios por archivo

### 8.1 Backend

| Archivo | Cambio |
|---|---|
| `db/migrate/…_add_reopen_to_case_tickets.rb` | `reopen_count:integer default 0`, `reopened_at:datetime` |
| `db/migrate/…_add_reopen_settings_to_case_settings.rb` | `reopen_window_days:integer default 30`, `reopen_on_customer_reply:boolean default true` |
| `case_ticket.rb` | `'closed' => %w[in_progress]`; `reopen!(actor:, reason:)`; `frozen_for_edit?`; `event_type_for_transition` cubre `closed → in_progress` |
| `case_tickets_controller.rb` | acción `reopen`; guardas de congelado en `update` y `assign` |
| `case_tasks_controller.rb` | guarda de congelado (excepto completar) |
| `case_settings_controller.rb` | exponer los dos ajustes nuevos |
| `app/listeners/case_ticket_listener.rb` | **nuevo** — `message_created` → reabrir |
| `app/dispatchers/async_dispatcher.rb` | registrar el listener |
| `config/routes.rb` | `patch :reopen` en el `member do` de `case_tickets` |

### 8.2 Frontend

| Archivo | Cambio |
|---|---|
| `TicketDetail.vue` | botón "Reabrir" (solo si `can_reopen`); modal con motivo **obligatorio**; deshabilitar Prioridad/Vence con tooltip |
| `TicketNotes.vue` | separador y marca 🔓 para notas post-cierre |
| `JourneyView.vue` | el evento `reopened` ya se pinta; revisar que el icono/color lo distinga de un `status_changed` normal |
| `Settings` del módulo | ventana de reapertura + toggle de reapertura por respuesta |
| `gestorTickets.json` (es/en) | bloque `CASE_TICKETS.REOPEN` |

**El backend debe mandar `can_reopen` calculado** (rol + ventana), no que el
front reimplemente la regla: si la duplicamos, se desincronizan.

## 9. Orden de trabajo

```
 1. Migraciones (reopen_count, reopened_at, ajustes de cuenta)
 2. Modelo: 'closed' => [in_progress] + reopen! + frozen_for_edit?
 3. Controlador: acción reopen + guardas de congelado
 4. UI: botón Reabrir + modal de motivo + campos deshabilitados
 ── corte: aquí ya es usable y auditable ──
 5. Listener de respuesta del cliente (+ registro en el dispatcher)
 6. Marca de notas post-cierre
 7. Ajustes por cuenta en la UI de configuración
```

Los pasos 1–4 son autónomos. El 5 es el que puede romper cosas ajenas al
módulo (toca el dispatcher global), así que va después y con su propia
verificación.

## 10. Verificación

- **Consola:** `t.reopen!(actor: admin, reason: 'x')` sobre un cerrado → status
  `in_progress`, `closed_at` nil, `reopen_count` 1, evento `reopened` con motivo.
- **Guardas:** `PATCH` de prioridad sobre cerrado → 422. Mismo `PATCH` sobre
  abierto → 200 (que la guarda no se pase de lista).
- **Ventana:** cerrado hace 31 días con N=30 → agente 422, admin 200.
- **Listener:** mensaje `incoming` en la conversación de un cerrado → reabre;
  mensaje `outgoing` del agente → **no** reabre (la trampa de §7).
- **Browser** (ver [[Pruebas-en-browser]]): botón Reabrir solo visible con
  permiso; motivo vacío no envía; el Recorrido muestra la reapertura con motivo.
- **Regresión:** cerrar un ticket sigue funcionando igual; `cancelled` sigue sin
  salida.

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Reabrir descuadra las métricas (un ticket cuenta dos veces como resuelto) | `reopen_count` permite excluir/segmentar; revisar `metrics` antes de dar por buenas las cifras |
| El listener reabre en bucle con bots que responden solos | Filtrar `incoming` + ignorar mensajes de agent_bot |
| Reabrir masivamente por respuestas viejas al activar la regla | El toggle nace por cuenta y la ventana lo acota; activar en una cuenta piloto |
| La guarda de congelado rompe automatizaciones existentes que tocan tickets cerrados | Auditar `case_rules` antes; las reglas del sistema deben poder saltarse la guarda (`actor: nil`) |
