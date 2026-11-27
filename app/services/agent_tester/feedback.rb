# frozen_string_literal: true

# Probador de agentes — lo que hace quien prueba con una respuesta del agente:
#   👎 down  dice qué debió responder (y, opcional, qué estuvo mal). Queda un AgentTestLog
#            «pending» con su prueba, y el diagnóstico corre aparte (AgentTester::DiagnoseJob):
#            la causa la ve quien revisa, no quien prueba.
#   👍 up    la respuesta estaba bien: queda como prueba «a cuidar» (origin 'good').
# La marca (👍/👎) queda en el mensaje, para verla en «Revisión».
class AgentTester::Feedback
  def initialize(conversation, message, template:, user:)
    @conversation = conversation
    @message = message
    @template = template
    @user = user
  end

  def down(input)
    rate('down')
    log = AgentTestLog.create!(account: @conversation.account, tracking_template: @template, user: @user,
                               engine: Motor2.on?(@template) ? '2' : '1', kind: 'pending', status: 'pending',
                               feedback: input[:feedback], note: input[:note], reply: @message.content,
                               conversation_id: @conversation.id, message_id: @message.id)
    test_case = AgentTester::AutoCase.add(@template, messages: input[:messages], expected: input[:feedback], origin: 'correction',
                                                     bad_reply: @message.content, variables: input[:variables])
    log.update!(agent_test_case: test_case) if test_case
    AgentTester::DiagnoseJob.perform_later(log.id)
    { queued: true, log_id: log.id, saved_in: test_case&.batch&.name }
  end

  def up
    rate('up')
    turns = Motor2::Prompt.history(@conversation, upto: @message).map(&:stringify_keys)
    test_case = AgentTester::AutoCase.add(@template, messages: turns, origin: 'good',
                                                     expected: "Que conteste como esta respuesta, que estaba bien: #{@message.content}",
                                                     variables: AgentTester::Sandbox.new(@conversation.account).variables_for(@conversation))
    { saved_in: test_case&.batch&.name }
  end

  # Sin callbacks: es una plática de prueba.
  def rate(value)
    @message.update_columns(content_attributes: @message.content_attributes.to_h.merge('agent_tester_rating' => value)) # rubocop:disable Rails/SkipsModelValidations
  end
end
