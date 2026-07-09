---
titulo: Archivos reales — AI Agent Attachments
tipo: implementacion
tags: [ai-agent-attachments, archivos]
---

# Archivos reales (a tocar / crear)

> Estado: **por construir**. Esta lista es el mapa objetivo; se marca [x] a medida que se
> implementa. Todo abre con `# proyecto@ai_agent_attachments`.

## Backend

- [x] `db/migrate/20260615000001_create_ai_agent_attachments.rb` — tabla (Opción A) · migrada
- [x] `app/models/ai_agent_attachment.rb` — `has_one_attached :file`, `belongs_to
      :tracking_template, :account`, `name` slug único por template **(NUEVO)**
- [x] `app/models/tracking_template.rb` — `has_many :ai_agent_attachments, dependent:
      :destroy` **(EDITADO)**
- [x] `app/controllers/api/v1/accounts/tracking_templates/attachments_controller.rb`
      — CRUD de adjuntos (index/create/update/destroy) **(NUEVO)**
- [x] `config/routes.rb` — `resources :attachments` anidado en `tracking_templates` **(EDITADO)**
- [x] Parseo + envío de `{{nombre}}` en
      `app/jobs/contact_tracking_response_analyzer_job.rb` (`send_auto_reply` +
      `resolve_attachment_directives` + hint al system prompt + const
      `MAX_DIRECTIVE_ATTACHMENTS`). Reutiliza el blob vía signed_id en MessageBuilder. **(EDITADO)**

## Frontend

- [x] `app/javascript/dashboard/api/aiAgentAttachments.js` — api client (list/upload/rename/remove) **(NUEVO)**
- [x] `app/javascript/dashboard/routes/dashboard/settings/trackingTemplates/EditTemplate.vue`
      — tab "📎 Archivos" (idx `archivosTabIndex = agendasTabIndex + 1`), subir/listar/borrar +
      snippet copiable, y **autocompletado `{{nombre}}`** con `MentionBox` en el textarea de
      Entrenamiento **(EDITADO)**
- [x] i18n `TRACKING_TEMPLATES.FORM.ATTACHMENTS.*` en `es` y `en` **(EDITADO)**

> Nota: en modo **create** el tab pide "guardar primero" (los adjuntos requieren un
> `tracking_template_id` ya existente, por la API anidada). La gestión en vivo es en **edit**.
> Falta `rename` en la UI (la API ya lo soporta) y verificación corriendo la app.

## Referencias del patrón a imitar (Contact Tracking)

- Directivas del prompt complementario: `@agendar_calendar`, `@buscar_predefinidas`.
- Subida de adjuntos nativa: compositor de mensajes de Chatwoot (ActiveStorage).
