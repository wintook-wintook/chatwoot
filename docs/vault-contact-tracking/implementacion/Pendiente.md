---
titulo: Pendiente — Contact Tracking
tipo: implementacion
tags: [contact-tracking, pendiente, todo]
---

# Pendiente

Tareas abiertas e integraciones a medias. Confirmar contra el código antes de
asumir que algo falta (el módulo avanza rápido). Ver también [[Estado-actual]].

- [ ] **Conversación con tracking no se puede borrar** — borrar una conversación
      referenciada por un `ContactTracking` falla con `PG::ForeignKeyViolation` (FK
      `contact_trackings.conversation_id` es NO ACTION y `Conversation` no declara la
      asociación). Romper el borrado de conversación desde la UI. Arreglo: añadir
      `has_many :contact_trackings, dependent: :nullify` (o `:destroy`) en `Conversation`,
      o cambiar la FK a `on_delete: :nullify`. Ver [[Borrado-y-cascadas]].
- [ ] **Tickets huérfanos al borrar** — al borrar contacto/conversación/tracking, los
      `case_tickets` conservan IDs colgando (no hay FK ni `dependent`); `ticket.contact.name`
      puede dar nil/errores. Definir política: `dependent: :nullify` en las asociaciones
      o conservar con histórico. Ver [[Borrado-y-cascadas]].
### 📅 Agendado de citas / Google Calendar

- [x] ~~**Verificar creación de evento en vivo (TC-04)**~~ — ✅ **HECHO**: TC-04 PASS,
      evento real creado en Google Calendar (conv #29, "1" → evento 2026-06-15 09:00 UTC).
      Ver [[Testeo-funcional]].
- [x] ~~**Timezone del inbox en UTC**~~ — ✅ **HECHO** (zona horaria propia del Agente IA):
      el inbox default `UTC` hacía que los slots 9-18, la hora mostrada y el evento cayeran en UTC.
      Ahora cada Agente IA tiene su campo `timezone` (migración + validación + UI en la pestaña
      Agendas, reutiliza la lista de Horario laboral). El job resuelve con `appointment_timezone`:
      Agente IA → inbox → default `America/Mexico_City`. Ver [[Testeo-funcional]] TC-04.
- [x] ~~**Cita sin invitado cuando el contacto no tiene email**~~ — ✅ **HECHO** (email opcional):
      si el contacto no tiene email, tras elegir el horario el bot lo pide una vez
      (`[PENDING_EMAIL]` + `prompt_for_email`/`handle_pending_email`). Si lo da, se guarda en el
      contacto y se le invita al evento; si responde "sin correo"/omite, se agenda igual sin
      invitado. Si ya tenía email, confirma directo.
- [x] ~~**Negociación de cita multi-turno**~~ — ✅ **HECHO**: si el cliente, en vez de elegir
      número, propone otra fecha/hora, `handle_slot_negotiation` la interpreta (IA →
      `parse_requested_datetime`), verifica disponibilidad (`AvailabilitySlotService#slot_for`)
      y: confirma si está libre, ofrece horarios cercanos si está ocupada o si solo dio el día
      (`call(from:)`), o repregunta. Un dígito 1-5 dentro de una frase de hora ya no se confunde
      con elegir slot (`looks_like_datetime_proposal?`). Ver [[Testeo-funcional]] TC-03.
- [x] ~~**Mover una cita ya agendada**~~ — ✅ **HECHO**: se persiste `appointment_event_id` +
      `appointment_calendar_id`; `confirm_and_create_appointment` reutiliza la cita
      (`create_or_move_calendar_event`): misma agenda → `update_event` (mueve), otra agenda →
      crea nuevo y borra el viejo (`delete_stale_appointment_event`). Evita duplicados.
- [x] ~~**Cancelar una cita ya agendada**~~ — ✅ **HECHO**: nuevo `GoogleCalendarService#delete_event`
      (idempotente ante 404/410), ruta `:cancel_appointment` en `RouterService` y
      `handle_cancel_appointment` (borra el evento, limpia los campos de cita, `outcome=cancelled`;
      sin cita activa se trata como rechazo).
- [x] ~~**BUG: confirmación falsa de cita**~~ — ✅ **HECHO**: si `create_event` falla, ya **no** se
      confirma; se avisa que un asesor confirmará, se escala a humano (nota + aviso admin) y
      **no** se marca `outcome=appointment` (no contamina el KPI).
- [ ] **Política multi-agente de slots** — `AvailabilitySlotService` propone los **5 slots
      más tempranos combinados** de todos los `calendar_integration_ids`, sin balancear entre
      agentes. Definir si debe balancear o filtrar por el agente del seguimiento.
- [ ] **Respuesta cuando el agente no tiene calendario configurado** — hoy cae a
      `:interested` (sin calendar_ids) o `:book_appointment_no_slots` + escala a humano
      (integración borrada), sin mensaje específico. Definir el mensaje esperado.
- [ ] **Sentimiento end-to-end** — revisar `ResponseAnalyzerJob` y si hay dashboard
      que consuma `last_sentiment_analysis` (índice ya existe).
- [ ] **KBase real en el router** — la ruta `:kbase` y `kbase_hook_id` existen;
      conectar con la búsqueda/respuesta de la Base de Conocimiento (`vault-kbase`).
- [ ] **BotSeller** — ruta `:botseller` definida; confirmar la delegación al bot.
- [ ] **Feature flag** — decidir si el módulo necesita gating por cuenta
      (`config/features.yml`); hoy está siempre activo.
- [ ] **Bóveda** — completar con flujos de referencia y "trampas/gotchas" a medida
      que se toque el código (estilo nota `Trampas` de `vault-tickets`).

### 📡 Multicanal

- [x] ~~**Permitir seguimientos en paralelo por canal**~~ — ✅ **IMPLEMENTADO** (2026-06-12):
      índice `(contact_id, inbox_id, status)` + validación + guardas por `(contacto, inbox)`.
      Verificado: mismo contacto en 2 inboxes = permitido; 2 en el mismo inbox = bloqueado
      (modelo + BD). Ver [[Seguimiento-por-canal]].

> Cuando se cierre un punto, muévelo a [[Estado-actual]] como ✅.
