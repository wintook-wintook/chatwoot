---
titulo: API y rutas — AI Agent Attachments
tipo: diseno
tags: [ai-agent-attachments, api]
---

# API y rutas

Endpoints para gestionar los adjuntos de un Agente IA (`tracking_template`). Anidados
bajo el recurso existente `tracking_templates`.

Controlador base actual:
`app/controllers/api/v1/accounts/tracking_templates_controller.rb`.

## Rutas previstas (Opción A — tabla `ai_agent_attachments`)

```
GET    /api/v1/accounts/:account_id/tracking_templates/:template_id/attachments
POST   /api/v1/accounts/:account_id/tracking_templates/:template_id/attachments
PATCH  /api/v1/accounts/:account_id/tracking_templates/:template_id/attachments/:id   # renombrar
DELETE /api/v1/accounts/:account_id/tracking_templates/:template_id/attachments/:id
```

- `POST` recibe `multipart/form-data`: `file` (binario) + `name` (clave de la directiva).
- `GET` devuelve lista: `{ id, name, filename, byte_size, content_type, url, created_at }`.
- `PATCH` solo cambia `name` (no re-sube el archivo).

## Definir en `config/routes.rb`

Anidar `resources :attachments` dentro del bloque de `tracking_templates` del namespace
`api/v1/accounts`. Marcar con `# proyecto@ai_agent_attachments`.

## Permisos / scoping

- Siempre `current_account` + el `tracking_template` debe pertenecer a la cuenta.
- Mismas políticas de autorización que el resto de `tracking_templates`.

## Notas

- La descarga/URL del archivo usa el `url_for` / `rails_blob_url` de ActiveStorage
  (igual que los adjuntos de mensajes).
- Si finalmente se elige la **Opción B** (`has_many_attached`), los endpoints operan
  sobre `ai_files` y no hay `name` editable (ver [[Modelo-de-datos]]).
