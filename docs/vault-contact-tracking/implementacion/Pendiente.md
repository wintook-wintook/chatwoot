---
titulo: Pendiente — Contact Tracking
tipo: implementacion
tags: [contact-tracking, pendiente, todo]
---

# Pendiente

Tareas abiertas e integraciones a medias. Confirmar contra el código antes de
asumir que algo falta (el módulo avanza rápido). Ver también [[Estado-actual]].

- [ ] **Alinear UI al nombre "Agente IA"** — en producto las plantillas de seguimiento
      se llaman **Agente IA**, pero la UI todavía dice "plantilla de seguimiento". Revisar
      labels e i18n (`es`/`en`): acción de automatización `assign_tracking_template`
      (`routes/dashboard/settings/automation/constants.js:663` "Asignar plantilla de
      seguimiento"), sección `settings/trackingTemplates/*`, `bulkTrackingAssign.json`,
      `trackingTemplates.json`, `contactTracking.js`. Cambiar solo etiquetas visibles, NO
      claves de código/columnas (`tracking_template` sigue igual). Ver [[Vision-y-convenciones]].
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
