---
titulo: Modelo de datos — AI Agent Attachments
tipo: diseno
tags: [ai-agent-attachments, datos]
---

# Modelo de datos

El Agente IA es `tracking_templates` (esquema vivo en la cabecera de
`app/models/tracking_template.rb`). Este módulo añade **archivos asociados** + una
**clave `nombre`** por archivo para que la directiva pueda referenciarlos.

## Decisión: cómo asociar los archivos

Dos opciones; la directiva `{{nombre}}` necesita una **clave estable y única por
agente**, no solo el filename del blob (que puede repetirse o tener espacios).

### Opción A — Tabla intermedia `ai_agent_attachments` (recomendada)

Modelo nuevo con `has_one_attached :file` (ActiveStorage) + columna `name`:

```
ai_agent_attachments
  id                    :bigint  PK
  tracking_template_id  :bigint  FK → tracking_templates  (not null)
  account_id            :bigint  FK → accounts            (not null)
  name                  :string  not null   # clave de {{name}}
  created_at/updated_at :datetime

índices:
  index_ai_agent_attachments_on_tracking_template_id
  index_ai_agent_attachments_on_template_and_name  (tracking_template_id, name) UNIQUE
```

- `name` **único por agente** → `{{catalogo}}` resuelve sin ambigüedad.
- El binario real va en `active_storage_blobs/attachments` (nativo Chatwoot).
- Asociación: `TrackingTemplate has_many :ai_agent_attachments, dependent: :destroy`.

### Opción B — `has_many_attached` directo en `tracking_template`

```ruby
class TrackingTemplate < ApplicationRecord
  has_many_attached :ai_files
end
```

- Más simple, sin migración propia, pero la directiva tendría que referenciar por
  **filename del blob** (frágil: espacios, duplicados, sin alias legible).

> **Recomendación:** Opción A. Da `nombre` legible y único por agente, valida unicidad y
> permite renombrar sin re-subir. Confirmar en [[Pendiente]] antes de migrar.

## Validaciones previstas (Opción A)

- `name`: presente, único por `tracking_template_id`, longitud 1–60, slug recomendado.
- `file`: adjunto presente; validar `content_type` y tamaño máx (alinear con límites de
  adjuntos de mensajes de Chatwoot / canal destino, p. ej. WhatsApp).

## Migraciones (al final, una por cambio)

1. `create_ai_agent_attachments` — tabla + índices + FKs.

> Si se elige la Opción B no hay migración de tabla (ActiveStorage ya existe), pero se
> pierde la clave `nombre`. Ver [[Directiva-y-envio]] para el impacto en el parseo.
