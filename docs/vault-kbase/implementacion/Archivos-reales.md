# Archivos reales

> _Stub — verificar rutas exactas contra la rama `feat/kbase_contact_tracking`._

## Frontend (`knowledgeSources/`)

- `Index.vue`, `SourceCard.vue`, `AddSourceModal.vue`, `api.js`.

## Backend

- `app/controllers/api/v1/accounts/knowledge_base_controller.rb`
- `app/jobs/knowledge_item_sync_job.rb`
- `app/jobs/discourse_knowledge_sync_job.rb`
- `app/jobs/discourse_topic_sync_job.rb`
- `app/models/knowledge_item.rb` (`has_neighbors :embedding`)
- `app/models/canned_response.rb` (callback `after_commit`)
- `app/services/bot_seller/dispatcher.rb`
- `KnowledgeBaseResponseService`, `ContactTrackings::RouterService`

Detalle de cada pieza en [[Arquitectura]], [[Flujo-de-vectorizacion]], [[Sync-Discourse]],
[[RouterService-y-bot]].
