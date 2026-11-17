# frozen_string_literal: true

# Probador de agentes — cada 👎 revisado queda solo como prueba, en el lote «Correcciones · <agente>»
# (uno por agente, se crea solo): lo que escribió el cliente hasta la respuesta mala y, como lo
# esperado, lo que dijo el usuario en el 👎. Así, al cambiar el agente, se corre ese lote y se ve si
# algún error de antes volvió. Cuando Kontrolya corrige un error del motor, se vuelve a correr.
module AgentTester::AutoCase
  KINDS = %w[prompt content model engine].freeze

  module_function

  # → el lote (nil si no aplica: solo una pregunta del entrenador, o sin mensajes del cliente).
  def save(template, messages:, feedback:, kinds:)
    customer = Array(messages).filter_map { |m| m['content'].to_s.strip.presence if m['role'] == 'user' }
    return if !kinds.intersect?(KINDS) || customer.empty? || feedback.blank?

    batch = batch_for(template)
    customer = customer.last(AgentTestCase::MAX_MESSAGES)
    unless batch.cases.exists?(['messages = ?::jsonb AND expected = ?', customer.to_json, feedback])
      batch.cases.create!(account: template.account, name: feedback.first(120), messages: customer, expected: feedback)
    end
    batch
  end

  def batch_for(template)
    AgentTestBatch.find_or_create_by!(account: template.account, tracking_template: template) do |batch|
      batch.name = "Correcciones · #{template.name}".first(120)
    end
  end

  # Al corregirse un error del motor: se corre el lote de correcciones de ese agente.
  def rerun(template, user: nil)
    batch = AgentTestBatch.find_by(account: template.account, tracking_template: template)
    return unless batch&.cases&.exists?

    run = batch.runs.create!(account: template.account, tracking_template: template, created_by: user, total: batch.cases.count)
    AgentTester::RunJob.perform_later(run.id)
    run
  end
end
