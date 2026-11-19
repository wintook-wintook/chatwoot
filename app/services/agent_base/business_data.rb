# frozen_string_literal: true

# Base común de los agentes que le hablan a clientes (Motor 2.0, Agentes listos y Seguimiento IA):
# los DATOS DEL NEGOCIO de la cuenta. Se llenan una vez en «Cómo habla tu empresa» y todos los
# agentes los toman; lo que un agente tenga propio manda sobre esto.
#   - los de «Tu negocio» de Agentes listos: qué vende, a quién, dónde, por qué elegirnos, precios/pagos/tiempos;
#   - renglones libres: horario, dirección, teléfono, página, formas de pago, lo que sea fijo.
#
#   AgentBase::BusinessData.get(account)            → { 'fixed' => { 'what' => … }, 'rows' => [{ 'label', 'value' }] }
#   AgentBase::BusinessData.update!(account, attrs)
#   AgentBase::BusinessData.block(account)          → el bloque para el prompt ('' si no hay nada)
#
# Vive en account.custom_attributes['ai_business'].
module AgentBase::BusinessData
  FIXED = {
    'what' => 'Qué vende', 'who' => 'A quién le vende (cliente ideal)', 'coverage' => 'Dónde da servicio',
    'why' => 'Por qué elegirnos', 'practical' => 'Precios desde, formas de pago y tiempos'
  }.freeze
  KEY = 'ai_business'
  MAX_CHARS = 600
  MAX_ROWS = 30

  module_function

  # Si la cuenta nunca los guardó, salen de «Tu negocio» del primer agente de «Atención a
  # prospectos» que los tenga (se guardan en la cuenta la próxima vez que se guarde «Cómo habla tu
  # empresa»). Sus respuestas viven en motor2['answers'] (Plan-Motor-Agentes §11.14).
  def get(account)
    saved = account.custom_attributes.to_h[KEY].presence&.to_h || from_ready_agent(account)
    { 'fixed' => FIXED.keys.index_with { |k| saved.dig('fixed', k).to_s }, 'rows' => Array(saved['rows']) }
  end

  def from_ready_agent(account)
    answers = account.tracking_templates.where(agent_function: 'prospects', archived_at: nil).order(:id)
                     .map { |t| t.motor2.to_h['answers'].to_h }
                     .find { |a| FIXED.keys.any? { |k| a["business_#{k}"].present? } }
    answers ? { 'fixed' => FIXED.keys.index_with { |k| answers["business_#{k}"].to_s } } : {}
  end

  def update!(account, attrs)
    attrs = attrs.to_h.deep_stringify_keys
    fixed = FIXED.keys.index_with { |k| attrs.dig('fixed', k).to_s.strip.first(MAX_CHARS) }.compact_blank
    account.custom_attributes = account.custom_attributes.to_h.merge(KEY => { 'fixed' => fixed, 'rows' => rows(attrs['rows']) })
    account.save!
    get(account)
  end

  def rows(raw)
    Array(raw).first(MAX_ROWS).filter_map do |row|
      row = row.to_h.stringify_keys
      label = row['label'].to_s.squish.first(80)
      value = row['value'].to_s.strip.first(MAX_CHARS)
      { 'label' => label, 'value' => value } if label.present? && value.present?
    end
  end

  # Los renglones como «Dato: valor» (fijos primero).
  def lines(account)
    data = get(account)
    FIXED.filter_map { |k, label| "#{label}: #{data['fixed'][k]}" if data['fixed'][k].present? } +
      data['rows'].map { |r| "#{r['label']}: #{r['value']}" }
  end

  # skip: valores que el agente ya trae propios (no se repiten).
  def block(account, skip: [])
    skip = skip.compact_blank.map(&:strip)
    list = lines(account).reject { |line| skip.include?(line.split(': ', 2).last.to_s.strip) }
    return '' if list.empty?

    "DATOS DEL NEGOCIO (de la empresa, para todos sus agentes; lo propio de este agente manda):\n#{list.map { |l| "- #{l}" }.join("\n")}"
  end
end
