# frozen_string_literal: true

# Probador de agentes — el diagnóstico de un 👎, en segundo plano. Quien probó solo dijo qué debió
# responder (y, si quiso, qué estuvo mal); la causa la ve después quien revisa (pestaña
# «Revisión»). La primera causa se escribe en el mismo AgentTestLog «pending» que dejó el 👎.
#
# review_note: lo que pidió quien revisa con «Otro diagnóstico».
class AgentTester::DiagnoseJob < ApplicationJob
  queue_as :low

  def perform(log_id, review_note = nil)
    log = AgentTestLog.find_by(id: log_id)
    return unless log&.diagnosing?

    run(log, review_note)
  rescue StandardError => e
    Rails.logger.error("[AgentTester::DiagnoseJob] #{log_id}: #{e.class}: #{e.message}")
    fail_with(log, 'No se pudo revisar esta respuesta.') if log
  end

  private

  def run(log, review_note)
    message = Message.find_by(id: log.message_id)
    return fail_with(log, 'Ya no existe la plática de prueba.') unless message&.conversation && log.tracking_template

    result = diagnose(log, message, review_note)
    fail_with(log, result[:messages].first&.dig(:text)) if log.reload.diagnosing?
  end

  def diagnose(log, message, review_note)
    input = AgentTester::FeedbackInput.for(message.conversation, message, feedback: log.feedback, note: log.note,
                                                                          review_note: review_note)
    AgentTester::Trainer.new(log.tracking_template, user: log.user).call(**input, into: log)
  end

  # Sin causa: queda pendiente con el motivo, para «Otro diagnóstico».
  def fail_with(log, text)
    log.update!(diagnosis: log.diagnosis.to_h.merge('error' => text.presence || 'No se pudo revisar esta respuesta.'))
  end
end
