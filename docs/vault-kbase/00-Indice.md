# 00 · Índice — Base de Conocimiento (MOC)

Mapa de contenido del módulo **Base de Conocimiento**. Notas atómicas conectadas por
`[[wikilinks]]`; abre el grafo de Foam/Obsidian para ver las relaciones.

> Estado: rama `feat/kbase_contact_tracking`. Módulo **implementado**; bóveda en
> construcción (notas stub que se irán completando).

## Diseño

- [[Vision-y-convenciones]] — qué es el módulo, capas, convenciones de código/UI.
- [[Arquitectura]] — frontend `knowledgeSources/` + backend + pgvector, de un vistazo.
- [[Flujo-de-vectorizacion]] — `after_commit` → Sidekiq → OpenAI embeddings → `knowledge_items`.
- [[Sync-Discourse]] — webhook + jobs de sync bulk/individual, chunking, rate limiting.
- [[Integracion-Google-Docs]] — plan: Google Docs/Sheets como fuente; polling por `modifiedTime`, re-chunk, Sheets FAQ+datos.
- [[Busqueda-semantica]] — `KnowledgeItem.search_by_embedding`, umbrales, configuración.
- [[RouterService-y-bot]] — `ContactTrackings::RouterService`, directivas, `BotSeller::Dispatcher`.

## Implementación

- [[Estado-actual]] — qué está hecho y qué falta (migraciones en producción).
- [[Archivos-reales]] — mapa de archivos frontend/backend reales.
- [[Pendiente]] — tareas abiertas.

## Relación con otras bóvedas

- Conecta con la bóveda de **Tickets** en el bloque **2H** (un ticket cerrado genera un
  `Article` y se vectoriza). Ver la nota de tickets sobre integración KB.
