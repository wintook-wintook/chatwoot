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

  # unknown_pending: opción @solicitudes(sin_dato=pendiente), ver #unknown.
  def initialize(account:, case_type_id:, skip: nil, unknown_pending: false)
    @account = account
    @skip = skip.to_s
    @unknown_pending = unknown_pending
    @case_type = case_type_id && account.case_types.includes(:case_type_fields).find_by(id: case_type_id)
  end

  def any?
    @case_type.present? && @case_type.case_type_fields.any?
  end

  # service_text: los datos de ESTE servicio. message_text: lo que escribió el cliente (contexto).
  # asked: las claves que se le pidieron en el turno anterior. customer_text: su mensaje tal cual.
  def call(service_text:, message_text:, previous: {}, asked: [], customer_text: nil)
    previos = previous.to_h
    return Result.new(found: previos, missing: []) unless any? && extractor.available?

    extraidos = extractor.extract(conversation_text: prompt_text(service_text, message_text), case_type: @case_type)['values'].to_h.except(@skip)
    valores = with_unknown(previos.merge(extraidos), Array(asked), customer_text.to_s)
    Result.new(found: valores, missing: missing_keys(valores))
  end

  # ── sin_dato=pendiente (27/11/2026, pruebas con la guía de SSUSA, conv. 200 y 209) ──────────
  # «No sé el peso exacto ni las medidas» repetía «Falta: Peso, Medidas» en cada mensaje: el
  # cliente no tenía cómo salir. Con la opción, el dato que se le pidió y dice no saber queda como
  # pendiente en el caso (lo ve el equipo) y ya no se pide. Sin IA, para que sea predecible:
  #   · el mensaje dice que no sabe o no tiene el dato («no sé», «no lo tengo», «desconozco»)
  #   · y nombra el campo («el peso», «las medidas»); si solo faltaba uno, basta con «no lo sé»
  # La fecha nunca: sin fecha no se puede programar.
  PENDING_VALUE = 'Pendiente: el cliente no lo sabe'
  UNKNOWN_RE = /\b(no\s+(?:l[oa]s?\s+)?s[eé]|no\s+(?:l[oa]s?\s+)?tengo|no\s+cuento\s+con|desconozco|no\s+(?:l[oa]s?\s+)?conozco|ni\s+idea)\b/i
  STOPWORDS = %w[para como cada desde hasta donde nombre].freeze

  def with_unknown(valores, asked, texto)
    return valores unless @unknown_pending && texto.match?(UNKNOWN_RE)

    valores.merge(unknown(missing_keys(valores) & asked, texto).index_with { PENDING_VALUE })
  end

  def unknown(pedidos, texto)
    candidatos = pedidos.reject { |clave| field(clave)&.field_type.to_s == 'date' }
    return candidatos if candidatos.one? && pedidos.one?

    candidatos.select { |clave| named?(field(clave), texto) }
  end

  def named?(campo, texto)
    words(campo).any? { |palabra| fold(texto).match?(/\b#{Regexp.escape(palabra)}/) }
  end

  def missing_keys(valores)
    required_keys.reject { |clave| present?(valores[clave]) }
  end

  private

  # «Equipo: plana» se copiaba al campo Material (conv. 380) y «Hiab 14 a 15 Ton» a Material y
  # Peso (conv. 383): el equipo y lo que aguanta son lo que se pide, no lo que se mueve.
  def prompt_text(service_text, message_text)
    'Datos de ESTE servicio. «Equipo» es la unidad que el cliente pide y sus toneladas son lo que AGUANTA: ' \
      'NO son la carga, el material ni el peso de lo que se transporta. Si el cliente no dice qué va a ' \
      'mover ni cuánto pesa, esos campos van en null. Los requisitos del equipo («con certificados», ' \
      "«en buenas condiciones», «5 extensiones») tampoco son material:\n#{service_text}\n\n" \
      "Mensaje del cliente (si pide varios servicios, usa solo lo que es de este):\n#{message_text.to_s.truncate(3000)}"
  end

  def required_keys
    @case_type.case_type_fields.ordered.select(&:required).map(&:key) - [@skip]
  end

  def present?(valor)
    [true, false].include?(valor) || valor.present?
  end

  def field(clave)
    @case_type.case_type_fields.find { |campo| campo.key == clave }
  end

  # Las palabras con que el cliente nombra el campo: las de su etiqueta y su clave («peso»,
  # «medidas», «contacto», «ubicacion», «recogida»…).
  def words(campo)
    return [] if campo.nil?

    "#{campo.label} #{campo.key.tr('_', ' ')}".then { |texto| fold(texto).scan(/[a-z]{4,}/) }.uniq - STOPWORDS
  end

  def fold(texto)
    I18n.transliterate(texto.to_s).downcase
  end

  def extractor
    @extractor ||= Cases::Ai::FieldExtractor.new(account: @account)
  end
end
