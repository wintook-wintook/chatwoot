# frozen_string_literal: true

# Asistente (Dali) — funciones de cotizaciones (formato de OpenAI). Lo que hacen vive en
# Assistant::QuoteTools.
module Assistant::QuoteToolDefinitions
  D = Assistant::ToolDefinitions

  ITEM = { type: 'object', properties: {
    catalog_item_id: D.int('Id del producto o servicio (de search_catalog); vacío si es una partida libre'),
    description: D.str('Qué se cotiza; obligatoria en partidas libres'),
    quantity: { type: 'number', description: 'Cantidad (1 si no la dijo)' },
    unit_price: { type: 'number', description: 'Precio unitario sin IVA. Vacío = el del catálogo; en partida libre pregúntalo' },
    discount_percent: { type: 'number', description: 'Descuento % solo si lo pidió' },
    unit: D.str('Unidad (pieza, servicio, hora…), opcional')
  }, required: %w[quantity] }.freeze

  ALL = [
    D.fn('search_catalog', 'Busca productos y servicios del Catálogo (nombre, clave o descripción) con su precio sin IVA. ' \
                           'Úsala antes de cotizar para tomar el producto y su precio.',
         { query: D.str('Palabra del producto o servicio') }, %w[query]),
    D.fn('list_quotes', 'Lista cotizaciones que el usuario ve (las más recientes), de un cliente o abiertas.',
         { contact_id: D.int('Id del contacto'), organization_id: D.int('Id de la organización'),
           status: { type: 'string', enum: %w[open all], description: 'open = borrador o enviada' } }),
    D.fn('propose_create_quote', 'Propone una cotización (queda en borrador al confirmar). Primero busca al cliente (search) y ' \
                                 'cada producto (search_catalog). Si una partida libre no trae precio, pregúntalo antes.',
         { contact_id: D.int('Id del contacto al que se cotiza'),
           items: { type: 'array', items: ITEM, description: 'Partidas' },
           currency: D.str('Moneda (MXN, USD…); vacío = la de la empresa'),
           opportunity_id: D.int('Oportunidad abierta del cliente a la que se liga; vacío = la más reciente'),
           notes: D.str('Notas para el cliente, opcional') }, %w[contact_id items]),
    D.fn('propose_send_quote', 'Propone mandarle la cotización al cliente por su conversación más reciente.',
         { quote_id: D.int('Id de la cotización') }, %w[quote_id])
  ].freeze
end
