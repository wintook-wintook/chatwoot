# Arquitectura

## Frontend — `app/javascript/dashboard/.../knowledgeSources/`

- **Index.vue** — 4 tabs: Contenido indexado / Fuentes / Prueba de búsqueda / Configuración.
- **SourceCard.vue** — tarjeta de fuente (estado webhook, progreso de sync, copy URL).
- **AddSourceModal.vue** — 2 tabs (Configuración + Categorías), genera webhook secret.
- **api.js** — endpoints: items, item_categories, sources CRUD, sync, search, etc.

## Backend

- **knowledge_base_controller.rb** — CRUD fuentes, items, búsqueda, provisioning webhook.
- Jobs: ver [[Sync-Discourse]] y [[Flujo-de-vectorizacion]].
- **KnowledgeBaseResponseService** + **BotSeller::Dispatcher** → ver [[RouterService-y-bot]].

## Almacenamiento

- `knowledge_items.embedding VECTOR(1536)` (gem `neighbor`, `has_neighbors`).
- Configuración de búsqueda en `account.custom_attributes['kbase_search']`.

Detalle de archivos en [[Archivos-reales]].

> _Stub — completar._
