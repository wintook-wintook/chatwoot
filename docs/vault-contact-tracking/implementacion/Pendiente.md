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

- [ ] **Verificar creación de evento en vivo (TC-04)** — `confirm_and_create_appointment`
      (`contact_tracking_response_analyzer_job.rb:495`) ya llama `GoogleCalendarService#create_event`
      al elegir un número de slot. Falta probar end-to-end que el evento aparece en el
      calendario. Ver [[Testeo-funcional]].
- [ ] **Negociación de cita multi-turno** — hoy el flujo es single-shot (ofrece 5 slots
      → espera un **número**). Entrar en una "conversación de agendar" hasta **confirmar**:
      manejar "ninguno me sirve", proponer otras fechas, interpretar lenguaje natural
      (hoy `parse_slot_choice` solo acepta dígito 1-5/palabra; ver [[Testeo-funcional]] TC-03).
- [ ] **Mover una cita ya agendada** — no soportado. `confirm_and_create_appointment`
      **no guarda el `event_id`** del evento creado, así que aunque existe
      `GoogleCalendarService#update_event`, no hay cómo identificar qué mover. `:reschedule`
      hoy reagenda el **tracking**, no el evento. Guardar `event_id` y usar `update_event`.
- [ ] **Cancelar una cita ya agendada** — no soportado. `GoogleCalendarService` **no tiene
      `delete_event`** y no se guarda `event_id`. Implementar borrado del evento al cancelar.
- [ ] **BUG: confirmación falsa de cita** — si el calendario se desconfigura entre ofrecer
      y confirmar, `confirm_and_create_appointment` deja `event_created = false` pero **igual
      responde "✅ ¡Perfecto! Tu cita está agendada…"**. No confirmar al cliente si el evento
      no se creó (responder error / escalar a humano).
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

> Cuando se cierre un punto, muévelo a [[Estado-actual]] como ✅.
