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
- [ ] **Cierre del agendado de citas** — `AvailabilitySlotService` propone slots;
      confirmar/implementar la creación real del evento en el calendario tras
      `:book_appointment` (usar `calendar_integration_ids` + `calendar_event_duration`).
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
