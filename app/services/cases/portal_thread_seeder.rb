# frozen_string_literal: true

# ================================================================================
# @tickets_cases — User Portal (P1)
# ================================================================================
# Servicio: Cases::PortalThreadSeeder
# Responsabilidad: sembrar los mensajes de un ticket abierto desde el portal en su
# conversación de Chatwoot.
#
#   1. (solo conversación NUEVA en inbox Api) mensaje entrante = cuerpo del cliente
#   2. nota privada (solo el agente) con el contexto del ticket
#   3. respuesta pública con el folio y los detalles para el cliente
#
# Los mensajes `incoming` solo se permiten en inboxes Channel::Api; si la conversación
# es reusada de otro canal (WhatsApp/email), el cuerpo del cliente va en la nota
# privada y en la descripción del ticket, no como mensaje entrante falso.
# ================================================================================

class Cases::PortalThreadSeeder
  def initialize(conversation:, ticket:, body:, new_conversation:, attachments: nil, portal: nil)
    @conversation     = conversation
    @ticket           = ticket
    @body             = body.to_s
    @new_conversation = new_conversation
    @attachments      = attachments.presence
    @portal           = portal
  end

  def perform
    incoming = create_incoming_if_possible
    create_private_note(with_attachments: incoming.nil?)
    create_public_reply
    @ticket
  end

  private

  def api_inbox?
    @conversation.inbox&.channel_type == 'Channel::Api'
  end

  # Mensaje entrante con el cuerpo del cliente. Solo en conversación nueva de inbox Api.
  def create_incoming_if_possible
    return unless @new_conversation && api_inbox?

    build_message(
      content:      @body.presence || @ticket.title,
      message_type: 'incoming',
      private:      false,
      attachments:  @attachments
    )
  end

  # Nota interna (solo agente) con el contexto del ticket.
  def create_private_note(with_attachments: false)
    build_message(
      content:      private_note_content,
      message_type: 'outgoing',
      private:      true,
      attachments:  with_attachments ? @attachments : nil
    )
  end

  # Respuesta pública con el folio: lo que ve el cliente por su canal.
  # En WhatsApp se envía como plantilla aprobada (regla de 24h de Meta).
  def create_public_reply
    build_message(
      content:         public_reply_content,
      message_type:    'outgoing',
      private:         false,
      template_params: whatsapp_template_params
    )
  end

  # @tickets_cases R2 — si el inbox destino es WhatsApp y el portal tiene plantilla
  # configurada, arma los template_params (folio como parámetro {{1}}).
  # send_on_whatsapp_service envía la plantilla cuando template_params está presente.
  def whatsapp_template_params
    return nil unless @conversation.inbox&.channel_type == 'Channel::Whatsapp'
    return nil if @portal&.acuse_template_name.blank?

    {
      name:             @portal.acuse_template_name,
      language:         @portal.acuse_template_language.presence || 'es',
      processed_params: { '1' => (@ticket.folio || "##{@ticket.id}") }
    }
  end

  def build_message(content:, message_type:, private:, attachments: nil, template_params: nil)
    params = { content: content, message_type: message_type, private: private }
    params[:attachments] = attachments if attachments.present?
    params[:template_params] = template_params if template_params.present?
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  rescue StandardError => e
    Rails.logger.error("[GestorTickets][Portal] seed message error (#{message_type}): #{e.message}")
    nil
  end

  def private_note_content
    lines = []
    lines << "🎫 Ticket creado desde el portal · *#{@ticket.folio || "##{@ticket.id}"}*"
    lines << "Tipo: #{@ticket.case_type&.name || '—'} · Prioridad: #{@ticket.priority}"
    lines << "Asunto: #{@ticket.title}"
    lines << ''
    lines << @body if @body.present?
    custom = custom_fields_summary
    if custom.present?
      lines << ''
      lines << 'Datos adicionales:'
      lines.concat(custom)
    end
    lines.join("\n")
  end

  def custom_fields_summary
    (@ticket.custom_attributes || {}).filter_map do |key, value|
      next if value.blank?

      "• #{key}: #{value}"
    end
  end

  def public_reply_content
    folio = @ticket.folio || "##{@ticket.id}"
    [
      "✅ ¡Tu solicitud quedó registrada! Folio: *#{folio}*.",
      "Tipo: #{@ticket.case_type&.name || '—'} · Prioridad: #{@ticket.priority}.",
      'Te avisaremos por este medio. Guarda tu folio para consultar el estado cuando quieras.'
    ].join("\n")
  end
end
