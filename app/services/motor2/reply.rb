# frozen_string_literal: true

# Motor 2.0 — el cliente escribió y su conversación la atiende un agente 2.0. Lo de siempre
# (baja, vendedor atendiendo, calificación de campaña, palabras clave, bienvenida) se hace con
# las mismas piezas del 1.0, sin tocarlas; la respuesta la escribe Motor2::Runner.
#
# Un turno a la vez por seguimiento (with_lock: también lo usa ContactTrackingJob, así que un
# intento y una respuesta nunca salen juntos).
class Motor2::Reply
  def initialize(tracking, message)
    @tracking = tracking
    @message = message
    @conversation = message.conversation
    @config = Motor2::Config.new(tracking.tracking_template)
  end

  def call
    return opt_out! if ContactTrackings::OptOut.requested_in?(text)
    return if TrackingCampaigns::HandoffAttention.seller_owns?(@conversation)

    ContactTrackings::ProspectReply.call(@tracking, at: @message.created_at)
    TrackingCampaigns::ProspectClassifier.call(@tracking, @message)
    @tracking.with_lock { turn }
  end

  private

  def text = @message.content.to_s

  def opt_out!
    ContactTrackings::OptOut.call(@conversation.contact, source: 'reply')
  end

  # Sin `return` dentro del bloque de with_lock: en Rails 7 salir así deshace la transacción.
  def turn
    if Motor2::LIVE.exclude?(@tracking.status)
      nil
    elsif human_stepped_in?
      @tracking.pause!
    else
      Motor2::TicketHook.call(@message)
      # Mismo orden que el 1.0: bienvenida, palabras clave y luego la respuesta.
      greeted_only = welcome! && ContactTrackings::WelcomeMessage.only_greeting?(text)
      answer unless greeted_only || keyword_fired?
    end
  end

  # Una persona le escribió al cliente después del último mensaje del agente: se hace a un lado.
  def human_stepped_in?
    since = @conversation.messages.where("#{AiFollowUp.message_attr_sql('ai_agent')} = 'true'").maximum(:created_at) ||
            @tracking.created_at
    @conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                 .where('created_at > ?', since)
                 .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end

  def keyword_fired?
    text.present? && ContactTrackings::KeywordActionService.new(@tracking, text, 'incoming').call
  end

  # La bienvenida de la ficha, una sola vez por seguimiento. Si el mensaje trae pregunta, se
  # contesta también (lección f52f3c79: la bienvenida se comía la pregunta).
  def welcome!
    return false if @config.welcome.blank? || state['welcome_sent']

    Motor2::Delivery.send_reply(@tracking, @conversation, @config.welcome)
    state['welcome_sent'] = true
    save_state
    true
  end

  def answer
    result = Motor2::Runner.new(@config, state: state, conversation: @conversation, tracking: @tracking).call
    return failed(result.error) if result.error

    Motor2::Delivery.send_reply(@tracking, @conversation, result.reply, trace: result.trace)
    save_state
    Motor2::Outcomes.new(@tracking, @conversation, @config).apply(*result.decision) if result.decision
  end

  def failed(error)
    Rails.logger.error("[Motor2] seguimiento ##{@tracking.id}: #{error}")
    @tracking.update_columns(last_error: error.to_s.first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def state = @state ||= Motor2::State.new(@tracking.motor2_state)

  def save_state
    @tracking.update_columns(motor2_state: state.to_h, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
