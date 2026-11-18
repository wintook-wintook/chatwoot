# frozen_string_literal: true

# Probador de agentes — cómo se entregan a la pantalla un 👎 (AgentTestLog), un mensaje de la
# plática y la plática misma. Lo usan el probador y «Revisión».
module AgentTester::LogJson
  module_function

  def call(log)
    { id: log.id, kind: log.kind, engine: log.engine, agent: log.tracking_template&.name, template_id: log.tracking_template_id,
      user: log.user&.name, feedback: log.feedback, note: log.note, reply: log.reply, created_at: log.created_at,
      report_status: report_status(log), conversation_id: log.conversation_id, message_id: log.message_id,
      status: log.status, retest: log.retest, has_case: log.agent_test_case_id.present?,
      dismissed_reason: log.dismissed_reason }.merge(diagnosis_json(log))
  end

  def diagnosis_json(log)
    diagnosis = log.diagnosis.to_h
    { diagnosis: diagnosis, diagnosing: log.diagnosing?, canned_id: diagnosis['canned_id'], error: diagnosis['error'] }
  end

  # Para quien solo prueba: su 👎 y cómo va, sin el diagnóstico (eso es de quien revisa).
  def tester(log)
    call(log).slice(:id, :agent, :template_id, :user, :feedback, :note, :reply, :created_at, :conversation_id, :status,
                    :dismissed_reason).merge(kind: 'pending', diagnosis: {})
  end

  def report_status(log)
    log.motor2_report_id && Motor2Report.find_by(id: log.motor2_report_id)&.status
  end

  def message(message, account)
    role = 'assistant'
    role = 'note' if message.private
    role = 'user' if message.incoming?
    { id: message.id, role: role, content: message.content.to_s,
      lines: AgentTester::Trace.lines(AgentTester::Trace.normalize(message.content_attributes.to_h), account: account) }
  end

  def session(conversation, template)
    { conversation_id: conversation.id, display_id: conversation.display_id, template_id: template.id, engine: template.engine,
      name: template.name, after: conversation.messages.maximum(:id).to_i }
  end
end
