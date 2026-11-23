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
    @config = Motor2::Config.for(tracking)
  end

  def call
    ProspectLists.promote!(@conversation.contact) # contestó: deja la cuarentena de la lista fría (aunque sea para darse de baja)
    return opt_out! if ContactTrackings::OptOut.requested_in?(text)
    return if TrackingCampaigns::HandoffAttention.seller_owns?(@conversation)

    Motor2::FollowUp.revive!(@tracking) # contestó después del último recordatorio
    note_replied_touch!
    # Con seguimiento corto (Motor2::FollowUp), ese manda y los toques que faltaban ya no salen; si no, queda un solo
    # toque de recuperación en 3 días hábiles (ProspectReply).
    if Motor2::FollowUp.plan_for(@config.function)
      stop_campaign_touches!
    else
      ContactTrackings::ProspectReply.call(@tracking, at: @message.created_at)
    end
    TrackingCampaigns::ProspectClassifier.call(@tracking, @message)
    @tracking.with_lock { turn }
  end

  private

  def text = @message.content.to_s

  # Campaña con Vendedor IA: después de qué toque contestó la primera vez (resultados «por toque»).
  def note_replied_touch!
    state = @tracking.motor2_state.to_h
    return unless @tracking.tracking_campaign&.motor2? && state['touches_sent'] && !state.key?('replied_on_touch')

    @tracking.update_columns(motor2_state: state.merge('replied_on_touch' => state['touches_sent'])) # rubocop:disable Rails/SkipsModelValidations
  end

  # Campaña con Vendedor IA: contestó, así que los toques que faltaban ya no salen solos (pase lo que pase con la
  # respuesta del vendedor: antes seguían si su respuesta no preguntaba nada). Si deja de contestar, lo retoma el
  # seguimiento corto del vendedor (Motor2::FollowUp).
  def stop_campaign_touches!
    return unless @tracking.tracking_campaign&.motor2? && %w[pending scheduled].include?(@tracking.status)

    @tracking.update_columns(status: 'active', scheduled_for: Motor2::InboxRouter::NO_ATTEMPTS.from_now, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

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
      # Mismo orden que el 1.0: bienvenida, palabras clave y luego la respuesta. Los agentes de una
      # función (Atención a prospectos…) la mandan combinada con su primera respuesta, en un mensaje.
      combined = combined_welcome
      greeted_only = combined.nil? && welcome! && ContactTrackings::WelcomeMessage.only_greeting?(text)
      answer(welcome: combined) unless greeted_only || keyword_fired?
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
    names = Motor2::Skills::Files.welcome_names(@tracking.tracking_template)
    ContactTrackings::EventFiles.deliver(@tracking.tracking_template, @conversation, names, Motor2::Delivery.sender(@config.account))
    state.files_sent.concat(@tracking.tracking_template.ai_agent_attachments.where(name: names).ids)
    state['welcome_sent'] = true
    save_state
    true
  end

  # La bienvenida que va al inicio de la primera respuesta (agentes de una función), o nil.
  def combined_welcome
    return nil unless @config.function && @config.welcome.present? && !state['welcome_sent']

    @config.welcome
  end

  def answer(welcome: nil)
    result = Motor2::Runner.new(@config, state: state, conversation: @conversation, tracking: @tracking, welcome: welcome).call
    return failed(result.error) if result.error

    state['welcome_sent'] = true if welcome
    deliver(result)
  end

  def deliver(result)
    Motor2::Delivery.send_reply(@tracking, @conversation, result.reply, trace: result.trace,
                                                                        attachments: result.attachments.pluck(:signed_id))
    state.files_sent.concat(result.attachments.pluck(:id)).uniq!
    save_state
    result.after.each(&:call)
    Motor2::Labels.apply(@conversation, result.labels)
    Motor2::Outcomes.new(@tracking, @conversation, @config).apply(*result.decision) if result.decision
    Motor2::FollowUp.schedule!(@tracking, @config.function, result.reply) unless result.decision # si deja de contestar
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
