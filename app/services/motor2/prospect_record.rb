# frozen_string_literal: true

# Motor 2.0 — «Atención a prospectos»: lo que se supo del prospecto queda en su contacto (no solo en la nota),
# para filtrar y reportar:
#   - custom_attributes['temperatura_prospecto'] = caliente | tibio | frio  (atributo de contacto «Temperatura
#     del prospecto», tipo lista; se crea solo la primera vez: sale en los filtros de Contactos);
#   - additional_attributes['calificacion'] = { agente, fecha, temperatura, respuestas }.
module Motor2::ProspectRecord
  KEY = 'temperatura_prospecto'
  VALUES = %w[caliente tibio frio].freeze

  module_function

  def save(contact, template, state)
    answers = state.to_h['answers'].to_h
    temperature = state.to_h['temperature'].to_s.presence_in(VALUES)
    return if contact.nil? || (answers.empty? && temperature.nil?)

    ensure_attribute(contact.account) if temperature
    record = { 'agente' => template.name, 'fecha' => Time.current.to_date.iso8601, 'temperatura' => temperature, 'respuestas' => answers }
    write(contact, record.compact, temperature)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::ProspectRecord] contacto #{contact&.id}: #{e.class}: #{e.message}")
  end

  def write(contact, record, temperature)
    contact.update(additional_attributes: contact.additional_attributes.to_h.merge('calificacion' => record),
                   custom_attributes: contact.custom_attributes.to_h.merge({ KEY => temperature }.compact))
  end

  def ensure_attribute(account)
    account.custom_attribute_definitions.find_or_create_by!(attribute_key: KEY, attribute_model: :contact_attribute) do |definition|
      definition.attribute_display_name = 'Temperatura del prospecto'
      definition.attribute_display_type = :list
      definition.attribute_values = VALUES
      definition.attribute_description = 'La pone el agente de Atención a prospectos al calificarlo o pasarlo.'
    end
  end
end
