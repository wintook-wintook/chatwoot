# frozen_string_literal: true

# ================================================================================
# proyecto@diagrama_agente_ia — F3: TODA LA PILA EN SECO
# ================================================================================
# Cada prueba de la pila del agente contra un texto (el borrador, o lo recién publicado:
# D5), con DryRunService: la ruta que elige el clasificador real, la fuente y lo que
# trae su búsqueda. No redacta ni envía nada; cuesta una clasificación por prueba.
#
# Cada resultado queda en la prueba (last_dry, y el que había pasa a previous_dry) con
# su firma de camino. Las que cambiaron de camino se anotan en el avance (`changed`):
# es lo que el panel ofrece correr en vivo al publicar.
# ================================================================================

class ContactTrackings::Assistant::TestCasesDryJob < ApplicationJob
  queue_as :low

  TestCases = ContactTrackings::Assistant::TestCases

  def perform(account_id, template_id, draft, inbox_id = nil, trigger = 'manual')
    account = Account.find(account_id)
    template = account.tracking_templates.find(template_id)
    cambiadas = run_all(account, template, draft, inbox_id && account.inboxes.find_by(id: inbox_id), trigger)
    save!(template, trigger, 'status' => 'done', 'done' => template.test_cases.count, 'changed' => cambiadas,
                             'finished_at' => Time.current.iso8601)
  rescue StandardError => e
    Rails.logger.error "[TestCasesDry] #{e.class}: #{e.message}"
    save!(template, trigger, 'status' => 'failed') if template
  end

  private

  def run_all(account, template, draft, inbox, trigger)
    casos = template.test_cases.ordered.to_a
    casos.each_with_index.with_object([]) do |(caso, i), cambiadas|
      cambiadas << caso.id if run_one(account, caso, draft, inbox)
      save!(template, trigger, 'status' => 'running', 'total' => casos.size, 'done' => i + 1, 'changed' => cambiadas)
    end
  end

  # true si su camino cambió respecto de la corrida anterior.
  def run_one(account, caso, draft, inbox)
    TestCases.run_one_dry(account, caso, draft: draft, inbox: inbox)
  rescue StandardError => e
    Rails.logger.warn "[TestCasesDry] prueba ##{caso.id}: #{e.message}"
    false
  end

  def save!(template, trigger, cambios)
    anterior = Rails.cache.read(TestCases.dry_key(template.id)) || {}
    Rails.cache.write(TestCases.dry_key(template.id), anterior.merge('trigger' => trigger).merge(cambios), expires_in: TestCases::TTL)
  end
end
