# frozen_string_literal: true

# feat/chat_interno (plan v2, R3) — «INTERNO» NO ES PARA CLIENTES
# Los despachadores preguntan aquí si un evento es de una conversación interna. Si lo es,
# solo lo reciben el tiempo real (ActionCableListener) y los avisos (NotificationListener);
# nada de bots, automatizaciones, casos, embudo, reportes, SLA, CSAT, webhooks,
# integraciones ni participación por asignación (abriría un directo a un tercero).
module InternalChannel::Events
  SYNC_LISTENERS = %w[ActionCableListener].freeze
  ASYNC_LISTENERS = %w[NotificationListener].freeze

  module_function

  def internal?(data)
    conversation = data[:conversation] || data[:message]&.conversation
    conversation.respond_to?(:internal?) && conversation.internal?
  end

  # Publica solo a las escuchas permitidas (en vez de a todas las suscritas).
  def publish_internal(listeners, allowed, method_name, event)
    listeners.select { |listener| allowed.include?(listener.class.name) }.each do |listener|
      listener.public_send(method_name, event) if listener.respond_to?(method_name)
    end
  end
end
