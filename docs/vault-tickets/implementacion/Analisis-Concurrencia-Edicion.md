---
titulo: Análisis — Concurrencia al editar un ticket / nota / tarea
tipo: análisis
tags: [tickets, concurrencia, bloqueo, lock, integridad]
---

# Análisis — Concurrencia al editar un ticket / nota / tarea

> Estado: 📋 **solo análisis** (2026-07-29). Nada implementado.
> Origen: observación preventiva — *"¿qué pasa si varios agentes (o la IA) modifican
> lo mismo dentro de un ticket a la vez?"*. **No es un bug reproducido**, es un hueco
> de diseño que conviene blindar antes de que muerda en producción.
> Relacionado: [[Pendiente]] · [[Plan-Ticket-Cerrado]] · [[Plan-Crear-Ticket-IA]]

---

## 1. Qué pasa hoy si dos actores escriben a la vez

No truena nada. El comportamiento es **"gana el último que guarda"** (*last-write-wins*),
**en silencio**:

```
   t0  Agente A abre el ticket #1234 (prioridad=media, estado=abierto)
   t0  Agente B ya lo tenía abierto de antes (mismo snapshot)
   t1  A cambia prioridad → alta   y guarda  ─► PATCH {priority: alta, status: abierto, ...}
   t2  B cambia estado → en_proceso y guarda  ─► PATCH {priority: media, status: en_proceso, ...}
                                                          ▲
                                                          └── el form de B llevaba la
                                                              prioridad VIEJA (media)
   ───────────────────────────────────────────────────────────────────────
   Resultado: prioridad vuelve a "media".  El cambio de A se PERDIÓ.
              Nadie recibe error ni aviso.  (lost update)
```

En equipos chicos casi no se nota; con **varios agentes + la IA + jobs de fondo**
escribiendo sobre el mismo ticket, empieza a producir cambios que "se deshacen solos".

---

## 2. Qué defensa existe hoy — y su hueco

Existe un **bloqueo a nivel de ticket** (implementado, ver [[Pendiente]] §"Tareas + Bloqueo"):

| Pieza | Dónde | Qué hace |
|---|---|---|
| Columnas `locked_by_id`, `locked_at` | `case_tickets` (schema) | Quién y cuándo tomó el ticket |
| TTL 3 min | `CaseTicket::LOCK_TTL` (`case_ticket.rb:112`) | El lock caduca solo tras inactividad |
| `lock_active?` / `locked_by_other?` | `case_ticket.rb:115` y `:120` | ¿Hay lock vigente? ¿lo tiene otro? |
| Endpoints `lock` / `unlock` | `case_tickets_controller.rb:325` y `:338` | Tomar / soltar el bloqueo |
| `acquireLock()` / `releaseLock()` | `TicketDetail.vue:436`, `:454` | Toma al abrir la ficha, suelta al salir |
| Banner "X está editando" | `TicketDetail.vue:1571` | Aviso visual (`lockedByOther`) |

### Los 4 huecos

1. **El bloqueo es solo cosmético.** El endpoint `update` (`case_tickets_controller.rb:174`)
   **NO verifica el lock**. `locked_by_other?` únicamente se consulta dentro del propio
   endpoint `lock` (línea 328). El banner avisa, pero si el `PATCH` llega igual, **pisa**.

2. **No hay bloqueo optimista.** No existe `lock_version` en `case_tickets`, `case_tasks`
   ni en la nota. Dos guardados concurrentes no chocan: el segundo sobrescribe al primero.

3. **La IA y los jobs no toman el lock.** El lock solo lo adquiere un humano al abrir la
   ficha. El agente IA (`@crear_ticket` / `@estado_ticket`), las reglas de automatización
   y el job de SLA escriben **sin pasar por el lock** → chocan con el humano en edición.
   **Este es el escenario que motivó el análisis.**

4. **Notas y tareas no están cubiertas.** El lock es del ticket; editar una `case_task`
   o una nota en paralelo no valida nada.

```
   Cobertura actual del bloqueo:

                    │ humano vs humano │ humano vs IA │ humano vs job │ notas/tareas
   ─────────────────┼──────────────────┼──────────────┼───────────────┼──────────────
   banner (avisa)   │        sí        │     no*      │      no       │     no
   update (impide)  │        NO        │     NO       │      NO       │     NO
   ─────────────────┴──────────────────┴──────────────┴───────────────┴──────────────
   * la IA no toma el lock, así que ni siquiera aparece en el banner
```

---

## 3. Opciones (de lo más barato a lo más robusto)

| # | Solución | Cubre | Costo |
|---|---|---|---|
| **A** | **`update` respeta el lock**: si `locked_by_other?` → `423 Locked` en vez de pisar. Reusa todo lo que ya existe. | Humano vs humano | Bajo — 1 guarda en el controller |
| **B** | **Bloqueo optimista (`lock_version`)** en ticket / tarea / nota → Rails lanza `StaleObjectError` y devolvemos `409` con *"cambió, recarga"*. | **Todos** (humano, IA, jobs) | Medio — migración + manejo 409 en front |
| **C** | **La IA/automatización se abstiene** cuando hay lock humano vigente (o escribe solo en su carril: notas internas, no campos que el humano edita). | Humano vs IA | Medio — guarda en los services de IA |
| **D** | **Notas append-only** (una nota por autor, no editar el mismo registro). | Notas | Bajo |

### Por qué A y B juntas (recomendación)

- **A sola** no basta: depende de que *todos* tomen el lock, y la IA/jobs no lo toman.
- **B sola** protege el dato pero pierde el aviso amable *"lo está editando Fulano"* que
  A + el banner ya dan.
- **Juntas**: aviso claro (A) **y** garantía de que nadie pisa a nadie, incluida la IA y
  los jobs (B). **C** queda como fase 2, solo si se observa que la IA compite de verdad.

```
   Recomendado:  A (rápido, tapa el hueco humano-humano ya)
               + B (red de seguridad real, cubre IA + jobs)
   Fase 2:       C (la IA cede ante el humano)
   Opcional:     D (notas append-only, elimina el conflicto de notas de raíz)
```

---

## 4. Alcance técnico de A + B (si se aprueba)

- **A** — una guarda en `case_tickets_controller#update`: `return 423` si
  `@ticket.locked_by_other?(current_user)`. Sin migración.
- **B** — migración: `add_column :lock_version, :integer, default: 0, null: false` a
  `case_tickets`, `case_tasks` y la nota. Rails activa el bloqueo optimista solo con esa
  columna. `update` pasa a rescatar `ActiveRecord::StaleObjectError → 409`.
- **Front** — enviar `lock_version` en el `PATCH`; ante 409 mostrar
  *"El ticket cambió mientras editabas, recarga"* y recargar la ficha.

**No es estructural**: una migración chica + una guarda + un manejo de 409. No toca la
máquina de estados, ni SLA, ni el portal.

---

## 🔗 Relacionado
- [[Pendiente]] — §"Tareas + Bloqueo de ticket" y §"Futuro Lock"
- [[Historial-de-implementacion]] · [[00-Indice]]
