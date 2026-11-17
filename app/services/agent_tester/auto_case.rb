# frozen_string_literal: true

# Probador de agentes — cada 👎 revisado queda solo como prueba en el lote del agente y del día,
# «Correcciones · <agente> · 17 nov» (se crea solo con el primer 👎 del día; ahí caen los de todos
# los usuarios). La prueba es lo que escribió el cliente hasta la respuesta mala y, como lo
# esperado, lo que dijo el usuario en el 👎. El día es el de la bandeja del agente (o México).
# Cuando Kontrolya corrige un error del motor, se vuelve a correr el lote del día en que se reportó.
module AgentTester::AutoCase
  KINDS = %w[prompt content model engine].freeze
  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze
  ZONE = 'America/Mexico_City'

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

  def today(template, at = Time.current)
    zone = ActiveSupport::TimeZone[template.inbox&.timezone.to_s] || ActiveSupport::TimeZone[ZONE]
    at.in_time_zone(zone).to_date
  end

  def batch_for(template, day = today(template))
    AgentTestBatch.find_or_create_by!(account: template.account, tracking_template: template, day: day) do |batch|
      batch.name = "Correcciones · #{template.name} · #{day.day} #{MONTHS[day.month - 1]}".first(120)
    end
  end

  # Todas las pruebas de corrección de un agente (todos sus días), en una sola corrida.
  def run_all(template, user: nil)
    batches = AgentTestBatch.where(account: template.account, tracking_template: template)
    ids = AgentTestCase.where(agent_test_batch_id: batches.select(:id)).order(:id).ids
    return if ids.empty?

    run = batches.order(:day).last.runs.create!(account: template.account, tracking_template: template, created_by: user,
                                                total: ids.size, case_ids: ids, label: "Todas las correcciones · #{template.name}")
    AgentTester::RunJob.perform_later(run.id)
    run
  end

  # Al corregirse un error del motor: el lote del día en que se reportó.
  def rerun(template, at:, user: nil)
    batch = AgentTestBatch.find_by(account: template.account, tracking_template: template, day: today(template, at))
    return unless batch&.cases&.exists?

    run = batch.runs.create!(account: template.account, tracking_template: template, created_by: user, total: batch.cases.count)
    AgentTester::RunJob.perform_later(run.id)
    run
  end
end
