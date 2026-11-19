# frozen_string_literal: true

# «Atención a prospectos» › «Qué sabe» › «¿Dónde están tus productos y precios?» (answers['price_source']):
#   'catalog'          en el Catálogo de productos (catalog_items)
#   'google_sheet:12'  en una hoja de Google conectada (mejor en modo «Datos»: se busca exacto)
#   'canned'           en las respuestas predefinidas
#   'none'             no da precios: un asesor se los da
# La fuente elegida entra sola a las del agente (extra_sources) y el prompt dice que los precios se
# buscan SOLO ahí. Los agentes de antes con «Lo que vendo y sus precios están en mi Catálogo»
# (business_use_catalog) quedan en 'catalog'. Lo incluye Motor2::Functions::Prospects.
module Motor2::Functions::ProspectPrices
  PRICE_SOURCES = %w[catalog canned none].freeze

  def price_source
    value = answer(:price_source).to_s
    return value if PRICE_SOURCES.include?(value) || value.match?(/\Agoogle_sheet:\d+\z/)

    answer(:business_use_catalog) == true ? 'catalog' : 'canned'
  end

  # Las fuentes que pone la función: la de los precios (si es el catálogo o una hoja).
  def extra_sources
    key = price_source
    key == 'catalog' || key.start_with?('google_sheet:') ? [key] : []
  end

  # La línea de «EL NEGOCIO» sobre productos y precios.
  def price_line
    case price_source
    when 'none' then '- Precios: NO los das. Si pregunta un precio, dile que un asesor se lo da y sigue con lo tuyo.'
    when 'canned' then '- Productos y precios: búscalos con buscar_en_fuentes en las respuestas predefinidas.'
    else "- Productos y precios: búscalos con buscar_en_fuentes SOLO en «#{price_source_name}» (fuente: #{price_source_name}); " \
         'no los busques ni los saques de otra parte.'
    end
  end

  def price_source_name
    entry = Motor2::SourceMap.new(config.account).entries([price_source]).find { |e| e[:key] == price_source }
    entry ? entry[:name] : 'tus fuentes'
  end
end
