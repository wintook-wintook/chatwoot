# frozen_string_literal: true

# Seguimiento IA — crea un seguimiento delegado (desde el botón del caso o desde Dali).
#
#   AiFollowUps::Creator.new(account:, user:, conversation:, case_ticket: nil, params: {}).call
#
# params: objective (obligatorio), instructions, starts_at (Time o ISO; nada = ahora),
#         max_attempts (1..10), interval_value, interval_unit (minutes/hours/days),
#         on_finish (notify/assign), time_zone, template_name + template_language (plantilla de
#         WhatsApp para reabrir la ventana de 24 h; nada = el agente elige).
#         replace: true → si ya hay un Seguimiento IA vivo en la conversación, se cancela y arranca
#         este en la misma transacción (si algo falla, el anterior sigue).
# Rechaza (ArgumentError) si la conversación ya tiene un seguimiento vivo (sin replace) o uno
# de siempre: nunca contestan dos a la vez.
class AiFollowUps::Creator
  CLASSIC_LIVE = %w[pending scheduled active paused].freeze

  def initialize(account:, user:, conversation:, case_ticket: nil, params: {})
    @account = account
    @user = user
    @conversation = conversation
    @case_ticket = case_ticket
    @params = params.to_h.stringify_keys
  end

  def call
    validate!
    follow_up = AiFollowUp.new(attributes.merge(template_attributes))
    follow_up.add_log(:created, @user&.name)
    replaced = nil
    ActiveRecord::Base.transaction do
      replaced = cancel_live
      follow_up.add_log(:replaced, "##{replaced.id}") if replaced
      follow_up.save!
    end
    AiFollowUps::Notifier.new(follow_up).started(replaced: replaced)
    # Si empieza ya, el primer mensaje sale enseguida; si no, lo toma AiFollowUps::DueJob a su hora.
    AiFollowUps::RunJob.perform_later(follow_up.id, 'scheduled') unless follow_up.next_run_at.future?
    follow_up
  end

  private

  def validate!
    raise ArgumentError, 'Falta la conversación del cliente.' unless @conversation
    raise ArgumentError, 'Escribe qué quieres lograr.' if @params['objective'].blank?
    raise ArgumentError, "Esta conversación ya tiene un #{AiFollowUp::DISPLAY_NAME} activo." if AiFollowUp.live_for?(@conversation.id) && !replace?

    validate_template!
    classic = ContactTracking.where(conversation_id: @conversation.id, status: CLASSIC_LIVE).first
    return unless classic

    raise ArgumentError, "Este cliente ya tiene un seguimiento activo con el agente «#{classic.tracking_template&.name}». " \
                         'Páusalo o cancélalo primero.'
  end

  def replace?
    ActiveModel::Type::Boolean.new.cast(@params['replace'])
  end

  # El vivo de la conversación, cancelado (solo con replace).
  def cancel_live
    return unless replace?

    live = AiFollowUp.live.where(conversation_id: @conversation.id).lock.first
    live&.cancel!(by: @user)
    live
  end

  def validate_template!
    return if @params['template_name'].blank?
    return if AiFollowUps::Templates.new(@conversation).find(@params['template_name'], @params['template_language'])

    raise ArgumentError, "La plantilla «#{@params['template_name']}» no está aprobada en esta bandeja o no se puede usar " \
                         '(lleva archivo en el encabezado o variables en botones).'
  end

  def attributes
    { account: @account, conversation: @conversation, contact_id: @conversation.contact_id, case_ticket: @case_ticket,
      created_by: @user, objective: @params['objective'].to_s.strip.first(1000),
      instructions: @params['instructions'].to_s.strip.first(2000).presence, status: 'active',
      next_run_at: starts_at, max_attempts: @params['max_attempts'].presence&.to_i&.clamp(1, 10) || 3,
      interval_value: [@params['interval_value'].to_i, 1].max,
      interval_unit: @params['interval_unit'].presence_in(AiFollowUp::UNITS) || 'days',
      on_finish: @params['on_finish'].presence_in(AiFollowUp::ON_FINISH) || 'notify',
      time_zone: @params['time_zone'].presence }
  end

  def template_attributes
    template = AiFollowUps::Templates.new(@conversation).find(@params['template_name'], @params['template_language'])
    template ? { template_name: template[:name], template_language: template[:language] } : {}
  end

  def starts_at
    value = @params['starts_at']
    time = value.is_a?(String) ? Time.zone.parse(value) : value
    time && time > Time.current ? time : Time.current
  rescue ArgumentError
    Time.current
  end
end
