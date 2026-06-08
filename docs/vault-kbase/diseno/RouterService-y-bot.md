# RouterService y bot

## `ContactTrackings::RouterService`

Enruta un evento de seguimiento de contacto a una de:
`:rejected`, `:interested`, `:reschedule`, `:kbase`, `:botseller`, `:tracking`.

## `KnowledgeBaseResponseService`

Detecta **directivas** en el mensaje:
- `@buscar_predeterminadas` — busca en respuestas predefinidas.
- `@buscar_foro(nombre)` — busca en una fuente Discourse concreta.

Hace [[Busqueda-semantica]] y genera la respuesta con OpenAI `gpt-4o-mini`.

## `BotSeller::Dispatcher`

`app/services/bot_seller/dispatcher.rb` — envía el evento al bot externo vía
`INTERNAL_WEBHOOK_URL`.

> _Stub — completar._
