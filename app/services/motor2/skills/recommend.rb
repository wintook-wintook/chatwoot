# frozen_string_literal: true

# «Atención a prospectos» — recomendar (los agentes de venta líderes proponen opciones concretas): con lo que
# busca y su presupuesto, 2 o 3 productos del Catálogo, con su precio tal cual y su foto (si la tiene).
# Solo si la empresa eligió «mis precios están en el Catálogo» (Functions::Prospects#skills).
#
#   memoria: state['recomendados'] = [ids]  (no se le recomienda dos veces lo mismo)
class Motor2::Skills::Recommend < Motor2::Skills::Base
  MAX = 3
  BUDGET_SLACK = 1.1 # hasta 10 % arriba de su presupuesto

  def self.key = 'recommend'

  def tools
    [fn('recomendar', 'Busca en el Catálogo 2 o 3 opciones que le sirvan, con lo que busca y su presupuesto (si lo dijo). ' \
                      'Las fotos se mandan solas.',
        { lo_que_busca: STR, presupuesto: { type: 'number', description: 'Su presupuesto, si lo dijo (solo el número)' } },
        %w[lo_que_busca])]
  end

  def instructions
    <<~TEXT.strip
      - RECOMENDAR: en cuanto sepas qué busca (y su presupuesto, si lo dijo), usa recomendar y propónle 2 o 3 opciones: el
        nombre y el precio de cada una tal cual vienen, y en una línea por qué le sirve. Solo lo que regrese recomendar;
        si no regresa nada, no inventes opciones. Después sigue con la pregunta pendiente.
    TEXT
  end

  def call(_name, args)
    items = options(args['lo_que_busca'].to_s, args['presupuesto'].to_f)
    return { opciones: [], nota: 'No hay opciones en el Catálogo para eso: no inventes; sigue con la plática.' } if items.empty?

    remember(items)
    rows = items.map { |item| row(item) }
    @turn.seen << rows.to_json # sus precios cuentan como vistos (Motor2::Runner#unsourced?)
    @turn.evidence << "Catálogo (recomendar): #{rows.to_json}" # y como confirmados (Motor2::AreaChecks#ensure_evidence)
    { opciones: rows }
  end

  private

  # Por palabras (Motor2::CatalogSearch) y, si dijo presupuesto, que le alcance; sin repetir lo ya recomendado.
  def options(wanted, budget)
    names = Array(Motor2::CatalogSearch.new(config.account).call(wanted)[:results]).pluck(:nombre)
    scope = config.account.catalog_items.active.where(name: names).where.not(id: Array(state['recomendados']))
    scope = scope.where(price: 1..(budget * BUDGET_SLACK)) if budget.positive?
    scope.with_attached_image.order(price: :desc).limit(MAX).to_a
  end

  # No se repiten y sus fotos van con el mensaje.
  def remember(items)
    state['recomendados'] = (Array(state['recomendados']) + items.map(&:id)).uniq.last(30)
    items.each { |item| @turn.attach_blob("catalogo-#{item.id}", item.name, item.image.blob) if item.image.attached? }
    trace.event(:recomendo, items.map(&:name).join(' · '))
  end

  def row(item)
    { nombre: item.name, precio: item.price.to_f, moneda: item.currency, descripcion: item.description.to_s.truncate(200),
      foto: item.image.attached? }.compact
  end
end
