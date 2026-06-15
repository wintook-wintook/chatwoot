---
titulo: Visión y convenciones — AI Agent Attachments
tipo: diseno
tags: [ai-agent-attachments, vision]
---

# Visión y convenciones

## Qué es

**AI Agent Attachments** permite **adjuntar archivos a un Agente IA** (un
`tracking_template`) y que el agente los **envíe automáticamente en la conversación**
cuando su lógica lo decide. El disparo se declara en el **prompt complementario** del
Agente IA mediante la directiva **`@adjunto:nombre`**.

No es un sistema de archivos nuevo: **reutiliza ActiveStorage**, la forma nativa de
Chatwoot de guardar adjuntos (la misma que usan los mensajes).

## Alcance (hoy)

- **Tab "📎 Archivos"** en la edición del Agente IA, **después** del tab "📅 Agendas"
  (`EditTemplate.vue`). Subir, listar, renombrar (`nombre`) y borrar archivos.
- Cada archivo tiene un **`nombre`** (clave estable) usado por la directiva.
- **Directiva `@adjunto:nombre`** en el prompt complementario → al dispararse, el
  archivo se adjunta al mensaje saliente del Agente IA. Ver [[Directiva-y-envio]].

## Fuera de alcance (por ahora)

- Adjuntos como **contexto/RAG** (que la IA *lea* el archivo). Aquí solo se **envían**.
- Adjuntos en la **cabecera de plantillas de WhatsApp** (header media) — eso vive en el
  tab "📱 Plantillas WhatsApp" y es independiente.

## Capas

| Capa | Dónde | Detalle |
|---|---|---|
| Datos | `tracking_templates` + ActiveStorage (`active_storage_*`) | [[Modelo-de-datos]] |
| Modelo | `app/models/tracking_template.rb` | [[Modelo-de-datos]] |
| Directiva / envío | servicio del prompt complementario + job de envío | [[Directiva-y-envio]] |
| API | `tracking_templates_controller` (+ endpoints de adjuntos) | [[API-y-rutas]] |
| Frontend | `dashboard/.../settings/trackingTemplates/EditTemplate.vue` | [[Frontend]] |

## ⭐ Terminología

- **"Agente IA" = `tracking_template`** (nombre de producto/UI ↔ nombre en código),
  igual que en `vault-contact-tracking`.
- **"Adjunto del Agente IA"** = un archivo (blob ActiveStorage) asociado a un
  `tracking_template`, identificado por un **`nombre`** dentro de ese agente.

## Convenciones

- **Código/columnas/enums en inglés; UI en español** (i18n `es` y `en`).
- **Sin feature flag**: el módulo está siempre activo (no se añade entrada en
  `config/features.yml`).
- **Migraciones siempre al final**, una por cambio.
- **Commit solo cuando se pida.**

## Marcador en el código

Todos los archivos del módulo abren con `# proyecto@ai_agent_attachments`. Útil para
`grep -rn "proyecto@ai_agent_attachments" app/`.
