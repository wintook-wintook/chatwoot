# frozen_string_literal: true

# Motor 2.0 — lo que se decidió en el turno, aplicado después de mandar el mensaje:
#   done      → objetivo cumplido (el seguimiento termina)
#   discarded → no le interesa / no es para nosotros (se cancela, outcome «rejected»)
#   handoff   → nota privada, se asigna a quien dice la ficha y el agente se pausa
class Motor2::Outcomes
  def initialize(tracking, conversation, config)
    @tracking = tracking
    @conversation = conversation
    @config = config
  end

  def apply(kind, text)
    case kind
    when 'done' then done(text)
    when 'discarded' then discarded(text)
    when 'handoff' then handoff(text)
    end
  end

  private

  def done(text)
    note("🎯 Objetivo cumplido: #{text}")
    @tracking.mark_objective_met!
  end

  def discarded(text)
    note("🚫 Descartado por el agente: #{text}")
    @tracking.update_columns(outcome: 'rejected', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.cancel!
  end

  def handoff(text)
    note("🙋 El agente lo pasa a una persona: #{text}")
    assign
    @tracking.update_columns(outcome: 'handed_off', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  def assign
    setting = @config.skill(:handoff)
    user = @config.account.users.find_by(id: setting['user_id']) if setting['user_id'].present?
    team = @config.account.teams.find_by(id: setting['team_id']) if setting['team_id'].present?
    attrs = { assignee: user, team: team }.compact
    @conversation.update(attrs) if attrs.any?
  rescue StandardError => e
    Rails.logger.error("[Motor2] asignar: #{e.message}")
  end

  def note(text) = Motor2::Delivery.note(@tracking, @conversation, text)
end
