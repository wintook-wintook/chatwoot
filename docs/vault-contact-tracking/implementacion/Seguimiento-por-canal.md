---
titulo: Seguimientos en paralelo por canal — limitación y solución
tipo: implementacion
tags: [contact-tracking, inbox, canal, indice, limitacion, solucion]
---

# Seguimientos en paralelo por canal (mismo contacto)

## Limitación actual

Un contacto solo puede tener **un seguimiento activo a la vez**, **sin importar el
inbox/canal** (mismo tipo o distinto). No se puede llevar, p. ej., un seguimiento por
WhatsApp y otro por Email para el mismo contacto al mismo tiempo.

Lo imponen **3 capas**, todas por `contact_id` (ninguna mira `inbox_id`):

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

## Solución propuesta (permitir 1 activo por contacto **y canal**)

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

## Consideraciones / riesgos

- `find_active_trackings` ya está bien (filtra por conversación) → la respuesta no se cruza.
- Revisar que ningún otro punto asuma "1 activo por contacto" globalmente (buscar
  `where(contact_id` + `status` en el módulo antes de implementar).
- Es **cambio de comportamiento**: pasa de "1 por persona" a "1 por persona y canal".
  Confirmar que es el caso de negocio deseado antes de aplicar.
- Migración siempre al final (convención del módulo).

Ver el índice en [[Modelo-de-datos]] y el listado en [[Pendiente]].
