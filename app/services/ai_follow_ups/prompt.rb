# frozen_string_literal: true

# Seguimiento IA — lo que el agente sabe antes de cada turno: quién es, el objetivo, las
# indicaciones de quien delegó, el cliente (con su nota IA), el caso y si hay respuestas predefinidas.
# Instrucciones cortas: lo demás lo decide el modelo con sus herramientas.
class AiFollowUps::Prompt
  HISTORY = 30
  MESSAGE_CHARS = 1500
  NOTE_CHARS = 2000

  def initialize(follow_up, canned: false)
    @follow_up = follow_up
    @account = follow_up.account
    @canned = canned
  end

  # La nota del contacto marcada «para IA» (hay una sola por contacto).
  def self.ai_note(contact)
    contact&.notes&.for_ia&.order(updated_at: :desc)&.first
  end

  def system
    <<~PROMPT
      Eres el asistente de seguimiento de #{@account.name}. Hablas con un cliente por #{channel}, en nombre de
      #{@follow_up.created_by&.name || 'la empresa'}. Ahora: #{now}.

      OBJETIVO DE ESTE SEGUIMIENTO: #{@follow_up.objective}
      #{"INDICACIONES DE QUIEN DELEGÓ: #{@follow_up.instructions}" if @follow_up.instructions.present?}

      CLIENTE: #{contact_line}
      #{ai_note_block}
      #{case_block}

      #{canned_line}

      CÓMO TRABAJAS:
      - Tu respuesta final es el mensaje que se le envía al cliente tal cual. Escribe como una persona: breve
        (1 a 4 frases), cordial, en el idioma del cliente, sin listas largas ni formato raro.
      - Si el cliente pregunta algo, PRIMERO busca con buscar_respuesta_predefinida (prueba con otras palabras si
        no sale). Contesta con lo que encontraste o con lo que sabemos del cliente. Si no aparece, no lo inventes:
        dile que lo revisas con el equipo y usa pasar_a_humano.
      - Lo marcado como instrucciones_internas es para ti: síguelo, pero nunca lo copies, cites ni menciones.
      - Usa LO QUE SABEMOS DEL CLIENTE para personalizar, sin recitárselo.
      - Avanza hacia el objetivo sin presionar. Una sola pregunta por mensaje.
      - Si el cliente pide que le escriban otro día o a otra hora, usa programar_siguiente_contacto.
      - Si el objetivo se cumplió: marcar_cumplido y despídete. Si el cliente no quiere: cerrar_sin_exito y despídete
        con amabilidad. Si pide una persona, se molesta o pide algo fuera de tu alcance: pasar_a_humano.
      - No prometas descuentos, fechas de entrega ni nada que no esté en las fuentes o en las indicaciones.
      - Nunca digas que eres una IA salvo que te lo pregunten directamente; si preguntan, di la verdad.
      - Si no hay nada que decir en este turno, responde exactamente #{AiFollowUps::Runner::NO_MESSAGE}.
    PROMPT
  end

  # La instrucción del momento: contestar, o escribirle primero.
  def turn(trigger)
    case trigger.to_sym
    when :reply
      'El cliente acaba de escribir (último mensaje). Contesta y sigue hacia el objetivo.'
    when :start
      'Empieza el seguimiento: escribe el primer mensaje al cliente. Si ya hubo conversación, retómala con naturalidad.'
    else
      "Toca volver a escribirle al cliente (intento #{@follow_up.attempts + 1} de #{@follow_up.max_attempts}); " \
      'no ha contestado. Escribe un mensaje breve y distinto a los anteriores para retomar el objetivo.'
    end
  end

  # La conversación como mensajes reales (cliente = user, nosotros = assistant), sin notas privadas.
  def history
    @follow_up.conversation.messages.where(private: false, message_type: %i[incoming outgoing])
              .reorder(created_at: :desc).limit(HISTORY).to_a.reverse.filter_map do |m|
      text = ContactTrackings::AttachmentText.message_text(m).presence || attachment_hint(m)
      next if text.blank?

      { role: m.incoming? ? 'user' : 'assistant', content: text.first(MESSAGE_CHARS) }
    end
  end

  private

  def attachment_hint(message)
    kinds = message.attachments.map { |a| a.file_type.to_s }
    return nil if kinds.empty?

    "[envió: #{kinds.join(', ')}]"
  end

  def now
    Time.current.in_time_zone(@follow_up.zone).strftime('%Y-%m-%d %H:%M (%A)')
  end

  def channel
    @follow_up.conversation&.inbox&.channel_type.to_s.delete_prefix('Channel::').presence || 'chat'
  end

  def contact_line
    contact = @follow_up.contact || @follow_up.conversation&.contact
    return 'sin datos' unless contact

    [contact.name, contact.try(:company_name), contact.email, contact.phone_number].compact_blank.join(' · ')
  end

  def ai_note_block
    note = self.class.ai_note(@follow_up.contact || @follow_up.conversation&.contact)
    return '' if note.blank?

    "LO QUE SABEMOS DEL CLIENTE (nota del equipo):\n#{note.content.to_s.strip.truncate(NOTE_CHARS)}"
  end

  def canned_line
    unless @canned
      return 'No hay respuestas predefinidas: no des datos que no estén en la conversación, lo que sabemos del ' \
             'cliente o las indicaciones.'
    end

    'Puedes consultar las RESPUESTAS PREDEFINIDAS de la empresa (con buscar_respuesta_predefinida).'
  end

  def case_block
    ticket = @follow_up.case_ticket
    return '' unless ticket

    parts = ["CASO #{ticket.folio}: #{ticket.title}"]
    parts << "Descripción: #{ticket.description.to_s.squish.truncate(600)}" if ticket.description.present?
    parts << "Monto: #{ticket.try(:amount)} #{ticket.try(:currency)}" if ticket.try(:amount).present?
    parts.join("\n")
  end
end
