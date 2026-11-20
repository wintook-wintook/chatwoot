# frozen_string_literal: true

# Motor 2.0 — sugerencias para el asistente de un agente listo, con lo que la empresa contó de su negocio
# (sirve para cualquier giro: software, aire acondicionado, autos…). AiModels::REVIEW, temperatura baja.
#   areas      «Atención a clientes»: ejemplos de «sí es» y «no es» de cada área (lo que el cliente escribiría)
#   questions  «Atención a prospectos»: 3 a 5 preguntas para calificar
#
#   Motor2::BusinessSuggestions.new(account: a).call(kind: 'areas', business: { what:, who: }, areas: %w[support sales])
#   → { 'support' => { 'yes' => [...], 'no' => [...] }, … }  |  { 'questions' => [...] }
class Motor2::BusinessSuggestions < Cases::Ai::BaseService
  AREAS = { 'support' => 'Soporte: algo no funciona, falla, se descompuso, o duda de cómo usarlo',
            'sales' => 'Comercial: quiere conocer, cotizar, comprar o contratar',
            'admin' => 'Administrativo: facturas, pagos, saldo, datos fiscales de su cuenta',
            'other' => 'Otra área de la empresa' }.freeze
  SYSTEM = {
    'areas' => <<~TEXT,
      Escribes ejemplos de mensajes que mandarían los CLIENTES de este negocio por WhatsApp, para enseñar a un
      clasificador. Para cada área: 4 de «sí es de esta área» y 2 de «no es» (que se parezcan pero sean de otra
      área: p. ej. «quiero cotizar un minisplit» no es Soporte). Cortos, como escribe la gente, con el vocabulario
      del negocio. Responde solo JSON: {"support": {"yes": [], "no": []}, …}
    TEXT
    'questions' => <<~TEXT
      Escribes de 3 a 5 preguntas para calificar a un PROSPECTO nuevo de este negocio por WhatsApp (qué necesita, para
      cuándo, presupuesto u otra cosa que este negocio necesita saber para venderle). Una por línea, cortas y amables,
      con signos ¿?. Responde solo JSON: {"questions": []}
    TEXT
  }.freeze

  def call(kind:, business:, areas: [])
    kind = kind.to_s.presence_in(SYSTEM.keys) || 'areas'
    result = chat(system: SYSTEM[kind], user: context(business, kind, areas), json: true, temperature: 0.4, max_tokens: 700)
    kind == 'areas' ? clean_areas(result, areas) : { 'questions' => list(result.to_h['questions'], 5) }
  rescue StandardError => e
    Rails.logger.warn("[Motor2::BusinessSuggestions] #{e.class}: #{e.message}")
    {}
  end

  private

  def model = AiModels::REVIEW

  def context(business, kind, areas)
    lines = ["EL NEGOCIO: #{business[:what].presence || 'sin descripción'}", "SUS CLIENTES: #{business[:who].presence || '—'}"]
    lines << "ÁREAS:\n#{areas.filter_map { |a| "- #{a}: #{AREAS[a]}" if AREAS[a] }.join("\n")}" if kind == 'areas'
    lines.join("\n")
  end

  def clean_areas(result, areas)
    areas.select { |a| AREAS.key?(a) }.index_with do |area|
      row = result.to_h[area].to_h
      { 'yes' => list(row['yes'], 6), 'no' => list(row['no'], 4) }
    end
  end

  def list(value, max) = Array(value).map { |t| t.to_s.squish.first(200) }.compact_blank.uniq.first(max)
end
