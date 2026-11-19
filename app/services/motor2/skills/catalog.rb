# frozen_string_literal: true

# «Catálogo» — buscar productos o servicios del Catálogo de la empresa, con su precio
# (Motor2::CatalogSearch). Lo que regresa cuenta como «visto»: el precio que salga de aquí no se
# toma por inventado.
#
#   skills.catalog = { 'on' => true }   (en «Atención a prospectos»: «Lo que vendo y sus precios están en mi Catálogo»)
class Motor2::Skills::Catalog < Motor2::Skills::Base
  def self.key = 'catalog'

  def on? = config.skill_on?(key)

  def tools
    [fn('buscar_en_catalogo', 'Busca productos o servicios del catálogo de la empresa, con su precio.', { consulta: STR }, %w[consulta])]
  end

  def instructions = '- Productos y precios: búscalos con buscar_en_catalogo; no des un precio que no salga de ahí o de tus fuentes.'

  def call(_name, args)
    result = Motor2::CatalogSearch.new(config.account).call(args['consulta'].to_s)
    rows = result[:results]
    trace.source(name: 'Catálogo', kind: 'catalog', query: args['consulta'], found: rows.map { |r| r.values.join(' · ') })
    @turn.seen << rows.to_json
    rows.any? ? result : { results: [], nota: 'No está en el catálogo. No lo inventes.' }
  end
end
