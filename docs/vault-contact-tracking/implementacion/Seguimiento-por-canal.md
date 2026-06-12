---
titulo: Seguimientos en paralelo por canal — limitación y solución
tipo: implementacion
tags: [contact-tracking, inbox, canal, indice, limitacion, solucion]
---

# Seguimientos en paralelo por canal (mismo contacto)

> ✅ **IMPLEMENTADO (2026-06-12).** Ahora la regla es **1 seguimiento activo por
> `(contacto, inbox)`**: un contacto puede tener seguimientos en paralelo en canales
> (inboxes) distintos, pero no dos en el mismo canal. Migración
> `20260612120000_change_unique_active_tracking_index_to_per_inbox`. La sección
> "Limitación actual" describe cómo era **antes**; la solución de abajo es lo aplicado.

## Limitación anterior (resuelta)

Antes, un contacto solo podía tener **un seguimiento activo a la vez**, **sin importar el
inbox/canal**. No se podía llevar, p. ej., un seguimiento por WhatsApp y otro por Email
para el mismo contacto al mismo tiempo.

Lo imponían **3 capas**, todas por `contact_id` (ninguna miraba `inbox_id`):

1. **Índice único (BD)** — `index_unique_active_tracking_per_contact`
   `UNIQUE (contact_id, status) WHERE status IN (pending, scheduled, active, paused)`.
2. **Validación de modelo** — `ContactTracking#only_one_active_tracking_per_contact`
   (`app/models/contact_tracking.rb:447`, `on: :create`).
3. **Guardas de servicios** (no crean si ya hay activo):
   - `app/services/action_service.rb:110` (`assign_tracking_template`).
   - `app/services/contact_trackings/bulk_assign_service.rb:65` (`skip_active`).
   - `app/models/message.rb:485` (`will_trigger_tracking_automation?`).

## Por qué la solución es limpia

La parte difícil —**a qué seguimiento responder** cuando llega un mensaje— **ya está
resuelta**: `ContactTrackingResponseAnalyzerJob#find_active_trackings`
(`contact_tracking_response_analyzer_job.rb:222`) filtra por **`contact_id` Y
`conversation_id`**. Como cada conversación pertenece a un inbox, la respuesta ya
queda acotada al canal correcto aunque existan varios trackings activos.

## Solución aplicada (1 activo por contacto **y canal**)

1. **Migración** — reemplazar el índice por uno que incluya `inbox_id`:
   ```ruby
   remove_index :contact_trackings, name: :index_unique_active_tracking_per_contact
   add_index :contact_trackings, [:contact_id, :inbox_id, :status],
     unique: true,
     where: "status IN ('pending','scheduled','active','paused')",
     name: :index_unique_active_tracking_per_contact_inbox
   ```
   **Seguro sin migrar datos:** el índice nuevo es **más laxo** que el viejo (1 por
   `contact_id+inbox` en vez de 1 por `contact_id`), así que ningún registro existente
   puede violarlo.
2. **Modelo** — en `only_one_active_tracking_per_contact` añadir `.where(inbox_id: inbox_id)`
   (y renombrar a `…_per_contact_and_inbox`); ajustar el mensaje de error.
3. **`action_service.rb:110`** — añadir `inbox_id:` al `where` del guard.
4. **`bulk_assign_service.rb:65`** — añadir `inbox_id:` al chequeo `skip_active`.
5. **`message.rb:485`** (`will_trigger_tracking_automation?`) — acotar el `exists?` al
   `inbox_id` de la conversación.

## Verificación (2026-06-12)

Probado en transacción con rollback (cuenta 2, contacto en inbox 4 y 5):
- Tracking en inbox A → ✅ creado.
- Tracking del mismo contacto en inbox B → ✅ **creado** (paralelo por canal).
- Segundo tracking en inbox A → 🛑 bloqueado por la **validación de modelo**.
- `insert!` (salta validaciones) en inbox A → 🛑 bloqueado por el **índice único de BD**.

## Consideraciones / notas

- `find_active_trackings` ya filtraba por conversación → la respuesta no se cruza entre canales.
- `message.rb#will_trigger_tracking_automation?` quedó acotado al `inbox_id` de la conversación.
- **Cambio de comportamiento aplicado**: de "1 por persona" a "1 por persona y canal".

Ver el índice en [[Modelo-de-datos]] y el listado en [[Pendiente]].
