# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — MENSAJE DE BIENVENIDA FIJO
# ================================================================================
# Un Entrenamiento puede traer una sección:
#
#   [MENSAJE DE BIENVENIDA]
#   Hola, soy el asistente de…
#
# y el primer mensaje del cliente en la conversación se contesta con ese texto TAL CUAL,
# diga lo que diga el cliente: sin clasificar la rama, sin buscar en ninguna fuente y sin
# pasar por el modelo. Cierra con #bienvenida, para las automatizaciones.
#
# Antes se intentó desde el prompt («si BIENVENIDA_ENVIADA=NO responde solo con la
# bienvenida»), medido en la cuenta 568 (convs 2702, 2709, 2798, 2808): el motor ya había
# clasificado la rama y buscado en las predefinidas antes de que el modelo leyera la regla,
# así que llegaban la etiqueta y el pie de esa rama; el modelo recortaba el texto o se
# llevaba pegada la línea «Objetivo de la conversación» que el motor pone a continuación.
#
# Solo la primera vez: se marca en conversation.additional_attributes['welcome_sent'] por
# Agente IA (como agent_variables), así que si la conversación se resuelve y se reabre,
# o la regla de reapertura crea otro seguimiento del mismo agente, no se repite.
#
# La sección se quita del prompt que ve el modelo: si la viera, la volvería a mandar.
# ================================================================================

module ContactTrackings::WelcomeMessage
  STORE_KEY = 'welcome_sent'
  TAG       = '#bienvenida'

  HEADER_RE = /\A[ \t]*\[[ \t]*MENSAJE[ \t]+DE[ \t]+BIENVENIDA[ \t]*\][ \t]*(.*)\z/i
  # Cualquier otro rótulo cierra la sección, también los que llevan el texto en la misma
  # línea («[ESTILO] Dos párrafos…»), además del rótulo markdown.
  NEXT_HEADER_RE = /\A[ \t]*\[[^\]\n]+\]/

  module_function

  # El texto de la sección, o nil si el Entrenamiento no la trae (o la trae vacía).
  def text(prompt)
    _, body = split(prompt)
    body&.join("\n")&.strip.presence
  end

  # El prompt sin la sección.
  def strip(prompt)
    rest, body = split(prompt)
    return prompt.to_s if body.nil?

    rest.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # [líneas fuera de la sección, líneas de la sección (nil si no hay)]
  def split(prompt)
    rest = []
    body = nil
    dentro = false
    prompt.to_s.split("\n").each do |linea|
      if (match = linea.match(HEADER_RE))
        body = (body || []) + [match[1]].compact_blank
        dentro = true
      else
        dentro &&= !header?(linea)
        (dentro ? body : rest) << linea
      end
    end
    [rest, body]
  end

  def header?(linea)
    linea.match?(NEXT_HEADER_RE) || linea.match?(ContactTrackings::Assistant::DraftPieces::MARKDOWN_RE)
  end

  # El texto a enviar si a este mensaje le toca la bienvenida, o nil. Marca la conversación
  # en el mismo bloqueo: dos mensajes seguidos del cliente corren en jobs paralelos y solo
  # uno debe mandarla.
  def claim(tracking, conversation)
    welcome = text(tracking&.complementary_prompt)
    return nil if welcome.blank? || conversation.nil?

    "#{welcome}\n\n#{TAG}" if mark_sent(tracking, conversation)
  end

  # true si esta llamada la marcó como enviada. Se bloquea la fila por id, no el objeto:
  # el de message.conversation puede traer cambios sin guardar y with_lock se niega a
  # bloquearlo.
  def mark_sent(tracking, conversation)
    key = ContactTrackings::ConversationVariables.store_key(tracking)
    Conversation.transaction do
      locked = Conversation.lock.find(conversation.id)
      attrs  = locked.additional_attributes || {}
      # Una conversación que ya traía respuestas del bot antes de que el agente tuviera
      # bienvenida no la recibe a media plática.
      next false if attrs.dig(STORE_KEY, key).present? || bot_replied_before?(locked)

      sent = attrs[STORE_KEY].to_h.merge(key => Time.current.iso8601)
      locked.update_columns(additional_attributes: attrs.merge(STORE_KEY => sent)) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # content_attributes se guarda como texto JSON dentro de la columna json (doble
  # codificación), así que «->>'sentiment_auto_reply'» siempre da NULL: se busca en el texto.
  def bot_replied_before?(conversation)
    conversation.messages.outgoing.where("content_attributes::text LIKE '%sentiment_auto_reply%'").exists?
  end
end
