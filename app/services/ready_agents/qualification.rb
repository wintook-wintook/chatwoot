# frozen_string_literal: true

# Agentes listos — cómo califica el agente de prospectos, con lo que la empresa marcó al activarlo:
#
#   questions          las preguntas armadas que prendió (con su texto editado), en orden
#   objections         frases frecuentes del prospecto y cómo contestarlas
#   required_contact   datos que debe juntar antes de pasarlo (nombre, correo, empresa, ciudad)
#   missing_contact    cuáles de esos datos faltan todavía
#
# En `settings`: qualify [{ key, on, text }], objections [{ objection, answer }], required_contact [..].
# Sin `qualify` guardado (agentes de antes) va la de «qué necesita» prendida, como viene en el formulario.
module ReadyAgents::Qualification
  QUESTIONS = {
    'need' => { label: 'Qué necesita y para qué', ask: '¿Qué necesitas y para qué lo quieres?', on: true },
    'when' => { label: 'Para cuándo', ask: '¿Para cuándo lo necesitas?' },
    'budget' => { label: 'Presupuesto', ask: '¿Tienes un presupuesto aproximado?' },
    'decides' => { label: 'Quién decide', ask: '¿Tú decides la compra o alguien más?' },
    'location' => { label: 'Ubicación', ask: '¿En qué ciudad o zona estás?' },
    'quantity' => { label: 'Cantidad o tamaño', ask: '¿Qué cantidad o tamaño necesitas?' },
    'source' => { label: 'Cómo nos conoció', ask: '¿Cómo nos conociste?' }
  }.freeze
  CONTACT_FIELDS = {
    'name' => 'nombre', 'email' => 'correo', 'company' => 'empresa', 'city' => 'ciudad'
  }.freeze
  TEMPERATURES = %w[caliente tibio frio].freeze
  MAX_OBJECTIONS = 15

  module_function

  # [{ key:, label:, ask: }] de las prendidas, en el orden del catálogo.
  def questions(agent)
    saved = Array(agent.setting(:qualify)).index_by { |q| q['key'].to_s }
    QUESTIONS.filter_map do |key, base|
      row = saved[key]
      on = row ? ActiveModel::Type::Boolean.new.cast(row['on']) : base[:on]
      next unless on

      { key: key, label: base[:label], ask: row&.dig('text').presence || base[:ask] }
    end
  end

  def objections(agent)
    Array(agent.setting(:objections)).filter_map do |row|
      objection = row['objection'].to_s.strip
      answer = row['answer'].to_s.strip
      { objection: objection, answer: answer } if objection.present? && answer.present?
    end.first(MAX_OBJECTIONS)
  end

  def required_contact(agent)
    Array(agent.setting(:required_contact)).map(&:to_s) & CONTACT_FIELDS.keys
  end

  # Los datos obligatorios que faltan, en palabras («correo», «empresa»). `noted` = lo que el
  # prospecto dio en este turno (actualizar_contacto), que en el chat de prueba no se guarda.
  def missing_contact(agent, contact, noted = {})
    required_contact(agent).reject { |field| present?(field, contact, noted) }.map { |field| CONTACT_FIELDS[field] }
  end

  CHECKS = {
    'name' => ->(c) { c.name.present? && !c.name.to_s.match?(/\A[+\d\s()-]+\z/) }, # el teléfono no es nombre
    'email' => ->(c) { c.email.present? },
    'company' => ->(c) { c.additional_attributes.to_h['company_name'].present? || c.try(:organization).present? },
    'city' => ->(c) { c.additional_attributes.to_h['city'].present? }
  }.freeze

  def present?(field, contact, noted)
    noted[CONTACT_FIELDS[field]].present? || (contact.present? && CHECKS[field].call(contact))
  end

  # Lo que dio con actualizar_contacto, limpio (el correo solo si es válido).
  def contact_data(args)
    data = args.to_h.slice('nombre', 'correo', 'empresa', 'ciudad').transform_values { |v| v.to_s.strip }.compact_blank
    email = data['correo'].to_s.downcase
    email.match?(URI::MailTo::EMAIL_REGEXP) ? data.merge('correo' => email) : data.except('correo')
  end
end
