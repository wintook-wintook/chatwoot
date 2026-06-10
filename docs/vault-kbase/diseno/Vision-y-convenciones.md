# Visión y convenciones

El módulo **Base de Conocimiento** permite **búsqueda semántica** sobre contenido
(foro Discourse + respuestas predefinidas) y **respuestas automáticas** del bot en
los seguimientos de contacto.

## Convenciones

- Tablas/columnas/enums y **código en inglés**; **UI en español**.
- Búsqueda por **embeddings** (pgvector), no por keywords.
- La API key de OpenAI sale de la **integración OpenAI de la cuenta** (hook
  `app_id:'openai'`), con fallback a `ENV['OPENAI_API_KEY']`.

## Próximas notas

Ver [[Arquitectura]] para el panorama, y [[Flujo-de-vectorizacion]] para el detalle
del pipeline de embeddings.

> _Stub — completar._
