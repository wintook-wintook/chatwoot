---
titulo: Pendiente — AI Agent Attachments
tipo: implementacion
tags: [ai-agent-attachments, pendiente]
---

# Pendiente

## Decisiones por confirmar

- [ ] **Modelo de datos:** Opción A (tabla `ai_agent_attachments` + `name`) vs Opción B
      (`has_many_attached :ai_files`). Recomendada **A**. → [[Modelo-de-datos]]
- [ ] **Punto de intercepción** de `@adjunto:nombre`: job de envío vs servicio de
      respuesta. → [[Directiva-y-envio]]
- [ ] **Límite de adjuntos por mensaje** y validación de tipo/peso por canal (WhatsApp).

## Backend

- [x] Migración `create_ai_agent_attachments` (migrada).
- [x] Modelo `AiAgentAttachment` + asociación en `TrackingTemplate`.
- [x] Controlador CRUD de adjuntos + rutas anidadas.
- [ ] Parser de `@adjunto:nombre` + adjuntar blob al mensaje saliente.

## Frontend

- [x] Tab "📎 Archivos" en `EditTemplate.vue` (índice dinámico `agendasTabIndex + 1`).
- [x] Subir / listar / borrar + snippet copiable `@adjunto:nombre`.
- [x] **Autocompletado `@adjunto:`** en el textarea del prompt complementario,
      reutilizando `MentionBox.vue` + `useKeyboardNavigableList`. → [[Frontend]]
- [x] i18n `es`/`en` bajo `TRACKING_TEMPLATES.FORM.ATTACHMENTS.*`.
- [ ] **Renombrar** adjunto en la UI (la API `rename` ya existe).
- [ ] Verificar corriendo la app (subir → autocompletar → guardar prompt).

## Calidad

- [ ] Specs de modelo (unicidad de `name`), request specs del controlador.
- [ ] Caso de testeo funcional (subir archivo → directiva → envío en conversación).
- [ ] Verificar límites del canal WhatsApp con un envío real.
