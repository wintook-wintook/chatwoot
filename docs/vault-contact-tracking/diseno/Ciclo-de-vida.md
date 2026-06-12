---
titulo: Ciclo de vida — Contact Tracking
tipo: diseno
tags: [contact-tracking, estados, ciclo-de-vida]
---

# Ciclo de vida del tracking

`app/models/contact_tracking.rb`. Siete estados en `status` (string, no enum):

```
 pending ──► scheduled ──► active ──┬──► completed   (alcanzó max_attempts / éxito)
    │            │           │       ├──► cancelled   (cancel! o keyword_action)
    │            │           │       └──► failed       (error irrecuperable)
    └────────────┴───────────┴──► paused ──► (resume!) ──► scheduled/active
```

- **pending** — creado, aún sin programar firme.
- **scheduled** — con `scheduled_for` futuro, esperando el cron.
- **active** — en ejecución / conversando.
- **paused** — pausado manualmente (`paused_at` set).
- **completed** / **cancelled** / **failed** — terminales.

Los cuatro estados `pending/scheduled/active/paused` son los que cuentan para el
índice único de "1 activo por contacto" (ver [[Modelo-de-datos]]).

## Guardas de transición

`can_execute?` (156), `can_pause?` (161), `can_resume?` (166), `can_cancel?` (171)
validan si la transición es legal antes de aplicarla.

## Métodos de control

| Método | Línea | Qué hace |
|---|---|---|
| `pause!` | 334 | → `paused`, marca `paused_at`, recalcula job |
| `resume!(new_time = nil)` | 355 | sale de `paused`, reprograma |
| `cancel!` | 422 | → `cancelled` (terminal) |
| `mark_attempt_successful!(msg)` | 278 | `attempt_count++`, guarda `last_message_sent` |
| `mark_attempt_failed!(err)` | 269 | guarda `last_error`, decide reintento |
| `reschedule_next_attempt` | 294 | calcula y agenda el siguiente intento |
| `reschedule_to(datetime)` | 306 | reprogramación manual a fecha concreta |
| `next_scheduled_time` | 245 | próxima ejecución según `retry_interval_*` |
| `current_template` / `use_template_for_current_attempt?` | 192 / 209 | plantilla WA del intento actual |
| `auto_retry_mode?` | 214 | detecta modo reagendamiento (usa `response_adjustments_count`) |

## Scopes

```ruby
scope :active_or_scheduled  # status IN (active, scheduled, pending)
scope :due_for_execution    # scheduled_for <= now AND active_or_scheduled
scope :by_inbox / :by_conversation
scope :recent               # order created_at desc
scope :upcoming             # scheduled_for > now, asc
```

## Callbacks → jobs

`after_create` programa el job de Sidekiq; `after_update` lo reprograma vía
`reschedule_job_if_needed` (586) si cambió `scheduled_for`. El cron
`ExecutePendingJob` (cada 5 min) es el respaldo que recoge los `due_for_execution`.
Detalle en [[Servicios-y-jobs]].
