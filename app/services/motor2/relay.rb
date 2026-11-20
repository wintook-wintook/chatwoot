# frozen_string_literal: true

# Motor 2.0 — el RELEVO del Vendedor de campaña (Plan-Motor-Agentes §11.16): al que le interesó la oferta
# se le pasa a quien sigue, en la misma conversación y sin que lo note:
#   - el agente que atiende la bandeja de la conversación (Motor2::InboxRouter.principal: con el par,
#     el de «Atención a clientes» si ya es cliente y el de «Atención a prospectos» si no);
#   - si no hay agente, o la empresa eligió «a una persona»: la persona o equipo del asistente, y si la
#     campaña tiene tablero de entrega, la entrega de siempre (TrackingCampaigns::HandOff, con plazo).
# El seguimiento de la campaña queda «interesado» y cumplido; el del agente que sigue empieza activo, con
# la bienvenida ya dada y una nota de contexto, y contesta el mismo mensaje (Motor2::ReplyJob).
#
#   Motor2::Relay.target_for(tracking, function) → { agent: template, name: } | { person: true, name: } | nil
#   Motor2::Relay.new(tracking, conversation, function).call(summary)
class Motor2::Relay
  def self.target_for(tracking, function)
    conversation = tracking&.conversation
    return nil unless conversation

    agent = function.relay_to_person? ? nil : next_agent(tracking, conversation)
    return { agent: agent, name: agent.name } if agent

    { person: true, name: 'equipo' }
  end

  def self.next_agent(tracking, conversation)
    agent = Motor2::InboxRouter.principal(conversation.account_id, conversation.inbox_id, contact: conversation.contact)
    agent if agent && agent.id != tracking.tracking_template_id && agent.agent_function != Motor2::Functions::CampaignSeller::KEY
  end

  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
  end

  def call(summary)
    interested!
    target = self.class.target_for(@tracking, @function)
    target&.dig(:agent) ? to_agent(target[:agent], summary) : to_person(summary)
  end

  private

  def interested!
    @tracking.update_columns(prospect_stage: 'interested', interested_at: @tracking.interested_at || Time.current, # rubocop:disable Rails/SkipsModelValidations
                             updated_at: Time.current)
  end

  # Cierra el de la campaña y abre el del agente que sigue; ese contesta el último mensaje del cliente.
  def to_agent(template, summary)
    note("Le interesó la campaña#{campaign_name}: pasa a «#{template.name}». #{summary}".strip)
    finish("relayed: #{template.name}")
    interest_files # las imágenes de «cuando muestre interés», antes de que conteste quien sigue
    tracking = ContactTracking.create!(Motor2::InboxRouter.attributes(template, @conversation)
                                         .merge(motor2_state: { 'welcome_sent' => true, 'from_campaign' => summary.to_s.first(300) }))
    last = @conversation.messages.incoming.order(:id).last
    Motor2::ReplyJob.perform_later(last.id) if last
    tracking
  end

  # A una persona: la entrega de la campaña (tablero y plazo) si la tiene; si no, se asigna y el agente se pausa.
  def to_person(summary)
    note("Le interesó la campaña#{campaign_name}: pasa a una persona. #{summary}".strip)
    delivered = @tracking.tracking_campaign&.handoff_board_id.present? && TrackingCampaigns::HandOff.new(@tracking).call
    assign(@function.handoff_target) unless delivered
    Motor2::AttendClock.start(@tracking, @conversation, @function) unless delivered # la entrega de la campaña ya trae su reloj
    @tracking.update_columns(outcome: 'relayed: person', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  def interest_files
    own = @tracking.tracking_template
    names = Motor2::Skills::Files.with_rule(own, 'interest', own.ai_agent_attachments).first(Motor2::Skills::Files::MAX_PER_MESSAGE)
    ContactTrackings::EventFiles.deliver(own, @conversation, names, Motor2::Delivery.sender(@conversation.account))
  end

  def finish(outcome)
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: outcome.first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def assign(target)
    attrs = {}
    attrs[:assignee_id] = @conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    attrs[:team_id] = @conversation.account.teams.where(id: target[:team_id]).pick(:id) if target[:team_id].present?
    @conversation.update!(attrs.compact) if attrs.compact.any?
  end

  def campaign_name
    name = @tracking.tracking_campaign&.name
    name.present? ? " «#{name}»" : ''
  end

  def note(text)
    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@tracking.tracking_template.name}: #{text}")
  end
end
