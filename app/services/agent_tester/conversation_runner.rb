# frozen_string_literal: true

# Probador de agentes — una prueba completa en el canal de pruebas: el cliente manda sus mensajes
# uno por uno, se espera a que el agente conteste (y se quede callado) y se juzga la última
# respuesta. Lo usa la corrida de lotes; el chat del probador va turno por turno desde la pantalla.
class AgentTester::ConversationRunner
  POLL = 3
  QUIET = 8
  MAX_WAIT = 100

  def initialize(template, user:)
    @template = template
    @sandbox = AgentTester::Sandbox.new(template.account)
    @user = user
  end

  def run(test_case)
    conversation = @sandbox.start(@template, user: @user)
    return { name: test_case.name, ok: false, reason: 'No se pudo asignar el agente a la plática de prueba.' } unless conversation

    turns, last = converse(conversation, test_case.messages)
    verdict = AgentTester::Judge.new(account: @template.account).call(turns: turns, reply: last[:text], expected: test_case.expected)
    { case_id: test_case.id, name: test_case.name, conversation_id: conversation.display_id, reply: last[:text].to_s,
      trace: last[:trace], **verdict }
  end

  private

  # [la plática para el juez, la última respuesta]
  def converse(conversation, messages)
    turns = []
    last = {}
    Array(messages).compact_blank.each do |text|
      sent = @sandbox.say(conversation, text)
      turns << { 'role' => 'user', 'content' => text }
      last = wait_reply(conversation, sent.id)
      turns << { 'role' => 'assistant', 'content' => last[:text] } if last[:text].present?
    end
    [turns, last]
  end

  def wait_reply(conversation, after_id)
    started = Time.current
    sleep POLL until quiet?(conversation, after_id) || Time.current - started > MAX_WAIT
    out = replies(conversation, after_id)
    { text: out.pluck(:content).compact_blank.join("\n\n"), trace: out.pluck(:trace).find(&:present?) }
  end

  # Ya contestó y lleva QUIET segundos callado.
  def quiet?(conversation, after_id)
    out = replies(conversation, after_id)
    out.any? && Time.current - out.last[:created_at] > QUIET
  end

  # Sin caché de consultas: el job corre dentro del executor de Rails (caché de SQL activa) y la
  # respuesta la escribe otro proceso; con caché, la misma consulta devolvía siempre «nada» y la
  # corrida esperaba MAX_WAIT por mensaje y acababa en «El agente no contestó nada».
  def replies(conversation, after_id)
    ActiveRecord::Base.uncached { @sandbox.since(conversation, after_id).reject { |m| m[:private] } }
  end
end
