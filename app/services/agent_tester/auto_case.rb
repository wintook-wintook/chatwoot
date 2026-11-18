# frozen_string_literal: true

# Probador de agentes — las pruebas van solas al lote del agente y del día, «Pruebas · <agente> ·
# 17 nov» (se crea solo; ahí caen las de todos los usuarios):
#   correction  cada 👎 revisado: lo que escribió el cliente hasta la respuesta mala y, como lo
#               esperado, lo que dijo el usuario en el 👎;
#   manual      «Guardar prueba» del probador: la plática que el usuario quiere cuidar y lo que espera.
# El día es el de la bandeja del agente (o México).
# Cuando Kontrolya corrige un error del motor, se vuelve a correr el lote del día en que se reportó.
module AgentTester::AutoCase
  KINDS = %w[prompt content search model engine].freeze
  MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze
  ZONE = 'America/Mexico_City'

  module_function

  # → la prueba (nil si no aplica: solo una pregunta del entrenador, o sin mensajes del cliente).
  # `bad_reply`: la respuesta del 👎, para que el juez sepa qué estaba mal.
  def save(template, messages:, feedback:, kinds:, bad_reply: nil)
    return unless kinds.intersect?(KINDS)

    add(template, messages: messages, expected: feedback, origin: 'correction', bad_reply: bad_reply)
  end

  # → la prueba, nueva o la igual que ya estaba (nil si no hay mensajes del cliente o no dice qué
  # se espera). Su lote es `prueba.batch`.
  def add(template, messages:, expected:, origin:, bad_reply: nil)
    customer = Array(messages).filter_map { |m| m['content'].to_s.strip.presence if m['role'] == 'user' }
    return if customer.empty? || expected.blank?

    batch = batch_for(template)
    customer = customer.last(AgentTestCase::MAX_MESSAGES)
    batch.cases.where('messages = ?::jsonb AND expected = ?', customer.to_json, expected).first ||
      batch.cases.create!(account: template.account, name: expected.first(120), messages: customer, expected: expected,
                          origin: origin, bad_reply: bad_reply.to_s.strip.first(4000).presence)
  end

  def today(template, at = Time.current)
    zone = ActiveSupport::TimeZone[template.inbox&.timezone.to_s] || ActiveSupport::TimeZone[ZONE]
    at.in_time_zone(zone).to_date
  end

  def batch_for(template, day = today(template))
    AgentTestBatch.find_or_create_by!(account: template.account, tracking_template: template, day: day) do |batch|
      batch.name = "Pruebas · #{template.name} · #{day.day} #{MONTHS[day.month - 1]}".first(120)
    end
  end

  # Todas las pruebas de un agente (todos sus días), en una sola corrida.
  def run_all(template, user: nil)
    batches = AgentTestBatch.where(account: template.account, tracking_template: template)
    ids = AgentTestCase.where(agent_test_batch_id: batches.select(:id)).order(:id).ids
    return if ids.empty?

    AgentTestRun.start!(batch: batches.order(:day).last, template: template, user: user, case_ids: ids,
                        label: "Todas las pruebas · #{template.name}")
  end

  # Al corregirse un error del motor: el lote del día en que se reportó.
  def rerun(template, at:, user: nil)
    batch = AgentTestBatch.find_by(account: template.account, tracking_template: template, day: today(template, at))
    return unless batch&.cases&.exists?

    AgentTestRun.start!(batch: batch, template: template, user: user)
  end
end
