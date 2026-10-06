# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LOS CAMPOS DEL TIPO DE CASO DE CADA SERVICIO (observaciones SSUSA, 06/10/2026)
# ================================================================================
# @crear_ticket(tipo=Renta Unidades) por la vía de @solicitudes creaba el caso sin sus campos
# particulares (Material, Peso, Ubicación Recogida…): ese llenado solo existía en
# Cases::TicketCreatorService. Aquí se reusa el mismo extractor (Cases::Ai::FieldExtractor),
# pero con el texto de UN servicio, porque un mensaje puede pedir varios.
#
# Nada está escrito para grúas: los campos y cuáles son obligatorios salen del tipo de caso.
# Un tipo sin campos (o sin clave de OpenAI) no cambia nada.
#
#   found   → case_tickets.custom_attributes[key] (lo nuevo gana; lo que no vino se conserva)
#   missing → claves de los OBLIGATORIOS sin valor; el turno las pregunta (Turn#missing)
# ================================================================================

class ContactTrackings::ServiceRequests::Fields
  PENDING_KEY = 'faltan_campos'
  # @solicitudes(asignar=unidad): ese campo lo llena Choice#hold con la unidad apartada; la IA no
  # lo toca y no se le pregunta al cliente («Unidad: t» salía del peso, conv. 378).
  ASSIGNED_KEY = 'campo_asignado'

  Result = Struct.new(:found, :missing, keyword_init: true)

  # Las etiquetas de lo que falta, en el orden del tipo de caso.
  def self.missing_labels(ticket)
    claves = Array(ticket.metadata[PENDING_KEY])
    return [] if claves.empty? || ticket.case_type.nil?

    ticket.case_type.case_type_fields.ordered.select { |campo| claves.include?(campo.key) }.map do |campo|
      opciones = campo.field_list? ? Array(campo.options).join(', ') : ''
      opciones.present? ? "#{campo.label} (opciones: #{opciones})" : campo.label
    end
  end

  def self.date_field_missing?(ticket)
    claves = Array(ticket.metadata[PENDING_KEY])
    ticket.case_type&.case_type_fields&.any? { |campo| campo.field_type.to_s == 'date' && claves.include?(campo.key) } || false
  end

  def initialize(account:, case_type_id:, skip: nil)
    @account = account
    @skip = skip.to_s
    @case_type = case_type_id && account.case_types.includes(:case_type_fields).find_by(id: case_type_id)
  end

  def any?
    @case_type.present? && @case_type.case_type_fields.any?
  end

  # service_text: los datos de ESTE servicio. message_text: lo que escribió el cliente (contexto).
  def call(service_text:, message_text:, previous: {})
    previos = previous.to_h
    return Result.new(found: previos, missing: []) unless any? && extractor.available?

    extraidos = extractor.extract(conversation_text: prompt_text(service_text, message_text), case_type: @case_type)['values'].to_h.except(@skip)
    valores = previos.merge(extraidos)
    Result.new(found: valores, missing: required_keys.reject { |clave| present?(valores[clave]) })
  end

  private

  # «Equipo: plana» se copiaba al campo Material (conv. 380) y «Hiab 14 a 15 Ton» a Material y
  # Peso (conv. 383): el equipo y lo que aguanta son lo que se pide, no lo que se mueve.
  def prompt_text(service_text, message_text)
    'Datos de ESTE servicio. «Equipo» es la unidad que el cliente pide y sus toneladas son lo que AGUANTA: ' \
      'NO son la carga, el material ni el peso de lo que se transporta. Si el cliente no dice qué va a ' \
      "mover ni cuánto pesa, esos campos van en null:\n#{service_text}\n\n" \
      "Mensaje del cliente (si pide varios servicios, usa solo lo que es de este):\n#{message_text.to_s.truncate(3000)}"
  end

  def required_keys
    @case_type.case_type_fields.ordered.select(&:required).map(&:key) - [@skip]
  end

  def present?(valor)
    [true, false].include?(valor) || valor.present?
  end

  def extractor
    @extractor ||= Cases::Ai::FieldExtractor.new(account: @account)
  end
end
