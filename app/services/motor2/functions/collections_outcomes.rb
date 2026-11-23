# frozen_string_literal: true

# «Cobranza» — lo que pasa cuando el agente decide (Motor2::Outcomes lo llama):
#   promise  (registrar_promesa)  → nota; el seguimiento termina (no se le cobra hasta la fecha)
#   claim    (ya_pague)           → nota con @mención al cobrador; se le asigna; termina
#   dispute  (aclarar_factura)    → nota, caso para el área y se le asigna al cobrador
#   handoff  (pasar_a_humano)     → nota, se le asigna al cobrador y el agente se pausa
# El cobrador: el de ese cliente en la cartera o, si no hay, el del agente.
class Motor2::Functions::CollectionsOutcomes
  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
    @customer = function.customer_for(conversation)
  end

  def apply(kind, text)
    case kind
    when 'promise' then finish("🗓️ Promesa de pago: #{text}.", "Promesa #{text}")
    when 'claim' then claim(text)
    when 'dispute' then dispute(text)
    when 'handoff' then handoff(text)
    end
  rescue StandardError => e
    Rails.logger.error("[Motor2::CollectionsOutcomes] #{e.class}: #{e.message}")
  end

  def booked(_meeting); end

  private

  def claim(text)
    assign
    finish("🧾 #{mention}dice que ya pagó: #{text}. Revisa el comprobante en Cobranza › Comprobantes.", 'Dice que ya pagó')
  end

  def dispute(text)
    assign
    open_case(text)
    finish("⚠️ #{mention}aclaración: #{text}.", 'Aclaración')
  end

  def handoff(text)
    assign
    note("🙋 #{mention}pasa al cobrador: #{text}")
    Motor2::AttendClock.start(@tracking, @conversation, @function)
    @tracking.update_columns(outcome: 'handed_off', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  def finish(note_text, outcome)
    note(note_text)
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: outcome.first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def note(text)
    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@tracking.tracking_template.name}: #{text}")
  end

  def collector = @collector ||= @customer&.collector || @conversation.account.users.find_by(id: @function.handoff_target[:user_id])

  def mention = collector ? "#{TrackingCampaigns::HandOff.mention(collector)} " : ''

  def assign
    attrs = { assignee_id: collector&.id, team_id: (@function.handoff_target[:team_id] if collector.nil?) }.compact
    @conversation.update!(attrs) if attrs.any?
  end

  def open_case(text)
    account = @conversation.account
    type_id = account.case_types.active.order(:id).pick(:id)
    Cases::OrchestratorService.new(account: account, contact: @conversation.contact, conversation: @conversation)
                              .create_for_manual(title: "Aclaración de cobranza: #{@customer&.name || @conversation.contact&.name}".first(200),
                                                 description: text.to_s, case_type_id: type_id, priority: 'medium',
                                                 assignee_id: collector&.id, team_id: @function.handoff_target[:team_id])
  end
end
