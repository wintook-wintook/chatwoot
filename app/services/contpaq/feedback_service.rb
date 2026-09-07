# frozen_string_literal: true

# @kbase_contpaq — Calificacion de una respuesta del Agente de Servicio CONTPAQi.
#
# Solo backend: en esta etapa no se agrega el pulgar arriba/abajo a la conversacion.
# Lo que queda listo es poder calificar una respuesta ya entregada, que es lo que la
# interfaz necesitara despues.
#
# El `message_id` que devuelve /answer es el UNICO dato que hay que conservar: el cuerpo
# de /feedback/message no lleva conversacion ni el par pregunta/respuesta, todo eso lo
# resuelve el servidor a partir de ese identificador.
#
# Se guarda en content_attributes del mensaje saliente y no en una tabla propia: la
# relacion es uno a uno con ese mensaje, no tiene ciclo de vida propio y siempre se
# consulta en esa direccion (este mensaje -> su identificador). Es ademas donde el motor
# ya cuelga metadatos por mensaje (sentiment_auto_reply, en send_reply).
class Contpaq::FeedbackService
  KEY = 'contpaq'

  class << self
    # Cuelga del mensaje saliente el identificador de la respuesta de CONTPAQi.
    def remember(message, source:, message_id:)
      return if message.blank? || message_id.blank?

      attrs = message.content_attributes || {}
      attrs[KEY] = { 'message_id' => message_id.to_s, 'source_id' => source.id }
      message.content_attributes = attrs
      message.save!
    rescue StandardError => e
      # Que no se pueda calificar despues no justifica perder la respuesta ya enviada.
      Rails.logger.error "[CONTPAQi] ⚠️ No se pudo guardar el message_id: #{e.message}"
    end

    # ¿Este mensaje es una respuesta de CONTPAQi calificable?
    def ratable?(message)
      reference(message).present?
    end

    def reference(message)
      ref = message&.content_attributes&.dig(KEY)
      ref.is_a?(Hash) && ref['message_id'].present? ? ref : nil
    end
  end

  def initialize(message)
    @message = message
    @ref     = self.class.reference(message)
  end

  # rating: 1 = me sirvio, -1 = no me sirvio. Devuelve true solo si CONTPAQi confirma
  # que quedo guardada: un fallo de escritura aqui nunca se reporta como exito.
  def rate(rating, comments: nil)
    return false if @ref.blank?

    source = knowledge_source
    return false if source.blank?

    user_id = Contpaq::UserIdBuilder.new(@message.conversation&.contact, @message.account).build
    return false if user_id.blank?

    send_rating(source, user_id, rating, comments)
  end

  private

  def send_rating(source, user_id, rating, comments)
    ok = Contpaq::ServiceAgent.new(source).feedback(
      message_id: @ref['message_id'], rating: rating, user_id: user_id, comments: comments
    )
    persist_rating(rating, comments) if ok
    ok
  end

  # Se deja constancia local de la calificacion enviada. Calificar dos veces la misma
  # respuesta la sobrescribe tambien del lado de CONTPAQi, asi que aqui se refleja igual.
  def persist_rating(rating, comments)
    attrs = @message.content_attributes || {}
    attrs[KEY] = @ref.merge('rating' => rating.to_i, 'rated_at' => Time.current.iso8601,
                            'comments' => comments.presence).compact
    @message.content_attributes = attrs
    @message.save!
  rescue StandardError => e
    Rails.logger.error "[CONTPAQi] ⚠️ Calificacion enviada pero no registrada localmente: #{e.message}"
  end

  def knowledge_source
    @message.account.knowledge_sources.active.find_by(id: @ref['source_id'])
  end
end
