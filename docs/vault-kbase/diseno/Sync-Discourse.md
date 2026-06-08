# Sync con Discourse

Indexa temas del foro Discourse como `knowledge_items` vectorizados.

- **Webhook** `/webhooks/discourse/:source_id` (secret generado en `AddSourceModal`).
- **`discourse_knowledge_sync_job.rb`** — sync **bulk** con rate limiting (0.4s entre
  jobs), filtrado por categorías.
- **`discourse_topic_sync_job.rb`** — sync **individual** con **chunking** (6000 chars,
  overlap 800), retry en 429.

Cada chunk pasa por el pipeline de [[Flujo-de-vectorizacion]].

> _Stub — completar._
