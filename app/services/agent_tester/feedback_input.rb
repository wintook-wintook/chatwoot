# frozen_string_literal: true

# Probador de agentes — lo que necesita el entrenador (AgentTester::Trainer#call) de un 👎: la
# plática hasta esa respuesta, la respuesta, su traza y las variables de la plática. Lo usan el
# 👎 al momento (quien entrena con «Ver diagnóstico al momento») y AgentTester::DiagnoseJob.
module AgentTester::FeedbackInput
  module_function

  def for(conversation, message, feedback:, note: nil, review_note: nil)
    { messages: Motor2::Prompt.history(conversation, upto: message).map(&:stringify_keys), reply: message.content,
      feedback: feedback.to_s.first(2000), note: note.to_s.first(2000).presence, review_note: review_note.to_s.first(2000).presence,
      trace: AgentTester::Trace.normalize(message.content_attributes.to_h),
      variables: AgentTester::Sandbox.new(conversation.account).variables_for(conversation),
      conversation_id: conversation.id, message_id: message.id }
  end
end
