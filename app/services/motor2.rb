# frozen_string_literal: true

# Motor 2.0 de Agentes a medida — docs/vault-tickets/implementacion/Plan-Motor-Agentes.md §11.
#
# Comparte las tablas del 1.0 (tracking_templates / contact_trackings) y se prende por agente:
# tracking_templates.engine = '2'. El modelo decide la plática; el código pone las reglas con
# habilidades (Motor2::Skills). El motor 1.0 (ContactTrackingResponseAnalyzerJob, RouterService)
# no se toca: solo hay dos desvíos, en Message#analyze_for_active_trackings (respuestas) y en
# ContactTrackingJob#generate_message (intentos, con Motor2::AttemptHook sin editar el job).
module Motor2
  ENGINE = '2'
  # El cliente suele mandar varios mensajes seguidos: se espera y se contesta solo el último.
  WAIT = 15.seconds
  # Los seguimientos que contestan. Pausado = lo atiende una persona.
  LIVE = %w[pending scheduled active].freeze

  module_function

  def on?(template)
    template.present? && template.engine.to_s == ENGINE
  end

  # El seguimiento 2.0 vivo de la conversación del mensaje (el más reciente), si lo hay.
  def tracking_for(message)
    return if message.conversation_id.blank?

    ContactTracking.joins(:tracking_template)
                   .where(conversation_id: message.conversation_id, status: LIVE + %w[paused])
                   .where(tracking_templates: { engine: ENGINE })
                   .order(created_at: :desc).first
  end

  # Para el desvío de Message: el mensaje es del cliente y lo atiende un agente 2.0.
  def takes?(message)
    message.incoming? && tracking_for(message).present?
  end
end
