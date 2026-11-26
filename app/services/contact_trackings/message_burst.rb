# frozen_string_literal: true

# ================================================================================
# Mensajes seguidos del cliente, contestados juntos — opcional por agente (25/11/2026)
# ================================================================================
# El cliente escribe en ráfaga: «El sbaa» + «Sábado», o una foto y luego «¿sigue disponible?».
# Cada mensaje disparaba su análisis y el agente contestaba dos veces, la primera sin saber
# lo que venía.
#
# Con resources['group_seconds'] en el agente (Recursos › Canal y seguimiento), el análisis
# espera esos segundos; si mientras tanto llegó otro mensaje del cliente, ese análisis no
# contesta y el último lo hace con el texto de todos los que siguen sin respuesta. Es el
# patrón de Motor 2.0 (Motor2::ReplyJob, Motor2::WAIT). Sin la opción (0 o vacía), el
# agente contesta como siempre, sin espera.
# ================================================================================
module ContactTrackings::MessageBurst
  KEY = 'group_seconds'
  MAX_SECONDS = 30
  LIVE = %w[active scheduled pending paused].freeze

  module_function

  # Los segundos de espera de la conversación: los del agente de su seguimiento vivo (0 = sin espera).
  def seconds_for(conversation_id)
    ContactTracking.joins(:tracking_template).where(conversation_id: conversation_id, status: LIVE)
                   .pluck('tracking_templates.resources').map { |r| seconds(r) }.max.to_i
  rescue StandardError
    0
  end

  def seconds(resources)
    resources.to_h[KEY].to_i.clamp(0, MAX_SECONDS)
  end

  # ¿Llegó otro mensaje del cliente después de este? Entonces lo contesta el análisis de ese.
  def newer_incoming?(message)
    message.conversation.messages.incoming.exists?(['id > ?', message.id])
  end

  # El texto de los mensajes del cliente sin respuesta hasta este, uno por renglón, con sus
  # imágenes marcadas (ver MediaNote). nil si solo está este.
  def text(message)
    previos = pending_before(message)
    return nil if previos.empty?

    lineas = previos.map { |m| ContactTrackings::MediaNote.with_marks(m.content, m) }.compact_blank
    [*lineas, message.content.to_s.strip.presence].compact.join("\n")
  end

  def pending_before(message)
    mensajes = message.conversation.messages
    ultima = mensajes.where(message_type: :outgoing, private: false).where('id < ?', message.id).maximum(:id).to_i
    mensajes.incoming.where('id > ? AND id < ?', ultima, message.id).order(:id).to_a
  end
end
