# Flujo de vectorización

`CannedResponse`/`Article`/`Discourse topic` → **embedding** en PostgreSQL.

1. **`after_commit`** dispara el job (no `after_save`: el job corre en otra conexión y
   necesita el COMMIT hecho). Ej: `canned_response.rb`.
2. **`KnowledgeItemSyncJob`** (Sidekiq): busca/crea el `KnowledgeSource`, arma el texto,
   llama a OpenAI `/v1/embeddings` (`text-embedding-3-small` → 1536 floats) y hace
   **upsert** en `knowledge_items` (UNIQUE por `account_id + source_type + source_id`).
3. `source_type` ∈ `{ canned_response, discourse, article }`.

## API key

`openai_api_key(account)`: primero el hook `app_id:'openai'` de la cuenta; fallback
`ENV['OPENAI_API_KEY']`. El costo va a la cuenta.

Relacionado: [[Sync-Discourse]] (genera items de foro), [[Busqueda-semantica]] (los consume).

> _Stub — basado en memoria del proyecto; verificar contra código._
