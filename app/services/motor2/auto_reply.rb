# frozen_string_literal: true

# Campaña con Vendedor IA — ¿lo que llegó es la RESPUESTA AUTOMÁTICA de su WhatsApp Business («Gracias por comunicarte,
# en breve te atendemos»)? WhatsApp no lo marca: se decide por señales.
#   known    el mismo texto que ese contacto ya mandó antes como automático (contact.additional_attributes)
#   strong   frases que solo dice una máquina: «mensaje automático», «en breve te atendemos», horario, menú de opciones
#   fast     llegó a los pocos segundos de nuestro mensaje: con «gracias por comunicarte» basta; si no, lo decide una
#            revisión corta con IA
# Un «fuera de la oficina / regreso el…» NO se toma aquí: lo atiende la IA y lo reprograma («más adelante»).
#
# Si es automática (Motor2::Reply#call): se marca el mensaje (content_attributes['auto_reply']), se recuerda en el
# contacto, la conversación lleva la etiqueta «autorespuesta», NO cuenta como que contestó, los toques siguen y la IA
# no le contesta a la máquina.
#   Motor2::AutoReply.new(tracking, message).call → true (lo manejó) | false (es de una persona: sigue lo normal)
class Motor2::AutoReply
  LABEL = 'autorespuesta'
  FAST = 20.seconds
  KNOWN_KEY = 'auto_reply_text'

  # Bastan solas.
  STRONG = [
    /(en breve|a la brevedad|lo antes posible|en un momento) (te|le|lo|la|nos)? ?(atender|contest|respond|comunic)/i,
    /(mensaje|respuesta) autom[aá]tic/i,
    /nuestro horario (de atenci[oó]n )?es/i,
    /(horario|d[ií]as) de atenci[oó]n/i,
    /bienvenid[oa] a /i,
    /(1️⃣|\b1[.)]).{1,120}(2️⃣|\b2[.)])/m, # menú de opciones
    /(selecciona|elige|escribe) (una opci[oó]n|el n[uú]mero)/i
  ].freeze
  # Una persona también lo dice («gracias por tu mensaje, sí me interesa»): solo cuentan si llegó en segundos.
  WEAK = /gracias por (comunicarte|contactar(nos|te)?|escribir(nos)?|tu mensaje|ponerte en contacto)/i
  # Vacaciones o fuera de la oficina: lo maneja la IA (reprograma con «más adelante»).
  AWAY = /(vacaciones|fuera de (la )?oficina|regreso el|estar[eé] ausente|out of office|no me encuentro)/i

  def initialize(tracking, message)
    @tracking = tracking
    @message = message
    @contact = message.conversation.contact
  end

  def call
    return false unless applies?
    return false unless auto?

    mark!
    true
  end

  def auto?
    return false if text.blank? || text.match?(AWAY)
    return true if known? || strong?
    return false unless fast?

    text.match?(WEAK) || Motor2::AutoReplyCheck.new(account: @tracking.account).auto?(text)
  end

  private

  def applies? = @tracking&.tracking_campaign&.motor2? && @message.incoming?

  def text = @message.content.to_s.strip

  def strong? = STRONG.any? { |p| text.match?(p) }

  def known?
    saved = @contact&.additional_attributes.to_h[KNOWN_KEY].to_s
    saved.present? && normalize(saved) == normalize(text)
  end

  def normalize(value) = value.downcase.gsub(/[^\p{L}\p{N}]+/, ' ').squish.first(300)

  # Llegó a los pocos segundos de nuestro último mensaje (la plantilla o el toque).
  def fast?
    last = @message.conversation.messages.where(message_type: :outgoing, private: false).where('id < ?', @message.id).last
    last.present? && (@message.created_at - last.created_at) <= FAST
  end

  def mark!
    attrs = @message.content_attributes.to_h.merge('auto_reply' => true)
    @message.update_columns(content_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
    remember!
    @message.conversation.add_labels([LABEL])
  rescue StandardError => e
    Rails.logger.warn("[Motor2::AutoReply] #{e.class}: #{e.message}")
  end

  def remember!
    return unless @contact

    extra = { KNOWN_KEY => text.first(500), 'auto_reply_at' => Time.current.iso8601 }
    @contact.update_columns(additional_attributes: @contact.additional_attributes.to_h.merge(extra)) # rubocop:disable Rails/SkipsModelValidations
  end
end
