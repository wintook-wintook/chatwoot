---
titulo: Estado actual — AI Agent Attachments
tipo: implementacion
tags: [ai-agent-attachments, estado]
---

# Estado actual

Rama: `feat/ai_agent_attachments` (deriva de `develop`). Fecha de arranque: 2026-06-15.

## Resumen

🟡 **Diseño/plan creado, implementación no iniciada.** Esta bóveda define el alcance; el
código aún no existe.

## Hecho

- [x] Bóveda de diseño creada (esta carpeta), espejo de `vault-contact-tracking`.
- [x] Decidida la directiva: **`@adjunto:nombre`**.
- [x] Anclado el punto de UI: tab "📎 Archivos" tras "📅 Agendas" en `EditTemplate.vue`.
- [x] Confirmado: almacenamiento con **ActiveStorage** (nativo Chatwoot); se **extiende**
      `tracking_template` (no entidad nueva).

- [x] **Backend construido y migrado (Opción A):** tabla `ai_agent_attachments`, modelo
      `AiAgentAttachment` (slug único por agente + ActiveStorage), asociación en
      `TrackingTemplate`, controlador CRUD anidado y rutas. Rutas y validaciones verificadas.
- [x] **Frontend construido:** api client `aiAgentAttachments.js`, tab "📎 Archivos" en
      `EditTemplate.vue` (subir/listar/borrar + snippet copiable) y **autocompletado
      `@adjunto:`** con `MentionBox` en el textarea de Entrenamiento. i18n es/en.
- [x] **Parser de envío construido:** `send_auto_reply` resuelve `@adjunto:nombre`,
      reutiliza el blob (signed_id → MessageBuilder), limpia el texto y respeta
      `MAX_DIRECTIVE_ATTACHMENTS`. Sintaxis OK, código limpio en rubocop. → [[Directiva-y-envio]]

- [x] **Verificado sobre la app viva (2026-06-15):** API CRUD por HTTP real (201/200,
      validaciones 422 nombre/duplicado/sin-archivo, 401 sin auth, PATCH 200) y parser
      end-to-end vía `send_auto_reply` en conversación real → mensaje saliente con el
      archivo **reusando el blob** (mismo `blob_id`), tokens limpiados, adjunto inexistente
      omitido. GUI Vue no conducida en navegador (sin motor de navegador en el entorno);
      se verificó la API que el tab consume.

## Pendiente

- Verificación **visual** de la GUI (tab Archivos + autocompletado) en navegador.
- UI: renombrar adjunto (API ya lo soporta).
- Soporte de `@adjunto:` en el mensaje proactivo y combinado con directivas kbase.
- Validación de tipo/peso por canal. Ver [[Archivos-reales]] y [[Pendiente]].
