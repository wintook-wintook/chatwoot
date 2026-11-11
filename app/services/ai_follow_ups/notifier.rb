# frozen_string_literal: true

# Seguimiento IA — avisa a quien delegó: nota privada en la conversación (con mención) y,
# si hay caso, nota en su bitácora. Con on_finish = 'assign' además le asigna la conversación.
class AiFollowUps::Notifier
  RESULTS = {
    'done' => '✅ cumplió el objetivo', 'failed' => '❌ cerró sin éxito', 'handed_off' => '🙋 pide una persona',
    'no_response' => '⏳ se quedó sin respuesta', 'blocked' => '⛔ no pudo escribir', 'cancelled' => 'se canceló'
  }.freeze

  def initialize(follow_up)
    @follow_up = follow_up
    @conversation = follow_up.conversation
    @user = follow_up.created_by
  end

  # replaced: el seguimiento que se canceló para arrancar este (se cambió el que corría).
  def started(replaced: nil)
    if replaced
      case_note("Se cambió el #{AiFollowUp::DISPLAY_NAME}: se canceló el anterior (iba en el intento " \
                "#{replaced.attempts.to_i} de #{replaced.max_attempts}) y arrancó el nuevo.")
    end
    case_note("#{AiFollowUp::DISPLAY_NAME} empezó. Objetivo: #{@follow_up.objective}", event: :tracking_triggered)
  end

  def finished
    text = "#{AiFollowUp::DISPLAY_NAME} #{RESULTS[@follow_up.status] || @follow_up.status}" \
           "#{": #{@follow_up.outcome}" if @follow_up.outcome.present?}"
    private_note(text)
    case_note(text)
    assign if @follow_up.on_finish == 'assign' || @follow_up.status == 'handed_off'
  end

  # Se reanuda en el renglón bajo «Delegar seguimiento»: el del caso si se delegó desde
  # uno; si no, el del panel de la conversación o la ficha del contacto.
  def paused_for_human
    where = @follow_up.case_ticket_id ? 'desde el caso' : 'desde «Delegar seguimiento» en la conversación o en la ficha del contacto'
    private_note("#{AiFollowUp::DISPLAY_NAME} se pausó porque una persona le escribió al cliente. Reanúdalo #{where} si quieres que siga.")
  end

  private

  def private_note(text)
    who = @user ? "#{TrackingCampaigns::HandOff.mention(@user)} " : ''
    @conversation.messages.create!(account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                                   message_type: :outgoing, private: true, sender: @user,
                                   content: "🤖 #{who}#{text}", content_attributes: { ai_follow_up_id: @follow_up.id })
  rescue StandardError => e
    Rails.logger.error("[AiFollowUp] nota privada: #{e.message}")
  end

  def case_note(text, event: :internal_note)
    ticket = @follow_up.case_ticket
    return unless ticket

    payload = if event == :tracking_triggered
                { agent: AiFollowUp::DISPLAY_NAME, objective: @follow_up.objective,
                  ai_follow_up_id: @follow_up.id }
              else
                { content: text }
              end
    ticket.case_events.create!(account: @follow_up.account, event_type: event, origin: :bot, actor: @user, payload: payload)
  rescue StandardError => e
    Rails.logger.error("[AiFollowUp] bitácora del caso: #{e.message}")
  end

  def assign
    return unless @user

    @conversation.update!(assignee: @user)
  rescue StandardError => e
    Rails.logger.error("[AiFollowUp] asignar: #{e.message}")
  end
end
