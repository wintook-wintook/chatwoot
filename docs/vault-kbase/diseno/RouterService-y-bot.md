# RouterService y bot

## `ContactTrackings::RouterService`

Enruta un evento de seguimiento de contacto a una de:
`:rejected`, `:interested`, `:reschedule`, `:kbase`, `:botseller`, `:tracking`.

## `KnowledgeBaseResponseService`

Detecta **directivas** en el `complementary_prompt` (precedencia en este orden):
- `@buscar_predefinidas` — pgvector local sobre Respuestas predefinidas.
- `@buscar_articulo` — pgvector local sobre artículos del Centro de Ayuda.
- `@buscar_foro(nombre)` — búsqueda en vivo en una fuente Discourse concreta.
- `@discourse` — búsqueda en vivo vía la integración Discourse del inbox.

Hace [[Busqueda-semantica]] y genera la respuesta con OpenAI `gpt-4o-mini`.

## `BotSeller::Dispatcher`

`app/services/bot_seller/dispatcher.rb` — envía el evento al bot externo vía
`INTERNAL_WEBHOOK_URL`.

> _Stub — completar._
