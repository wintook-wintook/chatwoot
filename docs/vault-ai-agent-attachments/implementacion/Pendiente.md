---
titulo: Pendiente — AI Agent Attachments
tipo: implementacion
tags: [ai-agent-attachments, pendiente]
---

# Pendiente

## Decisiones (confirmadas)

- [x] **Modelo de datos:** Opción A (tabla `ai_agent_attachments` + `name`). → [[Modelo-de-datos]]
- [x] **Punto de intercepción** de `@adjunto:nombre`: job de envío
      (`resolve_attachment_directives`). → [[Directiva-y-envio]]
- [x] **Límite de adjuntos por mensaje**: `MAX_DIRECTIVE_ATTACHMENTS=5`.
- [ ] **Validación de tipo/peso por canal** (WhatsApp): aún pendiente.

## Backend

- [x] Migración `create_ai_agent_attachments` (migrada).
- [x] Modelo `AiAgentAttachment` + asociación en `TrackingTemplate`.
- [x] Controlador CRUD de adjuntos + rutas anidadas.
- [x] Parser de `@adjunto:nombre` + adjuntar blob al mensaje saliente
      (`resolve_attachment_directives` + reuso de `signed_id`).
- [x] **Reescritura de referencias** al renombrar/borrar un adjunto
      (`AiAgentAttachments::DirectiveReferenceService`): actualiza el prompt del agente
      y los seguimientos vivos. → [[Directiva-y-envio]]
- [ ] **Enviar `@adjunto:` también desde la base de conocimiento**
      (`KnowledgeBaseResponseService`): hoy `@adjunto:` solo se resuelve en la ruta
      conversacional (`:tracking`); si el agente usa directivas kbase (`@buscar_*`,
      `@discourse`) el mensaje se rutea a la kbase y no envía adjuntos.

## Frontend

- [x] Tab "📎 Archivos" en `EditTemplate.vue` (índice dinámico `agendasTabIndex + 1`).
- [x] Subir / listar (scroll, ~3 visibles) / borrar + snippet copiable `@adjunto:nombre`.
- [x] **Selector de adjuntos** en modal que inserta `@adjunto:nombre` en el cursor
      (reemplaza el autocompletado con `MentionBox`). → [[Frontend]]
- [x] **Selector de directivas** en modal (`@buscar_*`, `@discourse`, `@agendar_calendar`,
      `@crear_ticket`); `@buscar_foro` ofrece las fuentes Discourse existentes.
- [x] Área de subida en una línea con botón estilo Chatwoot y "Subir archivo".
- [x] i18n `es`/`en` bajo `TRACKING_TEMPLATES.FORM.ATTACHMENTS.*`.
- [x] **Renombrar** adjunto en la UI (inline, usando la API `rename`).
- [ ] Verificar corriendo la app el flujo UI (subir → insertar directiva → guardar prompt).

## Calidad

- [x] Specs de modelo (unicidad de `name`) + request specs del controlador + spec del job.
- [x] Spec de `DirectiveReferenceService` (rename/remove, boundary, estados vivos).
- [ ] Caso de testeo funcional (subir archivo → directiva → envío en conversación).
- [ ] Verificar límites del canal WhatsApp con un envío real.
