# Búsqueda semántica

`KnowledgeItem.search_by_embedding` (gem `neighbor`, distancia coseno sobre
`embedding VECTOR(1536)`).

## Configuración (en `account.custom_attributes['kbase_search']`)

- `similarity_threshold` — default **0.20**
- `max_results` — default **3**
- `max_context_chars` — default **6000**

La pestaña **"Prueba de búsqueda"** del `Index.vue` permite probarla en vivo.

Consume lo generado por [[Flujo-de-vectorizacion]] y [[Sync-Discourse]]; la usa
[[RouterService-y-bot]] para responder.

> _Stub — completar._
